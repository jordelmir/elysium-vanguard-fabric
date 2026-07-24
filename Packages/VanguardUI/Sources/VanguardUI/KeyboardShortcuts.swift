import Foundation
import os.log

public actor KeyboardShortcutService {
    private var registeredShortcuts: [ShortcutID: KeyboardShortcut] = [:]
    private var shortcutCallbacks: [(KeyboardShortcut) -> Void] = []
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Shortcuts")

    public var onShortcutTriggered: ((KeyboardShortcut) -> Void)?

    public init() {}

    public func registerShortcut(_ shortcut: KeyboardShortcut) throws {
        registeredShortcuts[shortcut.id] = shortcut
        logger.info("Registered shortcut: \(shortcut.name)")
    }

    public func unregisterShortcut(_ id: ShortcutID) {
        registeredShortcuts.removeValue(forKey: id)
    }

    public func getRegisteredShortcuts() -> [KeyboardShortcut] {
        Array(registeredShortcuts.values)
    }

    public func registerShortcutCallback(_ callback: @escaping @Sendable (KeyboardShortcut) -> Void) {
        shortcutCallbacks.append(callback)
    }

    public func handleKeyEvent(keyCode: UInt32, modifierFlags: UInt) -> Bool {
        for shortcut in registeredShortcuts.values {
            if shortcut.keyCode == keyCode && shortcut.modifierFlags == modifierFlags {
                onShortcutTriggered?(shortcut)
                for callback in shortcutCallbacks {
                    callback(shortcut)
                }
                return true
            }
        }
        return false
    }
}

public struct KeyboardShortcut: Sendable, Identifiable {
    public let id: ShortcutID
    public let name: String
    public let keyCode: UInt32
    public let modifierFlags: UInt
    public let category: ShortcutCategory

    public init(name: String, keyCode: UInt32, modifierFlags: UInt, category: ShortcutCategory) {
        self.id = ShortcutID()
        self.name = name
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.category = category
    }
}

public struct ShortcutID: Hashable, Sendable {
    public let rawValue: UUID
    public init() { rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }
}

public enum ShortcutCategory: String, Sendable, CaseIterable {
    case session = "Session"
    case view = "View"
    case terminal = "Terminal"
    case file = "File"
    case emergency = "Emergency"
}

public extension KeyboardShortcut {
    static let emergencyStop = KeyboardShortcut(
        name: "Emergency Stop",
        keyCode: 0x35,
        modifierFlags: 0x100000 | 0x40000 | 0x80000,
        category: .emergency
    )

    static let toggleFullscreen = KeyboardShortcut(
        name: "Toggle Fullscreen",
        keyCode: 0x24,
        modifierFlags: 0x100000 | 0x40000,
        category: .view
    )

    static let newTab = KeyboardShortcut(
        name: "New Terminal Tab",
        keyCode: 0x11,
        modifierFlags: 0x100000,
        category: .terminal
    )

    static let disconnect = KeyboardShortcut(
        name: "Disconnect",
        keyCode: 0x02,
        modifierFlags: 0x100000 | 0x40000,
        category: .session
    )
}
