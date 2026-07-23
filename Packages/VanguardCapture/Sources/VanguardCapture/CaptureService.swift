import Foundation
import VanguardDomain

// MARK: - Screen Capture Service Protocol

public protocol ScreenCaptureService: Sendable {
    func availableSources() async throws -> [CaptureSource]
    func startCapture(
        source: CaptureSource,
        configuration: CaptureConfiguration
    ) async throws -> AsyncThrowingStream<Data, Error>
    func stopCapture() async
    var stateUpdates: AsyncStream<CaptureState> { get }
}
