import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: NodeAppState
    @State private var showPairingSheet = false
    @State private var bgRotation: Double = 0

    var body: some View {
        ZStack {
            EV.Colors.bg.ignoresSafeArea()

            // Animated mesh background
            ZStack {
                RadialGradient(
                    colors: [EV.Colors.cyan.opacity(0.04), Color.clear],
                    center: .topLeading, startRadius: 0, endRadius: 300
                )
                .rotationEffect(.degrees(bgRotation))
                RadialGradient(
                    colors: [EV.Colors.blue.opacity(0.03), Color.clear],
                    center: .bottomTrailing, startRadius: 0, endRadius: 300
                )
                .rotationEffect(.degrees(-bgRotation))
            }
            .onAppear {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    bgRotation = 360
                }
            }
            .particleField(color: EV.Colors.cyan.opacity(0.15), count: 12)

            VStack(spacing: 0) {
                header
                Divider().background(EV.Colors.cyan.opacity(0.15))
                statusSection
                permissionsSection
                Divider().background(EV.Colors.cyan.opacity(0.15))
                controlsSection
            }
        }
        .frame(width: 420, height: 380)
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
    }

    private var header: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(EV.Colors.cyan.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(EV.Colors.cyan)
                    .neonGlow(EV.Colors.cyan, radius: 8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ELYSIUM")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(EV.Colors.cyan)
                    .tracking(4)
                Text("Vanguard Node")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(EV.Colors.textPrimary)
            }
            Spacer()
            StatusDot(color: state.isRunning ? EV.Colors.green : EV.Colors.textTertiary, size: 12)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var statusSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: state.isRunning ? "antenna.radiowaves.left.and.right" : "pause.circle")
                    .foregroundColor(state.isRunning ? EV.Colors.green : EV.Colors.textTertiary)
                    .font(.system(size: 16))
                Text(state.statusMessage)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(EV.Colors.textPrimary)
                Spacer()
            }
            .padding(12)
            .background(EV.Colors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke((state.isRunning ? EV.Colors.green : EV.Colors.textTertiary).opacity(0.2), lineWidth: 1)
            )
            .shadow(color: (state.isRunning ? EV.Colors.green : Color.clear).opacity(0.15), radius: 12, y: 4)

            if let console = state.connectedConsole {
                HStack(spacing: 10) {
                    Image(systemName: "link.badge.checkmark")
                        .foregroundColor(EV.Colors.cyan)
                    Text("Connected to \(console)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(EV.Colors.cyan)
                    Spacer()
                }
                .padding(12)
                .background(EV.Colors.cyan.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(EV.Colors.cyan.opacity(0.3), lineWidth: 1)
                )
                .neonGlow(EV.Colors.cyan, radius: 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var permissionsSection: some View {
        if state.permissions == .denied {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(EV.Colors.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Permissions Required")
                        .font(.system(.caption, weight: .bold))
                        .foregroundColor(EV.Colors.amber)
                    Text("Grant Screen Recording & Accessibility in System Settings")
                        .font(.caption2)
                        .foregroundColor(EV.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            .background(EV.Colors.amber.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(EV.Colors.amber.opacity(0.3), lineWidth: 1)
            )
            .neonGlow(EV.Colors.amber, radius: 4)
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                Task {
                    if state.isRunning { await state.stopNode() }
                    else { await state.startNode() }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: state.isRunning ? "stop.fill" : "play.fill")
                    Text(state.isRunning ? "Stop" : "Start")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeonProminentButtonStyle(color: state.isRunning ? EV.Colors.red : EV.Colors.green))

            Button(action: { Task { await state.checkPermissions() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                    Text("Permissions")
                }
            }
            .buttonStyle(NeonButtonStyle(color: EV.Colors.amber, isSmall: true))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
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
