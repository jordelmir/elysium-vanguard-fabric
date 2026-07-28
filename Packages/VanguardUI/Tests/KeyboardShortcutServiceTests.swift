import Testing
import Foundation
@testable import VanguardUI

private final class AtomicBool: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool { lock.withLock { _value } }
    func set(_ v: Bool) { lock.withLock { _value = v } }
}

@Suite("KeyboardShortcutService")
struct KeyboardShortcutServiceTests {

    @Test("Register and retrieve shortcut")
    func registerAndRetrieve() async {
        let service = KeyboardShortcutService()
        try? await service.registerShortcut(.emergencyStop)
        let shortcuts = await service.getRegisteredShortcuts()
        #expect(shortcuts.count >= 1)
        #expect(shortcuts.contains { $0.name == "Emergency Stop" })
    }

    @Test("Unregister shortcut removes it")
    func unregister() async {
        let service = KeyboardShortcutService()
        try? await service.registerShortcut(.disconnect)
        let id = await service.getRegisteredShortcuts().first?.id
        if let id {
            await service.unregisterShortcut(id)
        }
        let after = await service.getRegisteredShortcuts()
        #expect(after.isEmpty)
    }

    @Test("Handle key event triggers callback")
    func handleKeyEvent() async {
        let service = KeyboardShortcutService()
        try? await service.registerShortcut(.emergencyStop)
        let triggered = AtomicBool()
        await service.registerShortcutCallback { _ in triggered.set(true) }
        let handled = await service.handleKeyEvent(keyCode: 0x35, modifierFlags: 0x100000 | 0x40000 | 0x80000)
        #expect(handled == true)
        #expect(triggered.value == true)
    }

    @Test("Handle unmatched key event returns false")
    func unmatchedKey() async {
        let service = KeyboardShortcutService()
        try? await service.registerShortcut(.emergencyStop)
        let handled = await service.handleKeyEvent(keyCode: 0xFF, modifierFlags: 0)
        #expect(handled == false)
    }
}
