import SwiftUI
import VanguardUI
import VanguardDomain
import VanguardScheduler

struct ResourcesPanel: View {
    @EnvironmentObject private var state: ConsoleAppState

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            resourceList
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("RESOURCES", systemImage: "chart.bar.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.success)
            Spacer()
            Text("Live")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.success)
            Circle().fill(DS.Colors.success).frame(width: 6, height: 6)
                .opacity(pulseOpacity)
                .animation(.easeInOut(duration: 1.5).repeatForever(), value: pulseOpacity)
        }
        .padding(DS.Spacing.lg)
        .onAppear { pulseOpacity = 0.4 }
    }

    @State private var pulseOpacity: Double = 1.0

    private var resourceList: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                if state.discoveredNodes.isEmpty {
                    emptyState
                } else {
                    ForEach(state.discoveredNodes) { node in
                        NodeResourceCard(node: node)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "chart.xyaxis.line").font(.system(size: 28)).foregroundColor(DS.Colors.textQuaternary)
            Text("No resource data").font(DS.Typography.subheadline).foregroundColor(DS.Colors.textTertiary)
            Text("Connect to a node to see live metrics").font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }
}

struct NodeResourceCard: View {
    let node: ConsoleAppState.DiscoveredNode
    @State private var isHovered = false

    private var d: NodeResourceDescriptor? { node.resourceDescriptor }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(node.status == .online ? DS.Colors.success : DS.Colors.textQuaternary).frame(width: 8, height: 8)
                Text(node.name).font(DS.Typography.headline).foregroundColor(DS.Colors.textPrimary)
                Spacer()
                if let d = d {
                    Text("Updated \(Int(Date().timeIntervalSince(d.measuredAt)))s ago")
                        .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
                }
            }.padding(DS.Spacing.md)

            Divider().background(Color.white.opacity(0.04))

            VStack(spacing: DS.Spacing.sm) {
                MetricRow(icon: "cpu", label: "CPU", value: cpuLabel, detail: "\(d?.physicalCPUCount ?? 0) cores \(d?.architecture.rawValue ?? "")", color: DS.Colors.info, barValue: d?.currentCPULoad ?? 0)
                MetricRow(icon: "memorychip", label: "Memory", value: memLabel, detail: memPercent, color: DS.Colors.warning, barValue: 1.0 - (d.map { Double($0.availableMemoryBytes) / Double($0.totalMemoryBytes) } ?? 0))
                MetricRow(icon: "internaldrive", label: "Storage", value: storageLabel, detail: storagePercent, color: DS.Colors.accent, barValue: 1.0 - (d.map { Double($0.availableStorageBytes) / Double($0.totalStorageBytes) } ?? 0))
                MetricRow(icon: "thermometer", label: "Thermal", value: d?.thermalState.rawValue.capitalized ?? "Nominal", detail: thermalDetail, color: DS.Colors.success, barValue: d?.thermalState.schedulerScore ?? 0.8)
                MetricRow(icon: "bolt.fill", label: "Power", value: powerLabel, detail: powerDetail, color: DS.Colors.success, barValue: 1.0)
                MetricRow(icon: "network", label: "Jobs", value: "\(d?.currentJobCount ?? 0)", detail: "Active", color: DS.Colors.info, barValue: 0)
                if let d = d, d.logicalCPUCount != d.physicalCPUCount {
                    MetricRow(icon: "cpu", label: "Threads", value: "\(d.logicalCPUCount)", detail: "Logical", color: DS.Colors.info, barValue: 0)
                }
                if let d = d {
                    MetricRow(icon: "gauge.medium", label: "Pressure", value: String(format: "%.0f%%", d.currentMemoryPressure * 100), detail: d.currentMemoryPressure > 0.8 ? "High" : "Normal", color: d.currentMemoryPressure > 0.8 ? DS.Colors.error : DS.Colors.success, barValue: d.currentMemoryPressure)
                }
            }.padding(DS.Spacing.md)
        }
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
    }

    private var cpuLabel: String { d.map { String(format: "%.0f%%", $0.currentCPULoad * 100) } ?? "—" }
    private var memLabel: String { d.map { "\($0.availableMemoryBytes / (1024*1024*1024)) / \($0.totalMemoryBytes / (1024*1024*1024)) GB" } ?? "—" }
    private var memPercent: String { d.map { "\(Int((1.0 - Double($0.availableMemoryBytes) / Double($0.totalMemoryBytes)) * 100))% used" } ?? "—" }
    private var storageLabel: String { d.map { "\($0.availableStorageBytes / (1024*1024*1024)) / \($0.totalStorageBytes / (1024*1024*1024)) GB" } ?? "—" }
    private var storagePercent: String { d.map { "\(Int((1.0 - Double($0.availableStorageBytes) / Double($0.totalStorageBytes)) * 100))% used" } ?? "—" }
    private var thermalDetail: String { d.map { $0.currentCPULoad < 0.5 ? "Cool" : $0.currentCPULoad < 0.8 ? "Warm" : "Hot" } ?? "—" }
    private var powerLabel: String { d?.batteryState?.displayName ?? "AC Power" }
    private var powerDetail: String { d?.batteryState != nil ? "Battery" : "Connected" }
}

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color
    var barValue: Double = 0

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(color).frame(width: 20)
            Text(label).font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary).frame(width: 60, alignment: .leading)
            Text(value).font(DS.Typography.monoBold).foregroundColor(DS.Colors.textPrimary)
            Spacer()
            Text(detail).font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
        }
        if barValue > 0 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12)).frame(height: 2)
                    Capsule().fill(color).frame(width: geo.size.width * min(barValue, 1.0), height: 2)
                }
            }
            .frame(height: 2)
            .padding(.leading, DS.Spacing.md + 20 + DS.Spacing.md)
        }
    }
}
