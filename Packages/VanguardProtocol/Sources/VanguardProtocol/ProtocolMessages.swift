import Foundation
import VanguardDomain

// MARK: - Outbound Message

public struct OutboundMessage: Sendable {
    public let messageType: MessageType
    public let streamChannel: StreamChannel
    public let flags: MessageFlags
    public let operationID: OperationID?
    public let payload: Data

    public init(
        messageType: MessageType,
        streamChannel: StreamChannel = .control,
        flags: MessageFlags = .none,
        operationID: OperationID? = nil,
        payload: Data = Data()
    ) {
        self.messageType = messageType
        self.streamChannel = streamChannel
        self.flags = flags
        self.operationID = operationID
        self.payload = payload
    }
}

// MARK: - Inbound Message

public struct InboundMessage: Sendable {
    public let header: ProtocolHeader
    public let payload: Data
    public let receivedAt: UInt64

    public init(header: ProtocolHeader, payload: Data, receivedAt: UInt64 = 0) {
        self.header = header
        self.payload = payload
        self.receivedAt = receivedAt
    }
}

// MARK: - Message Payloads

public struct HelloPayload: Codable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let nodeID: NodeID
    public let displayName: String
    public let architecture: CPUArchitecture
    public let osFamily: OSFamily
    public let osVersion: String

    public init(
        protocolVersion: ProtocolVersion = .v1_0,
        nodeID: NodeID,
        displayName: String,
        architecture: CPUArchitecture,
        osFamily: OSFamily,
        osVersion: String
    ) {
        self.protocolVersion = protocolVersion
        self.nodeID = nodeID
        self.displayName = displayName
        self.architecture = architecture
        self.osFamily = osFamily
        self.osVersion = osVersion
    }
}

public struct HelloAckPayload: Codable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let nodeID: NodeID
    public let acceptedVersion: ProtocolVersion

    public init(
        protocolVersion: ProtocolVersion = .v1_0,
        nodeID: NodeID,
        acceptedVersion: ProtocolVersion = .v1_0
    ) {
        self.protocolVersion = protocolVersion
        self.nodeID = nodeID
        self.acceptedVersion = acceptedVersion
    }
}

public struct PairingRequestPayload: Codable, Sendable {
    public let consoleID: NodeID
    public let consoleDisplayName: String
    public let signingPublicKey: Data
    public let agreementPublicKey: Data

    public init(
        consoleID: NodeID,
        consoleDisplayName: String,
        signingPublicKey: Data,
        agreementPublicKey: Data
    ) {
        self.consoleID = consoleID
        self.consoleDisplayName = consoleDisplayName
        self.signingPublicKey = signingPublicKey
        self.agreementPublicKey = agreementPublicKey
    }
}

public struct PairingChallengePayload: Codable, Sendable {
    public let challengeCode: String
    public let expiresAtNanos: UInt64
    public let fingerprint: Data

    public init(challengeCode: String, expiresAtNanos: UInt64, fingerprint: Data) {
        self.challengeCode = challengeCode
        self.expiresAtNanos = expiresAtNanos
        self.fingerprint = fingerprint
    }
}

public struct PairingResponsePayload: Codable, Sendable {
    public let consoleID: NodeID
    public let challengeCode: String
    public let signingPublicKey: Data
    public let agreementPublicKey: Data
    public let transcriptHash: Data

    public init(
        consoleID: NodeID,
        challengeCode: String,
        signingPublicKey: Data,
        agreementPublicKey: Data,
        transcriptHash: Data
    ) {
        self.consoleID = consoleID
        self.challengeCode = challengeCode
        self.signingPublicKey = signingPublicKey
        self.agreementPublicKey = agreementPublicKey
        self.transcriptHash = transcriptHash
    }
}

public struct PairingCompletePayload: Codable, Sendable {
    public let nodeID: NodeID
    public let trustedPeer: Data
    public let signature: Data

    public init(nodeID: NodeID, trustedPeer: Data, signature: Data) {
        self.nodeID = nodeID
        self.trustedPeer = trustedPeer
        self.signature = signature
    }
}

public struct AuthenticatePayload: Codable, Sendable {
    public let peerID: NodeID
    public let transcriptHash: Data
    public let signature: Data

    public init(peerID: NodeID, transcriptHash: Data, signature: Data) {
        self.peerID = peerID
        self.transcriptHash = transcriptHash
        self.signature = signature
    }
}

public struct AuthenticatedPayload: Codable, Sendable {
    public let nodeID: NodeID
    public let grantedCapabilities: Set<NodeCapability>

    public init(nodeID: NodeID, grantedCapabilities: Set<NodeCapability>) {
        self.nodeID = nodeID
        self.grantedCapabilities = grantedCapabilities
    }
}

public struct CapabilityRequestPayload: Codable, Sendable {
    public let capabilities: Set<NodeCapability>
    public let reason: String

    public init(capabilities: Set<NodeCapability>, reason: String = "") {
        self.capabilities = capabilities
        self.reason = reason
    }
}

public struct CapabilityGrantedPayload: Codable, Sendable {
    public let grantedCapabilities: Set<NodeCapability>

    public init(grantedCapabilities: Set<NodeCapability>) {
        self.grantedCapabilities = grantedCapabilities
    }
}

public struct CapabilityDeniedPayload: Codable, Sendable {
    public let deniedCapabilities: Set<NodeCapability>
    public let reason: String

    public init(deniedCapabilities: Set<NodeCapability>, reason: String) {
        self.deniedCapabilities = deniedCapabilities
        self.reason = reason
    }
}

public struct SessionOpenPayload: Codable, Sendable {
    public let sessionID: SessionID
    public let nodeID: NodeID
    public let capabilities: Set<NodeCapability>

    public init(sessionID: SessionID, nodeID: NodeID, capabilities: Set<NodeCapability>) {
        self.sessionID = sessionID
        self.nodeID = nodeID
        self.capabilities = capabilities
    }
}

public struct SessionClosePayload: Codable, Sendable {
    public let sessionID: SessionID
    public let reason: DisconnectReason

    public init(sessionID: SessionID, reason: DisconnectReason) {
        self.sessionID = sessionID
        self.reason = reason
    }
}

public struct HeartbeatPayload: Codable, Sendable {
    public let timestampNanos: UInt64
    public let sequence: UInt64

    public init(timestampNanos: UInt64, sequence: UInt64) {
        self.timestampNanos = timestampNanos
        self.sequence = sequence
    }
}

public struct VideoConfigurationPayload: Codable, Sendable {
    public let width: Int
    public let height: Int
    public let fps: Int
    public let bitrate: Int
    public let keyframeInterval: Int
    public let codecConfigRevision: UInt32

    public init(
        width: Int,
        height: Int,
        fps: Int,
        bitrate: Int,
        keyframeInterval: Int = 2,
        codecConfigRevision: UInt32 = 1
    ) {
        self.width = width
        self.height = height
        self.fps = fps
        self.bitrate = bitrate
        self.keyframeInterval = keyframeInterval
        self.codecConfigRevision = codecConfigRevision
    }
}

public struct VideoFramePayload: Codable, Sendable {
    public let frameID: UInt64
    public let presentationTimestampNanos: UInt64
    public let isKeyframe: Bool
    public let codecConfigurationRevision: UInt32
    public let payload: Data

    public init(
        frameID: UInt64,
        presentationTimestampNanos: UInt64,
        isKeyframe: Bool,
        codecConfigurationRevision: UInt32,
        payload: Data
    ) {
        self.frameID = frameID
        self.presentationTimestampNanos = presentationTimestampNanos
        self.isKeyframe = isKeyframe
        self.codecConfigurationRevision = codecConfigurationRevision
        self.payload = payload
    }
}

public struct TerminalOpenPayload: Codable, Sendable {
    public let sessionID: TerminalSessionID
    public let configuration: TerminalConfiguration

    public init(sessionID: TerminalSessionID, configuration: TerminalConfiguration) {
        self.sessionID = sessionID
        self.configuration = configuration
    }
}

public struct TerminalOpenedPayload: Codable, Sendable {
    public let sessionID: TerminalSessionID
    public let pid: Int32

    public init(sessionID: TerminalSessionID, pid: Int32) {
        self.sessionID = sessionID
        self.pid = pid
    }
}

public struct TerminalInputPayload: Codable, Sendable {
    public let sessionID: TerminalSessionID
    public let data: Data

    public init(sessionID: TerminalSessionID, data: Data) {
        self.sessionID = sessionID
        self.data = data
    }
}

public struct TerminalOutputPayload: Codable, Sendable {
    public let sessionID: TerminalSessionID
    public let data: Data
    public let offset: UInt64

    public init(sessionID: TerminalSessionID, data: Data, offset: UInt64) {
        self.sessionID = sessionID
        self.data = data
        self.offset = offset
    }
}

public struct TerminalResizePayload: Codable, Sendable {
    public let sessionID: TerminalSessionID
    public let columns: UInt16
    public let rows: UInt16

    public init(sessionID: TerminalSessionID, columns: UInt16, rows: UInt16) {
        self.sessionID = sessionID
        self.columns = columns
        self.rows = rows
    }
}

public struct TerminalClosePayload: Codable, Sendable {
    public let sessionID: TerminalSessionID
    public let signal: TerminalCloseSignal

    public init(sessionID: TerminalSessionID, signal: TerminalCloseSignal) {
        self.sessionID = sessionID
        self.signal = signal
    }
}

public struct AuditEventPayload: Codable, Sendable {
    public let entry: AuditEntry

    public init(entry: AuditEntry) {
        self.entry = entry
    }
}

public struct ErrorPayload: Codable, Sendable {
    public let code: UInt32
    public let message: String
    public let relatedOperationID: OperationID?

    public init(code: UInt32, message: String, relatedOperationID: OperationID? = nil) {
        self.code = code
        self.message = message
        self.relatedOperationID = relatedOperationID
    }
}

public struct FlowControlAckPayload: Codable, Sendable {
    public let channel: UInt8
    public let bytesReceived: UInt32

    public init(channel: UInt8, bytesReceived: UInt32) {
        self.channel = channel
        self.bytesReceived = bytesReceived
    }
}

// MARK: - Telemetry Payload

public struct TelemetrySnapshotPayload: Codable, Sendable {
    public let nodeID: String
    public let cpuLoad: Double
    public let memoryPressure: Double
    public let availableMemoryBytes: UInt64
    public let batteryLevel: Double
    public let thermalState: UInt8

    public init(nodeID: String, cpuLoad: Double, memoryPressure: Double, availableMemoryBytes: UInt64, batteryLevel: Double, thermalState: UInt8) {
        self.nodeID = nodeID
        self.cpuLoad = cpuLoad
        self.memoryPressure = memoryPressure
        self.availableMemoryBytes = availableMemoryBytes
        self.batteryLevel = batteryLevel
        self.thermalState = thermalState
    }
}

// MARK: - Job Payloads

public struct JobSubmitPayload: Codable, Sendable {
    public let jobID: String
    public let name: String
    public let command: [String]
    public let workingDirectory: String?
    public let environment: [String: String]
    public let timeoutSeconds: TimeInterval
    public let resourceRequirements: JobResourceRequirementsPayload

    public init(jobID: String, name: String, command: [String], workingDirectory: String? = nil, environment: [String: String] = [:], timeoutSeconds: TimeInterval = 300, resourceRequirements: JobResourceRequirementsPayload = JobResourceRequirementsPayload()) {
        self.jobID = jobID
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.timeoutSeconds = timeoutSeconds
        self.resourceRequirements = resourceRequirements
    }
}

public struct JobResourceRequirementsPayload: Codable, Sendable {
    public let minMemoryMB: Int
    public let minCPUCores: Int
    public let architecture: String?

    public init(minMemoryMB: Int = 0, minCPUCores: Int = 1, architecture: String? = nil) {
        self.minMemoryMB = minMemoryMB
        self.minCPUCores = minCPUCores
        self.architecture = architecture
    }
}

public struct JobAssignedPayload: Codable, Sendable {
    public let jobID: String
    public let nodeID: String

    public init(jobID: String, nodeID: String) {
        self.jobID = jobID
        self.nodeID = nodeID
    }
}

public struct JobProgressPayload: Codable, Sendable {
    public let jobID: String
    public let stdout: String?
    public let stderr: String?

    public init(jobID: String, stdout: String? = nil, stderr: String? = nil) {
        self.jobID = jobID
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct JobCompletedPayload: Codable, Sendable {
    public let jobID: String
    public let exitCode: Int32
    public let stdout: String?
    public let stderr: String?
    public let duration: TimeInterval

    public init(jobID: String, exitCode: Int32, stdout: String? = nil, stderr: String? = nil, duration: TimeInterval) {
        self.jobID = jobID
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
    }
}

public struct JobFailedPayload: Codable, Sendable {
    public let jobID: String
    public let error: String

    public init(jobID: String, error: String) {
        self.jobID = jobID
        self.error = error
    }
}

public struct JobCancelledPayload: Codable, Sendable {
    public let jobID: String

    public init(jobID: String) {
        self.jobID = jobID
    }
}

// MARK: - Artifact Payloads

public struct ArtifactManifestPayload: Codable, Sendable {
    public let artifactID: String
    public let name: String
    public let version: String
    public let chunkSize: Int
    public let totalSize: Int
    public let sha256Hash: String
    public let chunkHashes: [String]
    public let metadata: [String: String]

    public init(artifactID: String, name: String, version: String, chunkSize: Int, totalSize: Int, sha256Hash: String, chunkHashes: [String], metadata: [String: String] = [:]) {
        self.artifactID = artifactID
        self.name = name
        self.version = version
        self.chunkSize = chunkSize
        self.totalSize = totalSize
        self.sha256Hash = sha256Hash
        self.chunkHashes = chunkHashes
        self.metadata = metadata
    }
}

public struct ArtifactChunkPayload: Codable, Sendable {
    public let artifactID: String
    public let index: Int
    public let dataBase64: String
    public let sha256Hash: String

    public init(artifactID: String, index: Int, dataBase64: String, sha256Hash: String) {
        self.artifactID = artifactID
        self.index = index
        self.dataBase64 = dataBase64
        self.sha256Hash = sha256Hash
    }
}

public struct ArtifactRequestPayload: Codable, Sendable {
    public let artifactID: String
    public let chunkIndices: [Int]?

    public init(artifactID: String, chunkIndices: [Int]? = nil) {
        self.artifactID = artifactID
        self.chunkIndices = chunkIndices
    }
}

// MARK: - Clipboard Payload

public struct ClipboardDataPayload: Codable, Sendable {
    public let content: String
    public let contentType: String
    public let changeCount: Int

    public init(content: String, contentType: String = "public.utf8-plain-text", changeCount: Int) {
        self.content = content
        self.contentType = contentType
        self.changeCount = changeCount
    }
}

// MARK: - Agent Payloads

public struct AgentSubmitPayload: Codable, Sendable {
    public let planID: String
    public let objective: String
    public let steps: [String]

    public init(planID: String, objective: String, steps: [String]) {
        self.planID = planID
        self.objective = objective
        self.steps = steps
    }
}

public struct AgentProgressPayload: Codable, Sendable {
    public let planID: String
    public let stepIndex: Int
    public let output: String

    public init(planID: String, stepIndex: Int, output: String) {
        self.planID = planID
        self.stepIndex = stepIndex
        self.output = output
    }
}

public struct AgentCompletedPayload: Codable, Sendable {
    public let planID: String
    public let outputs: [String]

    public init(planID: String, outputs: [String]) {
        self.planID = planID
        self.outputs = outputs
    }
}

public struct AgentFailedPayload: Codable, Sendable {
    public let planID: String
    public let error: String

    public init(planID: String, error: String) {
        self.planID = planID
        self.error = error
    }
}

// MARK: - Workspace Payloads

public struct WorkspaceRequestPayload: Codable, Sendable {
    public let workspaceID: String

    public init(workspaceID: String) {
        self.workspaceID = workspaceID
    }
}

public struct WorkspaceResponsePayload: Codable, Sendable {
    public let workspaceID: String
    public let files: [String: String]
    public let stateHash: Data

    public init(workspaceID: String, files: [String: String], stateHash: Data) {
        self.workspaceID = workspaceID
        self.files = files
        self.stateHash = stateHash
    }
}
