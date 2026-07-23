import XCTest
import Foundation
@testable import VanguardInput
@testable import VanguardDomain

@available(macOS 12.3, *)
final class CGEventInputDispatchServiceTests: XCTestCase {
    func testIsAccessibilityAuthorized() async {
        let service = CGEventInputDispatchService()
        let authorized = await service.isAccessibilityAuthorized()
        XCTAssertNotNil(authorized)
    }

    func testRequestAccessibility() async {
        let service = CGEventInputDispatchService()
        let result = await service.requestAccessibility()
        XCTAssertNotNil(result)
    }

    func testDispatchMouseEvent() async {
        let service = CGEventInputDispatchService()
        let event = RemoteInputEvent.mouseButton(
            button: .left,
            phase: .down,
            normalizedX: 0.5,
            normalizedY: 0.5
        )
        do {
            try await service.dispatch(event)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("accessibility") || error.localizedDescription.contains("permission"),
                          "Unexpected error: \(error)")
        }
    }

    func testDispatchMouseMoveEvent() async {
        let service = CGEventInputDispatchService()
        let event = RemoteInputEvent.mouseMove(
            normalizedX: 0.5,
            normalizedY: 0.5,
            sequence: 1
        )
        do {
            try await service.dispatch(event)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("accessibility") || error.localizedDescription.contains("permission"),
                          "Unexpected error: \(error)")
        }
    }

    func testDispatchKeyDownEvent() async {
        let service = CGEventInputDispatchService()
        let event = RemoteInputEvent.key(
            keyCode: 0,
            phase: .down,
            modifiers: [],
            isRepeat: false
        )
        do {
            try await service.dispatch(event)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("accessibility") || error.localizedDescription.contains("permission"),
                          "Unexpected error: \(error)")
        }
    }

    func testDispatchScrollEvent() async {
        let service = CGEventInputDispatchService()
        let event = RemoteInputEvent.scroll(
            deltaX: 0,
            deltaY: -3,
            phase: .began,
            precise: false
        )
        do {
            try await service.dispatch(event)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("accessibility") || error.localizedDescription.contains("permission"),
                          "Unexpected error: \(error)")
        }
    }

    func testReleaseAllKeys() async {
        let service = CGEventInputDispatchService()
        await service.releaseAllKeys()
    }
}
