import Foundation
import CoreVideo
import VanguardDomain

public protocol ScreenCaptureService: Sendable {
    func availableSources() async throws -> [CaptureSource]
    func availableWindows() async throws -> [RemoteWindowDescriptor]
    func availableDisplays() async throws -> [DisplayDescriptor]
    func startCapture(
        source: CaptureSource,
        configuration: CaptureConfiguration
    ) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error>
    func startWindowCapture(
        windowID: UInt32,
        configuration: CaptureConfiguration
    ) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error>
    func switchDisplay(
        displayID: UInt32,
        configuration: CaptureConfiguration
    ) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error>
    func stopCapture() async
    var stateUpdates: AsyncStream<CaptureState> { get }
    var currentDisplayID: UInt32 { get }
    var currentCaptureMode: WindowCaptureMode { get }
}
