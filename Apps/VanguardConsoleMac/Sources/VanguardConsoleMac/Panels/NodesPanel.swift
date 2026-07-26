import SwiftUI
import VanguardUI
import VanguardDomain

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
            Text("\(state.discoveredNodes.count) found")
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                StatusIndicator(status: node.status == .online ? .connected : node.status == .connecting ? .scanning : .offline, size: 10)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(node.name)
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textPrimary)
                    Text(node.host)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                }
                Spacer()
                if node.status == .connecting {
                    ProgressView().scaleEffect(0.5)
                } else {
                    Text(node.status == .online ? "ONLINE" : "OFFLINE")
                        .font(DS.Typography.micro)
                        .foregroundColor(node.status == .online ? DS.Colors.success : DS.Colors.textQuaternary)
                }
            }
            .padding(DS.Spacing.md)

            Divider().background(Color.white.opacity(0.04))

            HStack(spacing: DS.Spacing.lg) {
                ResourceBar(icon: "cpu", label: "CPU", value: 0.38, color: DS.Colors.info)
                ResourceBar(icon: "memorychip", label: "RAM", value: 0.71, color: DS.Colors.warning)
                ResourceBar(icon: "internaldrive", label: "Disk", value: 0.45, color: DS.Colors.accent)
                ResourceBar(icon: "thermometer", label: "Temp", value: 0.32, color: DS.Colors.success)
            }
            .padding(DS.Spacing.md)
        }
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
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
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(value, 1.0), height: 4)
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
