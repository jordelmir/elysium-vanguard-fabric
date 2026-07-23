import Foundation
import VanguardDomain

// MARK: - Process Supervisor Protocol

public protocol ProcessSupervisor: Sendable {
    func listProcesses() async throws -> [ProcessInfo]
    func getProcessInfo(pid: Int32) async throws -> ProcessInfo
    func terminateProcess(pid: Int32, signal: Int32) async throws
}

// MARK: - Process Info

public struct ProcessInfo: Codable, Sendable, Equatable {
    public let pid: Int32
    public let name: String
    public let command: String
    public let cpuPercent: Double
    public let memoryBytes: UInt64
    public let startTime: Date
    public let state: ProcessState

    public init(
        pid: Int32,
        name: String,
        command: String,
        cpuPercent: Double,
        memoryBytes: UInt64,
        startTime: Date,
        state: ProcessState
    ) {
        self.pid = pid
        self.name = name
        self.command = command
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.startTime = startTime
        self.state = state
    }
}

public enum ProcessState: String, Codable, Sendable {
    case running
    case stopped
    case zombie
    case unknown
}
