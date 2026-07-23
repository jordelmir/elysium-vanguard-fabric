import SwiftUI
import VanguardDomain

struct TerminalView: View {
    let sessionID: String
    @StateObject private var terminalState = TerminalViewState()
    @EnvironmentObject private var consoleState: ConsoleAppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(EV.Colors.green.opacity(0.2))
            outputArea
            Divider().overlay(EV.Colors.green.opacity(0.2))
            inputBar
        }
        .background(EV.Colors.bg)
        .task { await terminalState.openTerminal(consoleState: consoleState) }
        .onDisappear { Task { await terminalState.closeTerminal(consoleState: consoleState) } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(EV.Colors.green.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: "terminal")
                    .font(.system(size: 13))
                    .foregroundColor(EV.Colors.green)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("TERMINAL")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(EV.Colors.green)
                    .tracking(2)
                Text("Remote shell session")
                    .font(.caption2)
                    .foregroundColor(EV.Colors.textTertiary)
            }
            Spacer()
            Button(action: { terminalState.toggleFullscreen() }) {
                Image(systemName: terminalState.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(EV.Colors.textSecondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(EV.Colors.bg)
    }

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                Text(terminalState.output)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(EV.Colors.green)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("output")
            }
            .background(Color.black.opacity(0.6))
            .onChange(of: terminalState.output) { _ in
                withAnimation { proxy.scrollTo("output", anchor: .bottom) }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("❯")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(EV.Colors.green)
                    .shadow(color: EV.Colors.green.opacity(0.5), radius: 4)
            }
            TextField("Type command...", text: $terminalState.input)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(EV.Colors.green)
                .onSubmit { terminalState.sendInput() }

            Button(action: { terminalState.sendInput() }) {
                Image(systemName: "return")
                    .font(.system(size: 11))
                    .foregroundColor(terminalState.input.isEmpty ? EV.Colors.textTertiary : EV.Colors.green)
            }
            .buttonStyle(.borderless)
            .disabled(terminalState.input.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(EV.Colors.surface.opacity(0.4))
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
