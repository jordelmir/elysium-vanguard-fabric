import SwiftUI

struct PairingView: View {
    let challengeCode: String
    let nodeDisplayName: String
    let onComplete: () -> Void
    @State private var timeRemaining = 300
    @State private var isExpired = false
    @State private var copied = false
    @State private var ringRotation: Double = 0
    @State private var breathe = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Animated glow ring around icon
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [EV.Colors.cyan, EV.Colors.blue, EV.Colors.cyan],
                                center: .center,
                                startAngle: .degrees(ringRotation),
                                endAngle: .degrees(ringRotation + 360)
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: EV.Colors.cyan.opacity(0.4), radius: 20)
                        .onAppear {
                            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                ringRotation = 360
                            }
                        }

                    // Inner shield
                    ZStack {
                        Circle()
                            .fill(EV.Colors.cyan.opacity(0.08 * (breathe ? 1.5 : 1.0)))
                            .frame(width: 80, height: 80)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36))
                            .foregroundColor(EV.Colors.cyan)
                            .neonGlow(EV.Colors.cyan, radius: 12)
                            .scaleEffect(breathe ? 1.05 : 0.95)
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever()) {
                        breathe = true
                    }
                }

                Spacer().frame(height: 20)

                Text("PAIRING REQUEST")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(EV.Colors.cyan)
                    .tracking(5)

                Spacer().frame(height: 12)

                Text("A console wants to connect to")
                    .font(.subheadline)
                    .foregroundColor(EV.Colors.textSecondary)
                Text(nodeDisplayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(EV.Colors.textPrimary)

                Spacer().frame(height: 32)

                VStack(spacing: 12) {
                    Text("SHOW THIS CODE TO THE CONSOLE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(EV.Colors.textTertiary)
                        .tracking(3)

                    HexCodeDisplay(code: challengeCode, fontSize: 38)
                }

                Spacer().frame(height: 28)

                VStack(spacing: 6) {
                    if isExpired {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.exclamationmark")
                            Text("CODE EXPIRED")
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(EV.Colors.red)
                        .pulsing(EV.Colors.red)
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(EV.Colors.green)
                                .frame(width: 6, height: 6)
                                .pulsing(EV.Colors.green)
                            Text("Expires in \(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(EV.Colors.textSecondary)
                        }
                    }
                }

                Spacer().frame(height: 24)

                VStack(alignment: .leading, spacing: 10) {
                    StepRow(n: "01", text: "Open Elysium Console on the other Mac")
                    StepRow(n: "02", text: "Click on this node when it appears")
                    StepRow(n: "03", text: "Enter the 6-digit code shown above")
                }
                .padding(.horizontal, 32)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { onComplete() }) {
                        Text("Close")
                    }
                    .buttonStyle(NeonButtonStyle(color: EV.Colors.textSecondary))

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(challengeCode, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied" : "Copy Code")
                        }
                    }
                    .buttonStyle(NeonProminentButtonStyle(color: EV.Colors.cyan))
                }
                .padding(.bottom, 28)
            }
            .frame(width: 460, height: 540)
            .background(EV.Colors.bg)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(AnimatedGradientBorder(cornerRadius: 24))
            .shadow(color: EV.Colors.cyan.opacity(0.12), radius: 40, y: 10)
            .shadow(color: EV.Colors.blue.opacity(0.08), radius: 60, y: 20)
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 { timeRemaining -= 1 }
            else { isExpired = true; timer.upstream.connect().cancel() }
        }
    }
}

struct StepRow: View {
    let n: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Text(n)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(EV.Colors.cyan)
                .frame(width: 24, height: 24)
                .background(EV.Colors.cyan.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(EV.Colors.textSecondary)
            Spacer()
        }
    }
}
