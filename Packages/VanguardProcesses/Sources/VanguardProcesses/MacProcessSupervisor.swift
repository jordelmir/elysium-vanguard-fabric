import Foundation
import VanguardDomain

public final class MacProcessSupervisor: ProcessSupervisor {
    public init() {}

    public func listProcesses() async throws -> [ProcessInfo] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid,comm,pcpu,rss,etime,state", "-r"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var processes: [ProcessInfo] = []
        let lines = output.components(separatedBy: "\n").dropFirst()

        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 6,
                  let pid = Int32(parts[0]) else { continue }

            let name = String(parts[1])
            let cpu = Double(parts[2]) ?? 0
            let rssKB = UInt64(parts[3]) ?? 0
            let stateStr = String(parts[5])

            let state: ProcessState
            switch stateStr {
            case "R": state = .running
            case "T", "S": state = .stopped
            case "Z": state = .zombie
            default: state = .unknown
            }

            processes.append(ProcessInfo(
                pid: pid,
                name: name,
                command: name,
                cpuPercent: cpu,
                memoryBytes: rssKB * 1024,
                startTime: Date(),
                state: state
            ))
        }

        return processes
    }

    public func getProcessInfo(pid: Int32) async throws -> ProcessInfo {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-p", String(pid), "-o", "pid,comm,pcpu,rss,etime,state"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ProcessError.processNotFound(pid: pid)
        }

        let lines = output.components(separatedBy: "\n").dropFirst()
        guard let line = lines.first else {
            throw ProcessError.processNotFound(pid: pid)
        }

        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 6,
              let parsedPID = Int32(parts[0]) else {
            throw ProcessError.processNotFound(pid: pid)
        }

        let name = String(parts[1])
        let cpu = Double(parts[2]) ?? 0
        let rssKB = UInt64(parts[3]) ?? 0
        let stateStr = String(parts[5])

        let state: ProcessState
        switch stateStr {
        case "R": state = .running
        case "T", "S": state = .stopped
        case "Z": state = .zombie
        default: state = .unknown
        }

        return ProcessInfo(
            pid: parsedPID,
            name: name,
            command: name,
            cpuPercent: cpu,
            memoryBytes: rssKB * 1024,
            startTime: Date(),
            state: state
        )
    }

    public func terminateProcess(pid: Int32, signal: Int32) async throws {
        let result = kill(pid, signal)
        if result != 0 {
            throw ProcessError.terminationFailed(pid: pid, reason: "kill failed with code \(errno)")
        }
    }
}

public enum ProcessError: Error, LocalizedError {
    case processNotFound(pid: Int32)
    case terminationFailed(pid: Int32, reason: String)

    public var errorDescription: String? {
        switch self {
        case .processNotFound(let pid):
            return "Process \(pid) not found"
        case .terminationFailed(let pid, let reason):
            return "Failed to terminate process \(pid): \(reason)"
        }
    }
}
