import XCTest
import Foundation
@testable import VanguardCapture
@testable import VanguardDomain

@available(macOS 12.3, *)
final class ScreenCaptureKitCaptureServiceTests: XCTestCase {
    func testAvailableSources() async {
        let service = ScreenCaptureKitCaptureService()
        do {
            let sources = try await service.availableSources()
            XCTAssertFalse(sources.isEmpty, "Expected at least one capture source")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("permission") || error.localizedDescription.contains("denied"),
                          "Unexpected error: \(error)")
        }
    }

    func testStopCaptureWhenNotCapturing() async {
        let service = ScreenCaptureKitCaptureService()
        await service.stopCapture()
    }
}
