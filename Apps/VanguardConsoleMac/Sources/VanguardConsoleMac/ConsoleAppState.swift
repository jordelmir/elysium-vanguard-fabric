import SwiftUI
import Combine
import CoreVideo
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

    private var coordinator: ConsoleSessionCoordinator?
    private let clipboardService = ClipboardService()
    private var identityService: CryptoKitIdentityService? = nil
    private var auditService: AuditIntegrationService?
    private let shortcutService = KeyboardShortcutService()

    public struct DiscoveredNode: Identifiable, Hashable {
        public let id = UUID()
        public let name: String
        public let host: String
        public let advertisement: NodeAdvertisement
        public var status: Status

        public enum Status: Hashable {
            case online
            case offline
            case connecting
        }

        public static func == (lhs: DiscoveredNode, rhs: DiscoveredNode) -> Bool {
            lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    public init() {
        Task { await registerShortcuts() }
    }

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
            AppLogger.info(.discovery, "LAN scan started")

            Task { await observeCoordinatorState() }
        } catch {
            statusMessage = "Failed to scan: \(error.localizedDescription)"
            AppLogger.error(.discovery, "Failed to start scan: \(error.localizedDescription)")
        }
    }

    public func stopScan() async {
        AppLogger.info(.discovery, "Stopping LAN scan")
        await coordinator?.stopScan()
        await clipboardService.stopWatching()
        await auditService?.stopAutoFlush()
        coordinator = nil
        identityService = nil
        auditService = nil
        isScanning = false
        statusMessage = "Stopped"
        AppLogger.info(.discovery, "LAN scan stopped")
    }

    public func connectToNode(_ node: DiscoveredNode) async {
        statusMessage = "Connecting to \(node.name)..."
        AppLogger.info(.session, "Connecting to node: \(node.name) at \(node.host)")
        discoveredNodes = discoveredNodes.map {
            var n = $0
            if n.id == node.id { n.status = .connecting }
            return n
        }

        do {
            let transport = NetworkTransport(
                host: node.host,
                port: node.advertisement.endpoint.port,
                useTLS: true
            )

            if coordinator == nil {
                let discoveryService = BonjourDiscoveryService()
                let localIdentityService = CryptoKitIdentityService()
                self.identityService = localIdentityService
                let permissionService = MacOSPermissionService()
                let terminalService = POSIXTerminalService()

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
                let terminalService = POSIXTerminalService()

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
            AppLogger.info(.session, "Connected to \(node.name)")

            await clipboardService.startWatching()
            AppLogger.info(.clipboard, "Clipboard sync started")

            if let audit = auditService, let identity = identityService {
                let localIdentity = try await identity.getOrCreateIdentity()
                await audit.logSecurityEvent(
                    actorNodeID: localIdentity.nodeID,
                    targetNodeID: localIdentity.nodeID,
                    sessionID: nil,
                    action: .connected
                )
            }
        } catch {
            statusMessage = "Failed to connect: \(error.localizedDescription)"
            AppLogger.error(.session, "Failed to connect to \(node.name): \(error.localizedDescription)")
            discoveredNodes = discoveredNodes.map {
                var n = $0
                if n.id == node.id { n.status = .online }
                return n
            }
        }
    }

    public func disconnect() async {
        AppLogger.info(.session, "Disconnecting")
        if let audit = auditService, let identity = identityService {
            let localIdentity = try? await identity.getOrCreateIdentity()
            if let localIdentity {
                await audit.logSecurityEvent(
                    actorNodeID: localIdentity.nodeID,
                    targetNodeID: localIdentity.nodeID,
                    sessionID: nil,
                    action: .disconnected
                )
            }
        }
        await coordinator?.disconnect()
        await clipboardService.stopWatching()
        isConnected = false
        connectedNodeName = nil
        statusMessage = "Disconnected"
        AppLogger.info(.session, "Disconnected")
    }

    public func submitPairingCode(_ code: String) async throws {
        guard let coordinator = coordinator else { throw ConsoleError.notConnected }
        try await coordinator.submitPairingCode(code)
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

    public func openTerminal(configuration: TerminalConfiguration) async throws -> TerminalSessionHandle {
        guard let coordinator = coordinator else { throw ConsoleError.notConnected }
        return try await coordinator.openTerminal(configuration: configuration)
    }

    public func sendTerminalInput(_ sessionID: TerminalSessionID, data: Data) async throws {
        guard let coordinator = coordinator else { throw ConsoleError.notConnected }
        try await coordinator.sendTerminalInput(sessionID, data: data)
    }

    public func closeTerminal(_ sessionID: TerminalSessionID) async throws {
        guard let coordinator = coordinator else { throw ConsoleError.notConnected }
        try await coordinator.closeTerminal(sessionID)
    }

    public var terminalOutputUpdates: AsyncStream<TerminalOutputPayload> {
        AsyncStream { continuation in
            Task {
                guard let coordinator = coordinator else { return }
                for await output in await coordinator.terminalOutputUpdates {
                    continuation.yield(output)
                }
            }
        }
    }

    public func setTheme(_ profile: ThemeProfile) {
        currentTheme = profile
    }

    public enum ConsoleError: Error {
        case notConnected
    }

    private func registerShortcuts() async {
        do {
            try await shortcutService.registerShortcut(.emergencyStop)
            try await shortcutService.registerShortcut(.toggleFullscreen)
            try await shortcutService.registerShortcut(.newTab)
            try await shortcutService.registerShortcut(.disconnect)
        } catch {
            print("Failed to register shortcuts: \(error)")
        }

        await shortcutService.registerShortcutCallback { [weak self] shortcut in
            guard let self else { return }
            Task { @MainActor in
                switch shortcut.name {
                case "Emergency Stop":
                    await self.disconnect()
                case "Disconnect":
                    await self.disconnect()
                default:
                    break
                }
            }
        }
    }

    private func observeCoordinatorState() async {
        guard let coordinator = coordinator else { return }
        for await state in await coordinator.stateUpdates {
            switch state {
            case .idle:
                currentState = .idle
                statusMessage = "Ready"
            case .scanning:
                currentState = .scanning
                statusMessage = "Scanning..."
            case .discovered(let nodes):
                discoveredNodes = nodes.map { ad in
                    DiscoveredNode(
                        name: ad.displayName,
                        host: ad.endpoint.host,
                        advertisement: ad,
                        status: .online
                    )
                }
                statusMessage = "Found \(nodes.count) node(s)"
            case .connecting(let ad):
                currentState = .connecting
                statusMessage = "Connecting to \(ad.displayName)..."
            case .connected(let nodeID):
                currentState = .connected
                isConnected = true
                connectedNodeName = nodeID.rawValue.uuidString.prefix(8).description
                statusMessage = "Connected"
            case .pairing(let code):
                currentState = .pairing(challengeCode: code)
                statusMessage = "Pairing — code: \(code)"
            case .paired(let nodeID):
                currentState = .paired
                isConnected = true
                connectedNodeName = nodeID.rawValue.uuidString.prefix(8).description
                statusMessage = "Paired"
            case .capturing:
                currentState = .capturing
                statusMessage = "Receiving video..."
            case .error(let msg):
                currentState = .error(msg)
                statusMessage = "Error: \(msg)"
            }
        }
    }
}
