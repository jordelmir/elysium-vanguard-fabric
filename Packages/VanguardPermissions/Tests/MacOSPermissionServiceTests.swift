import XCTest
import Foundation
@testable import VanguardPermissions
@testable import VanguardDomain

@available(macOS 12.3, *)
final class MacOSPermissionServiceTests: XCTestCase {
    func testCheckAllPermissions() async {
        let service = MacOSPermissionService()
        let descriptors = await service.checkAllPermissions()
        XCTAssertFalse(descriptors.isEmpty, "Expected at least one permission descriptor")
    }

    func testCheckScreenRecordingPermission() async {
        let service = MacOSPermissionService()
        let result = await service.checkPermission(kind: .screenRecording)
        XCTAssertTrue(
            result == .granted || result == .denied || result == .notDetermined || result == .unsupported
        )
    }

    func testCheckAccessibilityPermission() async {
        let service = MacOSPermissionService()
        let result = await service.checkPermission(kind: .accessibility)
        XCTAssertTrue(
            result == .granted || result == .denied || result == .notDetermined || result == .unsupported
        )
    }

    func testCheckLocalNetworkPermission() async {
        let service = MacOSPermissionService()
        let result = await service.checkPermission(kind: .localNetwork)
        XCTAssertTrue(
            result == .granted || result == .denied || result == .notDetermined || result == .unsupported
        )
    }
}
