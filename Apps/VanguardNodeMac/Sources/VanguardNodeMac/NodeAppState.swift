import SwiftUI
import Combine
import VanguardDomain
import VanguardProtocol
import VanguardDiscovery
import VanguardTransport
import VanguardIdentity
import VanguardPermissions
import VanguardCapture
import VanguardVideo
import VanguardInput
import VanguardTerminal
import VanguardSession
import VanguardClipboard
import VanguardSecurity
import VanguardAudit
import VanguardTelemetry
import VanguardUI

@MainActor
public final class NodeAppState: ObservableObject {
    @Published public var isRunning = false
    @Published public var nodeName = Host.current().localizedName ?? "Unknown Node"
    @Published public var permissions: PermissionStatus = .checking
    @Published public var connectedConsole: String?
    @Published public var statusMessage = "Stopped"
    @Published public var pendingPairingRequest: PairingRequest?
    @Published public var currentTheme: ThemeProfile = .balanced
    @Published public var pipelineStats: PipelineStats?

    private var coordinator: NodeSessionCoordinator?
    private let clipboardService = ClipboardService()
    private var identityService: CryptoKitIdentityService?
    private var auditService: AuditIntegrationService?
    private var telemetryTask: Task<Void, Never>?

    public struct PairingRequest: Identifiable, Equatable {
        public let id = UUID()
        public let consoleID: String
        public let challengeCode: String
        public let timestamp: Date

        public static func == (lhs: PairingRequest, rhs: PairingRequest) -> Bool {
            lhs.id == rhs.id
        }
    }

    public enum PermissionStatus: Equatable {
        case checking
        case authorized
        case denied
    }

    public init() {
        Task { @MainActor in
            await checkPermissions()
        }
    }

    public func checkPermissions() async {
        let permissionService = MacOSPermissionService()
        let screenState = await permissionService.checkPermission(kind: .screenRecording)
        let accessibilityState = await permissionService.checkPermission(kind: .accessibility)

        if screenState.isGranted && accessibilityState.isGranted {
            permissions = .authorized
        } else {
            permissions = .denied
        }
    }

    public func startNode() async {
        guard permissions == .authorized else {
            statusMessage = "Missing permissions"
            AppLogger.error(.permissions, "Cannot start node: permissions not authorized")
            return
        }

        AppLogger.info(.node, "Starting node...")
        statusMessage = "Starting..."

        guard #available(macOS 12.3, *) else {
            statusMessage = "Requires macOS 12.3+"
            return
        }

        do {
            let discoveryService = BonjourDiscoveryService()
            let identityService = CryptoKitIdentityService()
            self.identityService = identityService

            let auditLog = InMemoryAuditLogService()
            let auditService = AuditIntegrationService(auditLog: auditLog)
            self.auditService = auditService
            await auditService.startAutoFlush()

            let transport = NetworkTransport(host: "0.0.0.0", port: 49494, useTLS: true)
            let permissionService = MacOSPermissionService()
            let captureService = ScreenCaptureKitCaptureService()
            let encoderService = VideoToolboxEncoder()
            let inputService = CGEventInputDispatchService()
            let terminalService = POSIXTerminalService()

            coordinator = NodeSessionCoordinator(
                discoveryService: discoveryService,
                transport: transport,
                identityService: identityService,
                permissionService: permissionService,
                captureService: captureService,
                encoderService: encoderService,
                inputService: inputService,
                terminalService: terminalService
            )

            try await coordinator?.start()
            isRunning = true
            statusMessage = "Advertising on LAN..."
            AppLogger.info(.node, "Node started successfully")

            await clipboardService.startWatching()
            AppLogger.info(.clipboard, "Clipboard watching started")

            Task { await observeCoordinatorState() }
            startTelemetryPolling()
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
            AppLogger.error(.node, "Failed to start node: \(error.localizedDescription)")
        }
    }

    public func stopNode() async {
        AppLogger.info(.node, "Stopping node...")
        await coordinator?.stop()
        await clipboardService.stopWatching()
        await auditService?.stopAutoFlush()
        telemetryTask?.cancel()
        telemetryTask = nil
        coordinator = nil
        identityService = nil
        auditService = nil
        isRunning = false
        connectedConsole = nil
        pipelineStats = nil
        statusMessage = "Stopped"
        AppLogger.info(.node, "Node stopped")
    }

    public func approvePairing() async {
        guard let request = pendingPairingRequest else { return }
        do {
            try await coordinator?.approvePairing()
            pendingPairingRequest = nil
            if let audit = auditService, let identity = identityService {
                let localIdentity = try await identity.getOrCreateIdentity()
                await audit.logSecurityEvent(
                    actorNodeID: localIdentity.nodeID,
                    targetNodeID: localIdentity.nodeID,
                    sessionID: nil,
                    action: .pairingCompleted
                )
            }
        } catch {
            statusMessage = "Pairing failed: \(error.localizedDescription)"
        }
    }

    private func observeCoordinatorState() async {
        guard let coordinator = coordinator else { return }
        for await state in await coordinator.stateUpdates {
            switch state {
            case .idle:
                statusMessage = "Idle"
            case .advertising:
                statusMessage = "Advertising on LAN..."
            case .pairing(let code):
                pendingPairingRequest = PairingRequest(
                    consoleID: "Console",
                    challengeCode: code,
                    timestamp: Date()
                )
                statusMessage = "Pairing — code: \(code)"
            case .codeValidated(let nodeID):
                connectedConsole = nodeID.rawValue.uuidString.prefix(8).description
                statusMessage = "Code validated — ready to approve"
            case .connected(let nodeID):
                connectedConsole = nodeID.rawValue.uuidString.prefix(8).description
                statusMessage = "Connected"
                pendingPairingRequest = nil
            case .capturing:
                statusMessage = "Capturing screen..."
            case .error(let msg):
                statusMessage = "Error: \(msg)"
            }
        }
    }

    private func startTelemetryPolling() {
        telemetryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refreshTelemetry()
            }
        }
    }

    private func refreshTelemetry() async {
        guard let stats = await coordinator?.pipelineStats else { return }
        pipelineStats = stats
    }
}
