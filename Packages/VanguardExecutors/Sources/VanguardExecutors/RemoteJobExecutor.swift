import Foundation
import VanguardDomain

public protocol RemoteJobExecutor: Sendable {
    func submitJob(name: String, command: [String], workingDirectory: String?, timeoutSeconds: TimeInterval) async throws -> String
    func cancelJob(jobID: String) async throws
    func getJobStatus(jobID: String) async -> String?
}

public struct JobCheckpoint: Sendable, Codable {
    public let jobID: String
    public let timestamp: Date
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32?

    public init(jobID: String, timestamp: Date = Date(), stdout: String = "", stderr: String = "", exitCode: Int32? = nil) {
        self.jobID = jobID
        self.timestamp = timestamp
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}
