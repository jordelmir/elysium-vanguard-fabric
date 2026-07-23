import SwiftUI

public struct CursorGlowModifier: ViewModifier {
    @State private var location: CGPoint = .zero
    public var color: Color
    public init(color: Color = DS.Colors.accent) { self.color = color }
    public func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in if case .active(let loc) = phase { withAnimation(.easeOut(duration: 0.15)) { location = loc } } }
            .overlay(GeometryReader { geo in
                RadialGradient(colors: [color.opacity(0.12), Color.clear], center: .init(x: location.x / geo.size.width, y: location.y / geo.size.height), startRadius: 0, endRadius: 150)
                    .blendMode(.screen).allowsHitTesting(false)
            })
    }
}

public struct MagneticModifier: ViewModifier {
    @State private var offset: CGSize = .zero
    public var strength: CGFloat
    public init(strength: CGFloat = 8) { self.strength = strength }
    public func body(content: Content) -> some View {
        content.offset(offset)
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc): withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { offset = CGSize(width: (loc.x - 0.5) * strength, height: (loc.y - 0.5) * strength) }
                case .ended: withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { offset = .zero }
                }
            }
    }
}

public struct BreathingGlowModifier: ViewModifier {
    @State private var breathe = false
    public var color: Color
    public init(color: Color = DS.Colors.accent) { self.color = color }
    public func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(breathe ? 0.2 : 0.05), radius: breathe ? 16 : 8)
            .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever()) { breathe = true } }
    }
}

public extension View {
    func cursorGlow(_ color: Color = DS.Colors.accent) -> some View { modifier(CursorGlowModifier(color: color)) }
    func magnetic(strength: CGFloat = 8) -> some View { modifier(MagneticModifier(strength: strength)) }
    func breathingGlow(_ color: Color = DS.Colors.accent) -> some View { modifier(BreathingGlowModifier(color: color)) }
}
