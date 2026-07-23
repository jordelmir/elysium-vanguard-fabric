import SwiftUI

public struct CosmicBackground: View {
    @State private var mouseLocation: CGPoint = .zero
    @State private var time: Double = 0
    public var baseColor: Color
    public var particleCount: Int

    public init(baseColor: Color = DS.Colors.accent, particleCount: Int = 60) {
        self.baseColor = baseColor
        self.particleCount = particleCount
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                DS.Colors.bgDeep.ignoresSafeArea()
                nebulaLayer(size: geo.size)
                starField(size: geo.size)
                particleField(size: geo.size)
                depthFog
                mouseGlow(size: geo.size)
            }
            .onAppear { withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) { time = 1 } }
            .onContinuousHover { phase in
                if case .active(let loc) = phase { withAnimation(.easeOut(duration: 0.3)) { mouseLocation = loc } }
            }
        }
    }

    @ViewBuilder private func nebulaLayer(size: CGSize) -> some View {
        ZStack {
            RadialGradient(colors: [baseColor.opacity(0.06), Color.clear], center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: size.width * 0.6)
                .offset(x: sin(time * 2 * .pi) * 20, y: cos(time * 2 * .pi) * 15)
            RadialGradient(colors: [DS.Colors.accent.opacity(0.04), Color.clear], center: .init(x: 0.7, y: 0.7), startRadius: 0, endRadius: size.width * 0.5)
                .offset(x: cos(time * 2 * .pi) * 25, y: sin(time * 2 * .pi) * 20)
            RadialGradient(colors: [DS.Colors.info.opacity(0.03), Color.clear], center: .init(x: 0.5, y: 0.2), startRadius: 0, endRadius: size.width * 0.4)
        }
    }

    @ViewBuilder private func starField(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            for i in 0..<120 {
                let seed = Double(i) * 1.618
                let x = CGFloat(sin(seed * 127.1) * 0.5 + 0.5) * canvasSize.width
                let y = CGFloat(cos(seed * 311.7) * 0.5 + 0.5) * canvasSize.height
                let brightness = CGFloat(sin(seed * 43.7 + time * 6) * 0.3 + 0.5)
                let sz = CGFloat(sin(seed * 17.3) * 0.5 + 0.8) * 1.5
                ctx.opacity = Double(brightness * 0.6)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: sz, height: sz)), with: .color(.white))
            }
        }
    }

    @ViewBuilder private func particleField(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            for i in 0..<particleCount {
                let seed = Double(i) * 2.345
                let baseX = CGFloat(sin(seed * 73.1) * 0.5 + 0.5)
                let baseY = CGFloat(cos(seed * 91.3) * 0.5 + 0.5)
                let speed = CGFloat(sin(seed * 13.7) * 0.3 + 0.5)
                let drift = sin(time * 4 * .pi + seed) * 0.02
                let x = baseX * canvasSize.width + drift * canvasSize.width
                let y = (baseY - time * speed * 0.1).truncatingRemainder(dividingBy: 1.0) * canvasSize.height
                let adjustedY = y < 0 ? y + canvasSize.height : y
                let alpha = Double(sin(seed * 29.3 + time * 3) * 0.2 + 0.25)
                let pSize = CGFloat(sin(seed * 7.1) * 0.8 + 1.2)
                ctx.opacity = alpha
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: adjustedY, width: pSize, height: pSize)), with: .color(baseColor))
            }
        }
    }

    private var depthFog: some View {
        LinearGradient(colors: [Color.clear, DS.Colors.bgDeep.opacity(0.3), DS.Colors.bgDeep.opacity(0.7)], startPoint: .top, endPoint: .bottom)
    }

    @ViewBuilder private func mouseGlow(size: CGSize) -> some View {
        RadialGradient(colors: [baseColor.opacity(0.08), Color.clear], center: .init(x: mouseLocation.x / size.width, y: mouseLocation.y / size.height), startRadius: 0, endRadius: 200)
            .blendMode(.screen)
    }
}

public struct ScanLineModifier: ViewModifier {
    @State private var offset: CGFloat = -1
    public var color: Color
    public init(color: Color = DS.Colors.accent) { self.color = color }
    public func body(content: Content) -> some View {
        content.clipped().overlay(
            GeometryReader { geo in
                LinearGradient(colors: [Color.clear, color.opacity(0.08), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 80)
                    .offset(y: offset * geo.size.height)
                    .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { offset = 1.5 } }
            }.allowsHitTesting(false)
        )
    }
}

public extension View {
    func scanLine(_ color: Color = DS.Colors.accent) -> some View { modifier(ScanLineModifier(color: color)) }
}
