import Foundation

// MARK: - Terminal Configuration

public struct TerminalConfiguration: Codable, Sendable, Equatable {
    public let shell: String?
    public let workingDirectory: String?
    public let columns: UInt16
    public let rows: UInt16
    public let environment: [String: String]

    public init(
        shell: String? = nil,
        workingDirectory: String? = nil,
        columns: UInt16 = 80,
        rows: UInt16 = 24,
        environment: [String: String] = [:]
    ) {
        self.shell = shell
        self.workingDirectory = workingDirectory
        self.columns = columns
        self.rows = rows
        self.environment = environment
    }
}

// MARK: - Terminal Close Signal

public enum TerminalCloseSignal: String, Codable, Sendable {
    case hangup      // SIGHUP
    case interrupt   // SIGINT
    case terminate   // SIGTERM
    case kill        // SIGKILL
    case exit        // Normal exit
}

// MARK: - Terminal Session State

public enum TerminalSessionState: String, Codable, Sendable {
    case opening
    case open
    case closing
    case closed
    case error
}
