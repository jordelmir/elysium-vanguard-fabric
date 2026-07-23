import SwiftUI

public struct Glass: ViewModifier {
    public enum Style {
        case ultraThin, thin, regular, thick, colored(Color)
    }
    public var style: Style = .regular
    public var cornerRadius: CGFloat = DS.Radius.xl
    public var borderOpacity: Double = 0.08

    public init(style: Style = .regular, cornerRadius: CGFloat = DS.Radius.xl, borderOpacity: Double = 0.08) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.borderOpacity = borderOpacity
    }

    public func body(content: Content) -> some View {
        content
            .background(gradient(for: style))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(borderLayer)
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
    }

    @ViewBuilder
    private func gradient(for style: Style) -> some View {
        switch style {
        case .ultraThin:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Color.white.opacity(0.02))
        case .thin:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
                .overlay(Color.white.opacity(0.03))
        case .regular:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .overlay(Color.white.opacity(0.04))
        case .thick:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thickMaterial)
                .overlay(Color.white.opacity(0.06))
        case .colored(let color):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(color.opacity(0.06))
        }
    }

    private var borderLayer: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(borderOpacity * 1.5),
                        Color.white.opacity(borderOpacity * 0.5),
                        Color.white.opacity(borderOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
}

public struct NeonGlowModifier: ViewModifier {
    public let color: Color
    public let radius: CGFloat
    public init(color: Color, radius: CGFloat) { self.color = color; self.radius = radius }
    public func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.7), radius: radius)
            .shadow(color: color.opacity(0.4), radius: radius * 2.5)
            .shadow(color: color.opacity(0.15), radius: radius * 4)
    }
}

public struct InnerGlow: ViewModifier {
    public let color: Color
    public var radius: CGFloat = 20
    public var opacity: Double = 0.15
    public init(color: Color, radius: CGFloat = 20, opacity: Double = 0.15) { self.color = color; self.radius = radius; self.opacity = opacity }
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RadialGradient(colors: [color.opacity(opacity), Color.clear], center: .topLeading, startRadius: 0, endRadius: radius))
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
    }
}

public struct AdaptiveBorder: ViewModifier {
    public var color: Color = DS.Colors.accent
    public var isHighlighted: Bool = false
    public var cornerRadius: CGFloat = DS.Radius.xl
    public init(color: Color = DS.Colors.accent, isHighlighted: Bool = false, cornerRadius: CGFloat = DS.Radius.xl) { self.color = color; self.isHighlighted = isHighlighted; self.cornerRadius = cornerRadius }
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isHighlighted ? color.opacity(0.4) : Color.white.opacity(0.06), lineWidth: isHighlighted ? 1 : 0.5)
                    .animation(DS.Animation.springFast, value: isHighlighted)
            )
    }
}

public struct SpecularHighlight: ViewModifier {
    public init() {}
    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04), Color.clear], startPoint: .topLeading, endPoint: .init(x: 0.6, y: 0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .allowsHitTesting(false)
                }
            )
    }
}

public extension View {
    func glass(style: Glass.Style = .regular, cornerRadius: CGFloat = DS.Radius.xl) -> some View { modifier(Glass(style: style, cornerRadius: cornerRadius)) }
    func neonGlow(_ color: Color = DS.Colors.accent, radius: CGFloat = 12) -> some View { modifier(NeonGlowModifier(color: color, radius: radius)) }
    func innerGlow(_ color: Color = DS.Colors.accent, radius: CGFloat = 20) -> some View { modifier(InnerGlow(color: color, radius: radius)) }
    func adaptiveBorder(_ color: Color = DS.Colors.accent, highlighted: Bool = false) -> some View { modifier(AdaptiveBorder(color: color, isHighlighted: highlighted)) }
    func specular() -> some View { modifier(SpecularHighlight()) }
}
