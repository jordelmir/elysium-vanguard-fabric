import SwiftUI
import VanguardUI
import VanguardDomain
import VanguardWorkspace

struct WorkspacePanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var showNewSnapshot = false
    @State private var newSnapshotName = ""
    @State private var projectPath: String = NSHomeDirectory()

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            workspaceContent
        }
        .onAppear { state.loadWorkspaceSnapshots() }
        .sheet(isPresented: $showNewSnapshot) { newSnapshotSheet }
    }

    private var panelHeader: some View {
        HStack {
            Label("WORKSPACE", systemImage: "folder.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.accent)
            Spacer()
            Text("\(state.workspaceSnapshots.count) snapshots")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
            ElysiumButton(title: "New Snapshot", icon: "plus", color: DS.Colors.accent, style: .bordered) { showNewSnapshot = true }
                .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
    }

    private var workspaceContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                if state.workspaceSnapshots.isEmpty {
                    emptyState
                } else {
                    ForEach(state.workspaceSnapshots, id: \.workspaceID) { snapshot in
                        SnapshotCard(snapshot: snapshot, onDelete: { state.deleteWorkspaceSnapshot(snapshot) })
                    }
                }
            }.padding(DS.Spacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "folder.badge.questionmark").font(.system(size: 28)).foregroundColor(DS.Colors.textQuaternary)
            Text("No workspace snapshots").font(DS.Typography.subheadline).foregroundColor(DS.Colors.textTertiary)
            Text("Create a snapshot to start sharing files").font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private var newSnapshotSheet: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("NEW WORKSPACE SNAPSHOT").font(DS.Typography.micro).foregroundColor(DS.Colors.accent)
            TextField("Snapshot name", text: $newSnapshotName).textFieldStyle(.roundedBorder)
            HStack {
                Text("Project path:").font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary)
                TextField("~/Projects", text: $projectPath).textFieldStyle(.roundedBorder)
            }
            Text("Will scan for .swift, .json, .md files recursively")
                .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            HStack {
                ElysiumButton(title: "Cancel", icon: "xmark", color: DS.Colors.textTertiary, style: .bordered) { showNewSnapshot = false }
                ElysiumButton(title: "Scan & Create", icon: "folder.fill.badge.plus", color: DS.Colors.accent) {
                    guard !newSnapshotName.isEmpty else { return }
                    let files = scanProjectFiles(at: projectPath)
                    state.createWorkspaceSnapshot(name: newSnapshotName, files: files)
                    newSnapshotName = ""; showNewSnapshot = false
                }
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 500)
    }

    private func scanProjectFiles(at path: String) -> [String] {
        let url = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        let extensions = Set(["swift", "json", "md", "yml", "yaml", "toml", "txt", "sh", "py", "js", "ts", "html", "css"])
        var files: [String] = []
        for case let fileURL as URL in enumerator {
            if extensions.contains(fileURL.pathExtension.lowercased()) {
                let relative = fileURL.path.replacingOccurrences(of: path, with: "")
                files.append(relative.hasPrefix("/") ? String(relative.dropFirst()) : relative)
            }
        }
        return Array(files.prefix(500))
    }
}

struct SnapshotCard: View {
    let snapshot: WorkspaceSnapshot
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "folder.fill").foregroundColor(DS.Colors.accent)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(snapshot.name).font(DS.Typography.headline).foregroundColor(DS.Colors.textPrimary)
                Text("\(snapshot.fileHashes.count) files - created \(snapshot.created.formatted(date: .abbreviated, time: .shortened))")
                    .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 10)).foregroundColor(DS.Colors.error)
            }
            .buttonStyle(.plain)
            .help("Delete snapshot")
        }
        .padding(DS.Spacing.md)
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
    }
}
