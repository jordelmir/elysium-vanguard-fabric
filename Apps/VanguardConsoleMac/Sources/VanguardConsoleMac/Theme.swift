import SwiftUI

enum EV {
    enum Colors {
        static let bg = Color(red: 0.03, green: 0.04, blue: 0.08)
        static let bgDeep = Color(red: 0.02, green: 0.02, blue: 0.05)
        static let surface = Color(red: 0.06, green: 0.07, blue: 0.13)
        static let surfaceLight = Color(red: 0.09, green: 0.10, blue: 0.18)

        static let cyan = Color(red: 0.0, green: 0.88, blue: 1.0)
        static let cyanDim = Color(red: 0.0, green: 0.55, blue: 0.7)
        static let blue = Color(red: 0.15, green: 0.45, blue: 1.0)
        static let blueDim = Color(red: 0.1, green: 0.3, blue: 0.7)
        static let steel = Color(red: 0.45, green: 0.55, blue: 0.65)
        static let green = Color(red: 0.0, green: 1.0, blue: 0.53)
        static let greenDim = Color(red: 0.0, green: 0.7, blue: 0.4)
        static let amber = Color(red: 1.0, green: 0.72, blue: 0.0)
        static let red = Color(red: 1.0, green: 0.25, blue: 0.35)
        static let orange = Color(red: 1.0, green: 0.55, blue: 0.0)

        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.55)
        static let textTertiary = Color.white.opacity(0.3)
    }

    enum Gradients {
        static let neonBorder = LinearGradient(
            colors: [Colors.cyan, Colors.blue],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        static let scanLine = LinearGradient(
            colors: [Color.clear, Colors.cyan.opacity(0.18), Color.clear],
            startPoint: .top, endPoint: .bottom
        )
    }
}

struct AnimatedGradientBorder: View {
    @State private var rotation: Double = 0
    var colors: [Color] = [EV.Colors.cyan, EV.Colors.blue, EV.Colors.steel, EV.Colors.cyan]
    var lineWidth: CGFloat = 1.5
    var cornerRadius: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: colors),
                    center: .center,
                    startAngle: .degrees(rotation),
                    endAngle: .degrees(rotation + 360)
                ),
                lineWidth: lineWidth
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct NeonGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.7), radius: radius)
            .shadow(color: color.opacity(0.4), radius: radius * 2.5)
            .shadow(color: color.opacity(0.15), radius: radius * 4)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var borderColor: Color = EV.Colors.cyan.opacity(0.2)
    var borderWidth: CGFloat = 1
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(EV.Colors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: .black.opacity(0.6), radius: 24, y: 10)
            .shadow(color: borderColor.opacity(0.1), radius: 8, y: 4)
    }
}

struct NeonBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(EV.Gradients.neonBorder, lineWidth: 1.5)
                    .shadow(color: EV.Colors.cyan.opacity(0.4), radius: 10)
                    .shadow(color: EV.Colors.blue.opacity(0.3), radius: 16)
            )
    }
}

struct ScanLineModifier: ViewModifier {
    @State private var phase: CGFloat = -0.3
    func body(content: Content) -> some View {
        content
            .clipped()
            .overlay(
                GeometryReader { geo in
                    EV.Gradients.scanLine
                        .frame(height: 80)
                        .offset(y: phase * geo.size.height)
                        .onAppear {
                            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                                phase = 1.3
                            }
                        }
                }
                .allowsHitTesting(false)
            )
    }
}

struct PulsingModifier: ViewModifier {
    let color: Color
    @State private var pulse = false
    func body(content: Content) -> some View {
        content
            .opacity(pulse ? 1.0 : 0.4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                    pulse = true
                }
            }
    }
}

struct HolographicShimmer: ViewModifier {
    @State private var offset: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.06), Color.clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 3)
                    .offset(x: offset * geo.size.width * 2)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false)) {
                            offset = 1
                        }
                    }
                }
                .allowsHitTesting(false)
            )
    }
}

struct ParticleField: ViewModifier {
    @State private var particles: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
    let color: Color
    let count: Int

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    ZStack {
                        ForEach(0..<count, id: \.self) { i in
                            Circle()
                                .fill(color)
                                .frame(width: particles.indices.contains(i) ? particles[i].size : 2,
                                       height: particles.indices.contains(i) ? particles[i].size : 2)
                                .position(
                                    x: particles.indices.contains(i) ? particles[i].x * geo.size.width : CGFloat.random(in: 0...geo.size.width),
                                    y: particles.indices.contains(i) ? particles[i].y * geo.size.height : CGFloat.random(in: 0...geo.size.height)
                                )
                                .opacity(particles.indices.contains(i) ? particles[i].opacity : 0.3)
                        }
                    }
                }
                .allowsHitTesting(false)
            )
            .onAppear {
                particles = (0..<count).map { _ in
                    (x: .random(in: 0...1), y: .random(in: 0...1), size: .random(in: 1...3), opacity: .random(in: 0.1...0.4))
                }
                animateParticles()
            }
    }

    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in 0..<particles.count {
                withAnimation(.linear(duration: 0.05)) {
                    particles[i].y -= 0.002
                    if particles[i].y < -0.05 {
                        particles[i].y = 1.05
                        particles[i].x = .random(in: 0...1)
                    }
                }
            }
        }
    }
}

struct NeonButtonStyle: ButtonStyle {
    var color: Color = EV.Colors.cyan
    var isSmall: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isSmall ? .caption : .body)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, isSmall ? 10 : 18)
            .padding(.vertical, isSmall ? 6 : 10)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.6 : 0.15), radius: configuration.isPressed ? 14 : 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct NeonProminentButtonStyle: ButtonStyle {
    var color: Color = EV.Colors.cyan
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .fontWeight(.bold)
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: color.opacity(0.5), radius: 14)
            .shadow(color: color.opacity(0.2), radius: 28)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 10
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.8), radius: 5)
            .shadow(color: color.opacity(0.4), radius: 10)
            .scaleEffect(pulse ? 1.4 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                    pulse = true
                }
            }
    }
}

struct HexCodeDisplay: View {
    let code: String
    var fontSize: CGFloat = 36
    @State private var glowPhase = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(code.enumerated()), id: \.offset) { idx, char in
                Text(String(char))
                    .font(.system(size: fontSize, weight: .heavy, design: .monospaced))
                    .foregroundColor(EV.Colors.cyan)
                    .frame(width: fontSize * 1.3, height: fontSize * 1.7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(EV.Colors.cyan.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(EV.Colors.cyan.opacity(glowPhase ? 0.7 : 0.3), lineWidth: 1.5)
                    )
                    .shadow(color: EV.Colors.cyan.opacity(glowPhase ? 0.5 : 0.15), radius: glowPhase ? 10 : 4)
                    .offset(y: glowPhase ? -2 : 2)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever().delay(Double(idx) * 0.1),
                        value: glowPhase
                    )
            }
        }
        .onAppear { glowPhase = true }
    }
}

struct NeonTextFieldStyle: TextFieldStyle {
    var accentColor: Color = EV.Colors.cyan
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(10)
            .background(EV.Colors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accentColor.opacity(0.25), lineWidth: 1)
            )
    }
}

extension View {
    func neonGlow(_ color: Color = EV.Colors.cyan, radius: CGFloat = 12) -> some View {
        modifier(NeonGlowModifier(color: color, radius: radius))
    }
    func glassCard(cornerRadius: CGFloat = 16, borderColor: Color = EV.Colors.cyan.opacity(0.2)) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, borderColor: borderColor))
    }
    func neonBorder(cornerRadius: CGFloat = 16) -> some View {
        modifier(NeonBorderModifier(cornerRadius: cornerRadius))
    }
    func scanLine() -> some View {
        modifier(ScanLineModifier())
    }
    func pulsing(_ color: Color = EV.Colors.cyan) -> some View {
        modifier(PulsingModifier(color: color))
    }
    func holoShimmer() -> some View {
        modifier(HolographicShimmer())
    }
    func particleField(color: Color = EV.Colors.cyan.opacity(0.3), count: Int = 15) -> some View {
        modifier(ParticleField(color: color, count: count))
    }
}
