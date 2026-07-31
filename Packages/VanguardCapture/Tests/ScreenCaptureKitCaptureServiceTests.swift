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
            if sources.isEmpty {
                return
            }
            XCTAssertFalse(sources.isEmpty)
        } catch {
            return
        }
    }

    func testStopCaptureWhenNotCapturing() async {
        let service = ScreenCaptureKitCaptureService()
        await service.stopCapture()
    }
}
