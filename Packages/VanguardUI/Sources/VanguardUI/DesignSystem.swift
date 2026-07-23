import SwiftUI

public enum DS {
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
        public static let xxl: CGFloat = 24
        public static let xxxl: CGFloat = 32
        public static let xxxxl: CGFloat = 40
        public static let huge: CGFloat = 48
    }
    public enum Radius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 16
        public static let xxl: CGFloat = 20
        public static let xxxl: CGFloat = 24
        public static let pill: CGFloat = 100
    }
    public enum Typography {
        public static let hero = Font.system(size: 48, weight: .black, design: .rounded)
        public static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        public static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        public static let title3 = Font.system(size: 18, weight: .semibold, design: .rounded)
        public static let headline = Font.system(size: 15, weight: .semibold, design: .rounded)
        public static let body = Font.system(size: 14, weight: .regular, design: .rounded)
        public static let callout = Font.system(size: 13, weight: .regular, design: .rounded)
        public static let subheadline = Font.system(size: 12, weight: .regular, design: .rounded)
        public static let footnote = Font.system(size: 11, weight: .regular, design: .rounded)
        public static let caption = Font.system(size: 10, weight: .medium, design: .monospaced)
        public static let micro = Font.system(size: 9, weight: .black, design: .monospaced)
        public static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
        public static let monoBold = Font.system(size: 13, weight: .bold, design: .monospaced)
        public static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
    }
    public enum Colors {
        public static let bgDeep = Color(hex: "060911")
        public static let bg = Color(hex: "0A0F1C")
        public static let bgElevated = Color(hex: "0E1425")
        public static let bgSurface = Color(hex: "121A2E")
        public static let bgOverlay = Color(hex: "162035")
        public static let border = Color.white.opacity(0.06)
        public static let borderLight = Color.white.opacity(0.10)
        public static let borderFocus = Color.white.opacity(0.18)
        public static let textPrimary = Color.white
        public static let textSecondary = Color.white.opacity(0.60)
        public static let textTertiary = Color.white.opacity(0.35)
        public static let textQuaternary = Color.white.opacity(0.18)
        public static let accent = Color(hex: "00D4FF")
        public static let accentDim = Color(hex: "0099BB")
        public static let accentDeep = Color(hex: "006688")
        public static let success = Color(hex: "00E87B")
        public static let successDim = Color(hex: "00AA55")
        public static let warning = Color(hex: "FFB800")
        public static let warningDim = Color(hex: "CC9400")
        public static let error = Color(hex: "FF3B5C")
        public static let errorDim = Color(hex: "CC2E4A")
        public static let info = Color(hex: "4A9EFF")
        public static let nodeOffline = Color(hex: "3A4255")
        public static let nodeBooting = Color(hex: "FFB800")
        public static let nodeScanning = Color(hex: "4A9EFF")
        public static let nodePairing = Color(hex: "FF8C00")
        public static let nodeConnected = Color(hex: "00E87B")
        public static let nodeStreaming = Color(hex: "00D4FF")
        public static let nodeError = Color(hex: "FF3B5C")
        public static let nodeRecovery = Color(hex: "AA66FF")
    }
    public enum Animation {
        public static let springFast = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.7)
        public static let springMedium = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        public static let springSlow = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
        public static let springBouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.5)
        public static let springSnappy = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.8)
        public static let gentle = SwiftUI.Animation.easeInOut(duration: 0.4)
        public static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
    }
}

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
