import SwiftUI
import VanguardUI
import VanguardDomain

struct JobsPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var selectedTab: JobTab = .active

    enum JobTab: String, CaseIterable {
        case active = "Active"
        case queued = "Queued"
        case completed = "Completed"
        case failed = "Failed"
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            tabBar
            Divider().background(Color.white.opacity(0.04))
            jobList
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("JOBS", systemImage: "hammer.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.warning)
                
            Spacer()
            Text("0 active")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
        }
        .padding(DS.Spacing.lg)
    }

    private var tabBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(JobTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
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

    private var jobList: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sm) {
                emptyState
            }
            .padding(DS.Spacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.textQuaternary)
            Text("No \(selectedTab.rawValue.lowercased()) jobs")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textTertiary)
            Text("Submit a job from the Terminal or Agent panel")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct JobCard: View {
    let name: String
    let node: String
    let state: String
    let progress: Double?
    let color: Color
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textPrimary)
                Text("Node: \(node)")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            if let progress {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(state)
                        .font(DS.Typography.caption)
                        .foregroundColor(color)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(color.opacity(0.12)).frame(height: 3)
                            Capsule().fill(color).frame(width: geo.size.width * progress, height: 3)
                        }
                    }
                    .frame(width: 60, height: 3)
                }
            } else {
                Text(state)
                    .font(DS.Typography.caption)
                    .foregroundColor(color)
            }
        }
        .padding(DS.Spacing.md)
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
    }
}
