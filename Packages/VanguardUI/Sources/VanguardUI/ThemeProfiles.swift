import SwiftUI

public enum ThemeProfile: String, CaseIterable, Sendable {
    case minimal
    case balanced
    case ultra

    public var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .balanced: return "Balanced"
        case .ultra: return "Ultra"
        }
    }

    public var colorScheme: ThemeColors {
        switch self {
        case .minimal:
            return ThemeColors(
                background: Color(hex: "0A0A0A"),
                surface: Color(hex: "141414"),
                accent: Color(hex: "00D4FF"),
                textPrimary: .white,
                textSecondary: .white.opacity(0.5),
                border: .white.opacity(0.08)
            )
        case .balanced:
            return ThemeColors(
                background: DS.Colors.bg,
                surface: DS.Colors.bgSurface,
                accent: DS.Colors.accent,
                textPrimary: DS.Colors.textPrimary,
                textSecondary: DS.Colors.textSecondary,
                border: DS.Colors.border
            )
        case .ultra:
            return ThemeColors(
                background: Color(hex: "020408"),
                surface: Color(hex: "0A1020"),
                accent: Color(hex: "00FFD4"),
                textPrimary: .white,
                textSecondary: .white.opacity(0.65),
                border: .white.opacity(0.12)
            )
        }
    }

    public var spacing: ThemeSpacing {
        switch self {
        case .minimal:
            return ThemeSpacing(padding: 8, gap: 6, cornerRadius: 4)
        case .balanced:
            return ThemeSpacing(padding: 12, gap: 8, cornerRadius: 8)
        case .ultra:
            return ThemeSpacing(padding: 16, gap: 12, cornerRadius: 12)
        }
    }
}

public struct ThemeColors: Sendable {
    public let background: Color
    public let surface: Color
    public let accent: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let border: Color
}

public struct ThemeSpacing: Sendable {
    public let padding: CGFloat
    public let gap: CGFloat
    public let cornerRadius: CGFloat
}

public struct ThemeEnvironmentKey: EnvironmentKey {
    public static let defaultValue = ThemeProfile.balanced
}

public extension EnvironmentValues {
    var themeProfile: ThemeProfile {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
