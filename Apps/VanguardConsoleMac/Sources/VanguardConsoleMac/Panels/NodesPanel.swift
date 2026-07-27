import SwiftUI
import VanguardUI
import VanguardDomain
import VanguardScheduler

struct NodesPanel: View {
    @EnvironmentObject private var state: ConsoleAppState

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            if state.discoveredNodes.isEmpty {
                emptyState
            } else {
                nodeList
            }
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("NODOS", systemImage: "network")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.info)
            Spacer()
            Text("\(state.discoveredNodes.filter({ $0.status == .online }).count) online")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.success)
            Text("\(state.discoveredNodes.count) total")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
        }
        .padding(DS.Spacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "network.slash")
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.textQuaternary)
            Text("No nodes discovered")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textTertiary)
            Text("Start VanguardNode on another Mac and click Scan")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var nodeList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(Array(state.discoveredNodes.enumerated()), id: \.element.id) { index, node in
                    NodeDetailCard(node: node)
                        .progressiveReveal(delay: Double(index) * 0.05)
                }
            }
            .padding(DS.Spacing.md)
        }
    }
}

struct NodeDetailCard: View {
    let node: ConsoleAppState.DiscoveredNode
    @State private var isHovered = false

    private var descriptor: NodeResourceDescriptor? { node.resourceDescriptor }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                StatusIndicator(status: node.status == .online ? .connected : node.status == .connecting ? .scanning : .offline, size: 10)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(node.name)
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("\(node.host) · \(node.advertisement.architecture.rawValue)")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                }
                Spacer()
                if let d = descriptor {
                    Text("\(d.physicalCPUCount) cores · \(d.totalMemoryBytes / (1024*1024*1024))GB RAM")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                }
                Text(node.status == .online ? "ONLINE" : node.status == .connecting ? "CONNECTING" : "OFFLINE")
                    .font(DS.Typography.micro)
                    .foregroundColor(node.status == .online ? DS.Colors.success : node.status == .connecting ? DS.Colors.warning : DS.Colors.textQuaternary)
            }
            .padding(DS.Spacing.md)

            Divider().background(Color.white.opacity(0.04))

            HStack(spacing: DS.Spacing.lg) {
                ResourceBar(icon: "cpu", label: "CPU", value: descriptor?.currentCPULoad ?? 0, color: DS.Colors.info)
                ResourceBar(icon: "memorychip", label: "RAM", value: ramUsage, color: DS.Colors.warning)
                ResourceBar(icon: "internaldrive", label: "Disk", value: diskUsage, color: DS.Colors.accent)
                ResourceBar(icon: "thermometer", label: "Thermal", value: descriptor?.thermalState.schedulerScore ?? 0.8, color: DS.Colors.success)
            }
            .padding(DS.Spacing.md)

            if let d = descriptor {
                Divider().background(Color.white.opacity(0.04))
                HStack(spacing: DS.Spacing.md) {
                    Label("\(d.currentJobCount) jobs", systemImage: "hammer.fill")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textTertiary)
                    Spacer()
                    if let battery = d.batteryState {
                        Label(battery.displayName, systemImage: battery == .charging ? "battery.100.bolt" : "battery.75")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                    Label(d.operatingSystem.version, systemImage: "laptopcomputer")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }
        }
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
    }

    private var ramUsage: Double {
        guard let d = descriptor, d.totalMemoryBytes > 0 else { return 0 }
        return 1.0 - Double(d.availableMemoryBytes) / Double(d.totalMemoryBytes)
    }

    private var diskUsage: Double {
        guard let d = descriptor, d.totalStorageBytes > 0 else { return 0 }
        return 1.0 - Double(d.availableStorageBytes) / Double(d.totalStorageBytes)
    }
}

struct ResourceBar: View {
    let icon: String
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(label)
                    .font(DS.Typography.micro)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.12)).frame(height: 4)
                    Capsule().fill(color).frame(width: geo.size.width * min(value, 1.0), height: 4)
                }
            }
            .frame(height: 4)
            Text("\(Int(value * 100))%")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
