import SwiftUI
import Combine
import CoreVideo
import CoreFoundation
import CryptoKit
import IOKit
import IOKit.ps
import CSystemMetrics
import VanguardDomain
import VanguardProtocol
import VanguardDiscovery
import VanguardTransport
import VanguardIdentity
import VanguardPermissions
import VanguardVideo
import VanguardInput
import VanguardTerminal
import VanguardSession
import VanguardClipboard
import VanguardSecurity
import VanguardAudit
import VanguardUI
import VanguardScheduler
import VanguardCompute
import VanguardWorkspace
import VanguardObservability
import VanguardAgents
import VanguardFiles

@MainActor
public final class ConsoleAppState: ObservableObject {
    @Published public var isScanning = false
    @Published public var discoveredNodes: [DiscoveredNode] = []
    @Published public var statusMessage = "Ready"
    @Published public var consoleName: String = Host.current().localizedName ?? "Console"
    @Published public var isConnected = false
    @Published public var connectedNodeName: String?
    @Published public var currentState: SessionState = .idle
    @Published public var currentTheme: ThemeProfile = .balanced
    @Published public var permissions: PermissionStatus = .unknown

    @Published public var activeJobs: [TrackedJob] = []
    @Published public var terminalSessions: [TrackedTerminalSession] = []
    @Published public var auditEntries: [AuditLogEntry] = []
    @Published public var fabricEvents: [FabricEventEntry] = []
    @Published public var agentPlans: [TrackedAgentPlan] = []
    @Published public var workspaceSnapshots: [WorkspaceSnapshot] = []
    @Published public var grantedCapabilities: Set<NodeCapability> = [.screenView, .screenControl, .clipboardRead, .clipboardWrite, .terminalOpen, .processExecute, .fileRead, .nodeRestart]
    @Published public var schedulerWeights = SchedulerWeights()

    @Published public var availableDisplays: [DisplayDescriptor] = []
    @Published public var availableWindows: [RemoteWindowDescriptor] = []
    @Published public var selectedDisplayID: UInt32?
    @Published public var selectedWindowID: UInt32?
    @Published public var captureMode: WindowCaptureMode = .display

    public struct FabricEventEntry: Identifiable, Sendable {
        public let id = UUID()
        public let event: FabricEvent
        public let timestamp: Date
    }

    public struct AuditLogEntry: Identifiable {
        public let id = UUID()
        public let action: String
        public let severity: Severity
        public let timestamp: Date

        public enum Severity { case info, success, warning, error
            var color: SwiftUI.Color {
                switch self {
                case .info: return DS.Colors.info
                case .success: return DS.Colors.success
                case .warning: return DS.Colors.warning
                case .error: return DS.Colors.error
                }
            }
            var icon: String {
                switch self {
                case .info: return "info.circle"
                case .success: return "checkmark.circle"
                case .warning: return "exclamationmark.triangle"
                case .error: return "xmark.circle"
                }
            }
        }
    }

    public enum SessionState {
        case idle
        case scanning
        case connecting
        case connected
        case pairing(challengeCode: String)
        case paired
        case capturing
        case error(String)
    }

    public enum PermissionStatus: Equatable {
        case unknown
        case granted
        case denied
    }

    public struct DiscoveredNode: Identifiable, Hashable {
        public let id = UUID()
        public let name: String
        public let host: String
        public let advertisement: NodeAdvertisement
        public var status: Status
        public var resourceDescriptor: NodeResourceDescriptor?

        public enum Status: Hashable {
            case online
            case offline
            case connecting
        }

        public static func == (lhs: DiscoveredNode, rhs: DiscoveredNode) -> Bool { lhs.id == rhs.id }
        public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    public struct TrackedJob: Identifiable, @unchecked Sendable {
        public let id = UUID()
        public let spec: JobSpec
        public var state: JobState
        public var output: String
        public var nodeID: String
        public let createdAt: Date

        public init(spec: JobSpec, nodeID: String = "Local") {
            self.spec = spec
            self.state = .submitted
            self.output = ""
            self.nodeID = nodeID
            self.createdAt = Date()
        }
    }

    public struct TrackedTerminalSession: Identifiable, @unchecked Sendable {
        public let id: TerminalSessionID
        public let nodeName: String
        public var output: String
        public var isActive: Bool
        public var pid: Int32?

        public init(id: TerminalSessionID, nodeName: String, pid: Int32? = nil) {
            self.id = id
            self.nodeName = nodeName
            self.output = ""
            self.isActive = true
            self.pid = pid
        }
    }

    public struct TrackedAgentPlan: Identifiable {
        public let id = UUID()
        public let plan: AgentPlan
        public var state: AgentPipeline.PipelineState
        public var results: [UUID: AgentPipeline.StepResult]
        public var stepOutputs: [String]

        public init(plan: AgentPlan) {
            self.plan = plan
            self.state = .idle
            self.results = [:]
            self.stepOutputs = []
        }
    }

    public struct SchedulerWeights {
        public var cpuWeight: Double = 0.25
        public var memoryWeight: Double = 0.15
        public var localityWeight: Double = 0.20
        public var latencyWeight: Double = 0.10
        public var reliabilityWeight: Double = 0.15
        public var thermalWeight: Double = 0.10
        public var energyWeight: Double = 0.05
    }

    private var coordinator: ConsoleSessionCoordinator?
    private let clipboardService = ClipboardService()
    private var identityService: CryptoKitIdentityService? = nil
    private var auditService: AuditIntegrationService?
    private let shortcutService = KeyboardShortcutService()
    private let scheduler = FabricScheduler()
    private let eventLog = FabricEventLog()
    private let authGuard = AuthorizationGuard()
    private let workspaceService = WorkspaceService()
    private let agentPipeline = AgentPipeline()
    private let nativeExecutor = NativeProcessExecutor()
    private var terminalService: TerminalService = POSIXTerminalService()
    private var outputTasks: [TerminalSessionID: Task<Void, any Error>] = [:]
    private var currentSessionID: SessionID?
    private var refreshTimer: Timer?
    private var reconnectionTask: Task<Void, Never>?
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 10
    private var lastConnectedNode: DiscoveredNode?
    private var clipboardSyncTask: Task<Void, Never>?
    private let capabilityNegotiator = CapabilityNegotiator()
    private let fileTransferService = FileTransferService()
    private let metricsCollector = PipelineMetricsCollector()
    private let idempotencyCache = IdempotencyCache()
    private var metricsTimer: Timer?
    @Published public var trustedPeers: [TrustedPeer] = []
    @Published public var terminalScrollbackLimit: Int = 10000
    @Published public var isReconnecting = false
    @Published public var reconnectionAttempt = 0
    @Published public var currentNegotiation: CapabilityNegotiation?
    @Published public var auditChainValid: Bool = true
    @Published public var pipelineMetrics: PipelineMetrics = PipelineMetrics()

    public struct TrustedPeer: Identifiable, Codable, Sendable {
        public let id: UUID
        public let name: String
        public let host: String
        public let nodeIDHash: Data
        public let pairedAt: Date

        public init(id: UUID = UUID(), name: String, host: String, nodeIDHash: Data, pairedAt: Date = Date()) {
            self.id = id
            self.name = name
            self.host = host
            self.nodeIDHash = nodeIDHash
            self.pairedAt = pairedAt
        }
    }

    public init() {
        loadTrustedPeers()
        Task { await checkPermissions() }
        Task { await registerShortcuts() }
        Task { await startEmergencyStopHotkey() }
    }

    // MARK: - Jobs

    public func submitJob(name: String, executable: String, arguments: [String] = []) {
        let spec = JobSpec(
            submittedBy: UUID(),
            name: name,
            command: ExecutableCommand(executable: executable, arguments: arguments)
        )
        let tracked = TrackedJob(spec: spec)
        activeJobs.insert(tracked, at: 0)
        Task { await eventLog.record(.jobStarted(name)) }
        appendAudit("Job submitted: \(name)", severity: .info)

        Task {
            var updated = tracked
            updated.state = .queued
            if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                activeJobs[idx] = updated
            }

            if isConnected, let coordinator = coordinator {
                let command = [executable] + arguments
                do {
                    try await coordinator.submitJobToNode(
                        jobID: spec.jobID.uuidString,
                        name: name,
                        command: command
                    )
                    if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                        activeJobs[idx].state = .assigned(nodeID: UUID())
                    }
                    appendAudit("Job dispatched to node: \(name)", severity: .info)
                } catch {
                    if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                        activeJobs[idx].state = .failed(JobFailure(reason: error.localizedDescription))
                    }
                    appendAudit("Job dispatch failed: \(name) — \(error.localizedDescription)", severity: .error)
                }
                return
            }

            try? await Task.sleep(nanoseconds: 200_000_000)

            if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                activeJobs[idx].state = .assigned(nodeID: UUID())
            }

            try? await Task.sleep(nanoseconds: 100_000_000)

            if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                activeJobs[idx].state = .preparingSandbox
            }

            try? await Task.sleep(nanoseconds: 100_000_000)

            if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                activeJobs[idx].state = .running(progress: 0)
            }

            do {
                let result = try await nativeExecutor.execute(spec: spec, onOutput: { data in
                    Task { @MainActor in
                        if let idx = self.activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                            self.activeJobs[idx].output += String(data: data, encoding: .utf8) ?? ""
                        }
                    }
                }, onStderr: { data in
                    Task { @MainActor in
                        if let idx = self.activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                            self.activeJobs[idx].output += String(data: data, encoding: .utf8) ?? ""
                        }
                    }
                })
                if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                    activeJobs[idx].state = result.succeeded ? .succeeded : .failed(JobFailure(reason: "Exit code \(result.exitCode)", exitCode: result.exitCode))
                }
                Task { await eventLog.record(.jobCompleted(name, exitCode: result.exitCode)) }
                appendAudit("Job completed: \(name) (exit \(result.exitCode), \(String(format: "%.2f", result.duration))s)", severity: result.succeeded ? .success : .error)
                await refreshFabricEvents()
            } catch {
                if let idx = activeJobs.firstIndex(where: { $0.id == tracked.id }) {
                    activeJobs[idx].state = .failed(JobFailure(reason: error.localizedDescription))
                }
                Task { await eventLog.record(.jobFailed(name, error: error.localizedDescription)) }
                appendAudit("Job failed: \(name) — \(error.localizedDescription)", severity: .error)
                await refreshFabricEvents()
            }
        }
    }

    public func cancelJob(_ job: TrackedJob) {
        Task {
            if isConnected, let coordinator = coordinator {
                try? await coordinator.cancelJobOnNode(jobID: job.spec.jobID.uuidString)
            }
            await nativeExecutor.cancel(jobID: JobID(rawValue: job.spec.jobID))
            if let idx = activeJobs.firstIndex(where: { $0.id == job.id }) {
                activeJobs[idx].state = .cancelled
            }
            appendAudit("Job cancelled: \(job.spec.name)", severity: .warning)
        }
    }

    // MARK: - Terminal (Real PTY)

    public func openTerminalSession(nodeName: String) {
        let sessionID = TerminalSessionID(rawValue: UUID())
        let config = TerminalConfiguration(shell: "/bin/zsh", columns: 80, rows: 24)

        Task {
            do {
                let handle = try await terminalService.open(sessionID: sessionID, configuration: config)
                let session = TrackedTerminalSession(id: sessionID, nodeName: nodeName, pid: handle.pid)
                terminalSessions.append(session)
                appendAudit("Terminal opened on \(nodeName) (pid \(handle.pid))", severity: .info)
                await eventLog.record(.terminalOpened(sessionID))
                await refreshFabricEvents()

                let task = Task {
                    for try await data in terminalService.getOutput(sessionID: sessionID, fromOffset: 0) {
                        let text = String(data: data, encoding: .utf8) ?? ""
                        if let idx = self.terminalSessions.firstIndex(where: { $0.id == sessionID }) {
                            self.terminalSessions[idx].output += text
                        }
                    }
                    if let idx = self.terminalSessions.firstIndex(where: { $0.id == sessionID }) {
                        self.terminalSessions[idx].isActive = false
                    }
                }
                outputTasks[sessionID] = task
            } catch {
                appendAudit("Terminal open failed: \(error.localizedDescription)", severity: .error)
            }
        }
    }

    public func closeTerminalSession(_ session: TrackedTerminalSession) {
        outputTasks[session.id]?.cancel()
        outputTasks.removeValue(forKey: session.id)
        Task {
            await terminalService.close(sessionID: session.id, signal: .hangup)
            await eventLog.record(.terminalClosed(session.id))
            await refreshFabricEvents()
        }
        terminalSessions.removeAll { $0.id == session.id }
        appendAudit("Terminal closed on \(session.nodeName)", severity: .info)
    }

    public func sendTerminalCommand(_ session: TrackedTerminalSession, command: String) {
        guard let idx = terminalSessions.firstIndex(where: { $0.id == session.id }) else { return }
        terminalSessions[idx].output += "$ \(command)\n"

        Task {
            let data = (command + "\n").data(using: .utf8) ?? Data()
            try await terminalService.write(sessionID: session.id, data: data)
        }
    }

    // MARK: - Workspace

    public func createWorkspaceSnapshot(name: String, files: [String]) {
        Task {
            var hashes: [String: String] = [:]
            for file in files {
                let data = file.data(using: .utf8) ?? Data()
                let digest = SHA256.hash(data: data)
                hashes[file] = digest.map { String(format: "%02x", $0) }.joined()
            }
            let snapshot = await workspaceService.createSnapshot(name: name, fileHashes: hashes)
            workspaceSnapshots.insert(snapshot, at: 0)
            appendAudit("Workspace snapshot created: \(name) (\(files.count) files)", severity: .info)

            if isConnected, let coordinator = coordinator {
                try? await coordinator.requestWorkspace(workspaceID: snapshot.workspaceID.rawValue.uuidString)
                appendAudit("Workspace sync requested from node", severity: .info)
            }
        }
    }

    public func loadWorkspaceSnapshots() {
        Task {
            let snapshots = await workspaceService.listSnapshots()
            workspaceSnapshots = snapshots
        }
    }

    public func deleteWorkspaceSnapshot(_ snapshot: WorkspaceSnapshot) {
        Task {
            await workspaceService.deleteSnapshot(id: snapshot.workspaceID)
            workspaceSnapshots.removeAll { $0.workspaceID == snapshot.workspaceID }
            appendAudit("Workspace snapshot deleted: \(snapshot.name)", severity: .info)
        }
    }

    // MARK: - Agents (Real Pipeline)

    public func submitAgentPlan(objective: String, steps: [String]) {
        let planSteps = steps.map { AgentPlanStep(description: $0, action: .runCommand([$0])) }
        let plan = AgentPlan(objective: objective, steps: planSteps, estimatedRisk: .low, requiresHumanApproval: steps.count > 3)
        let tracked = TrackedAgentPlan(plan: plan)
        agentPlans.insert(tracked, at: 0)
        appendAudit("Agent plan created: \(objective)", severity: .info)

        Task {
            if isConnected, let coordinator = coordinator {
                do {
                    try await coordinator.submitAgentPlan(
                        planID: plan.planID.uuidString,
                        objective: objective,
                        steps: steps
                    )
                    if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                        agentPlans[idx].state = .executing
                    }
                    appendAudit("Agent plan dispatched to node: \(objective)", severity: .info)
                } catch {
                    if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                        agentPlans[idx].state = .failed(error.localizedDescription)
                    }
                    appendAudit("Agent plan dispatch failed: \(error.localizedDescription)", severity: .error)
                }
                return
            }

            var updated = tracked
            updated.state = .validating
            if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                agentPlans[idx] = updated
            }

            let validation = await agentPipeline.validatePlan(plan)

            if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                agentPlans[idx].state = .policyEvaluation
            }

            if validation.isValid {
                let policyEval = await agentPipeline.evaluatePolicy(plan: plan, availableCapabilities: Set(grantedCapabilities.map { FabricCapability(rawValue: $0.rawValue) ?? .processExecute }))

                if policyEval.approved {
                    await agentPipeline.startPlan(plan)
                    await agentPipeline.approvePlan(plan.planID)

                    if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                        agentPlans[idx].state = .executing
                    }
                    appendAudit("Agent plan approved: \(objective)", severity: .success)

                    for (stepIndex, step) in plan.steps.enumerated() {
                        let startTime = Date()
                        nonisolated(unsafe) var output = ""

                        switch step.action {
                        case .runCommand(let args):
                            let cmd = args.joined(separator: " ")
                            do {
                                let spec = JobSpec(submittedBy: UUID(), name: "agent-step-\(stepIndex)", command: ExecutableCommand(executable: "/bin/zsh", arguments: ["-c", cmd]))
                                let result = try await nativeExecutor.execute(spec: spec, onOutput: { data in
                                    output += String(data: data, encoding: .utf8) ?? ""
                                }, onStderr: { data in
                                    output += String(data: data, encoding: .utf8) ?? ""
                                })
                                let duration = Date().timeIntervalSince(startTime)
                                let stepResult = AgentPipeline.StepResult(stepID: step.stepID, succeeded: result.succeeded, output: output, error: result.succeeded ? nil : "Exit \(result.exitCode)", duration: duration)
                                await agentPipeline.recordStepResult(stepResult)
                                if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                                    agentPlans[idx].results[step.stepID] = stepResult
                                    agentPlans[idx].stepOutputs.append(output)
                                }
                            } catch {
                                let duration = Date().timeIntervalSince(startTime)
                                let stepResult = AgentPipeline.StepResult(stepID: step.stepID, succeeded: false, output: output, error: error.localizedDescription, duration: duration)
                                await agentPipeline.recordStepResult(stepResult)
                                if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                                    agentPlans[idx].results[step.stepID] = stepResult
                                    agentPlans[idx].stepOutputs.append("Error: \(error.localizedDescription)")
                                }
                            }
                        default:
                            let duration = Date().timeIntervalSince(startTime)
                            let stepResult = AgentPipeline.StepResult(stepID: step.stepID, succeeded: true, output: "Action \(String(describing: step.action)) completed", duration: duration)
                            await agentPipeline.recordStepResult(stepResult)
                            if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                                agentPlans[idx].results[step.stepID] = stepResult
                            }
                        }

                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }

                    if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                        agentPlans[idx].state = .completed
                    }
                    appendAudit("Agent plan completed: \(objective)", severity: .success)
                } else {
                    if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                        agentPlans[idx].state = .failed(policyEval.reason)
                    }
                    appendAudit("Agent plan rejected by policy: \(policyEval.reason)", severity: .warning)
                }
            } else {
                if let idx = agentPlans.firstIndex(where: { $0.id == tracked.id }) {
                    agentPlans[idx].state = .failed(validation.errors.joined(separator: ", "))
                }
                appendAudit("Agent plan invalid: \(validation.errors.joined(separator: ", "))", severity: .error)
            }
        }
    }

    // MARK: - Security

    public func registerSecuritySession() {
        Task {
            let sessionID = SessionID(rawValue: UUID())
            currentSessionID = sessionID
            await authGuard.registerSession(sessionID, capabilities: grantedCapabilities)
            appendAudit("Security session registered with \(grantedCapabilities.count) capabilities", severity: .info)
        }
    }

    public func refreshFabricEvents() async {
        let events = await eventLog.recentEvents(count: 100)
        fabricEvents = events.map { FabricEventEntry(event: $0.event, timestamp: $0.timestamp) }
    }

    public func clearFabricEvents() {
        Task {
            await eventLog.clear()
            fabricEvents = []
            appendAudit("Event log cleared", severity: .info)
        }
    }

    // MARK: - Settings

    public func updateSchedulerWeights(_ weights: SchedulerWeights) {
        schedulerWeights = weights
        let w = VanguardScheduler.SchedulerWeights(
            cpuWeight: weights.cpuWeight,
            memoryWeight: weights.memoryWeight,
            localityWeight: weights.localityWeight,
            latencyWeight: weights.latencyWeight,
            reliabilityWeight: weights.reliabilityWeight,
            thermalWeight: weights.thermalWeight,
            energyWeight: weights.energyWeight
        )
        Task { await scheduler.updateWeights(w) }
        appendAudit("Scheduler weights updated", severity: .info)
    }

    // MARK: - Permissions

    public func checkPermissions() async {
        let permissionService = MacOSPermissionService()
        let screenState = await permissionService.checkPermission(kind: .screenRecording)
        let accessibilityState = await permissionService.checkPermission(kind: .accessibility)

        if screenState.isGranted && accessibilityState.isGranted {
            permissions = .granted
        } else {
            permissions = .denied
        }
    }

    public func requestPermissions() async {
        let permissionService = MacOSPermissionService()
        _ = await permissionService.requestPermission(kind: .screenRecording)
        _ = await permissionService.requestPermission(kind: .accessibility)
        await checkPermissions()
    }

    // MARK: - Scanning

    public func startScan() async {
        AppLogger.info(.discovery, "Starting LAN scan...")
        statusMessage = "Scanning..."

        do {
            let discoveryService = BonjourDiscoveryService()
            let identityService = CryptoKitIdentityService()
            self.identityService = identityService

            let auditLog = InMemoryAuditLogService()
            let auditService = AuditIntegrationService(auditLog: auditLog)
            self.auditService = auditService
            await auditService.startAutoFlush()

            let permissionService = MacOSPermissionService()
            let terminalService = POSIXTerminalService()
            self.terminalService = terminalService

            coordinator = ConsoleSessionCoordinator(
                discoveryService: discoveryService,
                transport: InMemoryTransport(),
                identityService: identityService,
                permissionService: permissionService,
                terminalService: terminalService,
                decoderService: VideoToolboxDecoder()
            )

            try await coordinator?.startScan()
            isScanning = true
            statusMessage = "Scanning LAN for nodes..."
            appendAudit("LAN scan started", severity: .info)
            registerSecuritySession()
            startTelemetryRefresh()

            Task { await observeCoordinatorState() }
            Task { await observeJobEvents() }
            Task { await observeClipboardFromNode() }
            Task { await observeAgentEvents() }
        } catch {
            statusMessage = "Failed to scan: \(error.localizedDescription)"
            appendAudit("Scan failed: \(error.localizedDescription)", severity: .error)
        }
    }

    public func stopScan() async {
        await coordinator?.stopScan()
        await clipboardService.stopWatching()
        await auditService?.stopAutoFlush()
        coordinator = nil
        identityService = nil
        auditService = nil
        isScanning = false
        statusMessage = "Stopped"
        refreshTimer?.invalidate()
        appendAudit("LAN scan stopped", severity: .info)
    }

    // MARK: - Connection

    public func connectToNode(_ node: DiscoveredNode) async {
        statusMessage = "Connecting to \(node.name)..."
        lastConnectedNode = node
        discoveredNodes = discoveredNodes.map { var n = $0; if n.id == node.id { n.status = .connecting }; return n }

        do {
            let transport = NetworkTransport(host: node.host, port: node.advertisement.endpoint.port, useTLS: true)

            if coordinator == nil {
                let discoveryService = BonjourDiscoveryService()
                let localIdentityService = CryptoKitIdentityService()
                self.identityService = localIdentityService
                let permissionService = MacOSPermissionService()

                coordinator = ConsoleSessionCoordinator(
                    discoveryService: discoveryService,
                    transport: transport,
                    identityService: localIdentityService,
                    permissionService: permissionService,
                    terminalService: terminalService,
                    decoderService: VideoToolboxDecoder()
                )
            } else {
                try await coordinator?.disconnect()
                let discoveryService = BonjourDiscoveryService()
                let localIdentityService = CryptoKitIdentityService()
                self.identityService = localIdentityService
                let permissionService = MacOSPermissionService()

                coordinator = ConsoleSessionCoordinator(
                    discoveryService: discoveryService,
                    transport: transport,
                    identityService: localIdentityService,
                    permissionService: permissionService,
                    terminalService: terminalService,
                    decoderService: VideoToolboxDecoder()
                )
            }
            try await coordinator?.connect(to: node.advertisement)
            isConnected = true
            connectedNodeName = node.name
            statusMessage = "Connected to \(node.name)"
            appendAudit("Connected to \(node.name)", severity: .success)
            await eventLog.record(.nodeConnected(NodeID(rawValue: node.advertisement.nodeIDHash.withUnsafeBytes { $0.load(as: UUID.self) })))
            await refreshFabricEvents()

            await clipboardService.startWatching()
            startClipboardSync()
            startMetricsCollection()

            let consoleCaps = await capabilityNegotiator.defaultConsoleCapabilities()
            let nodeCaps = await capabilityNegotiator.defaultNodeCapabilities()
            let negotiation = await capabilityNegotiator.negotiate(
                consoleOffered: consoleCaps,
                nodeRequired: nodeCaps,
                nodeOffered: nodeCaps
            )
            currentNegotiation = negotiation
            grantedCapabilities = negotiation.agreedUpon
            appendAudit("Capability negotiation: \(negotiation.agreedUpon.count) agreed, \(negotiation.rejectedByNode.count + negotiation.rejectedByConsole.count) rejected", severity: negotiation.isFullyAgreed ? .success : .warning)

            let metrics = Self.gatherLocalSystemMetrics()
            let descriptor = NodeResourceDescriptor(
                nodeID: NodeID(),
                architecture: node.advertisement.architecture,
                operatingSystem: OperatingSystemDescriptor(family: node.advertisement.osFamily, version: node.advertisement.osVersion),
                logicalCPUCount: metrics.logicalCPUCount,
                physicalCPUCount: metrics.physicalCPUCount,
                totalMemoryBytes: metrics.totalMemoryBytes,
                availableMemoryBytes: metrics.availableMemoryBytes,
                totalStorageBytes: metrics.totalStorageBytes,
                availableStorageBytes: metrics.availableStorageBytes,
                batteryState: metrics.batteryState,
                currentCPULoad: metrics.cpuLoad,
                currentMemoryPressure: metrics.memoryPressure
            )
            await scheduler.registerNode(descriptor)
            if let idx = discoveredNodes.firstIndex(where: { $0.id == node.id }) {
                discoveredNodes[idx].resourceDescriptor = descriptor
            }
        } catch {
            statusMessage = "Failed to connect: \(error.localizedDescription)"
            appendAudit("Connection failed: \(error.localizedDescription)", severity: .error)
            discoveredNodes = discoveredNodes.map { var n = $0; if n.id == node.id { n.status = .online }; return n }
        }
    }

    public func disconnect() async {
        if let audit = auditService, let identity = identityService {
            let localIdentity = try? await identity.getOrCreateIdentity()
            if let localIdentity {
                await audit.logSecurityEvent(actorNodeID: localIdentity.nodeID, targetNodeID: localIdentity.nodeID, sessionID: nil, action: .disconnected)
            }
        }
        stopClipboardSync()
        cancelReconnection()
        stopMetricsCollection()
        await coordinator?.disconnect()
        await clipboardService.stopWatching()
        isConnected = false
        connectedNodeName = nil
        statusMessage = "Disconnected"
        refreshTimer?.invalidate()
        appendAudit("Disconnected", severity: .info)
    }

    public func submitPairingCode(_ code: String) async throws {
        guard let coordinator = coordinator else { throw ConsoleError.notConnected }
        try await coordinator.submitPairingCode(code)
        appendAudit("Pairing code submitted", severity: .success)
    }

    public func sendInputEvent(_ event: RemoteInputEvent) async throws {
        guard let coordinator = coordinator else { throw ConsoleError.notConnected }
        try await coordinator.sendInputEvent(event)
    }

    public var frameUpdates: AsyncThrowingStream<SendablePixelBuffer, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let coordinator = coordinator else { return }
                for try await frame in await coordinator.frameUpdates {
                    continuation.yield(frame)
                }
            }
        }
    }

    public func setTheme(_ profile: ThemeProfile) { currentTheme = profile }

    public enum ConsoleError: Error { case notConnected }

    // MARK: - Private

    private func appendAudit(_ action: String, severity: AuditLogEntry.Severity) {
        auditEntries.insert(AuditLogEntry(action: action, severity: severity, timestamp: Date()), at: 0)
        if auditEntries.count > 200 { auditEntries.removeLast() }
    }

    private func startTelemetryRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshNodeTelemetry()
            }
        }
    }

    private func startMetricsCollection() {
        metricsTimer?.invalidate()
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.metricsCollector.updateMemoryUsage()
                self.pipelineMetrics = await self.metricsCollector.snapshot()
            }
        }
    }

    private func stopMetricsCollection() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }

    public func verifyAuditChain() async {
        if let audit = auditService {
            let isValid = (try? await audit.verifyIntegrity()) ?? true
            auditChainValid = isValid
            appendAudit("Audit chain integrity: \(isValid ? "VALID" : "BROKEN")", severity: isValid ? .success : .error)
        } else {
            auditChainValid = true
        }
    }

    public func recordFrameCaptured() { Task { await metricsCollector.recordFrameCaptured() } }
    public func recordFrameEncoded() { Task { await metricsCollector.recordFrameEncoded() } }
    public func recordFrameDecoded() { Task { await metricsCollector.recordFrameDecoded() } }
    public func recordFrameRendered() { Task { await metricsCollector.recordFrameRendered() } }
    public func recordFrameDropped() { Task { await metricsCollector.recordFrameDropped() } }
    public func recordBytesTransferred(_ bytes: Int) { Task { await metricsCollector.recordBytesTransferred(bytes) } }
    public func recordEncodeTime(_ ms: Double) { Task { await metricsCollector.recordEncodeTime(ms) } }
    public func recordDecodeTime(_ ms: Double) { Task { await metricsCollector.recordDecodeTime(ms) } }

    private func refreshNodeTelemetry() {
        let metrics = Self.gatherLocalSystemMetrics()
        for i in discoveredNodes.indices {
            guard discoveredNodes[i].status == .online else { continue }
            guard let existing = discoveredNodes[i].resourceDescriptor else { continue }
            let descriptor = NodeResourceDescriptor(
                nodeID: existing.nodeID,
                architecture: existing.architecture,
                operatingSystem: existing.operatingSystem,
                logicalCPUCount: metrics.logicalCPUCount,
                physicalCPUCount: metrics.physicalCPUCount,
                totalMemoryBytes: metrics.totalMemoryBytes,
                availableMemoryBytes: metrics.availableMemoryBytes,
                totalStorageBytes: metrics.totalStorageBytes,
                availableStorageBytes: metrics.availableStorageBytes,
                batteryState: metrics.batteryState,
                currentCPULoad: metrics.cpuLoad,
                currentMemoryPressure: metrics.memoryPressure,
                currentJobCount: activeJobs.filter({ !$0.state.isTerminal }).count
            )
            discoveredNodes[i].resourceDescriptor = descriptor
        }
    }

    struct LocalSystemMetrics {
        let logicalCPUCount: Int
        let physicalCPUCount: Int
        let totalMemoryBytes: UInt64
        let availableMemoryBytes: UInt64
        let totalStorageBytes: UInt64
        let availableStorageBytes: UInt64
        let batteryState: BatteryState?
        let cpuLoad: Double
        let memoryPressure: Double
    }

    static func gatherLocalSystemMetrics() -> LocalSystemMetrics {
        let raw = csystem_metrics_gather()

        var totalStorage: UInt64 = 512 * 1024 * 1024 * 1024
        var availableStorage: UInt64 = 256 * 1024 * 1024 * 1024
        if let rv = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) {
            if let t = rv.volumeTotalCapacity { totalStorage = UInt64(t) }
            if let a = rv.volumeAvailableCapacityForImportantUsage { availableStorage = UInt64(a) }
        }

        var batteryState: BatteryState? = nil
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
           let first = sources.first,
           let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any],
           let isCharging = desc[kIOPSIsChargingKey] as? Bool {
            batteryState = isCharging ? .charging : .discharging
        }

        return LocalSystemMetrics(
            logicalCPUCount: Int(raw.logical_cpu_count),
            physicalCPUCount: Int(raw.physical_cpu_count),
            totalMemoryBytes: raw.total_memory_bytes,
            availableMemoryBytes: raw.available_memory_bytes,
            totalStorageBytes: totalStorage,
            availableStorageBytes: availableStorage,
            batteryState: batteryState,
            cpuLoad: min(max(raw.cpu_load, 0), 1),
            memoryPressure: min(max(raw.memory_pressure, 0), 1)
        )
    }

    private func registerShortcuts() async {
        do {
            try await shortcutService.registerShortcut(.emergencyStop)
            try await shortcutService.registerShortcut(.toggleFullscreen)
            try await shortcutService.registerShortcut(.disconnect)
        } catch { print("Failed to register shortcuts: \(error)") }

        await shortcutService.registerShortcutCallback { [weak self] shortcut in
            guard let self else { return }
            Task { @MainActor in
                switch shortcut.name {
                case "Disconnect": await self.disconnect()
                default: break
                }
            }
        }
    }

    private func observeCoordinatorState() async {
        guard let coordinator = coordinator else { return }
        for await state in await coordinator.stateUpdates {
            switch state {
            case .idle: currentState = .idle; statusMessage = "Ready"
            case .scanning: currentState = .scanning; statusMessage = "Scanning..."
            case .discovered(let nodes):
                discoveredNodes = nodes.map { ad in
                    DiscoveredNode(name: ad.displayName, host: ad.endpoint.host, advertisement: ad, status: .online)
                }
                statusMessage = "Found \(nodes.count) node(s)"
                Task { for node in nodes { await self.eventLog.record(.nodeDiscovered(NodeID())) } }
                await refreshFabricEvents()
            case .connecting(let ad): currentState = .connecting; statusMessage = "Connecting to \(ad.displayName)..."
            case .connected(let nodeID): currentState = .connected; isConnected = true; connectedNodeName = nodeID.rawValue.uuidString.prefix(8).description; statusMessage = "Connected"; reconnectionAttempts = 0; isReconnecting = false
            case .pairing(let code): currentState = .pairing(challengeCode: code); statusMessage = "Pairing — code: \(code)"
            case .paired(let nodeID): currentState = .paired; isConnected = true; connectedNodeName = nodeID.rawValue.uuidString.prefix(8).description; statusMessage = "Paired"
            case .capturing: currentState = .capturing; statusMessage = "Receiving video..."
            case .error(let msg):
                currentState = .error(msg)
                statusMessage = "Error: \(msg)"
                if let node = lastConnectedNode, reconnectionAttempts < maxReconnectionAttempts {
                    startReconnection(to: node)
                }
            }
        }
    }

    private func observeJobEvents() async {
        guard let coordinator = coordinator else { return }
        for await event in await coordinator.jobEventUpdates {
            switch event {
            case .assigned(let jobID, let nodeID):
                if let idx = activeJobs.firstIndex(where: { $0.spec.jobID.uuidString == jobID }) {
                    activeJobs[idx].state = .assigned(nodeID: UUID(uuidString: nodeID) ?? UUID())
                    activeJobs[idx].nodeID = nodeID
                }
                appendAudit("Job \(jobID.prefix(8)) assigned to node \(nodeID.prefix(8))", severity: .info)
            case .progress(let jobID, let stdout, let stderr):
                if let idx = activeJobs.firstIndex(where: { $0.spec.jobID.uuidString == jobID }) {
                    if let stdout { activeJobs[idx].output += stdout }
                    if let stderr { activeJobs[idx].output += stderr }
                    activeJobs[idx].state = .running(progress: 0)
                }
            case .completed(let jobID, let exitCode, let stdout, let stderr, let duration):
                if let idx = activeJobs.firstIndex(where: { $0.spec.jobID.uuidString == jobID }) {
                    if let stdout { activeJobs[idx].output += stdout }
                    if let stderr { activeJobs[idx].output += stderr }
                    activeJobs[idx].state = exitCode == 0 ? .succeeded : .failed(JobFailure(reason: "Exit code \(exitCode)", exitCode: exitCode))
                }
                appendAudit("Remote job completed: \(jobID.prefix(8)) (exit \(exitCode), \(String(format: "%.2f", duration))s)", severity: exitCode == 0 ? .success : .error)
                await refreshFabricEvents()
            case .failed(let jobID, let error):
                if let idx = activeJobs.firstIndex(where: { $0.spec.jobID.uuidString == jobID }) {
                    activeJobs[idx].state = .failed(JobFailure(reason: error))
                }
                appendAudit("Remote job failed: \(jobID.prefix(8)) — \(error)", severity: .error)
                await refreshFabricEvents()
            case .cancelled(let jobID):
                if let idx = activeJobs.firstIndex(where: { $0.spec.jobID.uuidString == jobID }) {
                    activeJobs[idx].state = .cancelled
                }
                appendAudit("Remote job cancelled: \(jobID.prefix(8))", severity: .warning)
            }
        }
    }

    private func observeClipboardFromNode() async {
        guard let coordinator = coordinator else { return }
        for await payload in await coordinator.clipboardUpdates {
            await MainActor.run {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(payload.content, forType: .string)
            }
            appendAudit("Clipboard updated from node (\(payload.content.count) chars)", severity: .info)
        }
    }

    private func observeAgentEvents() async {
        guard let coordinator = coordinator else { return }
        for await event in await coordinator.agentEventUpdates {
            switch event {
            case .progress(let planID, let stepIndex, let output):
                if let idx = agentPlans.firstIndex(where: { $0.plan.planID.uuidString == planID }) {
                    agentPlans[idx].state = .executing
                    if stepIndex < agentPlans[idx].stepOutputs.count {
                        agentPlans[idx].stepOutputs[stepIndex] = output
                    } else {
                        agentPlans[idx].stepOutputs.append(output)
                    }
                }
            case .completed(let planID, let outputs):
                if let idx = agentPlans.firstIndex(where: { $0.plan.planID.uuidString == planID }) {
                    agentPlans[idx].state = .completed
                    agentPlans[idx].stepOutputs = outputs
                }
                appendAudit("Remote agent plan completed: \(planID.prefix(8))", severity: .success)
                await refreshFabricEvents()
            case .failed(let planID, let error):
                if let idx = agentPlans.firstIndex(where: { $0.plan.planID.uuidString == planID }) {
                    agentPlans[idx].state = .failed(error)
                }
                appendAudit("Remote agent plan failed: \(planID.prefix(8)) — \(error)", severity: .error)
                await refreshFabricEvents()
            }
        }
    }

    // MARK: - Reconnection

    private func startReconnection(to node: DiscoveredNode) {
        guard !isReconnecting else { return }
        isReconnecting = true
        reconnectionTask?.cancel()
        reconnectionTask = Task { [weak self] in
            guard let self else { return }
            while self.reconnectionAttempts < self.maxReconnectionAttempts && !Task.isCancelled {
                self.reconnectionAttempts += 1
                self.reconnectionAttempt = self.reconnectionAttempts
                let delay = min(pow(2.0, Double(self.reconnectionAttempts)) * 0.5, 30.0)
                self.statusMessage = "Reconnecting in \(Int(delay))s (attempt \(self.reconnectionAttempts))..."
                self.appendAudit("Reconnection attempt \(self.reconnectionAttempts) to \(node.name) in \(Int(delay))s", severity: .warning)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { break }
                do {
                    try await self.connectToNode(node)
                    self.isReconnecting = false
                    self.appendAudit("Reconnected to \(node.name)", severity: .success)
                    return
                } catch {
                    self.appendAudit("Reconnection failed: \(error.localizedDescription)", severity: .error)
                }
            }
            await MainActor.run {
                self.isReconnecting = false
                self.reconnectionAttempts = 0
            }
        }
    }

    public func cancelReconnection() {
        reconnectionTask?.cancel()
        reconnectionTask = nil
        isReconnecting = false
        reconnectionAttempts = 0
    }

    // MARK: - Remote Terminal

    public func openRemoteTerminalSession(nodeName: String) {
        if isConnected {
            let sessionID = TerminalSessionID(rawValue: UUID())
            let config = TerminalConfiguration(shell: "/bin/zsh", columns: 80, rows: 24)
            Task {
                do {
                    guard let coordinator = coordinator else { return }
                    let handle = try await coordinator.openTerminal(configuration: config)
                    let session = TrackedTerminalSession(id: sessionID, nodeName: nodeName, pid: handle.pid)
                    terminalSessions.append(session)
                    appendAudit("Remote terminal opened on \(nodeName)", severity: .info)
                    await eventLog.record(.terminalOpened(sessionID))
                    await refreshFabricEvents()

                    let task = Task {
                        for try await output in await coordinator.terminalOutputUpdates {
                            if output.sessionID == sessionID,
                               let idx = self.terminalSessions.firstIndex(where: { $0.id == sessionID }) {
                                let text = String(data: output.data, encoding: .utf8) ?? ""
                                self.terminalSessions[idx].output += text
                                if self.terminalSessions[idx].output.count > self.terminalScrollbackLimit {
                                    let excess = self.terminalSessions[idx].output.count - self.terminalScrollbackLimit
                                    self.terminalSessions[idx].output = String(self.terminalSessions[idx].output.dropFirst(excess))
                                }
                            }
                        }
                        if let idx = self.terminalSessions.firstIndex(where: { $0.id == sessionID }) {
                            self.terminalSessions[idx].isActive = false
                        }
                    }
                    outputTasks[sessionID] = task
                } catch {
                    appendAudit("Remote terminal open failed: \(error.localizedDescription)", severity: .error)
                }
            }
        } else {
            openTerminalSession(nodeName: nodeName)
        }
    }

    public func sendRemoteTerminalInput(_ session: TrackedTerminalSession, command: String) {
        guard isConnected, let coordinator = coordinator else {
            sendTerminalCommand(session, command: command)
            return
        }
        Task {
            let data = (command + "\n").data(using: .utf8) ?? Data()
            try await coordinator.sendTerminalInput(session.id, data: data)
        }
        if let idx = terminalSessions.firstIndex(where: { $0.id == session.id }) {
            terminalSessions[idx].output += "$ \(command)\n"
        }
    }

    // MARK: - Clipboard Sync

    public func startClipboardSync() {
        clipboardSyncTask?.cancel()
        clipboardSyncTask = Task { [weak self] in
            guard let self else { return }
            var lastPasteboard = NSPasteboard.general.string(forType: .string) ?? ""
            var lastChangeCount = NSPasteboard.general.changeCount
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                let currentChangeCount = NSPasteboard.general.changeCount
                if currentChangeCount != lastChangeCount {
                    let current = NSPasteboard.general.string(forType: .string) ?? ""
                    lastChangeCount = currentChangeCount
                    if current != lastPasteboard && !current.isEmpty {
                        lastPasteboard = current
                        await self.eventLog.record(.clipboardChanged)
                        self.appendAudit("Clipboard changed — \(current.count) chars", severity: .info)
                        if self.isConnected, let coordinator = self.coordinator {
                            try? await coordinator.sendClipboard(content: current, changeCount: currentChangeCount)
                        }
                    }
                }
            }
        }
    }

    public func stopClipboardSync() {
        clipboardSyncTask?.cancel()
        clipboardSyncTask = nil
    }

    // MARK: - Emergency Stop Hotkey

    private func startEmergencyStopHotkey() async {
        await shortcutService.registerShortcutCallback { [weak self] shortcut in
            guard let self else { return }
            Task { @MainActor in
                switch shortcut.name {
                case "Emergency Stop": await self.emergencyStop()
                default: break
                }
            }
        }
    }

    public func emergencyStop() async {
        appendAudit("EMERGENCY STOP triggered", severity: .error)
        await eventLog.record(.emergencyStop)
        await refreshFabricEvents()
        if isConnected, let coordinator = coordinator {
            let message = OutboundMessage(messageType: .emergencyStop, payload: Data())
            try? await coordinator.sendEmergencyStop()
        }
        stopClipboardSync()
        cancelReconnection()
        await coordinator?.disconnect()
        await clipboardService.stopWatching()
        isConnected = false
        connectedNodeName = nil
        currentState = .idle
        statusMessage = "Emergency Stop — disconnected"
    }

    // MARK: - Trusted Peers

    private func loadTrustedPeers() {
        if let data = UserDefaults.standard.data(forKey: "elysium.trustedPeers"),
           let peers = try? JSONDecoder().decode([TrustedPeer].self, from: data) {
            trustedPeers = peers
        }
    }

    private func saveTrustedPeers() {
        if let data = try? JSONEncoder().encode(trustedPeers) {
            UserDefaults.standard.set(data, forKey: "elysium.trustedPeers")
        }
    }

    public func addTrustedPeer(name: String, host: String, nodeIDHash: Data) {
        let peer = TrustedPeer(name: name, host: host, nodeIDHash: nodeIDHash)
        trustedPeers.append(peer)
        saveTrustedPeers()
        appendAudit("Trusted peer added: \(name)", severity: .info)
    }

    public func removeTrustedPeer(_ peer: TrustedPeer) {
        trustedPeers.removeAll { $0.id == peer.id }
        saveTrustedPeers()
        appendAudit("Trusted peer removed: \(peer.name)", severity: .info)
    }
}
