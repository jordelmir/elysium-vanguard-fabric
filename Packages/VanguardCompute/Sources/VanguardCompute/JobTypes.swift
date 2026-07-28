import Foundation
import VanguardDomain

// MARK: - Artifact Reference

public struct ArtifactReference: Codable, Sendable, Equatable {
    public let artifactID: UUID
    public let name: String
    public let sha256: Data

    public init(artifactID: UUID, name: String, sha256: Data) {
        self.artifactID = artifactID
        self.name = name
        self.sha256 = sha256
    }
}

// MARK: - Expected Artifact

public struct ExpectedArtifact: Codable, Sendable, Equatable {
    public let name: String
    public let contentType: String
    public let maxSizeBytes: UInt64

    public init(name: String, contentType: String = "application/octet-stream", maxSizeBytes: UInt64 = 100 * 1024 * 1024) {
        self.name = name
        self.contentType = contentType
        self.maxSizeBytes = maxSizeBytes
    }
}

// MARK: - Executable Command

public struct ExecutableCommand: Codable, Sendable, Equatable {
    public let executable: String
    public let arguments: [String]
    public let standardInputArtifact: ArtifactReference?

    public init(executable: String, arguments: [String], standardInputArtifact: ArtifactReference? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.standardInputArtifact = standardInputArtifact
    }
}

// MARK: - Job Requirements

public struct JobRequirements: Codable, Sendable, Equatable {
    public let allowedArchitectures: Set<CPUArchitecture>
    public let minimumLogicalCPUs: Int
    public let minimumMemoryBytes: UInt64
    public let minimumStorageBytes: UInt64
    public let requiredToolchains: [ToolchainRequirement]
    public let requiredCapabilities: Set<FabricCapability>
    public let requiresGPU: Bool
    public let requiresNetwork: Bool
    public let preferredNodeIDs: [UUID]
    public let excludedNodeIDs: [UUID]
    public let maximumThermalState: NodeThermalState
    public let requiresACPower: Bool

    public init(
        allowedArchitectures: Set<CPUArchitecture> = Set(CPUArchitecture.allCases),
        minimumLogicalCPUs: Int = 1,
        minimumMemoryBytes: UInt64 = 0,
        minimumStorageBytes: UInt64 = 0,
        requiredToolchains: [ToolchainRequirement] = [],
        requiredCapabilities: Set<FabricCapability> = [],
        requiresGPU: Bool = false,
        requiresNetwork: Bool = false,
        preferredNodeIDs: [UUID] = [],
        excludedNodeIDs: [UUID] = [],
        maximumThermalState: NodeThermalState = .critical,
        requiresACPower: Bool = false
    ) {
        self.allowedArchitectures = allowedArchitectures
        self.minimumLogicalCPUs = minimumLogicalCPUs
        self.minimumMemoryBytes = minimumMemoryBytes
        self.minimumStorageBytes = minimumStorageBytes
        self.requiredToolchains = requiredToolchains
        self.requiredCapabilities = requiredCapabilities
        self.requiresGPU = requiresGPU
        self.requiresNetwork = requiresNetwork
        self.preferredNodeIDs = preferredNodeIDs
        self.excludedNodeIDs = excludedNodeIDs
        self.maximumThermalState = maximumThermalState
        self.requiresACPower = requiresACPower
    }
}

// MARK: - Job Failure

public struct JobFailure: Codable, Sendable, Equatable {
    public let reason: String
    public let exitCode: Int32?
    public let timestamp: Date

    public init(reason: String, exitCode: Int32? = nil, timestamp: Date = Date()) {
        self.reason = reason
        self.exitCode = exitCode
        self.timestamp = timestamp
    }
}

// MARK: - Job State (expanded)

public enum JobState: Codable, Sendable, Equatable {
    case submitted
    case validating
    case waitingForDependencies
    case queued
    case assigned(nodeID: UUID)
    case transferringInputs
    case preparingSandbox
    case running(progress: Double?)
    case collectingOutputs
    case succeeded
    case failed(JobFailure)
    case cancelled
    case timedOut

    public var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled, .timedOut: return true
        default: return false
        }
    }

    public var displayName: String {
        switch self {
        case .submitted: return "Submitted"
        case .validating: return "Validating"
        case .waitingForDependencies: return "Waiting for Dependencies"
        case .queued: return "Queued"
        case .assigned: return "Assigned"
        case .transferringInputs: return "Transferring Inputs"
        case .preparingSandbox: return "Preparing Sandbox"
        case .running: return "Running"
        case .collectingOutputs: return "Collecting Outputs"
        case .succeeded: return "Succeeded"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        case .timedOut: return "Timed Out"
        }
    }
}

// MARK: - Job Spec (full)

public struct JobSpec: Codable, Sendable {
    public let jobID: UUID
    public let submittedBy: UUID
    public let name: String
    public let executor: ExecutorKind
    public let command: ExecutableCommand
    public let requirements: JobRequirements
    public let inputs: [ArtifactReference]
    public let expectedOutputs: [ExpectedArtifact]
    public let environment: [String: String]
    public let workingDirectoryPolicy: WorkingDirectoryPolicy
    public let timeoutSeconds: UInt64
    public let retryPolicy: RetryPolicy
    public let priority: JobPriority
    public let dependencies: [UUID]
    public let securityPolicy: JobSecurityPolicy
    public let createdAt: Date
    public let signature: Data

    public init(
        jobID: UUID = UUID(),
        submittedBy: UUID,
        name: String,
        executor: ExecutorKind = .nativeProcess,
        command: ExecutableCommand,
        requirements: JobRequirements = JobRequirements(),
        inputs: [ArtifactReference] = [],
        expectedOutputs: [ExpectedArtifact] = [],
        environment: [String: String] = [:],
        workingDirectoryPolicy: WorkingDirectoryPolicy = .sandboxOnly,
        timeoutSeconds: UInt64 = 300,
        retryPolicy: RetryPolicy = .noRetry,
        priority: JobPriority = .normal,
        dependencies: [UUID] = [],
        securityPolicy: JobSecurityPolicy = JobSecurityPolicy(),
        createdAt: Date = Date(),
        signature: Data = Data()
    ) {
        self.jobID = jobID
        self.submittedBy = submittedBy
        self.name = name
        self.executor = executor
        self.command = command
        self.requirements = requirements
        self.inputs = inputs
        self.expectedOutputs = expectedOutputs
        self.environment = environment
        self.workingDirectoryPolicy = workingDirectoryPolicy
        self.timeoutSeconds = timeoutSeconds
        self.retryPolicy = retryPolicy
        self.priority = priority
        self.dependencies = dependencies
        self.securityPolicy = securityPolicy
        self.createdAt = createdAt
        self.signature = signature
    }
}

// MARK: - Job Result

public struct JobResult: Sendable {
    public let jobID: JobID
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data
    public let duration: TimeInterval

    public init(jobID: JobID, exitCode: Int32, stdout: Data, stderr: Data, duration: TimeInterval) {
        self.jobID = jobID
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
    }

    public var succeeded: Bool { exitCode == 0 }
    public var stdoutString: String? { String(data: stdout, encoding: .utf8) }
    public var stderrString: String? { String(data: stderr, encoding: .utf8) }
}

// MARK: - Job Executor Protocol

public protocol JobExecutor: Sendable {
    func execute(spec: JobSpec, onOutput: @escaping @Sendable (Data) -> Void, onStderr: @escaping @Sendable (Data) -> Void) async throws -> JobResult
    func cancel(jobID: JobID) async
}

// MARK: - Job Error

public enum JobError: Error, Sendable {
    case notFound(JobID)
    case alreadyRunning(JobID)
    case spawnFailed(String)
    case timeout(TimeInterval)
    case cancelled
}

extension JobError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notFound(let id): return "Job not found: \(id.rawValue)"
        case .alreadyRunning(let id): return "Job already running: \(id.rawValue)"
        case .spawnFailed(let reason): return "Spawn failed: \(reason)"
        case .timeout(let t): return "Job timed out after \(t)s"
        case .cancelled: return "Job cancelled"
        }
    }
}

// MARK: - Resource Requirements (kept for backward compat)

public struct ResourceRequirements: Sendable, Codable {
    public let minMemoryMB: Int
    public let minCPUCores: Int
    public let architecture: CPUArchitecture?

    public init(minMemoryMB: Int = 0, minCPUCores: Int = 1, architecture: CPUArchitecture? = nil) {
        self.minMemoryMB = minMemoryMB
        self.minCPUCores = minCPUCores
        self.architecture = architecture
    }
}
