import SwiftUI
import VanguardUI
import VanguardDomain

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
            Button { } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
    }

    private var resourceList: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                if state.discoveredNodes.isEmpty {
                    emptyState
                } else {
                    ForEach(state.discoveredNodes) { node in
                        NodeResourceCard(name: node.name, host: node.host, isOnline: node.status == .online)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.textQuaternary)
            Text("No resource data")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textTertiary)
            Text("Connect to a node to see live metrics")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct NodeResourceCard: View {
    let name: String
    let host: String
    let isOnline: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle()
                    .fill(isOnline ? DS.Colors.success : DS.Colors.textQuaternary)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text(host)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            .padding(DS.Spacing.md)

            Divider().background(Color.white.opacity(0.04))

            VStack(spacing: DS.Spacing.sm) {
                MetricRow(icon: "cpu", label: "CPU", value: "38%", detail: "8 cores arm64", color: DS.Colors.info)
                MetricRow(icon: "memorychip", label: "Memory", value: "11.5 / 16 GB", detail: "71% used", color: DS.Colors.warning)
                MetricRow(icon: "internaldrive", label: "Storage", value: "230 / 512 GB", detail: "45% used", color: DS.Colors.accent)
                MetricRow(icon: "thermometer", label: "Thermal", value: "Nominal", detail: "42°C", color: DS.Colors.success)
                MetricRow(icon: "bolt.fill", label: "Power", value: "AC Power", detail: "Full charge", color: DS.Colors.success)
                MetricRow(icon: "network", label: "Network", value: "1 Gbps", detail: "Latency: 1ms", color: DS.Colors.info)
            }
            .padding(DS.Spacing.md)
        }
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
    }
}

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textTertiary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(DS.Typography.monoBold)
                .foregroundColor(DS.Colors.textPrimary)
            Spacer()
            Text(detail)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
        }
    }
}
