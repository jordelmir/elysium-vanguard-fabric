import Foundation
import CoreVideo
import os.log
import VanguardCapture
import VanguardVideo
import VanguardTransport
import VanguardRender
import VanguardDomain
import VanguardProtocol

public actor PipelineCoordinator {
    private let captureService: any ScreenCaptureService
    private let encoder: VideoToolboxEncoder
    private let decoder: VideoToolboxDecoder
    private let transport: NetworkTransport
    private let renderer: VideoMetalRenderer

    private var isCapturing = false
    private var isRendering = false
    private var captureTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?

    private var framesCaptured: UInt64 = 0
    private var framesEncoded: UInt64 = 0
    private var framesDecoded: UInt64 = 0
    private var framesRendered: UInt64 = 0
    private var totalEncodeTimeNs: UInt64 = 0
    private var totalDecodeTimeNs: UInt64 = 0
    private var totalRenderLatencyNs: UInt64 = 0

    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Pipeline")

    public init(
        captureService: any ScreenCaptureService,
        encoder: VideoToolboxEncoder,
        decoder: VideoToolboxDecoder,
        transport: NetworkTransport,
        renderer: VideoMetalRenderer
    ) {
        self.captureService = captureService
        self.encoder = encoder
        self.decoder = decoder
        self.transport = transport
        self.renderer = renderer
    }

    public func startCapturePipeline(
        source: CaptureSource,
        configuration: CaptureConfiguration,
        bitrate: Int = 5_000_000
    ) async throws {
        guard !isCapturing else { return }
        isCapturing = true

        try await encoder.configure(
            width: min(source.width, configuration.maxWidth),
            height: min(source.height, configuration.maxHeight),
            fps: configuration.fps,
            bitrate: bitrate
        )

        let stream = try await captureService.startCapture(
            source: source,
            configuration: configuration
        )

        let encoder = self.encoder
        let transport = self.transport

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await capturedFrame in stream {
                    guard !Task.isCancelled else { break }
                    let start = CFAbsoluteTimeGetCurrent()

                    let output = try await encoder.encode(capturedFrame)

                    let encodeTime = CFAbsoluteTimeGetCurrent() - start
                    await self.recordEncodeTime(encodeTime)
                    await self.incrementFramesEncoded()

                    switch output {
                    case .configuration(let config):
                        let payload = try JSONEncoder().encode(config)
                        let message = OutboundMessage(
                            messageType: .videoConfiguration,
                            streamChannel: .video,
                            payload: payload
                        )
                        try await transport.send(message)

                    case .accessUnit(let au):
                        let payload = try JSONEncoder().encode(au)
                        let message = OutboundMessage(
                            messageType: .videoAccessUnit,
                            streamChannel: .video,
                            payload: payload
                        )
                        try await transport.send(message)

                    case .configurationAndAccessUnit(let config, let au):
                        let configPayload = try JSONEncoder().encode(config)
                        let configMsg = OutboundMessage(
                            messageType: .videoConfiguration,
                            streamChannel: .video,
                            payload: configPayload
                        )
                        try await transport.send(configMsg)

                        let auPayload = try JSONEncoder().encode(au)
                        let auMsg = OutboundMessage(
                            messageType: .videoAccessUnit,
                            streamChannel: .video,
                            payload: auPayload
                        )
                        try await transport.send(auMsg)
                    }
                }
            } catch is CancellationError {
            } catch {
                self.logger.error("Capture pipeline error: \(error.localizedDescription)")
            }
        }

        logger.info("Capture pipeline started")
    }

    public func stopCapturePipeline() async {
        captureTask?.cancel()
        captureTask = nil
        await captureService.stopCapture()
        isCapturing = false
        logger.info("Capture pipeline stopped")
    }

    public func startRenderPipeline() async {
        guard !isRendering else { return }
        isRendering = true

        let decoder = self.decoder
        let renderer = self.renderer

        receiveTask = Task { [weak self] in
            guard let self else { return }
            try? await renderer.startRendering()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_666)
                // Rendering is driven by incoming frames via handleIncomingFrame
            }
        }

        logger.info("Render pipeline started")
    }

    public func stopRenderPipeline() async {
        receiveTask?.cancel()
        receiveTask = nil
        await renderer.stopRendering()
        isRendering = false
        logger.info("Render pipeline stopped")
    }

    public func handleIncomingFrame(_ payload: Data) async {
        let start = CFAbsoluteTimeGetCurrent()

        do {
            let auPayload = try JSONDecoder().decode(VideoAccessUnitPayload.self, from: payload)

            let accessUnit = EncodedVideoAccessUnit(
                frameID: auPayload.frameID,
                presentationTimestampNanos: auPayload.presentationTimestampNanos,
                durationNanos: auPayload.durationNanos,
                isKeyframe: auPayload.isKeyframe,
                configurationRevision: auPayload.configurationRevision,
                avccPayload: auPayload.avccData
            )

            let decoded = try await decoder.decode(accessUnit)
            await incrementFramesDecoded()

            let decodeTime = CFAbsoluteTimeGetCurrent() - start
            await recordDecodeTime(decodeTime)

            try? await renderer.renderPixelBuffer(decoded.pixelBuffer)
            await incrementFramesRendered()

            let renderLatency = CFAbsoluteTimeGetCurrent() - start
            await recordRenderLatency(renderLatency)
        } catch {
            logger.error("Failed to handle incoming frame: \(error.localizedDescription)")
        }
    }

    public func handleIncomingConfiguration(_ payload: Data) async {
        do {
            let config = try JSONDecoder().decode(VideoCodecConfigurationPayload.self, from: payload)
            try await decoder.configure(sps: config.sps, pps: config.pps, width: Int(config.width), height: Int(config.height))
        } catch {
            logger.error("Failed to configure decoder: \(error.localizedDescription)")
        }
    }

    public func getStats() async -> PipelineStats {
        let captured = framesCaptured
        let encoded = framesEncoded
        let decoded = framesDecoded
        let rendered = framesRendered
        let avgEncode = encoded > 0 ? Double(totalEncodeTimeNs) / Double(encoded) / 1_000_000 : 0
        let avgDecode = decoded > 0 ? Double(totalDecodeTimeNs) / Double(decoded) / 1_000_000 : 0
        let avgRender = rendered > 0 ? Double(totalRenderLatencyNs) / Double(rendered) / 1_000_000 : 0
        let bitrate = await encoder.currentBitrate

        return PipelineStats(
            framesCaptured: captured,
            framesEncoded: encoded,
            framesDecoded: decoded,
            framesRendered: rendered,
            averageEncodeTimeMs: avgEncode,
            averageDecodeTimeMs: avgDecode,
            averageRenderLatencyMs: avgRender,
            currentBitrate: bitrate
        )
    }

    private func recordEncodeTime(_ seconds: CFAbsoluteTime) {
        totalEncodeTimeNs += UInt64(seconds * 1_000_000_000)
    }

    private func recordDecodeTime(_ seconds: CFAbsoluteTime) {
        totalDecodeTimeNs += UInt64(seconds * 1_000_000_000)
    }

    private func recordRenderLatency(_ seconds: CFAbsoluteTime) {
        totalRenderLatencyNs += UInt64(seconds * 1_000_000_000)
    }

    private func incrementFramesEncoded() {
        framesEncoded += 1
    }

    private func incrementFramesDecoded() {
        framesDecoded += 1
    }

    private func incrementFramesRendered() {
        framesRendered += 1
    }
}

public struct PipelineStats: Sendable {
    public let framesCaptured: UInt64
    public let framesEncoded: UInt64
    public let framesDecoded: UInt64
    public let framesRendered: UInt64
    public let averageEncodeTimeMs: Double
    public let averageDecodeTimeMs: Double
    public let averageRenderLatencyMs: Double
    public let currentBitrate: Int
}

private struct EncodedVideoFramePayload: Codable {
    let frameID: UInt64
    let timestampNanos: UInt64
    let isKeyframe: Bool
    let configRevision: UInt32
    let data: Data
}
