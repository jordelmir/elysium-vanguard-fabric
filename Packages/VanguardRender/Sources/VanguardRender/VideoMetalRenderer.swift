import Foundation
import CoreVideo
import Metal
import MetalKit
import VanguardDomain

public enum RendererError: Error, Sendable {
    case metalUnavailable
    case commandQueueCreationFailed
    case textureCacheCreationFailed
    case shaderCompilationFailed(String)
    case pipelineStateCreationFailed(String)
    case pixelBufferCreationFailed(Int32)
    case textureCreationFailed(Int32)
    case bufferAllocationFailed
}

public protocol MetalRenderer: Sendable {
    func renderFrame(_ data: Data, width: Int, height: Int) async throws
    func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer) async throws
    func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) async throws
    func startRendering() async throws
    func stopRendering() async
}

private let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 texSize;
    float2 viewSize;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant float2 *positions [[buffer(0)]],
                              constant float2 *texCoords [[buffer(1)]]) {
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]],
                                constant Uniforms &uniforms [[buffer(0)]]) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear);

    float texAspect = uniforms.texSize.x / uniforms.texSize.y;
    float viewAspect = uniforms.viewSize.x / uniforms.viewSize.y;

    float scaleX = 1.0;
    float scaleY = 1.0;

    if (texAspect > viewAspect) {
        scaleY = viewAspect / texAspect;
    } else {
        scaleX = texAspect / viewAspect;
    }

    float2 centered = in.texCoord - float2(0.5);
    float2 scaled = float2(centered.x / scaleX, centered.y / scaleY);
    float2 finalCoord = scaled + float2(0.5);

    if (finalCoord.x < 0.0 || finalCoord.x > 1.0 || finalCoord.y < 0.0 || finalCoord.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    return tex.sample(texSampler, finalCoord);
}
"""

private let kMaxInflightBuffers = 3

public final class VideoMetalRenderer: NSObject, MetalRenderer, MTKViewDelegate, @unchecked Sendable {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var textureCache: CVMetalTextureCache?
    private var mtkView: MTKView?

    private let lock = NSLock()
    private var inflightSemaphore = DispatchSemaphore(value: kMaxInflightBuffers)
    private var inflightIndex = 0
    private var vertexBuffers: [MTLBuffer] = []
    private var texCoordBuffers: [MTLBuffer] = []
    private var uniformBuffers: [MTLBuffer] = []
    private var pendingPixelBuffer: CVPixelBuffer?
    private var pendingTextureSize = CGSize.zero
    public var lastRenderTimestamp: TimeInterval = 0

    private init(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        pipelineState: MTLRenderPipelineState,
        textureCache: CVMetalTextureCache
    ) throws {
        self.device = device
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.textureCache = textureCache
        super.init()

        for _ in 0..<kMaxInflightBuffers {
            guard let vb = device.makeBuffer(length: MemoryLayout<Float>.size * 8, options: .storageModeShared),
                  let tb = device.makeBuffer(length: MemoryLayout<Float>.size * 8, options: .storageModeShared),
                  let ub = device.makeBuffer(length: MemoryLayout<Float>.size * 4, options: .storageModeShared) else {
                throw RendererError.bufferAllocationFailed
            }
            vertexBuffers.append(vb)
            texCoordBuffers.append(tb)
            uniformBuffers.append(ub)
        }
    }

    public static func create() throws -> VideoMetalRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw RendererError.metalUnavailable
        }

        guard let queue = device.makeCommandQueue() else {
            throw RendererError.commandQueueCreationFailed
        }

        var cache: CVMetalTextureCache?
        let cacheStatus = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        guard cacheStatus == kCVReturnSuccess, let cache = cache else {
            throw RendererError.textureCacheCreationFailed
        }

        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: metalShaderSource, options: nil)
        } catch {
            throw RendererError.shaderCompilationFailed("\(error)")
        }

        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        let pipelineState: MTLRenderPipelineState
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            throw RendererError.pipelineStateCreationFailed("\(error)")
        }

        return try VideoMetalRenderer(
            device: device,
            commandQueue: queue,
            pipelineState: pipelineState,
            textureCache: cache
        )
    }

    public func setMTKView(_ view: MTKView) {
        Task { @MainActor in
            self.mtkView = view
            view.device = device
            view.delegate = self
            view.colorPixelFormat = .bgra8Unorm
            view.framebufferOnly = false
            view.preferredFramesPerSecond = 60
            view.enableSetNeedsDisplay = false
            view.isPaused = true
        }
    }

    public func renderFrame(_ data: Data, width: Int, height: Int) async throws {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let createdBuffer = buffer else {
            throw RendererError.pixelBufferCreationFailed(status)
        }

        CVPixelBufferLockBaseAddress(createdBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(createdBuffer, []) }

        guard let dest = CVPixelBufferGetBaseAddress(createdBuffer) else {
            throw RendererError.pixelBufferCreationFailed(-2)
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(createdBuffer)
        let srcBytesPerRow = width * 4

        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            if bytesPerRow == srcBytesPerRow {
                memcpy(dest, baseAddress, width * height * 4)
            } else {
                let srcPtr = baseAddress.assumingMemoryBound(to: UInt8.self)
                let destPtr = dest.assumingMemoryBound(to: UInt8.self)
                for row in 0..<height {
                    memcpy(
                        destPtr.advanced(by: row * bytesPerRow),
                        srcPtr.advanced(by: row * srcBytesPerRow),
                        srcBytesPerRow
                    )
                }
            }
        }

        lock.withLock {
            pendingPixelBuffer = createdBuffer
            pendingTextureSize = CGSize(width: width, height: height)
        }
    }

    public func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer) async throws {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        try await renderPixelBuffer(pixelBuffer, width: width, height: height)
    }

    public func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) async throws {
        guard let textureCache = textureCache else {
            throw RendererError.textureCacheCreationFailed
        }

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTex = cvTexture else {
            throw RendererError.textureCreationFailed(status)
        }

        lock.withLock {
            pendingPixelBuffer = pixelBuffer
            pendingTextureSize = CGSize(width: width, height: height)
        }

        _ = cvTex
    }

    public func startRendering() async throws {
        await MainActor.run {
            self.mtkView?.isPaused = false
            self.mtkView?.enableSetNeedsDisplay = false
        }
    }

    public func stopRendering() async {
        await MainActor.run {
            self.mtkView?.isPaused = true
        }
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        inflightSemaphore.wait()

        let (pixelBuffer, texSize) = lock.withLock {
            (pendingPixelBuffer, pendingTextureSize)
        }

        guard let pixelBuffer = pixelBuffer,
              let textureCache = textureCache else {
            inflightSemaphore.signal()
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess,
              let cvTex = cvTexture,
              let metalTexture = CVMetalTextureGetTexture(cvTex) else {
            inflightSemaphore.signal()
            return
        }

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            inflightSemaphore.signal()
            return
        }

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.inflightSemaphore.signal()
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        let idx = inflightIndex
        inflightIndex = (inflightIndex + 1) % kMaxInflightBuffers

        let positions: [Float] = [
            -1.0,  1.0,
            -1.0, -1.0,
             1.0,  1.0,
             1.0, -1.0
        ]
        let texCoords: [Float] = [
            0.0, 0.0,
            0.0, 1.0,
            1.0, 0.0,
            1.0, 1.0
        ]

        vertexBuffers[idx].contents().copyMemory(from: positions, byteCount: MemoryLayout<Float>.size * 8)
        texCoordBuffers[idx].contents().copyMemory(from: texCoords, byteCount: MemoryLayout<Float>.size * 8)

        let viewSize = view.drawableSize
        let uniforms: [Float] = [
            Float(texSize.width), Float(texSize.height),
            Float(viewSize.width), Float(viewSize.height)
        ]
        uniformBuffers[idx].contents().copyMemory(from: uniforms, byteCount: MemoryLayout<Float>.size * 4)

        renderEncoder.setVertexBuffer(vertexBuffers[idx], offset: 0, index: 0)
        renderEncoder.setVertexBuffer(texCoordBuffers[idx], offset: 0, index: 1)
        renderEncoder.setFragmentTexture(metalTexture, index: 0)
        renderEncoder.setFragmentBuffer(uniformBuffers[idx], offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        lastRenderTimestamp = Date.timeIntervalSinceReferenceDate
    }
}
