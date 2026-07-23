import SwiftUI

public enum NodeStatus {
    case offline, booting, scanning, pairing, connected, streaming, error, recovery
    public var breatheSpeed: Double {
        switch self {
        case .offline: return 2.0; case .booting: return 0.8; case .scanning: return 1.2
        case .pairing: return 1.0; case .connected: return 1.5; case .streaming: return 0.6
        case .error: return 0.4; case .recovery: return 0.7
        }
    }
}

public struct StatusIndicator: View {
    public let status: NodeStatus
    public var size: CGFloat
    @State private var breathe = false
    public init(status: NodeStatus, size: CGFloat = 10) { self.status = status; self.size = size }
    public var body: some View {
        Circle().fill(statusColor).frame(width: size, height: size)
            .shadow(color: statusColor.opacity(0.6), radius: 4)
            .shadow(color: statusColor.opacity(0.3), radius: 8)
            .scaleEffect(breathe ? 1.3 : 1.0)
            .onAppear { withAnimation(.easeInOut(duration: status.breatheSpeed).repeatForever()) { breathe = true } }
    }
    private var statusColor: Color {
        switch status {
        case .offline: return DS.Colors.nodeOffline; case .booting: return DS.Colors.nodeBooting
        case .scanning: return DS.Colors.nodeScanning; case .pairing: return DS.Colors.nodePairing
        case .connected: return DS.Colors.nodeConnected; case .streaming: return DS.Colors.nodeStreaming
        case .error: return DS.Colors.nodeError; case .recovery: return DS.Colors.nodeRecovery
        }
    }
}

public struct ElysiumButton: View {
    public let title: String
    public let icon: String?
    public var color: Color
    public var style: Style
    public let action: () -> Void
    public enum Style { case prominent, bordered, ghost }
    @State private var isHovered = false
    @State private var isPressed = false

    public init(title: String, icon: String? = nil, color: Color = DS.Colors.accent, style: Style = .prominent, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.color = color; self.style = style; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(DS.Typography.headline)
            }
            .foregroundColor(fgColor)
            .padding(.horizontal, DS.Spacing.xl).padding(.vertical, DS.Spacing.md)
            .frame(minHeight: 38)
            .background(bgView).overlay(ovView)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(color: shadowClr, radius: isPressed ? 2 : 8, y: isPressed ? 1 : 4)
            .scaleEffect(isPressed ? 0.97 : isHovered ? 1.02 : 1.0)
            .offset(y: isPressed ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onLongPressGesture(minimumDuration: 0, pressing: { p in withAnimation(DS.Animation.springSnappy) { isPressed = p } }, perform: {})
    }
    private var fgColor: Color { style == .prominent ? .black : color }
    @ViewBuilder private var bgView: some View {
        switch style {
        case .prominent: LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bordered: color.opacity(isHovered ? 0.12 : 0.06)
        case .ghost: Color.clear
        }
    }
    @ViewBuilder private var ovView: some View {
        if style != .prominent {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).stroke(color.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
    }
    private var shadowClr: Color { style == .prominent ? color.opacity(0.3) : .clear }
}

public struct HexCodeDisplay: View {
    public let code: String
    public var fontSize: CGFloat
    @State private var glowPhase = false
    public init(code: String, fontSize: CGFloat = 36) { self.code = code; self.fontSize = fontSize }
    public var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(Array(code.enumerated()), id: \.offset) { idx, char in
                Text(String(char))
                    .font(.system(size: fontSize, weight: .heavy, design: .monospaced))
                    .foregroundColor(DS.Colors.accent)
                    .frame(width: fontSize * 1.3, height: fontSize * 1.7)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).fill(DS.Colors.accent.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous).stroke(DS.Colors.accent.opacity(glowPhase ? 0.7 : 0.3), lineWidth: 1.5))
                    .shadow(color: DS.Colors.accent.opacity(glowPhase ? 0.5 : 0.15), radius: glowPhase ? 10 : 4)
                    .offset(y: glowPhase ? -2 : 2)
                    .animation(.easeInOut(duration: 1.2).repeatForever().delay(Double(idx) * 0.1), value: glowPhase)
            }
        }.onAppear { glowPhase = true }
    }
}

public struct NeonText: View {
    public let text: String
    public var font: Font
    public var color: Color
    public init(text: String, font: Font = DS.Typography.headline, color: Color = DS.Colors.accent) { self.text = text; self.font = font; self.color = color }
    public var body: some View {
        Text(text).font(font).foregroundColor(color)
            .shadow(color: color.opacity(0.6), radius: 4)
            .shadow(color: color.opacity(0.3), radius: 8)
    }
}

public struct ProgressiveReveal: ViewModifier {
    public let delay: Double
    @State private var revealed = false
    public init(delay: Double = 0) { self.delay = delay }
    public func body(content: Content) -> some View {
        content.opacity(revealed ? 1 : 0).offset(y: revealed ? 0 : 12)
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) { revealed = true } }
    }
}

public struct PulseModifier: ViewModifier {
    @State private var pulse = false
    public var color: Color
    public init(color: Color = DS.Colors.accent) { self.color = color }
    public func body(content: Content) -> some View {
        content.opacity(pulse ? 1.0 : 0.4)
            .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { pulse = true } }
    }
}

public struct AnimatedBorderModifier: ViewModifier {
    @State private var phase: Double = 0
    public var colors: [Color]
    public init(colors: [Color] = [DS.Colors.accent, DS.Colors.info]) { self.colors = colors }
    public func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(AngularGradient(gradient: Gradient(colors: colors), center: .center, startAngle: .degrees(phase), endAngle: .degrees(phase + 360)), lineWidth: 1.5)
                .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { phase = 360 } }
        )
    }
}

public extension View {
    func pulsing(_ color: Color = DS.Colors.accent) -> some View { modifier(PulseModifier(color: color)) }
    func progressiveReveal(delay: Double = 0) -> some View { modifier(ProgressiveReveal(delay: delay)) }
    func animatedBorder(_ colors: [Color] = [DS.Colors.accent, DS.Colors.info]) -> some View { modifier(AnimatedBorderModifier(colors: colors)) }
}
