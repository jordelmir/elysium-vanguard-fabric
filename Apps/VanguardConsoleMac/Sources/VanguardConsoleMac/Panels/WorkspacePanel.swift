import SwiftUI
import VanguardUI
import VanguardDomain

struct WorkspacePanel: View {
    @EnvironmentObject private var state: ConsoleAppState

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            workspaceContent
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("WORKSPACE", systemImage: "folder.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.accent)
                
            Spacer()
            ElysiumButton(title: "Sync", icon: "arrow.triangle.2.circlepath", color: DS.Colors.accent, style: .bordered) { }
                .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
    }

    private var workspaceContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                projectCard
                sharedFiles
                changeLog
            }
            .padding(DS.Spacing.md)
        }
    }

    private var projectCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(DS.Colors.accent)
                Text("Elysium Vanguard Fabric")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text("Owner: M1")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            .padding(DS.Spacing.md)

            Divider().background(Color.white.opacity(0.04))

            HStack(spacing: DS.Spacing.lg) {
                WorkspaceStat(icon: "doc.fill", label: "Files", value: "89")
                WorkspaceStat(icon: "arrow.triangle.merge", label: "Changes", value: "3")
                WorkspaceStat(icon: "clock.fill", label: "Last sync", value: "2m ago")
            }
            .padding(DS.Spacing.md)
        }
        .glass(style: .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder()
    }

    private var sharedFiles: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("SHARED FILES")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                

            ForEach(["Package.swift", "AGENTS.md", "Protocol/specification.md"], id: \.self) { file in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: file.hasSuffix(".swift") ? "swift" : "doc.text")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Colors.accent)
                    Text(file)
                        .font(DS.Typography.mono)
                        .foregroundColor(DS.Colors.textSecondary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.success)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    private var changeLog: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("RECENT CHANGES")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.textQuaternary)
                

            ChangeEntry(author: "M1", message: "feat: complete fabric foundation", time: "2h ago", color: DS.Colors.success)
            ChangeEntry(author: "M1", message: "docs: add comprehensive AGENTS.md", time: "1h ago", color: DS.Colors.info)
        }
    }
}

struct WorkspaceStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(DS.Colors.accent)
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

struct ChangeEntry: View {
    let author: String
    let message: String
    let time: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(message)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                Text("\(author) · \(time)")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
    }
}
