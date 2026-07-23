import SwiftUI
import VanguardUI
import VanguardDomain

struct TerminalView: View {
    let sessionID: String
    @StateObject private var terminalState = TerminalViewState()
    @EnvironmentObject private var consoleState: ConsoleAppState
    @State private var cursorBlink = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(DS.Colors.success.opacity(0.15))
            outputArea
            Divider().background(DS.Colors.success.opacity(0.15))
            inputBar
        }
        .task { await terminalState.openTerminal(consoleState: consoleState) }
        .onDisappear { Task { await terminalState.closeTerminal(consoleState: consoleState) } }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Colors.success.opacity(0.1))
                        .frame(width: 26, height: 26)
                    Image(systemName: "terminal")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DS.Colors.success)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("TERMINAL")
                        .font(DS.Typography.micro)
                        .foregroundColor(DS.Colors.success)
                        .tracking(2)
                    Text("Remote shell")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textQuaternary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                Text(terminalState.output)
                    .font(DS.Typography.mono)
                    .foregroundColor(DS.Colors.success)
                    .textSelection(.enabled)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("output")
            }
            .background(Color.black.opacity(0.5))
            .onChange(of: terminalState.output) { _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("output", anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("❯")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(DS.Colors.success)
                .shadow(color: DS.Colors.success.opacity(0.5), radius: 4)
                .opacity(cursorBlink ? 1 : 0.4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever()) { cursorBlink = true }
                }

            TextField("Type command...", text: $terminalState.input)
                .textFieldStyle(.plain)
                .font(DS.Typography.mono)
                .foregroundColor(DS.Colors.success)
                .onSubmit { terminalState.sendInput() }

            Button(action: { terminalState.sendInput() }) {
                Image(systemName: "return")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(terminalState.input.isEmpty ? DS.Colors.textQuaternary : DS.Colors.success)
            }
            .buttonStyle(.borderless)
            .disabled(terminalState.input.isEmpty)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .glass(style: .ultraThin, cornerRadius: 0)
    }
}

@MainActor
final class TerminalViewState: ObservableObject {
    @Published var output = ""
    @Published var input = ""
    @Published var isFullscreen = false
    @Published var isOpen = false

    private var sessionID: TerminalSessionID?
    private var outputTask: Task<Void, Never>?
    private weak var consoleState: ConsoleAppState?

    func openTerminal(consoleState: ConsoleAppState) async {
        self.consoleState = consoleState
        let config = TerminalConfiguration(shell: "/bin/zsh", columns: 80, rows: 24)
        do {
            let handle = try await consoleState.openTerminal(configuration: config)
            sessionID = handle.sessionID
            isOpen = true
            output = "Session started (pid \(handle.pid))\n"
            startListeningForOutput(consoleState: consoleState)
        } catch {
            output = "Failed to open terminal: \(error.localizedDescription)\n"
        }
    }

    func sendInput() {
        guard let sessionID = sessionID, let consoleState = consoleState, !input.isEmpty else { return }
        Task {
            let data = (input + "\n").data(using: .utf8) ?? Data()
            try? await consoleState.sendTerminalInput(sessionID, data: data)
            output += "$ " + input + "\n"
            input = ""
        }
    }

    func closeTerminal(consoleState: ConsoleAppState) async {
        outputTask?.cancel()
        if let sessionID = sessionID { try? await consoleState.closeTerminal(sessionID) }
        isOpen = false
    }

    func toggleFullscreen() { isFullscreen.toggle() }

    private func startListeningForOutput(consoleState: ConsoleAppState) {
        outputTask = Task {
            for await terminalOutput in consoleState.terminalOutputUpdates {
                if let text = String(data: terminalOutput.data, encoding: .utf8) {
                    output += text
                }
            }
        }
    }
}
