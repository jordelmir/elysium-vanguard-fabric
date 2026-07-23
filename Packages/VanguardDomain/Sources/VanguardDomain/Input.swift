import Foundation

// MARK: - Remote Input Event

public enum RemoteInputEvent: Codable, Sendable, Equatable {
    case mouseMove(
        normalizedX: Double,
        normalizedY: Double,
        sequence: UInt64
    )
    case mouseButton(
        button: MouseButton,
        phase: ButtonPhase,
        normalizedX: Double,
        normalizedY: Double
    )
    case scroll(
        deltaX: Double,
        deltaY: Double,
        phase: ScrollPhase,
        precise: Bool
    )
    case key(
        keyCode: UInt16,
        phase: KeyPhase,
        modifiers: ModifierSet,
        isRepeat: Bool
    )
    case releaseAll
}

// MARK: - Mouse Button

public enum MouseButton: UInt8, Codable, Sendable, CaseIterable {
    case left = 0
    case right = 1
    case middle = 2
}

// MARK: - Button Phase

public enum ButtonPhase: String, Codable, Sendable {
    case down
    case up
}

// MARK: - Scroll Phase

public enum ScrollPhase: String, Codable, Sendable {
    case began
    case changed
    case ended
    case cancelled
}

// MARK: - Key Phase

public enum KeyPhase: String, Codable, Sendable {
    case down
    case up
}

// MARK: - Modifier Set

public struct ModifierSet: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let shift = ModifierSet(rawValue: 1 << 0)
    public static let control = ModifierSet(rawValue: 1 << 1)
    public static let option = ModifierSet(rawValue: 1 << 2)
    public static let command = ModifierSet(rawValue: 1 << 3)
    public static let capsLock = ModifierSet(rawValue: 1 << 4)
    public static let function = ModifierSet(rawValue: 1 << 5)
}
