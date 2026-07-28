import SwiftUI
import VanguardUI
import VanguardDomain
import VanguardUpdates

struct SettingsPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @AppStorage("vanguard.darkMode") private var darkMode = true
    @AppStorage("vanguard.hardwareAccel") private var hardwareAccel = true
    @AppStorage("vanguard.showFPS") private var showFPS = true
    @AppStorage("vanguard.scrollbackLimit") private var scrollbackLimit = 10000
    @AppStorage("vanguard.cpuWeight") private var cpuWeight: Double = 0.25
    @AppStorage("vanguard.memoryWeight") private var memoryWeight: Double = 0.15
    @AppStorage("vanguard.localityWeight") private var localityWeight: Double = 0.20
    @AppStorage("vanguard.latencyWeight") private var latencyWeight: Double = 0.10
    @AppStorage("vanguard.reliabilityWeight") private var reliabilityWeight: Double = 0.15
    @AppStorage("vanguard.thermalWeight") private var thermalWeight: Double = 0.10
    @AppStorage("vanguard.energyWeight") private var energyWeight: Double = 0.05

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            settingsContent
        }
        .onAppear { syncFromBackend() }
    }

    private func syncFromBackend() {
        state.terminalScrollbackLimit = scrollbackLimit
        let w = state.schedulerWeights
        cpuWeight = w.cpuWeight
        memoryWeight = w.memoryWeight
        localityWeight = w.localityWeight
        latencyWeight = w.latencyWeight
        reliabilityWeight = w.reliabilityWeight
        thermalWeight = w.thermalWeight
        energyWeight = w.energyWeight
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

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                generalSection
                networkSection
                securitySection
                schedulerSection
                displaySection
                aboutSection
            }.padding(DS.Spacing.md)
        }
    }

    private var generalSection: some View {
        SettingsGroup(title: "GENERAL", icon: "gearshape") {
            SettingsRow(label: "Version", value: "v0.1.0-alpha")
            SettingsRow(label: "Build", value: "2026.01.25")
            SettingsRow(label: "Node", value: state.connectedNodeName ?? "Disconnected")
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack {
                    Text("Terminal Scrollback").font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary)
                    Spacer()
                    Text("\(scrollbackLimit)").font(DS.Typography.mono).foregroundColor(DS.Colors.textPrimary)
                }
                Slider(value: Binding(
                    get: { Double(scrollbackLimit) },
                    set: { scrollbackLimit = Int($0); state.terminalScrollbackLimit = scrollbackLimit }
                ), in: 1000...50000, step: 1000)
                    .tint(DS.Colors.accent)
            }
        }
    }

    private var networkSection: some View {
        SettingsGroup(title: "NETWORK", icon: "network") {
            SettingsRow(label: "Protocol", value: "Elysium v1.0")
            SettingsRow(label: "Service Type", value: "_elysium-vanguard._tcp")
            SettingsRow(label: "Port", value: "49494")
            SettingsRow(label: "TLS", value: "TLS 1.3 (Mutual)")
            SettingsRow(label: "Connected Nodes", value: "\(state.discoveredNodes.filter({ $0.status == .online }).count)")
        }
    }

    private var securitySection: some View {
        SettingsGroup(title: "SECURITY", icon: "lock.shield") {
            SettingsRow(label: "Model", value: "Zero Trust")
            SettingsRow(label: "Capabilities", value: "\(state.grantedCapabilities.count) granted")
            SettingsRow(label: "Audit Entries", value: "\(state.auditEntries.count)")
            SettingsRow(label: "Fabric Events", value: "\(state.fabricEvents.count)")
        }
    }

    private var schedulerSection: some View {
        SettingsGroup(title: "SCHEDULER WEIGHTS", icon: "slider.horizontal.3") {
            WeightSlider(label: "CPU", value: $cpuWeight, color: DS.Colors.info)
            WeightSlider(label: "Memory", value: $memoryWeight, color: DS.Colors.warning)
            WeightSlider(label: "Locality", value: $localityWeight, color: DS.Colors.accent)
            WeightSlider(label: "Latency", value: $latencyWeight, color: DS.Colors.success)
            WeightSlider(label: "Reliability", value: $reliabilityWeight, color: DS.Colors.info)
            WeightSlider(label: "Thermal", value: $thermalWeight, color: DS.Colors.error)
            WeightSlider(label: "Energy", value: $energyWeight, color: DS.Colors.success)
            HStack {
                let total = cpuWeight + memoryWeight + localityWeight + latencyWeight + reliabilityWeight + thermalWeight + energyWeight
                Text("Total: \(Int(total * 100))%")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
                Spacer()
                ElysiumButton(title: "Apply", icon: "checkmark", color: DS.Colors.accent) {
                    let weights = ConsoleAppState.SchedulerWeights(
                        cpuWeight: cpuWeight, memoryWeight: memoryWeight,
                        localityWeight: localityWeight, latencyWeight: latencyWeight,
                        reliabilityWeight: reliabilityWeight, thermalWeight: thermalWeight,
                        energyWeight: energyWeight
                    )
                    state.updateSchedulerWeights(weights)
                }.controlSize(.small)
            }
        }
    }

    private var displaySection: some View {
        SettingsGroup(title: "DISPLAY", icon: "display") {
            ToggleRow(label: "Dark Mode", isOn: $darkMode)
            ToggleRow(label: "Hardware Accel", isOn: $hardwareAccel)
            ToggleRow(label: "Show FPS Overlay", isOn: $showFPS)
        }
    }

    private var aboutSection: some View {
        SettingsGroup(title: "ABOUT", icon: "info.circle") {
            SettingsRow(label: "Product", value: "Elysium Vanguard Fabric")
            SettingsRow(label: "Developer", value: "Jorge David Del Valle Miranda")
            SettingsRow(label: "Copyright", value: "2026 All rights reserved")
            SettingsRow(label: "License", value: "Proprietary")
        }
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(title, systemImage: icon).font(DS.Typography.micro).foregroundColor(DS.Colors.info)
                Spacer()
            }.padding(DS.Spacing.md)
            VStack(spacing: DS.Spacing.xxs) { content }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)
        }
        .glass(style: .ultraThin, cornerRadius: DS.Radius.lg)
    }
}

struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary)
            Spacer()
            Text(value).font(DS.Typography.mono).foregroundColor(DS.Colors.textPrimary)
        }.padding(.vertical, DS.Spacing.xxs)
    }
}

struct WeightSlider: View {
    let label: String
    @Binding var value: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label).font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary).frame(width: 70, alignment: .leading)
            Slider(value: $value, in: 0...1)
                .tint(color)
            Text("\(Int(value * 100))%").font(DS.Typography.mono).foregroundColor(DS.Colors.textPrimary).frame(width: 35, alignment: .trailing)
        }.padding(.vertical, DS.Spacing.xxs)
    }
}

struct ToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label).font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(DS.Colors.accent)
        }.padding(.vertical, DS.Spacing.xxs)
    }
}
