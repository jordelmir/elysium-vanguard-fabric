import SwiftUI
import VanguardUI
import VanguardDomain

struct SecurityPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var selectedTab: SecurityTab = .capabilities

    enum SecurityTab: String, CaseIterable {
        case capabilities = "Capabilities"
        case peers = "Peers"
        case audit = "Audit Log"
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            tabBar
            Divider().background(Color.white.opacity(0.04))
            content
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("SECURITY", systemImage: "shield.checkered")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.error)
                
            Spacer()
            HStack(spacing: DS.Spacing.xs) {
                Circle().fill(DS.Colors.success).frame(width: 6, height: 6)
                Text("Zero Trust Active")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.success)
            }
        }
        .padding(DS.Spacing.lg)
    }

    private var tabBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(SecurityTab.allCases, id: \.self) { tab in
                Button { selectedTab = tab } label: {
                    Text(tab.rawValue)
                        .font(DS.Typography.caption)
                        .foregroundColor(selectedTab == tab ? DS.Colors.accent : DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .glass(style: selectedTab == tab ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.pill)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                switch selectedTab {
                case .capabilities: capabilitiesView
                case .peers: peersView
                case .audit: auditView
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    private var capabilitiesView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("GRANTED CAPABILITIES")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.xs) {
                CapabilityItem(name: "Screen View", icon: "display", granted: true)
                CapabilityItem(name: "Screen Control", icon: "cursorarrow", granted: true)
                CapabilityItem(name: "Audio Receive", icon: "speaker.wave.2", granted: false)
                CapabilityItem(name: "Clipboard Read", icon: "doc.on.clipboard", granted: true)
                CapabilityItem(name: "Clipboard Write", icon: "clipboard", granted: true)
                CapabilityItem(name: "Terminal Open", icon: "terminal", granted: true)
                CapabilityItem(name: "File Read", icon: "doc.text", granted: true)
                CapabilityItem(name: "File Write", icon: "square.and.arrow.down", granted: false)
                CapabilityItem(name: "Process Execute", icon: "gearshape.2", granted: true)
                CapabilityItem(name: "Job Submit", icon: "hammer.fill", granted: true)
                CapabilityItem(name: "Artifact Read", icon: "archivebox", granted: true)
                CapabilityItem(name: "Policy Admin", icon: "lock.shield", granted: false)
            }
        }
    }

    private var peersView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("TRUSTED PEERS")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                

            if state.discoveredNodes.isEmpty {
                emptyPeerState
            } else {
                ForEach(state.discoveredNodes) { node in
                    PeerCard(name: node.name, host: node.host, trusted: node.status == .online)
                }
            }
        }
    }

    private var auditView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("AUDIT TRAIL")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                

            AuditEntry(action: "Console started", time: "Just now", severity: .info)
            AuditEntry(action: "LAN scan initiated", time: "Just now", severity: .info)
            AuditEntry(action: "Clipboard sync started", time: "1m ago", severity: .info)
            AuditEntry(action: "Session connected", time: "2m ago", severity: .success)
        }
    }

    private var emptyPeerState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 22))
                .foregroundColor(DS.Colors.textQuaternary)
            Text("No trusted peers yet")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}

struct CapabilityItem: View {
    let name: String
    let icon: String
    let granted: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(granted ? DS.Colors.success : DS.Colors.textQuaternary)
                .frame(width: 16)
            Text(name)
                .font(DS.Typography.caption)
                .foregroundColor(granted ? DS.Colors.textSecondary : DS.Colors.textQuaternary)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .glass(style: .ultraThin, cornerRadius: DS.Radius.sm)
    }
}

struct PeerCard: View {
    let name: String
    let host: String
    let trusted: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(trusted ? DS.Colors.success : DS.Colors.error)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textPrimary)
                Text(host)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            Text(trusted ? "TRUSTED" : "UNTRUSTED")
                .font(DS.Typography.micro)
                .foregroundColor(trusted ? DS.Colors.success : DS.Colors.error)
        }
        .padding(DS.Spacing.md)
        .glass(style: .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder()
    }
}

struct AuditEntry: View {
    let action: String
    let time: String
    let severity: Severity

    enum Severity {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info: return DS.Colors.info
            case .success: return DS.Colors.success
            case .warning: return DS.Colors.warning
            case .error: return DS.Colors.error
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .success: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            }
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: severity.icon)
                .font(.system(size: 10))
                .foregroundColor(severity.color)
            Text(action)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Text(time)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
    }
}
