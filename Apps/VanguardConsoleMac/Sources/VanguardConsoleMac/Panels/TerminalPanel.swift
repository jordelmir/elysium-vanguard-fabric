import SwiftUI
import VanguardUI
import VanguardDomain

struct TerminalPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var selectedSessionID: TerminalSessionID?
    @State private var commandText = ""
    @State private var showNewSession = false

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            if state.terminalSessions.isEmpty {
                emptyState
            } else {
                sessionContent
            }
        }
        .sheet(isPresented: $showNewSession) { newSessionSheet }
    }

    private var panelHeader: some View {
        HStack {
            Label("TERMINAL", systemImage: "terminal.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.success)
            Spacer()
            let active = state.terminalSessions.filter({ $0.isActive }).count
            Text("\(active) active - \(state.terminalSessions.count) total")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
            if let session = activeSession {
                Button {
                    state.closeTerminalSession(session)
                    selectedSessionID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundColor(DS.Colors.error)
                }
                .buttonStyle(.plain)
                .help("Close session")
            }
            ElysiumButton(title: "New", icon: "plus", color: DS.Colors.success, style: .bordered) { showNewSession = true }
                .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
    }

    private var sessionContent: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(state.terminalSessions) { session in
                        SessionTab(session: session, isSelected: selectedSessionID == session.id) {
                            selectedSessionID = session.id
                        }
                    }
                }.padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.sm)
            }
            Divider().background(Color.white.opacity(0.04))
            outputView
            Divider().background(Color.white.opacity(0.04))
            inputBar
        }
    }

    private var outputView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    if let session = activeSession {
                        Text(session.output)
                            .font(DS.Typography.mono)
                            .foregroundColor(DS.Colors.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("No active session").font(DS.Typography.mono).foregroundColor(DS.Colors.textQuaternary)
                    }
                }.padding(DS.Spacing.md).id("output")
            }
            .background(Color.black.opacity(0.5))
            .onChange(of: activeSession?.output.count) { _ in
                withAnimation { proxy.scrollTo("output", anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("❯")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(DS.Colors.success)
            TextField("Command...", text: $commandText)
                .textFieldStyle(.plain)
                .font(DS.Typography.mono)
                .foregroundColor(DS.Colors.success)
                .onSubmit { sendCommand() }
            ElysiumButton(title: "Run", icon: "play.fill", color: DS.Colors.success) { sendCommand() }
                .controlSize(.small)
                .disabled(commandText.isEmpty || activeSession == nil)
        }
        .padding(DS.Spacing.md)
        .glass(style: .ultraThin, cornerRadius: 0)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "terminal").font(.system(size: 28)).foregroundColor(DS.Colors.textQuaternary)
            Text("No terminal sessions").font(DS.Typography.subheadline).foregroundColor(DS.Colors.textTertiary)
            Text("Open a session to a connected node").font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private var newSessionSheet: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("NEW TERMINAL SESSION").font(DS.Typography.micro).foregroundColor(DS.Colors.success)
            Text("Opens a real PTY shell via POSIXTerminalService")
                .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            if state.discoveredNodes.isEmpty {
                Text("No nodes connected").font(DS.Typography.caption).foregroundColor(DS.Colors.textTertiary)
            } else {
                ForEach(state.discoveredNodes) { node in
                    Button {
                        state.openTerminalSession(nodeName: node.name)
                        showNewSession = false
                    } label: {
                        HStack {
                            Circle().fill(node.status == .online ? DS.Colors.success : DS.Colors.textQuaternary).frame(width: 8, height: 8)
                            Text(node.name).font(DS.Typography.headline).foregroundColor(DS.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.right").foregroundColor(DS.Colors.textTertiary)
                        }.padding(DS.Spacing.md).glass(style: .ultraThin, cornerRadius: DS.Radius.md)
                    }.buttonStyle(.plain)
                }
            }
            ElysiumButton(title: "Cancel", icon: "xmark", color: DS.Colors.textTertiary, style: .bordered) { showNewSession = false }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 400)
    }

    private func sendCommand() {
        guard let session = activeSession, !commandText.isEmpty else { return }
        state.sendTerminalCommand(session, command: commandText)
        commandText = ""
    }

    private var activeSession: ConsoleAppState.TrackedTerminalSession? {
        state.terminalSessions.first { $0.id == selectedSessionID } ?? state.terminalSessions.first
    }
}

struct SessionTab: View {
    let session: ConsoleAppState.TrackedTerminalSession
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Circle().fill(session.isActive ? DS.Colors.success : DS.Colors.textQuaternary).frame(width: 6, height: 6)
                Image(systemName: "terminal").font(.system(size: 10))
                Text(session.nodeName).font(DS.Typography.caption)
            }
            .padding(.horizontal, DS.Spacing.md).padding(.vertical, DS.Spacing.xs)
            .glass(style: isSelected ? .colored(DS.Colors.success) : .ultraThin, cornerRadius: DS.Radius.pill)
        }
        .buttonStyle(.plain)
    }
}
