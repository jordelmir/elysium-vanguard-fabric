import SwiftUI
import VanguardUI

enum PanelTab: String, CaseIterable {
    case remoteDesktop = "Remote Desktop"
    case nodes = "Nodos"
    case jobs = "Jobs"
    case resources = "Resources"
    case workspace = "Workspace"
    case terminal = "Terminal"
    case agents = "Agents"
    case security = "Security"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .remoteDesktop: return "display"
        case .nodes: return "network"
        case .jobs: return "hammer.fill"
        case .resources: return "chart.bar.fill"
        case .workspace: return "folder.fill"
        case .terminal: return "terminal"
        case .agents: return "brain.head.profile"
        case .security: return "shield.checkered"
        case .settings: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .remoteDesktop: return DS.Colors.accent
        case .nodes: return DS.Colors.info
        case .jobs: return DS.Colors.warning
        case .resources: return DS.Colors.success
        case .workspace: return DS.Colors.accent
        case .terminal: return DS.Colors.success
        case .agents: return DS.Colors.warning
        case .security: return DS.Colors.error
        case .settings: return DS.Colors.textTertiary
        }
    }
}

struct ConsoleView: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var selectedTab: PanelTab = .remoteDesktop
    @State private var selectedNode: ConsoleAppState.DiscoveredNode?

    var body: some View {
        CosmicBackground(baseColor: DS.Colors.info, particleCount: 35)
            .overlay(
                HStack(spacing: 0) {
                    navigationSidebar
                    Divider().background(Color.white.opacity(0.04))
                    mainContent
                }
            )
            .frame(minWidth: 1000, minHeight: 640)
            .environment(\.themeProfile, state.currentTheme)
    }

    private var navigationSidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
                .padding(DS.Spacing.lg)
            Divider().background(Color.white.opacity(0.04))
            nodeList
            Divider().background(Color.white.opacity(0.04))
            tabList
            Divider().background(Color.white.opacity(0.04))
            sidebarFooter
        }
        .frame(minWidth: 260, idealWidth: 300)
    }

    private var sidebarHeader: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.info.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "scope")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DS.Colors.info)
                        .neonGlow(DS.Colors.info, radius: 6)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("ELYSIUM")
                        .font(DS.Typography.micro)
                        .foregroundColor(DS.Colors.info)
                        .tracking(3)
                    Text("Console")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textPrimary)
                }
                Spacer()
            }

            Picker("Theme", selection: Binding(
                get: { state.currentTheme },
                set: { state.setTheme($0) }
            )) {
                ForEach(ThemeProfile.allCases, id: \.self) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            ElysiumButton(
                title: state.isScanning ? "Stop" : "Scan LAN",
                icon: state.isScanning ? "stop.fill" : "antenna.radiowaves.left.and.right",
                color: state.isScanning ? DS.Colors.error : DS.Colors.info,
                style: state.isScanning ? .bordered : .prominent
            ) {
                Task {
                    if state.isScanning { await state.stopScan() }
                    else { await state.startScan() }
                }
            }
        }
    }

    private var nodeList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("NODES")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                .tracking(2)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

            ScrollView {
                LazyVStack(spacing: DS.Spacing.xs) {
                    if state.discoveredNodes.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "radar")
                                    .font(.system(size: 16))
                                    .foregroundColor(DS.Colors.textQuaternary)
                                    .pulsing(DS.Colors.info.opacity(0.3))
                                Text("Scanning...")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textQuaternary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.md)
                    } else {
                        ForEach(Array(state.discoveredNodes.enumerated()), id: \.element.id) { index, node in
                            SidebarNodeCard(node: node, isSelected: selectedNode?.id == node.id)
                                .progressiveReveal(delay: Double(index) * 0.05)
                                .onTapGesture {
                                    selectedNode = node
                                    selectedTab = .remoteDesktop
                                    Task { await state.connectToNode(node) }
                                }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
            }
        }
    }

    private var tabList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("PANELS")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                .tracking(2)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

            ScrollView {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(PanelTab.allCases, id: \.self) { tab in
                        TabButton(tab: tab, isSelected: selectedTab == tab) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(state.isConnected ? DS.Colors.success : DS.Colors.textQuaternary)
                    .frame(width: 6, height: 6)
                Text(state.statusMessage)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
                Spacer()
            }
            HStack(spacing: DS.Spacing.sm) {
                Text("\(state.discoveredNodes.count) nodes")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
                Spacer()
            }
        }
        .padding(DS.Spacing.md)
    }

    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .remoteDesktop:
            remoteDesktopArea
        case .nodes:
            NodesPanel()
                .environmentObject(state)
        case .jobs:
            JobsPanel()
                .environmentObject(state)
        case .resources:
            ResourcesPanel()
                .environmentObject(state)
        case .workspace:
            WorkspacePanel()
                .environmentObject(state)
        case .terminal:
            TerminalPanel()
                .environmentObject(state)
        case .agents:
            AgentsPanel()
                .environmentObject(state)
        case .security:
            SecurityPanel()
                .environmentObject(state)
        case .settings:
            SettingsPanel()
                .environmentObject(state)
        }
    }

    @ViewBuilder
    private var remoteDesktopArea: some View {
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
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.success)
                .neonGlow(DS.Colors.success, radius: 14)
            Text("CONNECTED")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.success)
                .tracking(4)
            Text("Waiting for video stream...")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
        }
    }

    private var welcomePlaceholder: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(DS.Colors.info.opacity(0.04))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 120, height: 120)
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(DS.Colors.info)
                    .neonGlow(DS.Colors.info, radius: 10)
            }
            VStack(spacing: DS.Spacing.sm) {
                Text("ELYSIUM CONSOLE")
                    .font(DS.Typography.micro)
                    .foregroundColor(DS.Colors.info)
                    .tracking(4)
                Text("Select a node from the sidebar")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
                Text("or click Scan to discover nodes on LAN")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
        }
    }
}

struct SidebarNodeCard: View {
    let node: ConsoleAppState.DiscoveredNode
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            StatusIndicator(status: node.status == .online ? .connected : node.status == .connecting ? .scanning : .offline, size: 6)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(node.name)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textPrimary)
                Text(node.host)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            if node.status == .connecting {
                ProgressView().scaleEffect(0.4)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(DS.Colors.textQuaternary)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .glass(style: isSelected ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.md)
        .adaptiveBorder(highlighted: isHovered || isSelected)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
        .animation(DS.Animation.springFast, value: isSelected)
    }
}

struct TabButton: View {
    let tab: PanelTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? tab.color : DS.Colors.textTertiary)
                    .frame(width: 20)
                Text(tab.rawValue)
                    .font(DS.Typography.caption)
                    .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .glass(style: isSelected ? .colored(tab.color) : .ultraThin, cornerRadius: DS.Radius.md)
            .adaptiveBorder(highlighted: isHovered || isSelected)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
        .animation(DS.Animation.springFast, value: isSelected)
    }
}

struct PairingCodeView: View {
    let nodeName: String
    let challengeCode: String
    @EnvironmentObject private var state: ConsoleAppState
    @State private var enteredCode = ""
    @State private var submitError: String?
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DS.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.warning.opacity(0.08))
                        .frame(width: 68, height: 68)
                    Image(systemName: "key.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(DS.Colors.warning)
                        .neonGlow(DS.Colors.warning, radius: 8)
                }

                Text("ENTER PAIRING CODE")
                    .font(DS.Typography.micro)
                    .foregroundColor(DS.Colors.warning)
                    .tracking(4)

                Text("The node \(nodeName) is requesting pairing")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: DS.Spacing.xxxl)

            HStack(spacing: DS.Spacing.sm) {
                ForEach(0..<6) { index in
                    let char = index < enteredCode.count
                        ? String(enteredCode[enteredCode.index(enteredCode.startIndex, offsetBy: index)])
                        : ""
                    Text(char)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundColor(char.isEmpty ? DS.Colors.textQuaternary : DS.Colors.accent)
                        .frame(width: 40, height: 52)
                        .glass(style: .ultraThin, cornerRadius: DS.Radius.md)
                        .adaptiveBorder(char.isEmpty ? DS.Colors.border : DS.Colors.accent, highlighted: !char.isEmpty)
                        .shadow(color: char.isEmpty ? .clear : DS.Colors.accent.opacity(0.2), radius: 6)
                }
            }

            Spacer().frame(height: DS.Spacing.xl)

            TextField("", text: $enteredCode)
                .textFieldStyle(.plain)
                .font(DS.Typography.mono)
                .foregroundColor(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 200)
                .padding(DS.Spacing.md)
                .glass(style: .ultraThin, cornerRadius: DS.Radius.md)
                .onChange(of: enteredCode) { val in
                    enteredCode = String(val.filter(\.isNumber).prefix(6))
                }

            if let err = submitError {
                Text(err).font(DS.Typography.caption).foregroundColor(DS.Colors.error)
                    .padding(.top, DS.Spacing.sm)
            }

            Spacer().frame(height: DS.Spacing.xl)

            ElysiumButton(
                title: isSubmitting ? "Submitting..." : "Submit Code",
                icon: isSubmitting ? "arrow.triangle.2.circlepath" : "lock.open.fill",
                color: DS.Colors.warning
            ) {
                isSubmitting = true
                Task {
                    do {
                        try await state.submitPairingCode(enteredCode)
                    } catch {
                        submitError = error.localizedDescription
                    }
                    isSubmitting = false
                }
            }
            .disabled(enteredCode.count != 6 || isSubmitting)
            .opacity(enteredCode.count == 6 ? 1.0 : 0.4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
