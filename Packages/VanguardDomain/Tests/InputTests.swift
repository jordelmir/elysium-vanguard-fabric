import XCTest
@testable import VanguardDomain
import VanguardTestSupport

final class InputTests: XCTestCase {
    func testRemoteInputEventMouseMove() {
        let event = RemoteInputEvent.mouseMove(
            normalizedX: 0.5,
            normalizedY: 0.5,
            sequence: 1
        )
        if case .mouseMove(let x, let y, let seq) = event {
            XCTAssertEqual(x, 0.5)
            XCTAssertEqual(y, 0.5)
            XCTAssertEqual(seq, 1)
        } else {
            XCTFail("Expected mouseMove event")
        }
    }

    func testRemoteInputEventMouseButton() {
        let event = RemoteInputEvent.mouseButton(
            button: .left,
            phase: .down,
            normalizedX: 0.25,
            normalizedY: 0.75
        )
        if case .mouseButton(let button, let phase, _, _) = event {
            XCTAssertEqual(button, .left)
            XCTAssertEqual(phase, .down)
        } else {
            XCTFail("Expected mouseButton event")
        }
    }

    func testRemoteInputEventKey() {
        let event = RemoteInputEvent.key(
            keyCode: 49,
            phase: .down,
            modifiers: [.command, .shift],
            isRepeat: false
        )
        if case .key(let code, let phase, let mods, let isRepeat) = event {
            XCTAssertEqual(code, 49)
            XCTAssertEqual(phase, .down)
            XCTAssertTrue(mods.contains(.command))
            XCTAssertTrue(mods.contains(.shift))
            XCTAssertFalse(isRepeat)
        } else {
            XCTFail("Expected key event")
        }
    }

    func testModifierSetOptionSet() {
        var mods = ModifierSet()
        mods.insert(.shift)
        mods.insert(.control)
        XCTAssertTrue(mods.contains(.shift))
        XCTAssertTrue(mods.contains(.control))
        XCTAssertFalse(mods.contains(.command))
    }

    func testScrollPhase() {
        XCTAssertEqual(ScrollPhase.began.rawValue, "began")
        XCTAssertEqual(ScrollPhase.changed.rawValue, "changed")
        XCTAssertEqual(ScrollPhase.ended.rawValue, "ended")
    }
}
