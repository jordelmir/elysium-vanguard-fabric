import SwiftUI
import VanguardUI
import VanguardDomain

struct AgentsPanel: View {
    @EnvironmentObject private var state: ConsoleAppState

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            agentContent
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("AGENTS", systemImage: "brain.head.profile")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.warning)
                
            Spacer()
            Circle()
                .fill(DS.Colors.success)
                .frame(width: 6, height: 6)
            Text("Ready")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.success)
        }
        .padding(DS.Spacing.lg)
    }

    private var agentContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                agentStatusCard
                recentPlans
                capabilities
            }
            .padding(DS.Spacing.md)
        }
    }

    private var agentStatusCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(DS.Colors.warning)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Agent Pipeline")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textPrimary)
                    Text("Planner → Policy → Validator → Approval → Compiler")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                }
                Spacer()
                Text("IDLE")
                    .font(DS.Typography.micro)
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)

            Divider().background(Color.white.opacity(0.04))

            HStack(spacing: DS.Spacing.lg) {
                AgentMetric(icon: "checkmark.circle", label: "Executed", value: "0", color: DS.Colors.success)
                AgentMetric(icon: "clock", label: "Pending", value: "0", color: DS.Colors.warning)
                AgentMetric(icon: "xmark.circle", label: "Failed", value: "0", color: DS.Colors.error)
                AgentMetric(icon: "shield.checkered", label: "Approved", value: "0", color: DS.Colors.info)
            }
            .padding(DS.Spacing.md)
        }
        .glass(style: .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder()
    }

    private var recentPlans: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("RECENT PLANS")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                

            VStack(spacing: DS.Spacing.xs) {
                PlanCard(
                    objective: "No plans yet",
                    risk: "readOnly",
                    steps: 0,
                    status: "Waiting",
                    color: DS.Colors.textQuaternary
                )
            }
        }
    }

    private var capabilities: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("AGENT CAPABILITIES")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.xs) {
                CapabilityBadge(name: "Screen View", enabled: true)
                CapabilityBadge(name: "Screen Control", enabled: true)
                CapabilityBadge(name: "Terminal", enabled: true)
                CapabilityBadge(name: "File Read", enabled: true)
                CapabilityBadge(name: "File Write", enabled: false)
                CapabilityBadge(name: "Job Submit", enabled: true)
                CapabilityBadge(name: "Artifact Read", enabled: true)
                CapabilityBadge(name: "Policy Admin", enabled: false)
            }
        }
    }
}

struct AgentMetric: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(label)
                    .font(DS.Typography.micro)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Text(value)
                .font(DS.Typography.monoBold)
                .foregroundColor(DS.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PlanCard: View {
    let objective: String
    let risk: String
    let steps: Int
    let status: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(objective)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                Text("\(steps) steps · \(risk) risk")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            Text(status)
                .font(DS.Typography.micro)
                .foregroundColor(color)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .glass(style: .ultraThin, cornerRadius: DS.Radius.md)
    }
}

struct CapabilityBadge: View {
    let name: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 9))
                .foregroundColor(enabled ? DS.Colors.success : DS.Colors.textQuaternary)
            Text(name)
                .font(DS.Typography.caption)
                .foregroundColor(enabled ? DS.Colors.textSecondary : DS.Colors.textQuaternary)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .glass(style: .ultraThin, cornerRadius: DS.Radius.sm)
    }
}
