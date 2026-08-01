import Foundation
import AppKit
import CoreGraphics
import os.log
import VanguardDomain

private let logger = Logger(subsystem: "com.elysium.vanguard", category: "InputDispatch")

public final class CGEventInputDispatchService: InputDispatchService, @unchecked Sendable {
    private let lock = NSLock()
    private var pressedKeys: Set<UInt16> = []
    private var pressedButtons: Set<MouseButton> = []
    private var lastMousePosition: CGPoint?
    private var isDragging = false
    private var dragButton: MouseButton?
    private var dragOrigin: CGPoint?
    private var lastClickTimestamp: CGEventTimestamp = 0
    private var lastClickButton: MouseButton?
    private var clickCount: Int = 0
    private var pendingScrollDeltaX: Double = 0
    private var pendingScrollDeltaY: Double = 0
    private var scrollCoalescingTimer: DispatchSourceTimer?
    private let scrollQueue = DispatchQueue(label: "com.elysium.scrollCoalesce", qos: .userInteractive)
    private var mouseMoveCoalescingTimer: DispatchSourceTimer?
    private let mouseMoveQueue = DispatchQueue(label: "com.elysium.mouseMoveCoalesce", qos: .userInteractive)
    private var lastCoalescedPosition: CGPoint?
    private var pendingMouseMoveX: Double = 0
    private var pendingMouseMoveY: Double = 0
    private var currentModifierFlags: CGEventFlags = []
    private var keyRepeatTimer: DispatchSourceTimer?
    private let keyRepeatQueue = DispatchQueue(label: "com.elysium.keyRepeat", qos: .userInteractive)
    private var repeatingKeyCode: UInt16?
    private var repeatingModifiers: ModifierSet = []
    private var tokenBucket: TokenBucket
    private var capturedDisplayID: CGDirectDisplayID = 0
    private var pointerContext: RemotePointerContext?
    private var geometryMapper: WindowGeometryMapper?
    public var emergencyEscapeHandler: (() -> Void)?

    public init() {
        tokenBucket = TokenBucket(maxRate: 1000)
    }

    public func setCapturedDisplayID(_ displayID: CGDirectDisplayID) {
        lock.withLock { capturedDisplayID = displayID }
    }

    public func setPointerContext(_ context: RemotePointerContext) {
        lock.withLock { pointerContext = context }
    }

    public func setWindowGeometryMapper(_ mapper: WindowGeometryMapper) {
        lock.withLock { geometryMapper = mapper }
    }

    deinit {
        scrollCoalescingTimer?.cancel()
        mouseMoveCoalescingTimer?.cancel()
        keyRepeatTimer?.cancel()
    }

    public func dispatch(_ event: RemoteInputEvent) async throws {
        guard await isAccessibilityAuthorized() else {
            throw InputError.accessibilityPermissionDenied
        }

        switch event {
        case .mouseMove(let normalizedX, let normalizedY, _):
            try dispatchMouseMove(x: normalizedX, y: normalizedY)

        case .mouseButton(let button, let phase, let normalizedX, let normalizedY):
            try dispatchMouseButton(button: button, phase: phase, x: normalizedX, y: normalizedY)

        case .scroll(let deltaX, let deltaY, let phase, let precise):
            try dispatchScroll(deltaX: deltaX, deltaY: deltaY, phase: phase, precise: precise)

        case .key(let keyCode, let phase, let modifiers, let isRepeat):
            if isEmergencyEscape(keyCode: keyCode, modifiers: modifiers) {
                emergencyEscapeHandler?()
                await releaseAllKeys()
                return
            }
            try dispatchKey(keyCode: keyCode, phase: phase, modifiers: modifiers, isRepeat: isRepeat)

        case .releaseAll:
            await releaseAllKeys()
        }
    }

    public func releaseAllKeys() async {
        lock.withLock {
            stopKeyRepeat()
            let source = CGEventSource(stateID: .hidSystemState)
            for keyCode in pressedKeys {
                if let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                    event.post(tap: .cghidEventTap)
                }
            }
            pressedKeys.removeAll()
            for button in pressedButtons {
                let cgButton = mapMouseButton(button)
                let mouseUpType: CGEventType
                switch button {
                case .left: mouseUpType = .leftMouseUp
                case .right: mouseUpType = .rightMouseUp
                case .middle: mouseUpType = .otherMouseUp
                }
                if let event = CGEvent(mouseEventSource: source, mouseType: mouseUpType, mouseCursorPosition: lastMousePosition ?? .zero, mouseButton: cgButton) {
                    event.post(tap: .cghidEventTap)
                }
            }
            pressedButtons.removeAll()
            isDragging = false
            dragButton = nil
            dragOrigin = nil
            currentModifierFlags = []
        }
    }

    public func isAccessibilityAuthorized() async -> Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibility() async -> Bool {
        Self.requestAccessibilityTrust()
    }

    private static func requestAccessibilityTrust() -> Bool {
        let key = unsafeBitCast(NSString("AXTrustedCheckOptionPrompt"), to: CFString.self)
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Mouse Movement

    private func dispatchMouseMove(x: Double, y: Double) throws {
        guard x >= 0 && x <= 1 && y >= 0 && y <= 1 else {
            throw InputError.invalidCoordinates(x: x, y: y)
        }
        let point = normalizeCoordinates(x: x, y: y)
        guard rateLimit() else {
            logger.debug("Mouse move rate limited")
            throw InputError.rateLimited
        }
        lock.withLock {
            lastMousePosition = point
        }
        coalesceMouseMove(point: point)
    }

    private func coalesceMouseMove(point: CGPoint) {
        lock.withLock {
            if let last = lastCoalescedPosition {
                let dx = abs(point.x - last.x)
                let dy = abs(point.y - last.y)
                if dx > 2 || dy > 2 {
                    mouseMoveCoalescingTimer?.cancel()
                    mouseMoveCoalescingTimer = nil
                    lastCoalescedPosition = point
                    if isDragging {
                        postDragMove(at: point)
                    } else {
                        postMouseMove(at: point)
                    }
                    return
                }
            } else {
                lastCoalescedPosition = point
                postMouseMove(at: point)
                return
            }
        }
        pendingMouseMoveX = point.x
        pendingMouseMoveY = point.y
        mouseMoveCoalescingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: mouseMoveQueue)
        timer.schedule(deadline: .now() + .milliseconds(1))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let finalPoint = CGPoint(x: self.pendingMouseMoveX, y: self.pendingMouseMoveY)
            self.lock.withLock {
                self.lastCoalescedPosition = finalPoint
            }
            if self.isDragging {
                self.postDragMove(at: finalPoint)
            } else {
                self.postMouseMove(at: finalPoint)
            }
        }
        timer.resume()
        mouseMoveCoalescingTimer = timer
    }

    private func postMouseMove(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Mouse Button

    private func dispatchMouseButton(button: MouseButton, phase: ButtonPhase, x: Double, y: Double) throws {
        guard x >= 0 && x <= 1 && y >= 0 && y <= 1 else {
            throw InputError.invalidCoordinates(x: x, y: y)
        }
        guard rateLimit() else {
            logger.debug("Mouse button rate limited")
            throw InputError.rateLimited
        }
        mouseMoveCoalescingTimer?.cancel()
        mouseMoveCoalescingTimer = nil
        let point = normalizeCoordinates(x: x, y: y)
        let now = mach_absolute_time()
        let cgButton = mapMouseButton(button)
        let mouseType = mapMouseButtonEvent(button: button, phase: phase)
        let source = CGEventSource(stateID: .hidSystemState)
        let clickInfo: (count: Int, shouldStartDrag: Bool) = lock.withLock {
            if phase == .down {
                let isDoubleClick = (button == lastClickButton) && (now - lastClickTimestamp < 300_000_000)
                let currentCount: Int
                if isDoubleClick {
                    clickCount = min(clickCount + 1, 3)
                    currentCount = clickCount
                } else {
                    clickCount = 1
                    currentCount = 1
                }
                lastClickTimestamp = now
                lastClickButton = button
                lastMousePosition = point
                pressedButtons.insert(button)
                let startDrag = currentCount == 1
                if startDrag {
                    isDragging = true
                    dragButton = button
                    dragOrigin = point
                }
                return (currentCount, startDrag)
            } else {
                lastMousePosition = point
                pressedButtons.remove(button)
                if button == dragButton {
                    isDragging = false
                    dragButton = nil
                    dragOrigin = nil
                }
                return (1, false)
            }
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: mouseType, mouseCursorPosition: point, mouseButton: cgButton) else {
            throw InputError.invalidCoordinates(x: x, y: y)
        }
        if phase == .down {
            event.setIntegerValueField(.mouseEventClickState, value: Int64(clickInfo.count))
        }
        event.post(tap: .cghidEventTap)
    }

    private func postDragMove(at point: CGPoint) {
        let button: MouseButton? = lock.withLock {
            guard isDragging, let btn = dragButton else { return nil }
            return btn
        }
        guard let activeButton = button else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let cgButton = mapMouseButton(activeButton)
        if let event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: cgButton) {
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Scroll

    private func dispatchScroll(deltaX: Double, deltaY: Double, phase: ScrollPhase, precise: Bool) throws {
        guard rateLimit() else {
            logger.debug("Scroll rate limited")
            throw InputError.rateLimited
        }
        lock.withLock {
            pendingScrollDeltaX += deltaX
            pendingScrollDeltaY += deltaY
        }
        switch phase {
        case .ended, .cancelled:
            flushScroll()
            return
        case .began, .changed:
            break
        }
        scrollCoalescingTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: scrollQueue)
        timer.schedule(deadline: .now() + .milliseconds(8))
        timer.setEventHandler { [weak self] in
            self?.flushScroll()
        }
        timer.resume()
        scrollCoalescingTimer = timer
    }

    private func flushScroll() {
        scrollCoalescingTimer?.cancel()
        scrollCoalescingTimer = nil
        let (dx, dy): (Double, Double) = lock.withLock {
            let ddx = pendingScrollDeltaX
            let ddy = pendingScrollDeltaY
            pendingScrollDeltaX = 0
            pendingScrollDeltaY = 0
            return (ddx, ddy)
        }
        guard dx != 0 || dy != 0 else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        if let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Keyboard

    private func dispatchKey(keyCode: UInt16, phase: KeyPhase, modifiers: ModifierSet, isRepeat: Bool) throws {
        guard isValidKeyCode(keyCode) else {
            throw InputError.invalidKeyCode(keyCode)
        }
        guard rateLimit() else {
            logger.debug("Key rate limited")
            throw InputError.rateLimited
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let isDown = (phase == .down)
        let newFlags = buildEventFlags(modifiers: modifiers)
        syncModifierState(newFlags)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else {
            throw InputError.invalidKeyCode(keyCode)
        }
        event.flags = newFlags
        event.post(tap: .cghidEventTap)
        lock.withLock {
            if isDown {
                pressedKeys.insert(keyCode)
                startKeyRepeat(keyCode: keyCode, modifiers: modifiers)
            } else {
                pressedKeys.remove(keyCode)
                if repeatingKeyCode == keyCode {
                    stopKeyRepeat()
                }
            }
        }
    }

    private func syncModifierState(_ newFlags: CGEventFlags) {
        lock.withLock {
            guard newFlags != currentModifierFlags else { return }
            let added = newFlags.subtracting(currentModifierFlags)
            let removed = currentModifierFlags.subtracting(newFlags)
            currentModifierFlags = newFlags
            let source = CGEventSource(stateID: .hidSystemState)
            if !added.isEmpty || !removed.isEmpty {
                let synthetic = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
                synthetic?.flags = newFlags
                synthetic?.post(tap: .cghidEventTap)
            }
        }
    }

    private func startKeyRepeat(keyCode: UInt16, modifiers: ModifierSet) {
        stopKeyRepeat()
        guard isPrintableKey(keyCode) else { return }
        repeatingKeyCode = keyCode
        repeatingModifiers = modifiers
        let timer = DispatchSource.makeTimerSource(queue: keyRepeatQueue)
        timer.schedule(deadline: .now() + .milliseconds(30), repeating: .milliseconds(30))
        timer.setEventHandler { [weak self] in
            self?.fireKeyRepeat()
        }
        timer.resume()
        keyRepeatTimer = timer
    }

    private func fireKeyRepeat() {
        let (key, mods): (UInt16, ModifierSet) = lock.withLock {
            guard let code = repeatingKeyCode else { return (0, []) }
            return (code, repeatingModifiers)
        }
        guard key != 0, pressedKeys.contains(key) else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let flags = buildEventFlags(modifiers: mods)
        if let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    private func stopKeyRepeat() {
        keyRepeatTimer?.cancel()
        keyRepeatTimer = nil
        repeatingKeyCode = nil
        repeatingModifiers = []
    }

    // MARK: - Emergency Escape

    private func isEmergencyEscape(keyCode: UInt16, modifiers: ModifierSet) -> Bool {
        let hasAll = modifiers.contains(.command) && modifiers.contains(.control) && modifiers.contains(.option)
        let isEscape = (keyCode == 0x35)
        return hasAll && isEscape
    }

    // MARK: - Validation

    private func isValidKeyCode(_ code: UInt16) -> Bool {
        code <= 0x7E
    }

    // MARK: - Rate Limiter

    private func rateLimit() -> Bool {
        tokenBucket.consume()
    }

    // MARK: - Coordinate Normalization

    private func normalizeCoordinates(x: Double, y: Double) -> CGPoint {
        let (ctxDisplayID, mapper) = lock.withLock { (capturedDisplayID, geometryMapper) }

        if let mapper = mapper, let ctx = lock.withLock({ pointerContext }) {
            let (mappedX, _) = mapper.mapNormalizedToRemote(x: x, y: y, targetDisplayID: ctx.displayID)
            let remoteDisplay = mapper.remoteDisplays.first(where: { $0.id == ctx.displayID }) ?? mapper.remoteDisplays.first
            let screenW = Double(remoteDisplay?.width ?? 1920)
            let screenH = Double(remoteDisplay?.height ?? 1080)
            let screenMinX = remoteDisplay?.originX ?? 0
            let screenMinY = remoteDisplay?.originY ?? 0
            let px = mappedX * screenW / screenW + screenMinX
            let py = (1.0 - y) * screenH + screenMinY
            return CGPoint(x: px, y: py)
        }

        let bounds: CGRect
        if ctxDisplayID != 0 {
            bounds = CGDisplayBounds(ctxDisplayID)
        } else if let mainScreen = NSScreen.main {
            bounds = mainScreen.visibleFrame
        } else {
            bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }

        let screenW = bounds.width
        let screenH = bounds.height
        let screenMinX = bounds.origin.x
        let screenMinY = bounds.origin.y

        let px = x * screenW + screenMinX
        let py = (1.0 - y) * screenH + screenMinY
        return CGPoint(x: px, y: py)
    }

    // MARK: - Helpers

    private func mapMouseButton(_ button: MouseButton) -> CGMouseButton {
        switch button {
        case .left: return .left
        case .right: return .right
        case .middle: return .center
        }
    }

    private func mapMouseButtonEvent(button: MouseButton, phase: ButtonPhase) -> CGEventType {
        switch (button, phase) {
        case (.left, .down): return .leftMouseDown
        case (.left, .up): return .leftMouseUp
        case (.right, .down): return .rightMouseDown
        case (.right, .up): return .rightMouseUp
        case (.middle, .down): return .otherMouseDown
        case (.middle, .up): return .otherMouseUp
        }
    }

    private func buildEventFlags(modifiers: ModifierSet) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(ModifierSet.shift) { flags.insert(.maskShift) }
        if modifiers.contains(ModifierSet.control) { flags.insert(.maskControl) }
        if modifiers.contains(ModifierSet.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(ModifierSet.command) { flags.insert(.maskCommand) }
        if modifiers.contains(ModifierSet.capsLock) { flags.insert(.maskAlphaShift) }
        if modifiers.contains(ModifierSet.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    private func isPrintableKey(_ code: UInt16) -> Bool {
        (0x00...0x32).contains(code) || (0x41...0x5A).contains(code) || (0x61...0x7A).contains(code) || (0x24...0x2F).contains(code)
    }
}

// MARK: - Token Bucket Rate Limiter

private struct TokenBucket {
    private let lock = NSLock()
    private var tokens: Double
    private let maxTokens: Double
    private let refillRate: Double
    private var lastRefill: UInt64

    init(maxRate: Int) {
        maxTokens = Double(maxRate)
        tokens = maxTokens
        refillRate = Double(maxRate) / 1_000_000_000
        lastRefill = mach_absolute_time()
    }

    mutating func consume() -> Bool {
        lock.withLock {
            let now = mach_absolute_time()
            let elapsed = Double(now - lastRefill)
            tokens = Swift.min(maxTokens, tokens + elapsed * refillRate)
            lastRefill = now
            guard tokens >= 1 else { return false }
            tokens -= 1
            return true
        }
    }
}
