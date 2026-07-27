import SwiftUI
import VanguardUI
import VanguardDomain
import VanguardCompute

struct JobsPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var selectedTab: JobTab = .active
    @State private var showNewJob = false
    @State private var newJobName = ""
    @State private var newJobExecutable = ""
    @State private var selectedJob: ConsoleAppState.TrackedJob?

    enum JobTab: String, CaseIterable {
        case active = "Active"
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
        .sheet(isPresented: $showNewJob) { newJobSheet }
        .sheet(item: $selectedJob) { job in JobDetailSheet(job: job) }
    }

    private var panelHeader: some View {
        HStack {
            Label("JOBS", systemImage: "hammer.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.warning)
            Spacer()
            Text("\(state.activeJobs.filter({ !$0.state.isTerminal }).count) active")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
            ElysiumButton(title: "New", icon: "plus", color: DS.Colors.warning, style: .bordered) { showNewJob = true }
                .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
    }

    private var tabBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(JobTab.allCases, id: \.self) { tab in
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

    private var jobList: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sm) {
                let filtered = state.activeJobs.filter { job in
                    switch selectedTab {
                    case .active: return !job.state.isTerminal
                    case .completed: return job.state == .succeeded
                    case .failed: if case .failed = job.state { return true }; return false
                    }
                }
                if filtered.isEmpty {
                    emptyState
                } else {
                    ForEach(filtered) { job in
                        Button { selectedJob = job } label: {
                            JobCard(
                                name: job.spec.name,
                                node: job.nodeID,
                                state: job.state.displayName,
                                progress: progressValue(job.state),
                                color: colorForState(job.state),
                                duration: durationString(job),
                                onCancel: selectedTab == .active ? { state.cancelJob(job) } : nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
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
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var newJobSheet: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("NEW JOB")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.warning)
            TextField("Job name", text: $newJobName).textFieldStyle(.roundedBorder)
            TextField("Executable (e.g. /bin/echo)", text: $newJobExecutable).textFieldStyle(.roundedBorder)
            HStack {
                ElysiumButton(title: "Cancel", icon: "xmark", color: DS.Colors.textTertiary, style: .bordered) { showNewJob = false }
                ElysiumButton(title: "Submit", icon: "hammer.fill", color: DS.Colors.warning) {
                    guard !newJobName.isEmpty, !newJobExecutable.isEmpty else { return }
                    state.submitJob(name: newJobName, executable: newJobExecutable)
                    newJobName = ""; newJobExecutable = ""; showNewJob = false
                }
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 400)
    }

    private func progressValue(_ s: JobState) -> Double? {
        if case .running(let p) = s { return p }
        return nil
    }

    private func durationString(_ job: ConsoleAppState.TrackedJob) -> String? {
        if case .succeeded = job.state {
            return "Done"
        }
        if case .failed = job.state {
            return "Failed"
        }
        if case .cancelled = job.state {
            return "Cancelled"
        }
        return nil
    }

    private func colorForState(_ s: JobState) -> Color {
        switch s {
        case .submitted, .validating, .queued, .assigned, .transferringInputs, .preparingSandbox: return DS.Colors.warning
        case .running: return DS.Colors.info
        case .collectingOutputs: return DS.Colors.accent
        case .succeeded: return DS.Colors.success
        case .failed, .timedOut: return DS.Colors.error
        case .cancelled: return DS.Colors.textTertiary
        case .waitingForDependencies: return DS.Colors.info
        }
    }
}

struct JobCard: View {
    let name: String
    let node: String
    let state: String
    let progress: Double?
    let color: Color
    var duration: String?
    var onCancel: (() -> Void)?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name).font(DS.Typography.headline).foregroundColor(DS.Colors.textPrimary)
                Text("Node: \(node)").font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            if let progress, let onCancel {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(state).font(DS.Typography.caption).foregroundColor(color)
                    HStack(spacing: DS.Spacing.xs) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(color.opacity(0.12)).frame(height: 3)
                                Capsule().fill(color).frame(width: geo.size.width * progress, height: 3)
                            }
                        }
                        .frame(width: 50, height: 3)
                        Button("Cancel") { onCancel() }
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.error)
                            .buttonStyle(.plain)
                    }
                }
            } else {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(state).font(DS.Typography.caption).foregroundColor(color)
                    if let d = duration {
                        Text(d).font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
    }
}

struct JobDetailSheet: View {
    let job: ConsoleAppState.TrackedJob
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            HStack {
                Text("JOB: \(job.spec.name)").font(DS.Typography.micro).foregroundColor(DS.Colors.warning)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").foregroundColor(DS.Colors.textTertiary) }.buttonStyle(.plain)
            }
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    InfoRow(label: "State", value: job.state.displayName)
                    InfoRow(label: "Executable", value: job.spec.command.executable)
                    InfoRow(label: "Arguments", value: job.spec.command.arguments.joined(separator: " "))
                    InfoRow(label: "Node", value: job.nodeID)
                }
                Spacer()
            }
            Divider().background(Color.white.opacity(0.04))
            if !job.output.isEmpty {
                ScrollView {
                    Text(job.output)
                        .font(DS.Typography.mono)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .background(Color.black.opacity(0.3))
            } else {
                Text("No output yet").font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 600, height: 500)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary).frame(width: 80, alignment: .leading)
            Text(value).font(DS.Typography.mono).foregroundColor(DS.Colors.textPrimary)
        }
    }
}
