import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import VanguardDomain

@available(macOS 12.3, *)
public final class ScreenCaptureKitCaptureService: NSObject, ScreenCaptureService, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var _stream: SCStream?
    private var _frameContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var _currentState: CaptureState = .idle
    private var _stateContinuation: AsyncStream<CaptureState>.Continuation?
    private var _frameCount: UInt64 = 0

    public override init() {
        super.init()
    }

    public var stateUpdates: AsyncStream<CaptureState> {
        AsyncStream { [weak self] continuation in
            guard let self else { return }
            self.lock.withLock {
                self._stateContinuation = continuation
            }
        }
    }

    private func updateState(_ newState: CaptureState) {
        lock.withLock {
            _currentState = newState
            _stateContinuation?.yield(newState)
        }
    }

    public func availableSources() async throws -> [CaptureSource] {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        var sources: [CaptureSource] = []

        for display in content.displays {
            sources.append(CaptureSource(
                id: display.displayID.description,
                name: "Display \(display.displayID)",
                type: .display,
                width: display.width,
                height: display.height
            ))
        }

        return sources
    }

    public func startCapture(
        source: CaptureSource,
        configuration: CaptureConfiguration
    ) async throws -> AsyncThrowingStream<Data, Error> {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        guard let display = content.displays.first(where: {
            $0.displayID.description == source.id
        }) ?? content.displays.first else {
            throw CaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = min(display.width, configuration.maxWidth)
        streamConfig.height = min(display.height, configuration.maxHeight)
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.fps))
        streamConfig.queueDepth = 3
        streamConfig.showsCursor = configuration.includeCursor

        let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)

        let (streamAsync, continuation) = AsyncThrowingStream<Data, Error>.makeStream()

        lock.withLock {
            self._frameContinuation = continuation
            self._frameCount = 0
        }

        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        try await stream.startCapture()

        lock.withLock {
            self._stream = stream
        }
        updateState(.streaming)

        return streamAsync
    }

    public func stopCapture() async {
        let streamToStop: SCStream? = lock.withLock {
            let s = _stream
            _stream = nil
            return s
        }

        if let stream = streamToStop {
            try? await stream.stopCapture()
        }

        let continuation: AsyncThrowingStream<Data, Error>.Continuation? = lock.withLock {
            let c = _frameContinuation
            _frameContinuation = nil
            return c
        }

        continuation?.finish()
        updateState(.stopped)
    }

    nonisolated public func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        guard sampleBuffer.isValid else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)

        guard let baseAddress else { return }

        let dataSize = height * bytesPerRow
        let data = Data(bytes: baseAddress, count: dataSize)

        Task { [weak self] in
            guard let self else { return }
            let continuation = self.lock.withLock { self._frameContinuation }
            continuation?.yield(data)
        }
    }
}
