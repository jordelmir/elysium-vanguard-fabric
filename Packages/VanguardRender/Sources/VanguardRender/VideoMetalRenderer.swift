import Foundation
import Metal
import MetalKit
import VanguardDomain

// MARK: - Metal Renderer Protocol

public protocol MetalRenderer: Sendable {
    func renderFrame(_ data: Data, width: Int, height: Int) async throws
    func startRendering() async throws
    func stopRendering() async
}

// MARK: - Metal Shaders

private let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 positions[4] = {
        float2(-1.0,  1.0),
        float2(-1.0, -1.0),
        float2( 1.0,  1.0),
        float2( 1.0, -1.0)
    };
    float2 texCoords[4] = {
        float2(0.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0)
    };
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                texture2d<float> tex [[texture(0)]]) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear);
    float4 color = tex.sample(texSampler, in.texCoord);
    return color;
}
"""

// MARK: - Metal Renderer Implementation

public final class VideoMetalRenderer: NSObject, MetalRenderer, MTKViewDelegate, @unchecked Sendable {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var texture: MTLTexture?
    private var mtkView: MTKView?

    public override init() {
        super.init()
        setupMetal()
    }

    private func setupMetal() {
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device?.makeCommandQueue()

        guard let device = device else { return }

        do {
            let library = try device.makeLibrary(source: metalShaderSource, options: nil)
            let vertexFunction = library.makeFunction(name: "vertexShader")
            let fragmentFunction = library.makeFunction(name: "fragmentShader")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Metal setup failed: \(error)")
        }
    }

    public func setMTKView(_ view: MTKView) {
        Task { @MainActor in
            self.mtkView = view
            view.device = device
            view.delegate = self
            view.colorPixelFormat = .bgra8Unorm
            view.framebufferOnly = false
        }
    }

    public func renderFrame(_ data: Data, width: Int, height: Int) async throws {
        guard let device = device else { return }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

        guard let newTexture = device.makeTexture(descriptor: textureDescriptor) else { return }

        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            newTexture.replace(
                region: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                 size: MTLSize(width: width, height: height, depth: 1)),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: width * 4
            )
        }

        self.texture = newTexture
        await MainActor.run {
            self.mtkView?.needsDisplay = true
        }
    }

    public func startRendering() async throws {
        await MainActor.run {
            self.mtkView?.isPaused = false
            self.mtkView?.enableSetNeedsDisplay = true
        }
    }

    public func stopRendering() async {
        await MainActor.run {
            self.mtkView?.isPaused = true
        }
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
              let pipelineState = pipelineState else { return }

        renderEncoder.setRenderPipelineState(pipelineState)

        if let texture = texture {
            renderEncoder.setFragmentTexture(texture, index: 0)
        }

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
