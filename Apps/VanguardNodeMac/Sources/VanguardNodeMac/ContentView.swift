import SwiftUI
import VanguardUI

struct ContentView: View {
    @EnvironmentObject private var state: NodeAppState
    @State private var showPairingSheet = false
    @State private var animateGlow = false

    var body: some View {
        CosmicBackground(baseColor: DS.Colors.accent, particleCount: 40)
            .overlay(
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.top, DS.Spacing.xxl)
                        .padding(.bottom, DS.Spacing.lg)

                    Divider().background(Color.white.opacity(0.04))

                    statusSection
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.top, DS.Spacing.lg)

                    if state.permissions == .denied {
                        permissionsWarning
                            .padding(.horizontal, DS.Spacing.xxl)
                            .padding(.top, DS.Spacing.md)
                    }

                    Spacer()

                    telemetrySection
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.bottom, DS.Spacing.lg)

                    controlsSection
                        .padding(.horizontal, DS.Spacing.xxl)
                        .padding(.bottom, DS.Spacing.xxl)
                }
                .frame(width: 420, height: 480)
            )
            .environment(\.themeProfile, state.currentTheme)
            .sheet(isPresented: $showPairingSheet) {
                if let pairing = state.pendingPairingRequest {
                    PairingView(
                        challengeCode: pairing.challengeCode,
                        nodeDisplayName: state.nodeName,
                        onComplete: { showPairingSheet = false }
                    )
                }
            }
            .onChange(of: state.pendingPairingRequest) { req in
                if req != nil { showPairingSheet = true }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever()) {
                    animateGlow = true
                }
            }
    }

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.accent.opacity(animateGlow ? 0.12 : 0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: "shield.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DS.Colors.accent)
                        .neonGlow(DS.Colors.accent, radius: 8)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("ELYSIUM")
                        .font(DS.Typography.micro)
                        .foregroundColor(DS.Colors.accent)
                        .tracking(3)
                    Text("Vanguard Node")
                        .font(DS.Typography.title3)
                        .foregroundColor(DS.Colors.textPrimary)
                }
            }

            Spacer()

            StatusIndicator(status: state.isRunning ? .connected : .offline, size: 12)
        }
    }

    private var statusSection: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: state.isRunning ? "antenna.radiowaves.left.and.right" : "pause.circle")
                    .foregroundColor(state.isRunning ? DS.Colors.success : DS.Colors.textTertiary)
                    .font(.system(size: 14))
                Text(state.statusMessage)
                    .font(DS.Typography.mono)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
            }
            .padding(DS.Spacing.lg)
            .glass(style: .thin, cornerRadius: DS.Radius.lg)

            if let console = state.connectedConsole {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "link.badge.checkmark")
                        .foregroundColor(DS.Colors.accent)
                    Text("Connected to \(console)")
                        .font(DS.Typography.mono)
                        .foregroundColor(DS.Colors.accent)
                    Spacer()
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                        .pulsing(DS.Colors.success)
                }
                .padding(DS.Spacing.lg)
                .glass(style: .colored(DS.Colors.accent), cornerRadius: DS.Radius.lg)
                .neonGlow(DS.Colors.accent, radius: 6)
            }
        }
    }

    private var permissionsWarning: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DS.Colors.warning)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Permissions Required")
                    .font(DS.Typography.footnote)
                    .foregroundColor(DS.Colors.warning)
                Text("Grant Screen Recording & Accessibility")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            Spacer()
            ElysiumButton(title: "Open", icon: "gear", color: DS.Colors.warning, style: .bordered) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .glass(style: .thin, cornerRadius: DS.Radius.lg)
        .innerGlow(DS.Colors.warning, radius: 60)
    }

    private var telemetrySection: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let stats = state.pipelineStats {
                HStack(spacing: DS.Spacing.lg) {
                    TelemetryItem(
                        icon: "arrow.down.circle",
                        label: "Rendered",
                        value: "\(stats.framesRendered)",
                        color: DS.Colors.success
                    )
                    TelemetryItem(
                        icon: "arrow.up.circle",
                        label: "Encoded",
                        value: "\(stats.framesEncoded)",
                        color: DS.Colors.accent
                    )
                    TelemetryItem(
                        icon: "clock",
                        label: "Latency",
                        value: String(format: "%.0fms", stats.averageRenderLatencyMs),
                        color: DS.Colors.info
                    )
                }
                .padding(DS.Spacing.md)
                .glass(style: .ultraThin, cornerRadius: DS.Radius.lg)
            }
        }
    }

    private var controlsSection: some View {
        HStack(spacing: DS.Spacing.md) {
            ElysiumButton(
                title: state.isRunning ? "Stop" : "Start",
                icon: state.isRunning ? "stop.fill" : "play.fill",
                color: state.isRunning ? DS.Colors.error : DS.Colors.success,
                style: .prominent
            ) {
                Task {
                    if state.isRunning { await state.stopNode() }
                    else { await state.startNode() }
                }
            }

            ElysiumButton(
                title: "Permissions",
                icon: "lock.shield",
                color: DS.Colors.warning,
                style: .bordered
            ) {
                Task { await state.checkPermissions() }
            }
        }
    }
}

struct TelemetryItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(label)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Text(value)
                .font(DS.Typography.monoBold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var state: NodeAppState

    var body: some View {
        Section {
            Label(state.isRunning ? "Running" : "Stopped", systemImage: state.isRunning ? "circle.fill" : "circle")
            if let console = state.connectedConsole {
                Label("Connected to \(console)", systemImage: "link")
            }
        }
        Divider()
        Button(state.isRunning ? "Stop" : "Start") {
            Task {
                if state.isRunning { await state.stopNode() }
                else { await state.startNode() }
            }
        }
        Button("Check Permissions") { Task { await state.checkPermissions() } }
        Divider()
        Button("Quit Elysium Node") { NSApplication.shared.terminate(nil) }
    }
}
