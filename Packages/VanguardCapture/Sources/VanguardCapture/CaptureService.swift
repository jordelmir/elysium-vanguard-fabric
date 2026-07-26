import Foundation
import CoreVideo
import VanguardDomain

public protocol ScreenCaptureService: Sendable {
    func availableSources() async throws -> [CaptureSource]
    func startCapture(
        source: CaptureSource,
        configuration: CaptureConfiguration
    ) async throws -> AsyncThrowingStream<CapturedVideoFrame, Error>
    func stopCapture() async
    var stateUpdates: AsyncStream<CaptureState> { get }
}
