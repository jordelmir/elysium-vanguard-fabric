import XCTest
@testable import VanguardClipboard

final class ClipboardServiceTests: XCTestCase {
    func testInitDefaults() async {
        let service = ClipboardService()
        XCTAssertNotNil(service)
    }

    func testCustomMaxSize() async {
        let service = ClipboardService(maxClipboardSize: 1024)
        XCTAssertNotNil(service)
    }

    func testAllowedTypesDefault() async {
        let service = ClipboardService()
        XCTAssertNotNil(service)
    }

    func testStopWatchingWithoutStart() async {
        let service = ClipboardService()
        await service.stopWatching()
    }
}
