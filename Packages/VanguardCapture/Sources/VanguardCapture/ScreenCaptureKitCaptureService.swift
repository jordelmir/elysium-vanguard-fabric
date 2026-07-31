import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import VanguardDomain

public enum CapturePreset {
    case text
    case balanced
    case fluid
    case ultra

    public static func configuration(for preset: CapturePreset) -> CaptureConfiguration {
        switch preset {
        case .text: return CaptureConfiguration(maxWidth: 800, maxHeight: 600, fps: 15)
        case .balanced: return CaptureConfiguration(maxWidth: 1280, maxHeight: 720, fps: 30)
        case .fluid: return CaptureConfiguration(maxWidth: 1920, maxHeight: 1080, fps: 60)
        case .ultra: return CaptureConfiguration(maxWidth: 3840, maxHeight: 2160, fps: 60)
        }
    }
}

@available(macOS 12.3, *)
public final class ScreenCaptureKitCaptureService: NSObject, ScreenCaptureService, SCStreamOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var _stream: SCStream?
    private var _frameContinuation: AsyncThrowingStream<CapturedVideoFrame, Error>.Continuation?
    private var _currentState: CaptureState = .idle
    private var _stateContinuation: AsyncStream<CaptureState>.Continuation?
    private var _frameCount: UInt64 = 0
    private var _selectedDisplayID: CGDirectDisplayID = 0
    private var _captureMode: WindowCaptureMode = .display
    private var _selectedWindowID: UInt32 = 0

    public override init() { super.init() }

    public var stateUpdates: AsyncStream<CaptureState> {
        AsyncStream { [weak self] continuation in
            guard let self else { return }
            self.lock.withLock { self._stateContinuation = continuation }
        }
    }

    public var currentDisplayID: UInt32 {
        lock.withLock { _selectedDisplayID }
    }

    public var currentCaptureMode: WindowCaptureMode {
        lock.withLock { _captureMode }
    }

    private func updateState(_ newState: CaptureState) {
        lock.withLock {
            _currentState = newState
            _stateContinuation?.yield(newState)
        }
    }

    public func availableSources() async throws -> [CaptureSource] {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays.map {
            CaptureSource(id: $0.displayID.description, name: "Display \($0.displayID)", type: .display, width: $0.width, height: $0.height)
        }
    }

    public func availableWindows() async throws -> [RemoteWindowDescriptor] {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.windows.compactMap { window in
            guard window.isOnScreen, !window.frame.isEmpty else { return nil }
            let bundleID = window.owningApplication?.bundleIdentifier ?? "unknown"
            let title = window.title ?? "Untitled"
            let bounds = WindowBounds(
                x: Double(window.frame.origin.x),
                y: Double(window.frame.origin.y),
                width: Double(window.frame.width),
                height: Double(window.frame.height)
            )
            return RemoteWindowDescriptor(
                windowID: window.windowID,
                appBundleID: bundleID,
                title: title,
                bounds: bounds,
                isMinimized: false,
                isMovable: true
            )
        }
    }

    public func availableDisplays() async throws -> [DisplayDescriptor] {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays.map { display in
            let bounds = CGDisplayBounds(display.displayID)
            return DisplayDescriptor(
                id: display.displayID,
                name: "Display \(display.displayID)",
                width: display.width,
                height: display.height,
                originX: Double(bounds.origin.x),
                originY: Double(bounds.origin.y),
                backingScaleFactor: 2.0,
                isMain: CGDisplayIsMain(display.displayID) != 0,
                isBuiltIn: CGDisplayIsBuiltin(display.displayID) != 0
            )
        }
    }

    private func makeStream(source: CaptureSource, configuration: CaptureConfiguration) async throws -> (filter: SCContentFilter, config: SCStreamConfiguration, stream: SCStream, displayID: CGDirectDisplayID) {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID.description == source.id }) ?? content.displays.first else {
            throw CaptureError.noDisplayAvailable
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = min(display.width, configuration.maxWidth)
        streamConfig.height = min(display.height, configuration.maxHeight)
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.fps))
        streamConfig.queueDepth = 3
        streamConfig.showsCursor = configuration.includeCursor
        return (filter, streamConfig, SCStream(filter: filter, configuration: streamConfig, delegate: nil), display.displayID)
    }

    private func makeWindowStream(windowID: UInt32, configuration: CaptureConfiguration) async throws -> (filter: SCContentFilter, config: SCStreamConfiguration, stream: SCStream, displayID: CGDirectDisplayID) {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permissionDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.noDisplayAvailable
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = min(Int(window.frame.width), configuration.maxWidth)
        streamConfig.height = min(Int(window.frame.height), configuration.maxHeight)
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.fps))
        streamConfig.queueDepth = 3
        streamConfig.showsCursor = configuration.includeCursor
        let windowCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        var bestDisplay: CGDirectDisplayID = 0
        var bestArea: CGFloat = 0
        for display in content.displays {
            let bounds = CGDisplayBounds(display.displayID)
            if bounds.contains(windowCenter) {
                bestDisplay = display.displayID
                break
            }
            let intersection = bounds.intersection(window.frame)
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestDisplay = display.displayID
            }
        }
        return (filter, streamConfig, SCStream(filter: filter, configuration: streamConfig, delegate: nil), bestDisplay)
    }

    public func startCapture(source: CaptureSource, configuration: CaptureConfiguration) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error> {
        let (_, _, stream, displayID) = try await makeStream(source: source, configuration: configuration)
        let (streamAsync, continuation) = AsyncThrowingStream<CapturedVideoFrame, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(2)
        )
        lock.withLock {
            self._frameContinuation = continuation
            self._frameCount = 0
            self._selectedDisplayID = displayID
            self._captureMode = .display
        }
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        try await stream.startCapture()
        lock.withLock { self._stream = stream }
        updateState(.streaming)
        return streamAsync
    }

    public func startWindowCapture(windowID: UInt32, configuration: CaptureConfiguration) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error> {
        let (_, _, stream, displayID) = try await makeWindowStream(windowID: windowID, configuration: configuration)
        let (streamAsync, continuation) = AsyncThrowingStream<CapturedVideoFrame, Error>.makeStream(
            bufferingPolicy: .bufferingNewest(2)
        )
        lock.withLock {
            self._frameContinuation = continuation
            self._frameCount = 0
            self._selectedDisplayID = displayID
            self._selectedWindowID = windowID
            self._captureMode = .window
        }
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInitiated))
        try await stream.startCapture()
        lock.withLock { self._stream = stream }
        updateState(.streaming)
        return streamAsync
    }

    public func switchDisplay(displayID: UInt32, configuration: CaptureConfiguration) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error> {
        await stopCapture()
        let source = CaptureSource(id: displayID.description, name: "Display \(displayID)", type: .display, width: 0, height: 0)
        return try await startCapture(source: source, configuration: configuration)
    }

    public func stopCapture() async {
        let streamToStop: SCStream? = lock.withLock { let s = _stream; _stream = nil; return s }
        if let stream = streamToStop { try? await stream.stopCapture() }
        let dc: AsyncThrowingStream<CapturedVideoFrame, Error>.Continuation? = lock.withLock { let c = _frameContinuation; _frameContinuation = nil; return c }
        dc?.finish()
        lock.withLock { _captureMode = .display }
        updateState(.stopped)
    }

    nonisolated public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        let displayID: CGDirectDisplayID = lock.withLock { self._selectedDisplayID }

        let frame = CapturedVideoFrame(
            pixelBuffer: imageBuffer,
            presentationTimeStamp: pts,
            displayID: displayID
        )

        let continuation = self.lock.withLock { self._frameContinuation }
        continuation?.yield(frame)
    }
}
