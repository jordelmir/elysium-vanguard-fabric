import Foundation
import VanguardDomain
import VanguardProtocol
import VanguardTransport
import VanguardDiscovery
import VanguardIdentity
import VanguardPermissions
import VanguardCapture
import VanguardVideo
import VanguardInput
import VanguardTerminal

// MARK: - Node Session Coordinator

@available(macOS 12.3, *)
public actor NodeSessionCoordinator {
    private let discoveryService: any DiscoveryService
    private let transport: any VanguardTransport
    private let identityService: any IdentityService
    private let permissionService: any PermissionService
    private let captureService: any ScreenCaptureService
    private let encoderService: any VideoEncoderService
    private let inputService: any InputDispatchService
    private let terminalService: any TerminalService

    private var currentState: NodeState = .idle
    private var currentSession: NodeSession?
    private var stateContinuation: AsyncStream<NodeState>.Continuation?
    private var currentChallengeCode: String?
    private var consoleNodeID: NodeID?

    public struct NodeSession {
        public let sessionID: SessionID
        public let consoleID: NodeID
        public let capabilities: Set<NodeCapability>
        public let connectedAt: Date
    }

    public enum NodeState: Sendable, Equatable {
        case idle
        case advertising
        case pairing(String)
        case connected(NodeID)
        case capturing
        case error(String)

        public static func == (lhs: NodeState, rhs: NodeState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.advertising, .advertising): return true
            case (.pairing(let a), .pairing(let b)): return a == b
            case (.connected(let a), .connected(let b)): return a == b
            case (.capturing, .capturing): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    public var stateUpdates: AsyncStream<NodeState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
        }
    }

    public init(
        discoveryService: any DiscoveryService,
        transport: any VanguardTransport,
        identityService: any IdentityService,
        permissionService: any PermissionService,
        captureService: any ScreenCaptureService,
        encoderService: any VideoEncoderService,
        inputService: any InputDispatchService,
        terminalService: any TerminalService
    ) {
        self.discoveryService = discoveryService
        self.transport = transport
        self.identityService = identityService
        self.permissionService = permissionService
        self.captureService = captureService
        self.encoderService = encoderService
        self.inputService = inputService
        self.terminalService = terminalService
    }

    public func start() async throws {
        updateState(.advertising)

        let identity = try await identityService.getOrCreateIdentity()
        let nodeID = identity.nodeID
        let hostname = Host.current().localizedName ?? "Unknown"

        #if arch(arm64)
        let arch: CPUArchitecture = .arm64
        #else
        let arch: CPUArchitecture = .x86_64
        #endif

        let advertisement = NodeAdvertisement(
            nodeIDHash: Data(nodeID.rawValue.uuidString.utf8),
            displayName: hostname,
            architecture: arch,
            osFamily: .macOS,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            protocolVersion: .v1,
            pairingState: .untrusted,
            endpoint: NodeEndpoint(host: hostname, port: 49494)
        )

        try await discoveryService.publishAdvertisement(advertisement)
        try await transport.listen(port: 49494)
        Task { await listenForMessages() }
    }

    public func stop() async {
        await discoveryService.unpublish()
        await transport.disconnect(reason: .userInitiated)
        updateState(.idle)
    }

    public func approvePairing() async throws {
        guard let code = currentChallengeCode, let consoleID = consoleNodeID else { return }

        let identity = try await identityService.getOrCreateIdentity()
        let completePayload = PairingCompletePayload(
            nodeID: identity.nodeID,
            trustedPeer: Data(),
            signature: Data()
        )
        let data = try JSONEncoder().encode(completePayload)
        let message = OutboundMessage(messageType: .pairingComplete, payload: data)
        try await transport.send(message)

        updateState(.connected(consoleID))
    }

    public func handleInputEvent(_ event: RemoteInputEvent) async throws {
        try await inputService.dispatch(event)
    }

    public func handleTerminalOpen(_ config: TerminalConfiguration) async throws -> TerminalSessionHandle {
        try await terminalService.open(configuration: config)
    }

    public func handleTerminalInput(_ sessionID: TerminalSessionID, data: Data) async throws {
        try await terminalService.write(sessionID: sessionID, data: data)
    }

    public func handleTerminalResize(_ sessionID: TerminalSessionID, columns: UInt16, rows: UInt16) async throws {
        try await terminalService.resize(sessionID: sessionID, columns: columns, rows: rows)
    }

    public func handleTerminalClose(_ sessionID: TerminalSessionID) async {
        await terminalService.close(sessionID: sessionID, signal: .hangup)
    }

    private func listenForMessages() async {
        do {
            for try await message in await transport.incomingMessages {
                await handleMessage(message)
            }
        } catch {
            updateState(.error("Connection lost"))
        }
    }

    private func handleMessage(_ message: InboundMessage) async {
        switch message.header.messageType {
        case .hello:
            await handleHello(message)
        case .pairingResponse:
            await handlePairingResponse(message)
        case .inputEvent:
            if let event = try? JSONDecoder().decode(RemoteInputEvent.self, from: message.payload) {
                try? await handleInputEvent(event)
            }
        case .terminalInput:
            if let payload = try? JSONDecoder().decode(TerminalInputPayload.self, from: message.payload) {
                try? await handleTerminalInput(payload.sessionID, data: payload.data)
            }
        case .terminalOpen:
            if let payload = try? JSONDecoder().decode(TerminalOpenPayload.self, from: message.payload) {
                let _ = try? await handleTerminalOpen(payload.configuration)
            }
        case .terminalResize:
            if let payload = try? JSONDecoder().decode(TerminalResizePayload.self, from: message.payload) {
                try? await handleTerminalResize(payload.sessionID, columns: payload.columns, rows: payload.rows)
            }
        case .terminalClose:
            if let payload = try? JSONDecoder().decode(TerminalClosePayload.self, from: message.payload) {
                await handleTerminalClose(payload.sessionID)
            }
        case .heartbeat:
            let ackPayload = HeartbeatPayload(timestampNanos: UInt64(Date().timeIntervalSince1970 * 1_000_000_000), sequence: 0)
            if let data = try? JSONEncoder().encode(ackPayload) {
                let msg = OutboundMessage(messageType: .heartbeatAck, payload: data)
                try? await transport.send(msg)
            }
        default:
            break
        }
    }

    private func handleHello(_ message: InboundMessage) async {
        guard let helloPayload = try? JSONDecoder().decode(HelloPayload.self, from: message.payload) else { return }

        let identity = try? await identityService.getOrCreateIdentity()
        let nodeID = identity?.nodeID ?? NodeID()

        consoleNodeID = helloPayload.nodeID
        currentSession = NodeSession(
            sessionID: SessionID(),
            consoleID: helloPayload.nodeID,
            capabilities: [],
            connectedAt: Date()
        )

        let ackPayload = HelloAckPayload(
            protocolVersion: .v1,
            nodeID: nodeID,
            acceptedVersion: .v1
        )
        if let data = try? JSONEncoder().encode(ackPayload) {
            let msg = OutboundMessage(messageType: .helloAck, payload: data)
            try? await transport.send(msg)
        }

        let code = String(format: "%06d", Int.random(in: 0...999999))
        currentChallengeCode = code

        let challengePayload = PairingChallengePayload(
            challengeCode: code,
            expiresAtNanos: UInt64(Date().addingTimeInterval(300).timeIntervalSince1970 * 1_000_000_000),
            fingerprint: Data()
        )
        if let data = try? JSONEncoder().encode(challengePayload) {
            let msg = OutboundMessage(messageType: .pairingRequest, payload: data)
            try? await transport.send(msg)
        }

        updateState(.pairing(code))
    }

    private func handlePairingResponse(_ message: InboundMessage) async {
        guard let payload = try? JSONDecoder().decode(PairingResponsePayload.self, from: message.payload),
              let expectedCode = currentChallengeCode else {
            updateState(.error("Invalid pairing response"))
            return
        }

        if payload.challengeCode == expectedCode {
            if let consoleID = consoleNodeID {
                updateState(.connected(consoleID))
            }
        } else {
            updateState(.error("Wrong pairing code"))
        }
    }

    private func updateState(_ newState: NodeState) {
        currentState = newState
        stateContinuation?.yield(newState)
    }
}

// MARK: - Console Session Coordinator

public actor ConsoleSessionCoordinator {
    private let discoveryService: any DiscoveryService
    private let transport: any VanguardTransport
    private let identityService: any IdentityService
    private let permissionService: any PermissionService
    private let terminalService: any TerminalService

    private var currentState: ConsoleState = .idle
    private var currentSession: ConsoleSession?
    private var discoveredNodes: [NodeAdvertisement] = []
    private var stateContinuation: AsyncStream<ConsoleState>.Continuation?
    private var frameContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var terminalContinuation: AsyncStream<TerminalOutputPayload>.Continuation?
    private var pendingChallengeCode: String?

    public struct ConsoleSession {
        public let sessionID: SessionID
        public let nodeID: NodeID
        public let nodeEndpoint: NodeEndpoint
        public let connectedAt: Date
    }

    public enum ConsoleState: Sendable, Equatable {
        case idle
        case scanning
        case discovered([NodeAdvertisement])
        case connecting(NodeAdvertisement)
        case pairing(String)
        case paired(NodeID)
        case connected(NodeID)
        case capturing
        case error(String)

        public static func == (lhs: ConsoleState, rhs: ConsoleState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.scanning, .scanning): return true
            case (.discovered(let a), .discovered(let b)): return a == b
            case (.connecting(let a), .connecting(let b)): return a == b
            case (.pairing(let a), .pairing(let b)): return a == b
            case (.paired(let a), .paired(let b)): return a == b
            case (.connected(let a), .connected(let b)): return a == b
            case (.capturing, .capturing): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    public var stateUpdates: AsyncStream<ConsoleState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
        }
    }

    public var frameUpdates: AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            self.frameContinuation = continuation
        }
    }

    public var terminalOutputUpdates: AsyncStream<TerminalOutputPayload> {
        AsyncStream { continuation in
            self.terminalContinuation = continuation
        }
    }

    public var currentChallengeCode: String? {
        pendingChallengeCode
    }

    public init(
        discoveryService: any DiscoveryService,
        transport: any VanguardTransport,
        identityService: any IdentityService,
        permissionService: any PermissionService,
        terminalService: any TerminalService
    ) {
        self.discoveryService = discoveryService
        self.transport = transport
        self.identityService = identityService
        self.permissionService = permissionService
        self.terminalService = terminalService
    }

    public func startScan() async throws {
        updateState(.scanning)
        try await discoveryService.startBrowsing()

        Task {
            for try await state in await discoveryService.stateUpdates {
                switch state {
                case .nodeFound(let ad), .nodeUpdated(let ad):
                    discoveredNodes.append(ad)
                    updateState(.discovered(discoveredNodes))
                case .nodeLost(let hash):
                    discoveredNodes.removeAll { $0.nodeIDHash == hash }
                    updateState(.discovered(discoveredNodes))
                default:
                    break
                }
            }
        }
    }

    public func stopScan() async {
        await discoveryService.stopBrowsing()
        updateState(.idle)
    }

    public func connect(to node: NodeAdvertisement) async throws {
        updateState(.connecting(node))

        let endpoint = node.endpoint
        try await transport.connect(to: endpoint)

        let identity = try await identityService.getOrCreateIdentity()

        #if arch(arm64)
        let arch: CPUArchitecture = .arm64
        #else
        let arch: CPUArchitecture = .x86_64
        #endif

        let nodeID = NodeID()
        currentSession = ConsoleSession(
            sessionID: SessionID(),
            nodeID: nodeID,
            nodeEndpoint: endpoint,
            connectedAt: Date()
        )

        let helloPayload = HelloPayload(
            protocolVersion: .v1,
            nodeID: identity.nodeID,
            displayName: Host.current().localizedName ?? "Console",
            architecture: arch,
            osFamily: .macOS,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
        let data = try JSONEncoder().encode(helloPayload)
        let message = OutboundMessage(messageType: .hello, payload: data)
        try await transport.send(message)

        Task { await listenForMessages() }
    }

    public func disconnect() async {
        await transport.disconnect(reason: .userInitiated)
        currentSession = nil
        updateState(.idle)
    }

    public func submitPairingCode(_ code: String) async throws {
        guard let session = currentSession else { return }

        let identity = try await identityService.getOrCreateIdentity()
        let responsePayload = PairingResponsePayload(
            consoleID: identity.nodeID,
            challengeCode: code,
            signingPublicKey: identity.signingPublicKey,
            agreementPublicKey: identity.agreementPublicKey,
            transcriptHash: Data()
        )
        let data = try JSONEncoder().encode(responsePayload)
        let message = OutboundMessage(messageType: .pairingResponse, payload: data)
        try await transport.send(message)
    }

    public func sendInputEvent(_ event: RemoteInputEvent) async throws {
        let payload = try JSONEncoder().encode(event)
        let message = OutboundMessage(messageType: .inputEvent, payload: payload)
        try await transport.send(message)
    }

    public func openTerminal(configuration: TerminalConfiguration) async throws -> TerminalSessionHandle {
        let sessionID = TerminalSessionID()
        let payload = TerminalOpenPayload(sessionID: sessionID, configuration: configuration)
        let data = try JSONEncoder().encode(payload)
        let message = OutboundMessage(messageType: .terminalOpen, payload: data)
        try await transport.send(message)
        return TerminalSessionHandle(sessionID: sessionID, pid: 0, state: .opening)
    }

    public func sendTerminalInput(_ sessionID: TerminalSessionID, data: Data) async throws {
        let payload = TerminalInputPayload(sessionID: sessionID, data: data)
        let encoded = try JSONEncoder().encode(payload)
        let message = OutboundMessage(messageType: .terminalInput, payload: encoded)
        try await transport.send(message)
    }

    public func resizeTerminal(_ sessionID: TerminalSessionID, columns: UInt16, rows: UInt16) async throws {
        let payload = TerminalResizePayload(sessionID: sessionID, columns: columns, rows: rows)
        let encoded = try JSONEncoder().encode(payload)
        let message = OutboundMessage(messageType: .terminalResize, payload: encoded)
        try await transport.send(message)
    }

    public func closeTerminal(_ sessionID: TerminalSessionID) async throws {
        let payload = TerminalClosePayload(sessionID: sessionID, signal: .hangup)
        let encoded = try JSONEncoder().encode(payload)
        let message = OutboundMessage(messageType: .terminalClose, payload: encoded)
        try await transport.send(message)
    }

    private func listenForMessages() async {
        do {
            for try await message in await transport.incomingMessages {
                await handleMessage(message)
            }
        } catch {
            updateState(.error("Connection lost"))
        }
    }

    private func handleMessage(_ message: InboundMessage) async {
        switch message.header.messageType {
        case .helloAck:
            await handleHelloAck(message)
        case .pairingRequest:
            await handlePairingRequest(message)
        case .pairingComplete:
            await handlePairingComplete(message)
        case .videoFrame:
            if let frame = try? JSONDecoder().decode(VideoFramePayload.self, from: message.payload) {
                frameContinuation?.yield(frame.payload)
            }
        case .terminalOutput:
            if let payload = try? JSONDecoder().decode(TerminalOutputPayload.self, from: message.payload) {
                terminalContinuation?.yield(payload)
            }
        case .terminalOpened:
            if let _ = try? JSONDecoder().decode(TerminalOpenedPayload.self, from: message.payload) {
            }
        case .heartbeatAck:
            break
        case .error:
            if let payload = try? JSONDecoder().decode(ErrorPayload.self, from: message.payload) {
                updateState(.error(payload.message))
            }
        default:
            break
        }
    }

    private func handleHelloAck(_ message: InboundMessage) async {
        guard let payload = try? JSONDecoder().decode(HelloAckPayload.self, from: message.payload) else { return }
        if let session = currentSession {
            updateState(.pairing("Waiting for challenge..."))
        }
    }

    private func handlePairingRequest(_ message: InboundMessage) async {
        guard let payload = try? JSONDecoder().decode(PairingChallengePayload.self, from: message.payload) else { return }
        pendingChallengeCode = payload.challengeCode
        updateState(.pairing(payload.challengeCode))
    }

    private func handlePairingComplete(_ message: InboundMessage) async {
        pendingChallengeCode = nil
        if let nodeID = currentSession?.nodeID {
            updateState(.connected(nodeID))
        }
    }

    private func updateState(_ newState: ConsoleState) {
        currentState = newState
        stateContinuation?.yield(newState)
    }
}
