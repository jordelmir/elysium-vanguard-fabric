import SwiftUI
import VanguardUI
import VanguardDomain

struct TerminalPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var sessions: [TerminalSession] = []
    @State private var selectedSession: TerminalSession?
    @State private var inputText = ""

    struct TerminalSession: Identifiable {
        let id = UUID()
        let node: String
        let shell: String
        let cwd: String
        var output: String
        var isActive: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            if sessions.isEmpty {
                emptyState
            } else {
                terminalArea
            }
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("TERMINAL", systemImage: "terminal")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.success)
                
            Spacer()
            ElysiumButton(title: "New", icon: "plus", color: DS.Colors.success, style: .bordered) {
                let session = TerminalSession(node: "Local", shell: "/bin/zsh", cwd: "~", output: "Last login: \(Date())\n", isActive: true)
                sessions.append(session)
                selectedSession = session
            }
            .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: "terminal")
                    .font(.system(size: 22))
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            VStack(spacing: DS.Spacing.xs) {
                Text("No terminal sessions")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textTertiary)
                Text("Click New to open a terminal")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var terminalArea: some View {
        VStack(spacing: 0) {
            sessionTabs
            Divider().background(Color.white.opacity(0.04))
            terminalOutput
            Divider().background(Color.white.opacity(0.04))
            terminalInput
        }
    }

    private var sessionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(sessions) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(session.isActive ? DS.Colors.success : DS.Colors.textQuaternary)
                                .frame(width: 5, height: 5)
                            Text(session.node)
                                .font(DS.Typography.caption)
                                .foregroundColor(selectedSession?.id == session.id ? DS.Colors.accent : DS.Colors.textTertiary)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .glass(style: selectedSession?.id == session.id ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.pill)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private var terminalOutput: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let session = selectedSession {
                        Text(session.output)
                            .font(DS.Typography.code)
                            .foregroundColor(DS.Colors.success)
                            .textSelection(.enabled)
                            .padding(DS.Spacing.md)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.3))
        }
        .frame(minHeight: 200)
    }

    private var terminalInput: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("❯")
                .font(DS.Typography.monoBold)
                .foregroundColor(DS.Colors.success)
            TextField("Type command...", text: $inputText)
                .textFieldStyle(.plain)
                .font(DS.Typography.code)
                .foregroundColor(DS.Colors.textPrimary)
                .onSubmit {
                    guard !inputText.isEmpty, var session = selectedSession else { return }
                    session.output += "$ \(inputText)\n"
                    inputText = ""
                    if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
                        sessions[idx] = session
                        selectedSession = session
                    }
                }
        }
        .padding(DS.Spacing.md)
    }
}
