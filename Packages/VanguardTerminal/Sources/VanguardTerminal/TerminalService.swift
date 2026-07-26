import Foundation
import VanguardDomain

// MARK: - Terminal Service Protocol

public protocol TerminalService: Sendable {
    func open(
        sessionID: TerminalSessionID,
        configuration: TerminalConfiguration
    ) async throws -> TerminalSessionHandle

    func write(
        sessionID: TerminalSessionID,
        data: Data
    ) async throws

    func resize(
        sessionID: TerminalSessionID,
        columns: UInt16,
        rows: UInt16
    ) async throws

    func close(
        sessionID: TerminalSessionID,
        signal: TerminalCloseSignal
    ) async

    func getOutput(
        sessionID: TerminalSessionID,
        fromOffset: UInt64
    ) -> AsyncThrowingStream<Data, Error>
}

// MARK: - Terminal Session Handle

public struct TerminalSessionHandle: Sendable {
    public let sessionID: TerminalSessionID
    public let pid: Int32
    public let state: TerminalSessionState

    public init(
        sessionID: TerminalSessionID,
        pid: Int32,
        state: TerminalSessionState = .open
    ) {
        self.sessionID = sessionID
        self.pid = pid
        self.state = state
    }
}
