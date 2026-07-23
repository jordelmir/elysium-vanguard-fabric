import Foundation
import AppKit
import CoreGraphics
import VanguardDomain

// MARK: - CGEvent Input Dispatch Service (macOS)

public final class CGEventInputDispatchService: InputDispatchService, @unchecked Sendable {
    private var pressedKeys: Set<UInt16> = []
    private var pressedButtons: Set<MouseButton> = []
    private let lock = NSLock()

    public init() {}

    public func dispatch(_ event: RemoteInputEvent) async throws {
        guard await isAccessibilityAuthorized() else {
            throw InputError.accessibilityPermissionDenied
        }

        switch event {
        case .mouseMove(let normalizedX, let normalizedY, _):
            try dispatchMouseMove(x: normalizedX, y: normalizedY)

        case .mouseButton(let button, let phase, let normalizedX, let normalizedY):
            try dispatchMouseButton(button: button, phase: phase, x: normalizedX, y: normalizedY)

        case .scroll(let deltaX, let deltaY, let phase, _):
            try dispatchScroll(deltaX: deltaX, deltaY: deltaY, phase: phase)

        case .key(let keyCode, let phase, let modifiers, let isRepeat):
            try dispatchKey(keyCode: keyCode, phase: phase, modifiers: modifiers, isRepeat: isRepeat)

        case .releaseAll:
            await releaseAllKeys()
        }
    }

    public func releaseAllKeys() async {
        lock.withLock {
            for keyCode in pressedKeys {
                let source = CGEventSource(stateID: .hidSystemState)
                if let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                    event.post(tap: .cghidEventTap)
                }
            }
            pressedKeys.removeAll()

            for button in pressedButtons {
                let source = CGEventSource(stateID: .hidSystemState)
                let cgButton: CGMouseButton
                switch button {
                case .left: cgButton = .left
                case .right: cgButton = .right
                case .middle: cgButton = .center
                }
                if let event = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: .zero, mouseButton: cgButton) {
                    event.post(tap: .cghidEventTap)
                }
            }
            pressedButtons.removeAll()
        }
    }

    public func isAccessibilityAuthorized() async -> Bool {
        return AXIsProcessTrusted()
    }

    public func requestAccessibility() async -> Bool {
        return AXIsProcessTrusted()
    }

    // MARK: - Private dispatch

    private func dispatchMouseMove(x: Double, y: Double) throws {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let point = CGPoint(
            x: x * screenFrame.width,
            y: (1.0 - y) * screenFrame.height
        )

        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else {
            throw InputError.invalidCoordinates(x: x, y: y)
        }
        event.post(tap: .cghidEventTap)
    }

    private func dispatchMouseButton(button: MouseButton, phase: ButtonPhase, x: Double, y: Double) throws {
        let screenFrame = NSScreen.main?.frame ?? .zero
        let point = CGPoint(
            x: x * screenFrame.width,
            y: (1.0 - y) * screenFrame.height
        )

        let cgButton: CGMouseButton
        switch button {
        case .left: cgButton = .left
        case .right: cgButton = .right
        case .middle: cgButton = .center
        }

        let mouseType: CGEventType
        switch (button, phase) {
        case (.left, .down): mouseType = .leftMouseDown
        case (.left, .up): mouseType = .leftMouseUp
        case (.right, .down): mouseType = .rightMouseDown
        case (.right, .up): mouseType = .rightMouseUp
        case (.middle, .down): mouseType = .otherMouseDown
        case (.middle, .up): mouseType = .otherMouseUp
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: mouseType, mouseCursorPosition: point, mouseButton: cgButton) else {
            throw InputError.invalidCoordinates(x: x, y: y)
        }
        event.post(tap: .cghidEventTap)

        lock.withLock {
            if phase == .down {
                pressedButtons.insert(button)
            } else {
                pressedButtons.remove(button)
            }
        }
    }

    private func dispatchScroll(deltaX: Double, deltaY: Double, phase: ScrollPhase) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: Int32(deltaY), wheel2: Int32(deltaX), wheel3: 0) else {
            return
        }
        event.post(tap: .cghidEventTap)
    }

    private func dispatchKey(keyCode: UInt16, phase: KeyPhase, modifiers: ModifierSet, isRepeat: Bool) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: phase == .down) else {
            throw InputError.invalidKeyCode(keyCode)
        }

        var flags: CGEventFlags = []
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.capsLock) { flags.insert(.maskAlphaShift) }
        if modifiers.contains(.function) { flags.insert(.maskSecondaryFn) }
        event.flags = flags

        event.post(tap: .cghidEventTap)

        lock.withLock {
            if phase == .down {
                pressedKeys.insert(keyCode)
            } else {
                pressedKeys.remove(keyCode)
            }
        }
    }
}
