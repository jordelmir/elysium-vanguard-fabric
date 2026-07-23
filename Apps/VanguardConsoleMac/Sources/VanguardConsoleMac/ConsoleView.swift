import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var bgRotation: Double = 0

    var body: some View {
        ZStack {
            EV.Colors.bg.ignoresSafeArea()

            ZStack {
                RadialGradient(
                    colors: [EV.Colors.blue.opacity(0.04), Color.clear],
                    center: .topTrailing, startRadius: 0, endRadius: 350
                )
                .rotationEffect(.degrees(bgRotation))
                RadialGradient(
                    colors: [EV.Colors.steel.opacity(0.03), Color.clear],
                    center: .bottomLeading, startRadius: 0, endRadius: 350
                )
                .rotationEffect(.degrees(-bgRotation))
            }
            .onAppear {
                withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                    bgRotation = 360
                }
            }
            .particleField(color: EV.Colors.blue.opacity(0.12), count: 10)

            HStack(spacing: 0) {
                sidebar
                Divider().background(EV.Colors.blue.opacity(0.15))
                mainArea
            }
        }
        .frame(minWidth: 800, minHeight: 540)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider().background(EV.Colors.blue.opacity(0.15))
            nodeList
        }
        .frame(minWidth: 240, idealWidth: 280)
        .background(EV.Colors.bg)
    }

    private var sidebarHeader: some View {
        VStack(spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(EV.Colors.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "scope")
                        .font(.system(size: 16))
                        .foregroundColor(EV.Colors.blue)
                        .neonGlow(EV.Colors.blue, radius: 8)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("ELYSIUM")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(EV.Colors.blue)
                        .tracking(3)
                    Text("Console")
                        .font(.headline)
                        .foregroundColor(EV.Colors.textPrimary)
                }
                Spacer()
            }

            Button(action: {
                Task {
                    if state.isScanning { await state.stopScan() }
                    else { await state.startScan() }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: state.isScanning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                    Text(state.isScanning ? "Stop" : "Scan")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeonButtonStyle(color: state.isScanning ? EV.Colors.red : EV.Colors.blue))
        }
        .padding(16)
    }

    private var nodeList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if state.discoveredNodes.isEmpty {
                    emptyState
                } else {
                    ForEach(state.discoveredNodes) { node in
                        NodeCard(node: node)
                            .onTapGesture {
                                Task { await state.connectToNode(node) }
                            }
                    }
                }
            }
            .padding(12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [EV.Colors.blue.opacity(0.3), Color.clear, EV.Colors.blue.opacity(0.3)],
                            center: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 60, height: 60)
                Image(systemName: "radar")
                    .font(.system(size: 28))
                    .foregroundColor(EV.Colors.textTertiary)
            }
            .pulsing(EV.Colors.blue.opacity(0.3))
            Text("Scanning LAN...")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(EV.Colors.textTertiary)
            Text("Start the Node app on another Mac")
                .font(.caption)
                .foregroundColor(EV.Colors.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var mainArea: some View {
        switch state.currentState {
        case .pairing(let code):
            PairingCodeView(nodeName: state.connectedNodeName ?? "Node", challengeCode: code)
                .environmentObject(state)
        case .connected, .paired, .capturing:
            if let node = state.discoveredNodes.first(where: { $0.status == .online }) {
                RemoteDesktopView(nodeName: node.name)
                    .environmentObject(state)
            } else {
                connectedPlaceholder
            }
        default:
            welcomePlaceholder
        }
    }

    private var connectedPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(EV.Colors.green)
                .neonGlow(EV.Colors.green, radius: 14)
            Text("CONNECTED")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(EV.Colors.green)
                .tracking(4)
            Text("Waiting for video stream...")
                .font(.subheadline)
                .foregroundColor(EV.Colors.textSecondary)
            Spacer()
        }
    }

    private var welcomePlaceholder: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(EV.Colors.blue.opacity(0.05))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(EV.Colors.blue.opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 44))
                    .foregroundColor(EV.Colors.blue)
                    .neonGlow(EV.Colors.blue, radius: 10)
            }
            VStack(spacing: 6) {
                Text("ELYSIUM CONSOLE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(EV.Colors.blue)
                    .tracking(4)
                Text("Select a node from the sidebar")
                    .font(.subheadline)
                    .foregroundColor(EV.Colors.textSecondary)
            }
            Spacer()
        }
    }
}

struct NodeCard: View {
    let node: ConsoleAppState.DiscoveredNode
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 14))
                    .foregroundColor(statusColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(node.name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundColor(EV.Colors.textPrimary)
                Text(node.host)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(EV.Colors.textTertiary)
            }
            Spacer()
            if node.status == .connecting {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(EV.Colors.textTertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovering ? EV.Colors.surfaceLight.opacity(0.5) : EV.Colors.surface.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hovering ? statusColor.opacity(0.4) : EV.Colors.textTertiary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: hovering ? statusColor.opacity(0.1) : .clear, radius: 8, y: 2)
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
    }

    private var statusColor: Color {
        switch node.status {
        case .online: return EV.Colors.green
        case .offline: return EV.Colors.textTertiary
        case .connecting: return EV.Colors.amber
        }
    }
}

struct PairingCodeView: View {
    let nodeName: String
    let challengeCode: String
    @EnvironmentObject private var state: ConsoleAppState
    @State private var enteredCode = ""
    @State private var submitError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(EV.Colors.amber.opacity(0.08))
                        .frame(width: 72, height: 72)
                    Image(systemName: "key.fill")
                        .font(.system(size: 30))
                        .foregroundColor(EV.Colors.amber)
                        .neonGlow(EV.Colors.amber, radius: 10)
                }

                Text("ENTER PAIRING CODE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(EV.Colors.amber)
                    .tracking(4)

                Text("The node \(nodeName) is requesting pairing")
                    .font(.subheadline)
                    .foregroundColor(EV.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 36)

            HStack(spacing: 8) {
                ForEach(0..<6) { index in
                    let char = index < enteredCode.count
                        ? String(enteredCode[enteredCode.index(enteredCode.startIndex, offsetBy: index)])
                        : ""
                    Text(char)
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .foregroundColor(EV.Colors.cyan)
                        .frame(width: 42, height: 54)
                        .background(EV.Colors.cyan.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(char.isEmpty ? EV.Colors.textTertiary.opacity(0.2) : EV.Colors.cyan.opacity(0.5), lineWidth: 1.5)
                        )
                        .shadow(color: char.isEmpty ? .clear : EV.Colors.cyan.opacity(0.3), radius: 6)
                }
            }

            Spacer().frame(height: 24)

            TextField("", text: $enteredCode)
                .textFieldStyle(NeonTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .foregroundColor(EV.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 200)
                .onChange(of: enteredCode) { val in
                    enteredCode = String(val.filter(\.isNumber).prefix(6))
                }

            if let err = submitError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(EV.Colors.red)
                    .padding(.top, 8)
            }

            Spacer().frame(height: 24)

            Button(action: {
                Task {
                    do { try await state.submitPairingCode(enteredCode) }
                    catch { submitError = error.localizedDescription }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                    Text("Submit Code")
                }
                .frame(width: 200)
            }
            .buttonStyle(NeonProminentButtonStyle(color: EV.Colors.amber))
            .disabled(enteredCode.count != 6)
            .opacity(enteredCode.count == 6 ? 1.0 : 0.5)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EV.Colors.bg)
    }
}

struct ConsoleMenuBarView: View {
    @EnvironmentObject private var state: ConsoleAppState

    var body: some View {
        Section {
            Label(state.isScanning ? "Scanning..." : "Idle", systemImage: state.isScanning ? "antenna.radiowaves.left.and.right" : "circle")
            Label("Nodes: \(state.discoveredNodes.count)", systemImage: "list.bullet")
        }
        Divider()
        Button(state.isScanning ? "Stop Scan" : "Start Scan") {
            Task {
                if state.isScanning { await state.stopScan() }
                else { await state.startScan() }
            }
        }
        Divider()
        Button("Quit Elysium Console") { NSApplication.shared.terminate(nil) }
    }
}
