import SwiftUI
import VanguardUI

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
            CosmicBackground(baseColor: DS.Colors.accent, particleCount: 30)
                .overlay(Color.black.opacity(0.4))

            VStack(spacing: 0) {
                Spacer()

                // Animated icon
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [DS.Colors.accent, DS.Colors.info, DS.Colors.accent],
                                center: .center,
                                startAngle: .degrees(ringRotation),
                                endAngle: .degrees(ringRotation + 360)
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: DS.Colors.accent.opacity(0.4), radius: 20)
                        .onAppear {
                            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                ringRotation = 360
                            }
                        }

                    ZStack {
                        Circle()
                            .fill(DS.Colors.accent.opacity(0.08 * (breathe ? 1.5 : 1.0)))
                            .frame(width: 72, height: 72)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32))
                            .foregroundColor(DS.Colors.accent)
                            .neonGlow(DS.Colors.accent, radius: 10)
                            .scaleEffect(breathe ? 1.05 : 0.95)
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever()) { breathe = true }
                }

                Spacer().frame(height: DS.Spacing.xxl)

                Text("PAIRING REQUEST")
                    .font(DS.Typography.micro)
                    .foregroundColor(DS.Colors.accent)
                    .tracking(4)

                Spacer().frame(height: DS.Spacing.md)

                Text("A console wants to connect to")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
                Text(nodeDisplayName)
                    .font(DS.Typography.title3)
                    .foregroundColor(DS.Colors.textPrimary)

                Spacer().frame(height: DS.Spacing.xxxl)

                VStack(spacing: DS.Spacing.md) {
                    Text("SHOW THIS CODE TO THE CONSOLE")
                        .font(DS.Typography.micro)
                        .foregroundColor(DS.Colors.textQuaternary)
                        .tracking(3)

                    HexCodeDisplay(code: challengeCode, fontSize: 36)
                }

                Spacer().frame(height: DS.Spacing.xxl)

                if isExpired {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "clock.badge.exclamationmark")
                        Text("CODE EXPIRED")
                    }
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.error)
                    .pulsing(DS.Colors.error)
                } else {
                    HStack(spacing: DS.Spacing.sm) {
                        Circle().fill(DS.Colors.success).frame(width: 5, height: 5)
                        Text("Expires in \(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }

                Spacer().frame(height: DS.Spacing.xxxl)

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    StepRow(n: "01", text: "Open Elysium Console on the other Mac")
                    StepRow(n: "02", text: "Click on this node when it appears")
                    StepRow(n: "03", text: "Enter the 6-digit code shown above")
                }
                .padding(.horizontal, DS.Spacing.xxxl)

                Spacer()

                HStack(spacing: DS.Spacing.md) {
                    ElysiumButton(title: "Close", color: DS.Colors.textTertiary, style: .ghost) {
                        onComplete()
                    }

                    ElysiumButton(
                        title: copied ? "Copied" : "Copy Code",
                        icon: copied ? "checkmark" : "doc.on.doc",
                        color: DS.Colors.accent
                    ) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(challengeCode, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                }
                .padding(.bottom, DS.Spacing.xxl)
            }
            .frame(width: 440, height: 540)
            .glass(style: .ultraThin, cornerRadius: DS.Radius.xxxl)
            .animatedBorder([DS.Colors.accent, DS.Colors.info])
            .shadow(color: DS.Colors.accent.opacity(0.1), radius: 40, y: 10)
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
        HStack(spacing: DS.Spacing.md) {
            Text(n)
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.accent)
                .frame(width: 24, height: 24)
                .background(DS.Colors.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
        }
    }
}
