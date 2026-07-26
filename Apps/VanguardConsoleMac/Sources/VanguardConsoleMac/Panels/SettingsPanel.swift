import SwiftUI
import VanguardUI
import VanguardDomain

struct SettingsPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var selectedSection: SettingsSection = .general

    enum SettingsSection: String, CaseIterable {
        case general = "General"
        case network = "Network"
        case security = "Security"
        case display = "Display"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            sectionPicker
            Divider().background(Color.white.opacity(0.04))
            settingsContent
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("SETTINGS", systemImage: "gearshape.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textTertiary)
                
            Spacer()
        }
        .padding(DS.Spacing.lg)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    Button { selectedSection = section } label: {
                        Text(section.rawValue)
                            .font(DS.Typography.caption)
                            .foregroundColor(selectedSection == section ? DS.Colors.accent : DS.Colors.textTertiary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .glass(style: selectedSection == section ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.pill)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                switch selectedSection {
                case .general: generalSettings
                case .network: networkSettings
                case .security: securitySettings
                case .display: displaySettings
                case .about: aboutSection
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    private var generalSettings: some View {
        VStack(spacing: DS.Spacing.sm) {
            SettingsGroup(title: "APPLICATION") {
                SettingsRow(label: "Console Name", value: state.consoleName, icon: "person.fill")
                SettingsRow(label: "Version", value: "0.1.0", icon: "info.circle")
                SettingsRow(label: "Build", value: "2026.07", icon: "hammer.fill")
            }
            SettingsGroup(title: "BEHAVIOR") {
                ToggleRow(label: "Auto-scan on launch", icon: "antenna.radiowaves.left.and.right", isOn: true)
                ToggleRow(label: "Connect to last node", icon: "link", isOn: true)
                ToggleRow(label: "Start in menu bar", icon: "menubar.rectangle", isOn: true)
            }
        }
    }

    private var networkSettings: some View {
        VStack(spacing: DS.Spacing.sm) {
            SettingsGroup(title: "CONNECTION") {
                SettingsRow(label: "Service Type", value: "_elysium-vanguard._tcp", icon: "network")
                SettingsRow(label: "Default Port", value: "49494", icon: "number")
                SettingsRow(label: "Protocol Version", value: "1.0", icon: "doc.text")
            }
            SettingsGroup(title: "TLS") {
                SettingsRow(label: "Version", value: "TLS 1.3", icon: "lock.fill")
                SettingsRow(label: "Certificate Pinning", value: "Enabled", icon: "checkmark.shield")
                SettingsRow(label: "mTLS", value: "Enabled", icon: "lock.shield")
            }
        }
    }

    private var securitySettings: some View {
        VStack(spacing: DS.Spacing.sm) {
            SettingsGroup(title: "IDENTITY") {
                SettingsRow(label: "Signing Key", value: "Ed25519", icon: "key.fill")
                SettingsRow(label: "Key Agreement", value: "P256", icon: "lock.fill")
                SettingsRow(label: "Device ID", value: "Persistent", icon: "person.crop.rectangle")
            }
            SettingsGroup(title: "AUTHORIZATION") {
                ToggleRow(label: "Require approval for pairing", icon: "hand.raised", isOn: true)
                ToggleRow(label: "Require approval for jobs", icon: "hammer", isOn: true)
                ToggleRow(label: "Audit logging", icon: "doc.text", isOn: true)
            }
        }
    }

    private var displaySettings: some View {
        VStack(spacing: DS.Spacing.sm) {
            SettingsGroup(title: "THEME") {
                ForEach(ThemeProfile.allCases, id: \.self) { theme in
                    ToggleRow(label: theme.displayName, icon: "paintbrush", isOn: state.currentTheme == theme)
                }
            }
            SettingsGroup(title: "REMOTE DESKTOP") {
                ToggleRow(label: "Show FPS overlay", icon: "speedometer", isOn: true)
                ToggleRow(label: "Show crosshair", icon: "scope", isOn: true)
                ToggleRow(label: "Hardware decoding", icon: "cpu", isOn: true)
            }
        }
    }

    private var aboutSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Colors.accent.opacity(0.08))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 88, height: 88)
                Image(systemName: "scope")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DS.Colors.accent)
                    .neonGlow(DS.Colors.accent, radius: 10)
            }
            VStack(spacing: DS.Spacing.xs) {
                Text("ELYSIUM VANGUARD FABRIC")
                    .font(DS.Typography.micro)
                    .foregroundColor(DS.Colors.accent)
                    
                Text("v0.1.0")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            VStack(spacing: DS.Spacing.xs) {
                Text("Sovereign local-first remote desktop")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
                Text("and distributed computing platform")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
            }
            VStack(spacing: DS.Spacing.xs) {
                SettingsRow(label: "License", value: "Proprietary", icon: "doc.text")
                SettingsRow(label: "Copyright", value: "© 2026 Jorge David Del Valle Miranda", icon: "person.fill")
                SettingsRow(label: "Repository", value: "github.com/jordelmir/elysium-vanguard-fabric", icon: "arrow.up.forward.square")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsGroup: View {
    let title: String
    let content: AnyView

    init(title: String, @ViewBuilder content: () -> some View) {
        self.title = title
        self.content = AnyView(content())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                .padding(.horizontal, DS.Spacing.md)
            VStack(spacing: DS.Spacing.xs) {
                content
            }
            .glass(style: .ultraThin, cornerRadius: DS.Radius.lg)
            .adaptiveBorder()
        }
    }
}

struct SettingsRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(DS.Colors.accent)
                .frame(width: 20)
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

struct ToggleRow: View {
    let label: String
    let icon: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(DS.Colors.accent)
                .frame(width: 20)
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            Circle()
                .fill(isOn ? DS.Colors.success : DS.Colors.textQuaternary)
                .frame(width: 8, height: 8)
            Text(isOn ? "ON" : "OFF")
                .font(DS.Typography.micro)
                .foregroundColor(isOn ? DS.Colors.success : DS.Colors.textQuaternary)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}
