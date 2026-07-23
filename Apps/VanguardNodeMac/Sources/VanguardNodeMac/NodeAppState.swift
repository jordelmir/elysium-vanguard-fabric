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

@MainActor
public final class NodeAppState: ObservableObject {
    @Published public var isRunning = false
    @Published public var nodeName = Host.current().localizedName ?? "Unknown Node"
    @Published public var permissions: PermissionStatus = .checking
    @Published public var connectedConsole: String?
    @Published public var statusMessage = "Stopped"
    @Published public var pendingPairingRequest: PairingRequest?

    private var coordinator: NodeSessionCoordinator?

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
            return
        }

        do {
            let discoveryService = BonjourDiscoveryService()
            let transport = NetworkTransport(host: "0.0.0.0", port: 49494, useTLS: false)
            let identityService = CryptoKitIdentityService()
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

            Task { await observeCoordinatorState() }
        } catch {
            statusMessage = "Failed to start: \(error.localizedDescription)"
        }
    }

    public func stopNode() async {
        await coordinator?.stop()
        coordinator = nil
        isRunning = false
        connectedConsole = nil
        statusMessage = "Stopped"
    }

    public func approvePairing() async {
        guard let request = pendingPairingRequest else { return }
        do {
            try await coordinator?.approvePairing()
            pendingPairingRequest = nil
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
}
