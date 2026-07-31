# Elysium Vanguard Fabric — API Reference

## Package: VanguardDomain

Core types shared across all packages. Zero Apple framework imports.

### Identifiers

```swift
struct NodeID: RawRepresentable<UUID>, Codable, Hashable, Sendable
struct SessionID: RawRepresentable<UUID>, Codable, Hashable, Sendable
struct JobID: RawRepresentable<UUID>, Codable, Hashable, Sendable
struct OperationID: RawRepresentable<UUID>, Codable, Hashable, Sendable
struct TerminalSessionID: RawRepresentable<UUID>, Codable, Hashable, Sendable
struct WorkspaceID: RawRepresentable<UUID>, Codable, Hashable, Sendable
```

### Platform Types

```swift
enum CPUArchitecture: String, Codable, CaseIterable { case arm64, x86_64 }
enum OSFamily: String, Codable { case macOS, linux, windows, android }
enum BatteryState: String, Codable { case unknown, charging, discharging, full, notPresent }
enum NodeThermalState: String, Codable, Comparable { case nominal, fair, serious, critical }
struct OperatingSystemDescriptor: Codable, Sendable { family, version }
struct NodeEndpoint: Codable, Sendable { host: String, port: UInt16 }
```

### Identity Types

```swift
struct SessionIdentity { sessionID, nodeID, keyPairRef, createdAt, expiresAt }
struct JobIdentity { jobID, ownerNodeID, executorNodeID, signedBy, signature, createdAt }
struct ArtifactIdentity { artifactID, producerNodeID, sha256, sizeBytes, signature, createdAt }
struct AgentIdentity { agentID, ownerNodeID, agentType, riskLevel, authorizedActions, signature, createdAt }
struct ApplicationIdentity { appBundleID, appVersion, signedBy, platform, capabilities, signature, registeredAt }
```

### Capabilities

```swift
enum FabricCapability: String, Codable, CaseIterable { 
    case screenView, screenControl, audioReceive, audioSend
    case clipboardRead, clipboardWrite, terminalOpen, terminalWrite
    case fileRead, fileWrite, processInspect, processExecute
    case jobSubmit, jobExecute, jobCancel, artifactRead, artifactWrite
    case workspaceRead, workspaceWrite, powerControl, softwareUpdate
    case agentPlan, agentExecute, policyAdmin
}
```

### NAT & Relay Types

```swift
enum NATType: String, Codable { 
    case unknown, directOpen, coneNAT, restrictedConeNAT
    case portRestrictedConeNAT, symmetricNAT, symmetricFirewall
}
struct STUNAddress: Codable { ip: String, port: UInt16 }
struct NATMapping: Codable { externalAddress, localAddress, natType, mappedAt }
struct RelayConfiguration: Codable { relayHost, relayPort, relayFingerprint, maxBandwidthMbps, requireEncryption }
enum ConnectionRoute: Codable { case direct(host:port:), relay(RelayConfiguration), vpn(host:port:) }
struct RelaySession: Codable { sessionID, relayHost, relayPort, sourceNodeID, targetNodeID, ... }
struct NetworkPath: Codable { route, natMapping, estimatedLatencyMs, estimatedBandwidthMbps, isEncrypted }
```

---

## Package: VanguardTransport

Network communication layer.

### Transport Protocol

```swift
protocol VanguardTransport: Sendable {
    var incomingMessages: AsyncThrowingStream<InboundMessage, Error> { get }
    func connect(to endpoint: NodeEndpoint) async throws
    func listen(port: UInt16) async throws
    func send(_ message: OutboundMessage) async throws
    func disconnect(reason: TransportDisconnectReason) async
}
```

### STUN Client

```swift
actor STUNClient {
    func discoverNATType(stunHost: String, stunPort: UInt16) async throws -> NATMapping
}
```

### Connection Route Negotiator

```swift
actor ConnectionRouteNegotiator {
    func negotiateRoute(
        localNATType: NATType,
        targetNATType: NATType,
        targetExternalAddress: STUNAddress?,
        relayAvailable: Bool,
        relayHost: String?,
        relayPort: UInt16?,
        preferRelay: Bool
    ) -> ConnectionRoute
}
```

---

## Package: VanguardProtocol

Wire protocol types.

### Message Types (key cases)

```swift
enum MessageType: UInt16, CaseIterable {
    // Handshake
    case hello = 0x0001, helloAck = 0x0002
    // Pairing
    case pairingRequest = 0x0010, pairingChallenge = 0x0011
    case pairingResponse = 0x0012, pairingComplete = 0x0013
    // Auth
    case authenticate = 0x0020, authenticated = 0x0021
    // Capabilities
    case capabilityRequest = 0x0030, capabilityGranted = 0x0031, capabilityDenied = 0x0032
    // Video
    case videoConfiguration = 0x0100, videoFrame = 0x0101
    // Input
    case inputEvent = 0x0200
    // Jobs
    case jobSubmit = 0x0800, jobAssigned = 0x0801, jobCompleted = 0x0803
    // Coordinator
    case presenceRegister = 0x0B00, rendezvousRequest = 0x0B10
    case signalingOffer = 0x0B20, relayAllocate = 0x0B30
}
```

### Envelope

```swift
struct FabricMessageEnvelope {
    let magic: UInt32           // 0x45564642
    let protocolMajor: UInt16
    let protocolMinor: UInt16
    let messageType: UInt16
    let channel: UInt16
    let flags: UInt16
    let reserved: UInt16
    let sessionID: UUID
    let sequence: UInt64
    let payloadLength: UInt64
    // Total: 48 bytes
}
```

---

## Package: VanguardCompute

Job execution.

### JobSpec

```swift
struct JobSpec: Codable, Sendable {
    let jobID: UUID
    let submittedBy: UUID
    let name: String
    let executor: ExecutorKind
    let command: ExecutableCommand
    let requirements: JobRequirements
    let inputs: [ArtifactReference]
    let expectedOutputs: [ExpectedArtifact]
    let environment: [String: String]
    let timeoutSeconds: UInt64
    let retryPolicy: RetryPolicy
    let priority: JobPriority
    let securityPolicy: JobSecurityPolicy
    let signature: Data
}
```

### JobExecutor Protocol

```swift
protocol JobExecutor: Sendable {
    func execute(spec: JobSpec, onOutput: @escaping @Sendable (Data) -> Void, onStderr: @escaping @Sendable (Data) -> Void) async throws -> JobResult
    func cancel(jobID: JobID) async
}
```

### PreparedExecution

```swift
struct PreparedExecution: Codable, Sendable {
    let jobID: JobID
    let resolvedExecutable: String
    let resolvedArguments: [String]
    let sandboxPath: String
    let inputsPath: String
    let outputsPath: String
    let logsPath: String
    let environment: [String: String]
    let processLimit: Int
    let timeoutSeconds: UInt64
}
```

### JobExecutionEvent

```swift
enum JobExecutionEvent: Sendable, Codable, Equatable {
    case started(jobID: JobID, nodeID: UUID)
    case stdoutChunk(jobID: JobID, data: Data)
    case stderrChunk(jobID: JobID, data: Data)
    case progress(jobID: JobID, percentage: Double)
    case checkpoint(jobID: JobID, checkpointID: UUID, sequence: UInt64)
    case resourceSample(jobID: JobID, cpuUsage: Double, memoryBytes: UInt64)
    case outputReady(jobID: JobID, artifactID: UUID, path: String, sha256: Data)
    case succeeded(jobID: JobID, exitCode: Int32, duration: TimeInterval)
    case failed(jobID: JobID, reason: String, exitCode: Int32)
    case cancelled(jobID: JobID)
    case timedOut(jobID: JobID, timeoutSeconds: UInt64)
}
```

---

## Package: VanguardScheduler

Node selection and scoring.

### FabricScheduler

```swift
actor FabricScheduler {
    func registerNode(_ descriptor: NodeResourceDescriptor)
    func unregisterNode(_ nodeID: NodeID)
    func updateWeights(_ weights: SchedulerWeights)
    func recordLatency(_ latency: TimeInterval, for nodeID: NodeID)
    func recordJobResult(nodeID: NodeID, succeeded: Bool)
    func registerArtifactLocation(artifactID: UUID, onNode nodeID: NodeID)
    func selectNode(for constraints: HardConstraints) throws -> SchedulerScore
    func selectNode(for constraints: HardConstraints, requiredArtifactIDs: [UUID]) throws -> SchedulerScore
    func allNodes() -> [NodeResourceDescriptor]
}
```

### SchedulerWeights

```swift
struct SchedulerWeights {
    cpuWeight, memoryWeight, localityWeight, latencyWeight
    reliabilityWeight, thermalWeight, energyWeight
    // Default: cpu=0.25, memory=0.15, locality=0.20, latency=0.10, reliability=0.15, thermal=0.10, energy=0.05
}
```

---

## Package: VanguardExecutors

Distributed job coordination.

### DistributedJobCoordinator

```swift
actor DistributedJobCoordinator {
    func registerExecutor(_ executor: RemoteJobExecutor, for nodeID: NodeID)
    func unregisterExecutor(for nodeID: NodeID)
    func submitJob(_ spec: JobSpec, requiredArtifactIDs: [UUID], onProgress: @Sendable @escaping (DistributedJobState) -> Void) async throws -> JobID
    func cancelJob(_ jobID: JobID) async
    func jobState(_ jobID: JobID) -> DistributedJobState?
    func jobResult(_ jobID: JobID) -> JobResult?
}
```

### RemoteJobExecutor Protocol

```swift
protocol RemoteJobExecutor: Sendable {
    func submitJob(name: String, command: [String], workingDirectory: String?, timeoutSeconds: TimeInterval) async throws -> String
    func cancelJob(jobID: String) async throws
    func getJobStatus(jobID: String) async -> String?
}
```

---

## Package: VanguardCoordinator

Server-side coordination services.

### CoordinatorService

```swift
actor CoordinatorService {
    func registerNode(nodeID:displayName:endpoint:architecture:capabilities:natType:)
    func deregisterNode(_ nodeID: NodeID)
    func heartbeat(_ nodeID: NodeID) -> Bool
    func nodeList() -> [RegisteredNode]
    func node(byID: NodeID) -> RegisteredNode?
    func nodes(withCapability: FabricCapability) -> [RegisteredNode]
    func nodes(architecture: CPUArchitecture) -> [RegisteredNode]
    func cleanupExpiredNodes() -> [NodeID]
}
```

### RendezvousService

```swift
actor RendezvousService {
    func requestRendezvous(consoleID:targetNodeID:preferredRoute:) async throws -> RendezvousRequest
    func respondToRendezvous(requestID:accepted:consoleEndpoint:nodeEndpoint:route:sessionSecret:) async -> RendezvousOffer?
    func completeRendezvous(requestID: UUID) -> RendezvousAnswer?
    func cancelRendezvous(requestID: UUID)
    func cleanupStale(maxAge: TimeInterval)
}
```

### SignalingService

```swift
actor SignalingService {
    func createOffer(_ offer: SignalingOffer) -> SignalingSession
    func receiveAnswer(_ answer: SignalingAnswer) -> SignalingSession?
    func addICECandidate(_ candidate: ICECandidate, toSession: UUID)
    func pendingICECandidates(for: UUID) -> [ICECandidate]
    func session(_ sessionID: UUID) -> SignalingSession?
    func closeSession(_ sessionID: UUID)
}
```

### RelayService

```swift
actor RelayService {
    func allocateChannel(sourceNodeID:targetNodeID:) -> RelayChannel
    func forwardPacket(channelID:data:from:) -> RelayForwardResult?
    func releaseChannel(_ channelID: UUID)
    func channelsForNode(_ nodeID: NodeID) -> [RelayChannel]
    func cleanupInactive(maxAge: TimeInterval) -> [UUID]
    func availableBandwidthMbps() -> Double
}
```

---

## Package: VanguardSession

Session lifecycle coordination for Console and Node.

### ConsoleSessionCoordinator

```swift
actor ConsoleSessionCoordinator {
    func openSession(to nodeID: NodeID, transport: VanguardTransport) async throws
    func closeSession(_ sessionID: SessionID) async
    func sendInput(_ event: InputEvent, to sessionID: SessionID) async throws
    func openTerminal(on sessionID: SessionID) async throws -> TerminalSessionID
    func sendTerminalInput(_ data: Data, to terminalID: TerminalSessionID) async throws
    func closeTerminal(_ terminalID: TerminalSessionID) async
    func requestClipboard(on sessionID: SessionID) async throws
    func sendClipboardContent(_ content: Data, to sessionID: SessionID) async throws
    func switchToWindow(_ windowID: WindowID, on sessionID: SessionID) async throws
    func switchToDisplay(_ displayID: DisplayID, on sessionID: SessionID) async throws
    func getAvailableWindows(on sessionID: SessionID) async throws -> [RemoteWindowDescriptor]
    func getAvailableDisplays(on sessionID: SessionID) async throws -> [DisplayDescriptor]
    func requestKeyframe(on sessionID: SessionID) async throws
    func sendEmergencyStop(to sessionID: SessionID) async throws
    func submitAgentPlan(_ plan: AgentPlan, to sessionID: SessionID) async throws -> UUID
    func requestWorkspace(on sessionID: SessionID) async throws
    func requestSync(on sessionID: SessionID) async throws
}
```

### NodeSessionCoordinator

```swift
actor NodeSessionCoordinator {
    func startListening(port: UInt16) async throws
    func stopListening() async
    func handleIncomingConnection(_ connection: NWConnection) async
    func startCapture(for sessionID: SessionID) async throws
    func stopCapture(for sessionID: SessionID) async
    func sendVideoFrame(_ frame: EncodedFrame, to sessionID: SessionID) async throws
    func handleInputEvent(_ event: InputEvent, from sessionID: SessionID) async throws
    func openTerminalSession(for sessionID: SessionID) async throws -> TerminalSessionID
    func sendTerminalOutput(_ data: Data, to sessionID: SessionID) async throws
    func closeTerminalSession(_ terminalID: TerminalSessionID) async
    func sendClipboardContent(_ content: Data, to sessionID: SessionID) async throws
    func handleClipboardRequest(from sessionID: SessionID) async throws
    func switchToWindow(_ windowID: WindowID, for sessionID: SessionID) async throws
    func switchToDisplay(_ displayID: DisplayID, for sessionID: SessionID) async throws
    func getAvailableWindows() async throws -> [RemoteWindowDescriptor]
    func getAvailableDisplays() async throws -> [DisplayDescriptor]
    func handleEmergencyStop(from sessionID: SessionID) async
    func handleAgentPlan(_ plan: AgentPlan, from sessionID: SessionID) async throws -> UUID
    func sendWorkspaceSnapshot(to sessionID: SessionID) async throws
    func sendNodeTelemetry(to sessionID: SessionID) async throws
}
```

---

## Package: VanguardUpdates

Signed update mechanism.

### UpdateService

```swift
actor UpdateService {
    func addTrustedKey(_ key: P256.Signing.PublicKey)
    func removeTrustedKey(_ key: P256.Signing.PublicKey)
    func checkForUpdate(manifest:currentVersion:) -> Bool
    func downloadUpdate(from: String) async throws -> Data
    func verifySignature(_ data: Data, signature: Data) async throws -> P256.Signing.PublicKey
    func verifyManifestSignature(_ data: Data) async throws -> P256.Signing.PublicKey
    func installUpdate(_ data: Data, stagingPath: String) throws
    func activateUpdate(stagingPath:activePath:) throws
    func healthCheck(binaryPath: String) -> Bool
    func rollback(stagingPath:activePath:)
    func reset()
}
```

---

## Package: VanguardBuild

Universal binary builds.

### UniversalBuildService

```swift
actor UniversalBuildService {
    func startBuild(_ request: UniversalBuildRequest) async throws -> BuildManifest
    func cancelBuild(_ buildID: UUID)
    func buildManifest(_ buildID: UUID) -> BuildManifest?
    func activeBuildIDs() -> [UUID]
    func cleanupCompletedBuilds(olderThan: TimeInterval)
}
```

### LipoService

```swift
actor LipoService {
    func combine(inputPaths:outputPath:) async throws -> LipoResult
    func extractArchitectures(from: String) async throws -> [CPUArchitecture]
    func verifyFatBinary(_ path: String, expectedArchs: [CPUArchitecture]) async throws -> Bool
}
```

---

## Package: VanguardObservability

Event logging and metrics.

### FabricEventCategory

```swift
enum FabricEventCategory: String, Sendable, CaseIterable, Codable {
    case identity, pairing, transport, session, capture, video, audio
    case input, terminal, clipboard, files, workspace, artifact
    case scheduler, job, agent, security, update, performance, error
}
```

### FabricSeverity

```swift
enum FabricSeverity: String, Sendable, Codable, Comparable {
    case debug, info, notice, warning, error, critical
}
```

### FabricEventLog

```swift
actor FabricEventLog {
    func record(_ event: FabricEvent, source: NodeID?)
    func recentEvents(count: Int) -> [FabricEventEntry]
    func eventsInCategory(_ category: String) -> [FabricEventEntry]
    func clear()
}
```

---

## Package: VanguardWorkspace

Workspace synchronization.

### WorkspaceOperation

```swift
enum WorkspaceOperation: Sendable, Codable, Equatable {
    case create(path: String, content: Data, sha256: Data)
    case modify(path: String, oldSHA256: Data, newContent: Data, newSHA256: Data)
    case delete(path: String, expectedSHA256: Data)
    case rename(from: String, to: String)
    case mkdir(path: String)
}
```

### WorkspaceChangeSet

```swift
struct WorkspaceChangeSet: Sendable, Codable {
    let snapshotID: WorkspaceID
    let added: [String]
    let modified: [String]
    let deleted: [String]
    var isEmpty: Bool
    var totalCount: Int
}
```
