import Foundation

// MARK: - Operation Context

public struct OperationContext: Codable, Sendable, Equatable {
    public let operationID: OperationID
    public let sessionID: SessionID
    public let sequenceNumber: UInt64
    public let issuedAtMonotonicNanos: UInt64

    public init(
        operationID: OperationID = OperationID(),
        sessionID: SessionID,
        sequenceNumber: UInt64,
        issuedAtMonotonicNanos: UInt64
    ) {
        self.operationID = operationID
        self.sessionID = sessionID
        self.sequenceNumber = sequenceNumber
        self.issuedAtMonotonicNanos = issuedAtMonotonicNanos
    }
}

// MARK: - Task Descriptor

public enum TaskDescriptor: Codable, Sendable {
    case collectDiagnostics(CollectDiagnosticsTask)
    case runTests(RunTestsTask)
    case buildProject(BuildProjectTask)
    case gitStatus(GitStatusTask)
}

public struct CollectDiagnosticsTask: Codable, Sendable {
    public init() {}
}

public struct RunTestsTask: Codable, Sendable {
    public let projectPath: String?
    public let testFilter: String?

    public init(projectPath: String? = nil, testFilter: String? = nil) {
        self.projectPath = projectPath
        self.testFilter = testFilter
    }
}

public struct BuildProjectTask: Codable, Sendable {
    public let projectPath: String?
    public let configuration: String?

    public init(projectPath: String? = nil, configuration: String? = nil) {
        self.projectPath = projectPath
        self.configuration = configuration
    }
}

public struct GitStatusTask: Codable, Sendable {
    public let repositoryPath: String?

    public init(repositoryPath: String? = nil) {
        self.repositoryPath = repositoryPath
    }
}

// MARK: - Task Status

public enum TaskStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}

// MARK: - Task Execution Result

public struct TaskExecutionResult: Codable, Sendable {
    public let operationID: OperationID
    public let startedAt: Date
    public let completedAt: Date
    public let status: TaskStatus
    public let exitCode: Int32?
    public let stdoutDigest: String?
    public let stderrDigest: String?

    public init(
        operationID: OperationID,
        startedAt: Date,
        completedAt: Date,
        status: TaskStatus,
        exitCode: Int32? = nil,
        stdoutDigest: String? = nil,
        stderrDigest: String? = nil
    ) {
        self.operationID = operationID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.exitCode = exitCode
        self.stdoutDigest = stdoutDigest
        self.stderrDigest = stderrDigest
    }
}
