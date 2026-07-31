import Foundation
import VanguardDomain
import CoreGraphics

// MARK: - Input Service Protocol (Console side - captures local input)

public protocol InputCaptureService: Sendable {
    func startCapturing() async throws -> AsyncThrowingStream<RemoteInputEvent, Error>
    func stopCapturing() async
}

// MARK: - Input Dispatch Service Protocol (Node side - dispatches remote input)

public protocol InputDispatchService: Sendable {
    func dispatch(_ event: RemoteInputEvent) async throws
    func releaseAllKeys() async
    func isAccessibilityAuthorized() async -> Bool
    func requestAccessibility() async -> Bool
    func setCapturedDisplayID(_ displayID: CGDirectDisplayID)
    func setPointerContext(_ context: RemotePointerContext)
    func setWindowGeometryMapper(_ mapper: WindowGeometryMapper)
}
