import Foundation
import os
import VanguardDomain

public final class POSIXTerminalService: TerminalService, @unchecked Sendable {
    private let state: SessionState
    private let logger = Logger(subsystem: "com.elysiumvanguard.fabric", category: "Terminal")

    public init() {
        self.state = SessionState()
    }

    public func open(configuration: TerminalConfiguration) async throws -> TerminalSessionHandle {
        let sessionID = TerminalSessionID()
        let cols = configuration.columns
        let rows = configuration.rows

        var masterFD: Int32 = 0
        var slaveFD: Int32 = 0

        var winsize = winsize()
        winsize.ws_row = rows
        winsize.ws_col = cols

        guard openpty(&masterFD, &slaveFD, nil, nil, &winsize) == 0 else {
            throw TerminalError.ptyAllocationFailed
        }

        let pid = spawnShell(slaveFD: slaveFD, shell: configuration.shell, workingDirectory: configuration.workingDirectory, environment: configuration.environment)
        if pid < 0 {
            Darwin.close(masterFD)
            Darwin.close(slaveFD)
            throw TerminalError.processSpawnFailed(reason: "posix_spawn failed")
        }

        Darwin.close(slaveFD)

        let session = PTYSession(
            sessionID: sessionID,
            masterFD: masterFD,
            pid: pid,
            cols: cols,
            rows: rows
        )

        await state.addSession(session)

        logger.info("Terminal session \(sessionID.rawValue.uuidString) created (pid \(pid))")

        return TerminalSessionHandle(
            sessionID: sessionID,
            pid: pid,
            state: .open
        )
    }

    public func write(sessionID: TerminalSessionID, data: Data) async throws {
        guard let session = await state.getSession(sessionID) else {
            throw TerminalError.sessionNotFound(sessionID)
        }

        let bytesWritten = data.withUnsafeBytes { buffer in
            Darwin.write(session.masterFD, buffer.baseAddress, buffer.count)
        }

        if bytesWritten < 0 {
            throw TerminalError.writeFailed(reason: "write() failed: \(String(cString: strerror(errno)))")
        }
    }

    public func resize(sessionID: TerminalSessionID, columns: UInt16, rows: UInt16) async throws {
        guard let session = await state.getSession(sessionID) else {
            throw TerminalError.sessionNotFound(sessionID)
        }

        var winsize = winsize()
        winsize.ws_row = rows
        winsize.ws_col = columns

        guard ioctl(session.masterFD, TIOCSWINSZ, &winsize) == 0 else {
            throw TerminalError.resizeFailed(reason: "ioctl(TIOCSWINSZ) failed")
        }

        await state.updateSession(sessionID, cols: columns, rows: rows)
    }

    public func close(sessionID: TerminalSessionID, signal: TerminalCloseSignal) async {
        guard let session = await state.removeSession(sessionID) else {
            return
        }

        Darwin.close(session.masterFD)

        let sig: Int32
        switch signal {
        case .hangup:  sig = SIGHUP
        case .interrupt: sig = SIGINT
        case .terminate: sig = SIGTERM
        case .kill:    sig = SIGKILL
        case .exit:    sig = SIGHUP
        }

        kill(session.pid, sig)
        logger.info("Terminal session \(sessionID.rawValue.uuidString) closed (signal \(signal.rawValue))")
    }

    public func getOutput(sessionID: TerminalSessionID, fromOffset: UInt64) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }
                await self.readLoop(sessionID: sessionID, continuation: continuation, fromOffset: fromOffset)
            }
        }
    }

    // MARK: - Private

    private func readLoop(sessionID: TerminalSessionID, continuation: AsyncThrowingStream<Data, Error>.Continuation, fromOffset: UInt64) async {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var offset = fromOffset

        while true {
            guard let session = await state.getSession(sessionID) else {
                break
            }

            let bytesRead = Darwin.read(session.masterFD, &buffer, buffer.count)

            if bytesRead > 0 {
                let data = Data(buffer.prefix(bytesRead))
                continuation.yield(data)
                offset += UInt64(bytesRead)
            } else if bytesRead == 0 {
                continuation.finish()
                return
            } else {
                if errno == EAGAIN || errno == EIO {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                    continue
                }
                continuation.finish(throwing: TerminalError.writeFailed(reason: "read() failed"))
                return
            }
        }

        continuation.finish()
    }

    private func spawnShell(slaveFD: Int32, shell: String?, workingDirectory: String?, environment: [String: String]) -> pid_t {
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, slaveFD, STDERR_FILENO)
        posix_spawn_file_actions_addclose(&fileActions, slaveFD)

        let shellPath = shell ?? "/bin/zsh"
        var pid: pid_t = 0

        let argv: [UnsafeMutablePointer<CChar>?] = [strdup(shellPath), nil]

        var envp: [UnsafeMutablePointer<CChar>?] = []
        for (key, value) in environment {
            let entry = "\(key)=\(value)"
            envp.append(strdup(entry))
        }
        envp.append(nil)

        let result = posix_spawn(&pid, shellPath, &fileActions, nil, argv, envp)

        posix_spawn_file_actions_destroy(&fileActions)

        for ptr in envp {
            if let ptr = ptr {
                free(ptr)
            }
        }

        return result == 0 ? pid : -1
    }
}

// MARK: - Session State (actor for safe concurrent access)

private actor SessionState {
    private var sessions: [TerminalSessionID: PTYSession] = [:]

    func addSession(_ session: PTYSession) {
        sessions[session.sessionID] = session
    }

    func getSession(_ id: TerminalSessionID) -> PTYSession? {
        sessions[id]
    }

    func removeSession(_ id: TerminalSessionID) -> PTYSession? {
        sessions.removeValue(forKey: id)
    }

    func updateSession(_ id: TerminalSessionID, cols: UInt16, rows: UInt16) {
        guard var session = sessions[id] else { return }
        session.cols = cols
        session.rows = rows
        sessions[id] = session
    }
}

private struct PTYSession {
    let sessionID: TerminalSessionID
    let masterFD: Int32
    let pid: pid_t
    var cols: UInt16
    var rows: UInt16
}
