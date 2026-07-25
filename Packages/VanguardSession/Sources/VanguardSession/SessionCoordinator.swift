import Foundation
import os
import CoreVideo
import Network
import VanguardDomain
import VanguardProtocol
import VanguardTransport
import VanguardDiscovery
import VanguardIdentity
import VanguardPermissions
import VanguardSecurity
import VanguardCapture
import VanguardVideo
import VanguardInput
import VanguardTerminal
import VanguardAudit

// MARK: - Node Session Coordinator

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
    private var auditService: AuditIntegrationService?
    private var isCapturing = false
    private var captureTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    private var authorizationGuard: AuthorizationGuard?
    private var _pipelineStats = PipelineStats(
        framesCaptured: 0, framesEncoded: 0, framesDecoded: 0,
        framesRendered: 0, averageEncodeTimeMs: 0, averageDecodeTimeMs: 0,
        averageRenderLatencyMs: 0, currentBitrate: 0
    )

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
        case codeValidated(NodeID)
        case connected(NodeID)
        case capturing
        case error(String)

        public static func == (lhs: NodeState, rhs: NodeState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.advertising, .advertising): return true
            case (.pairing(let a), .pairing(let b)): return a == b
            case (.codeValidated(let a), .codeValidated(let b)): return a == b
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

    public var pipelineStats: PipelineStats? { _pipelineStats }

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

    public func setAuditService(_ service: AuditIntegrationService) {
        self.auditService = service
    }

    // MARK: - Start (Single Listener with Bonjour)

    public func start() async throws {
        updateState(.advertising)

        let authGuard = AuthorizationGuard()
        self.authorizationGuard = authGuard

        let identity = try await identityService.getOrCreateIdentity()
        let hostname = Host.current().localizedName ?? "Unknown"

        #if arch(arm64)
        let arch: CPUArchitecture = .arm64
        #else
        let arch: CPUArchitecture = .x86_64
        #endif

        let ad = NodeAdvertisement(
            nodeIDHash: Data(identity.nodeID.rawValue.uuidString.utf8),
            displayName: hostname,
            architecture: arch,
            osFamily: .macOS,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            protocolVersion: .v1,
            pairingState: .untrusted,
            endpoint: NodeEndpoint(host: hostname, port: 49494)
        )

        var txtRecord: [String: String] = [:]
        txtRecord["pv"] = ad.protocolVersion.description
        txtRecord["arch"] = ad.architecture.rawValue
        txtRecord["os"] = ad.osFamily.rawValue
        txtRecord["osv"] = ad.osVersion
        txtRecord["pair"] = ad.pairingState.rawValue
        txtRecord["nh"] = ad.nodeIDHash.base64EncodedString()
        txtRecord["codec"] = "h264"
        txtRecord["capture"] = "sck"
        txtRecord["tls"] = "1.3"

        if let bonjourTransport = transport as? BonjourTransport {
            try await bonjourTransport.listenWithBonjour(
                port: 49494,
                serviceName: hostname,
                serviceType: "_elysium-vanguard._tcp",
                txtRecord: txtRecord
            )
        } else {
            try await transport.listen(port: 49494)
        }

        AppLogger.info(.node, "Node listening on port 49494 with Bonjour")

        messageTask = Task { await listenForMessages() }
    }

    public func stop() async {
        AppLogger.info(.node, "Stopping node")
        stopCapture()
        messageTask?.cancel()
        messageTask = nil

        if let sessionID = currentSession?.sessionID {
            await authorizationGuard?.revokeSession(sessionID)
        }

        await transport.disconnect(reason: .userInitiated)
        updateState(.idle)
        AppLogger.info(.node, "Node stopped")
    }

    // MARK: - Pairing

    public func approvePairing() async throws {
        guard let consoleID = consoleNodeID else {
            throw PairingError.noPendingPairing
        }

        AppLogger.info(.pairing, "Approving pairing with console: \(consoleID.rawValue.uuidString.prefix(8))")

        let grantedCaps: Set<NodeCapability> = [
            .screenView, .screenControl, .terminalOpen,
            .clipboardRead, .clipboardWrite,
            .fileRead, .fileWrite
        ]

        if let sessionID = currentSession?.sessionID {
            await authorizationGuard?.registerSession(sessionID, capabilities: grantedCaps)
        }

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
        updateState(.capturing)
        AppLogger.info(.pairing, "Pairing approved — starting video capture")
        await startCaptureLoop()
    }

    public enum PairingError: Error, Sendable {
        case noPendingPairing
    }

    // MARK: - Message Handling

    private func listenForMessages() async {
        do {
            for try await message in await transport.incomingMessages {
                await handleMessage(message)
            }
        } catch {
            updateState(.error("Connection lost: \(error.localizedDescription)"))
        }
    }

    private func handleMessage(_ message: InboundMessage) async {
        switch message.header.messageType {
        case .hello:
            await handleHello(message)
        case .pairingResponse:
            await handlePairingResponse(message)
        case .inputEvent:
            do {
                let event = try JSONDecoder().decode(RemoteInputEvent.self, from: message.payload)
                if let sessionID = currentSession?.sessionID,
                   await authorizationGuard?.checkCapability(.screenControl, sessionID: sessionID) == false {
                    AppLogger.warning(.input, "Input blocked — missing screenControl capability")
                } else {
                    try await inputService.dispatch(event)
                }
            } catch {
                AppLogger.error(.input, "Failed to handle input: \(error.localizedDescription)")
            }
        case .terminalInput:
            do {
                let payload = try JSONDecoder().decode(TerminalInputPayload.self, from: message.payload)
                if let sessionID = currentSession?.sessionID,
                   await authorizationGuard?.checkCapability(.terminalOpen, sessionID: sessionID) == false {
                    AppLogger.warning(.terminal, "Terminal input blocked — missing terminalOpen capability")
                } else {
                    try await terminalService.write(sessionID: payload.sessionID, data: payload.data)
                }
            } catch {
                AppLogger.error(.terminal, "Failed to handle terminal input: \(error.localizedDescription)")
            }
        case .terminalOpen:
            do {
                let payload = try JSONDecoder().decode(TerminalOpenPayload.self, from: message.payload)
                if let sessionID = currentSession?.sessionID,
                   await authorizationGuard?.checkCapability(.terminalOpen, sessionID: sessionID) == false {
                    AppLogger.warning(.terminal, "Terminal open blocked — missing terminalOpen capability")
                } else {
                    let handle = try await terminalService.open(sessionID: payload.sessionID, configuration: payload.configuration)
                    let openedPayload = TerminalOutputPayload(sessionID: handle.sessionID, data: Data("Terminal opened (pid \(handle.pid))\n".utf8), offset: 0)
                    let openedData = try JSONEncoder().encode(openedPayload)
                    let openedMsg = OutboundMessage(messageType: .terminalOutput, payload: openedData)
                    try await transport.send(openedMsg)
                }
            } catch {
                AppLogger.error(.terminal, "Failed to handle terminal open: \(error.localizedDescription)")
            }
        case .terminalResize:
            do {
                let payload = try JSONDecoder().decode(TerminalResizePayload.self, from: message.payload)
                try await terminalService.resize(sessionID: payload.sessionID, columns: payload.columns, rows: payload.rows)
            } catch {
                AppLogger.error(.terminal, "Failed to handle terminal resize: \(error.localizedDescription)")
            }
        case .terminalClose:
            if let payload = try? JSONDecoder().decode(TerminalClosePayload.self, from: message.payload) {
                await terminalService.close(sessionID: payload.sessionID, signal: .hangup)
            }
        case .videoKeyframeRequest:
            AppLogger.info(.capture, "Console requested keyframe")
            await encoderService.requestKeyframe()
        default:
            break
        }
    }

    private func handleHello(_ message: InboundMessage) async {
        guard let helloPayload = try? JSONDecoder().decode(HelloPayload.self, from: message.payload) else { return }

        do {
            let identity = try await identityService.getOrCreateIdentity()
            consoleNodeID = helloPayload.nodeID
            currentSession = NodeSession(
                sessionID: SessionID(),
                consoleID: helloPayload.nodeID,
                capabilities: [],
                connectedAt: Date()
            )

            let ackPayload = HelloAckPayload(
                protocolVersion: .v1,
                nodeID: identity.nodeID,
                acceptedVersion: .v1
            )
            let ackData = try JSONEncoder().encode(ackPayload)
            let ackMsg = OutboundMessage(messageType: .helloAck, payload: ackData)
            try await transport.send(ackMsg)

            let challenge = try await identityService.generateChallenge()
            currentChallengeCode = challenge.code

            let challengePayload = PairingChallengePayload(
                challengeCode: challenge.code,
                expiresAtNanos: UInt64(challenge.expiresAt.timeIntervalSince1970 * 1_000_000_000),
                fingerprint: challenge.fingerprint
            )
            let challengeData = try JSONEncoder().encode(challengePayload)
            let challengeMsg = OutboundMessage(messageType: .pairingRequest, payload: challengeData)
            try await transport.send(challengeMsg)

            updateState(.pairing(challenge.code))
        } catch {
            updateState(.error("Identity or pairing setup failed"))
        }
    }

    private func handlePairingResponse(_ message: InboundMessage) async {
        guard let payload = try? JSONDecoder().decode(PairingResponsePayload.self, from: message.payload),
              let expectedCode = currentChallengeCode else {
            updateState(.error("Invalid pairing response"))
            return
        }

        if payload.challengeCode == expectedCode {
            if let consoleID = consoleNodeID {
                updateState(.codeValidated(consoleID))
            }
        } else {
            updateState(.error("Wrong pairing code"))
        }
    }

    // MARK: - Video Capture

    private func startCaptureLoop() async {
        guard !isCapturing else { return }
        isCapturing = true

        captureTask = Task { [weak self] in
            guard let self else { return }

            do {
                let sources = try await self.captureService.availableSources()
                guard let source = sources.first else {
                    await self.updateState(.error("No display available"))
                    return
                }

                let config = CaptureConfiguration(maxWidth: 1280, maxHeight: 720, fps: 30)
                let frameStream = try await self.captureService.startCapture(source: source, configuration: config)

                try await self.encoderService.configure(width: 1280, height: 720, fps: 30, bitrate: 5_000_000)

                var frameCount: UInt64 = 0
                var displayIDSet = false

                for try await capturedFrame in frameStream {
                    guard !Task.isCancelled else { break }

                    if !displayIDSet, capturedFrame.displayID != 0 {
                        await self.inputService.setCapturedDisplayID(capturedFrame.displayID)
                        displayIDSet = true
                    }
                    frameCount += 1
                    let startEncode = Date()

                    do {
                        let output = try await self.encoderService.encode(capturedFrame)
                        let encodeTime = Date().timeIntervalSince(startEncode) * 1000

                        switch output {
                        case .configuration(let config):
                            let configPayload = VideoCodecConfigurationPayload(
                                codec: config.codec,
                                revision: config.revision,
                                width: config.width,
                                height: config.height,
                                nalLengthSize: config.nalLengthSize,
                                sps: config.sps,
                                pps: config.pps
                            )
                            let data = try JSONEncoder().encode(configPayload)
                            let msg = OutboundMessage(messageType: .videoConfiguration, payload: data)
                            try await self.transport.send(msg)

                        case .accessUnit(let au):
                            let auPayload = VideoAccessUnitPayload(
                                frameID: au.frameID,
                                presentationTimestampNanos: au.presentationTimestampNanos,
                                durationNanos: au.durationNanos,
                                isKeyframe: au.isKeyframe,
                                configurationRevision: au.configurationRevision,
                                avccData: au.avccPayload
                            )
                            let data = try JSONEncoder().encode(auPayload)
                            let msg = OutboundMessage(messageType: .videoAccessUnit, payload: data)
                            try await self.transport.send(msg)

                        case .configurationAndAccessUnit(let config, let au):
                            let configPayload = VideoCodecConfigurationPayload(
                                codec: config.codec,
                                revision: config.revision,
                                width: config.width,
                                height: config.height,
                                nalLengthSize: config.nalLengthSize,
                                sps: config.sps,
                                pps: config.pps
                            )
                            let configData = try JSONEncoder().encode(configPayload)
                            let configMsg = OutboundMessage(messageType: .videoConfiguration, payload: configData)
                            try await self.transport.send(configMsg)

                            let auPayload = VideoAccessUnitPayload(
                                frameID: au.frameID,
                                presentationTimestampNanos: au.presentationTimestampNanos,
                                durationNanos: au.durationNanos,
                                isKeyframe: au.isKeyframe,
                                configurationRevision: au.configurationRevision,
                                avccData: au.avccPayload
                            )
                            let auData = try JSONEncoder().encode(auPayload)
                            let auMsg = OutboundMessage(messageType: .videoAccessUnit, payload: auData)
                            try await self.transport.send(auMsg)
                        }

                        await self.updatePipelineStats(PipelineStats(
                            framesCaptured: frameCount, framesEncoded: frameCount,
                            framesDecoded: 0, framesRendered: 0,
                            averageEncodeTimeMs: encodeTime, averageDecodeTimeMs: 0,
                            averageRenderLatencyMs: 0, currentBitrate: 5_000_000
                        ))
                    } catch {
                        AppLogger.error(.capture, "Encode failed: \(error.localizedDescription)")
                    }
                }
            } catch {
                if !Task.isCancelled {
                    AppLogger.error(.capture, "Capture ended: \(error.localizedDescription)")
                }
            }

            await self.setCapturing(false)
        }
    }

    public func stopCapture() {
        captureTask?.cancel()
        captureTask = nil
        isCapturing = false
        Task {
            await captureService.stopCapture()
            await encoderService.reset()
        }
    }

    private func updateState(_ newState: NodeState) {
        currentState = newState
        stateContinuation?.yield(newState)
    }

    private func updatePipelineStats(_ stats: PipelineStats) {
        _pipelineStats = stats
    }

    private func setCapturing(_ value: Bool) {
        isCapturing = value
    }
}

// MARK: - Console Session Coordinator

public actor ConsoleSessionCoordinator {
    private let discoveryService: any DiscoveryService
    private let transport: any VanguardTransport
    private let identityService: any IdentityService
    private let permissionService: any PermissionService
    private let terminalService: any TerminalService
    private let decoderService: any VideoDecoderService

    private var currentState: ConsoleState = .idle
    private var currentSession: ConsoleSession?
    private var stateContinuation: AsyncStream<ConsoleState>.Continuation?
    private var frameContinuation: AsyncThrowingStream<SendablePixelBuffer, Error>.Continuation?
    private var terminalContinuation: AsyncStream<TerminalOutputPayload>.Continuation?
    private var pendingChallengeCode: String?
    private var isDecoderConfigured = false
    private var messageTask: Task<Void, Never>?

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

    public var frameUpdates: AsyncThrowingStream<SendablePixelBuffer, Error> {
        AsyncThrowingStream { continuation in
            self.frameContinuation = continuation
        }
    }

    public var terminalOutputUpdates: AsyncStream<TerminalOutputPayload> {
        AsyncStream { continuation in
            self.terminalContinuation = continuation
        }
    }

    public var currentChallengeCode: String? { pendingChallengeCode }

    public init(
        discoveryService: any DiscoveryService,
        transport: any VanguardTransport,
        identityService: any IdentityService,
        permissionService: any PermissionService,
        terminalService: any TerminalService,
        decoderService: any VideoDecoderService
    ) {
        self.discoveryService = discoveryService
        self.transport = transport
        self.identityService = identityService
        self.permissionService = permissionService
        self.terminalService = terminalService
        self.decoderService = decoderService
    }

    // MARK: - Scan

    public func startScan() async throws {
        updateState(.scanning)
        try await discoveryService.startBrowsing()

        Task { [weak self] in
            guard let self else { return }
            for try await state in await self.discoveryService.stateUpdates {
                switch state {
                case .nodeFound(let ad), .nodeUpdated(let ad):
                    await self.handleDiscoveredNode(ad)
                case .nodeLost:
                    break
                default:
                    break
                }
            }
        }
    }

    private var discoveredAdvertisements: [Data: NodeAdvertisement] = [:]

    private func handleDiscoveredNode(_ ad: NodeAdvertisement) async {
        discoveredAdvertisements[ad.nodeIDHash] = ad
        let all = Array(discoveredAdvertisements.values)
        updateState(.discovered(all))
    }

    public func stopScan() async {
        await discoveryService.stopBrowsing()
        messageTask?.cancel()
        messageTask = nil
        updateState(.idle)
    }

    // MARK: - Connect

    public func connect(to node: NodeAdvertisement) async throws {
        updateState(.connecting(node))
        AppLogger.info(.session, "Connecting to node: \(node.displayName)")

        try await transport.connect(to: node.endpoint)

        let identity = try await identityService.getOrCreateIdentity()

        #if arch(arm64)
        let arch: CPUArchitecture = .arm64
        #else
        let arch: CPUArchitecture = .x86_64
        #endif

        currentSession = ConsoleSession(
            sessionID: SessionID(),
            nodeID: NodeID(),
            nodeEndpoint: node.endpoint,
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

        messageTask = Task { await listenForMessages() }
    }

    public func disconnect() async {
        AppLogger.info(.session, "Disconnecting")
        messageTask?.cancel()
        messageTask = nil
        await transport.disconnect(reason: .userInitiated)
        currentSession = nil
        isDecoderConfigured = false
        updateState(.idle)
    }

    // MARK: - Pairing

    public func submitPairingCode(_ code: String) async throws {
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

    public func requestKeyframe() async throws {
        let message = OutboundMessage(messageType: .videoKeyframeRequest, payload: Data())
        try await transport.send(message)
    }

    // MARK: - Input

    public func sendInputEvent(_ event: RemoteInputEvent) async throws {
        let payload = try JSONEncoder().encode(event)
        let message = OutboundMessage(messageType: .inputEvent, payload: payload)
        try await transport.send(message)
    }

    // MARK: - Terminal

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

    public func closeTerminal(_ sessionID: TerminalSessionID) async throws {
        let payload = TerminalClosePayload(sessionID: sessionID, signal: .hangup)
        let encoded = try JSONEncoder().encode(payload)
        let message = OutboundMessage(messageType: .terminalClose, payload: encoded)
        try await transport.send(message)
    }

    // MARK: - Message Handling

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
        case .videoConfiguration:
            do {
                let config = try JSONDecoder().decode(VideoCodecConfigurationPayload.self, from: message.payload)
                try await decoderService.configure(
                    sps: config.sps,
                    pps: config.pps,
                    width: Int(config.width),
                    height: Int(config.height)
                )
                AppLogger.info(.decode, "Decoder configured: \(config.width)x\(config.height)")
            } catch {
                AppLogger.error(.decode, "Failed to configure decoder: \(error.localizedDescription)")
            }
        case .videoAccessUnit:
            do {
                let auPayload = try JSONDecoder().decode(VideoAccessUnitPayload.self, from: message.payload)
                let accessUnit = EncodedVideoAccessUnit(
                    frameID: auPayload.frameID,
                    presentationTimestampNanos: auPayload.presentationTimestampNanos,
                    durationNanos: auPayload.durationNanos,
                    isKeyframe: auPayload.isKeyframe,
                    configurationRevision: auPayload.configurationRevision,
                    avccPayload: auPayload.avccData
                )
                let decoded = try await decoderService.decode(accessUnit)
                frameContinuation?.yield(SendablePixelBuffer(decoded.pixelBuffer))
            } catch {
                AppLogger.error(.decode, "Failed to decode video frame: \(error.localizedDescription)")
            }
        case .terminalOutput:
            do {
                let payload = try JSONDecoder().decode(TerminalOutputPayload.self, from: message.payload)
                terminalContinuation?.yield(payload)
            } catch {
                os_log(.error, "Failed to decode terminal output: %{public}@", error.localizedDescription)
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
        guard let _ = try? JSONDecoder().decode(HelloAckPayload.self, from: message.payload) else { return }
        if currentSession != nil {
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
            updateState(.capturing)
            AppLogger.info(.session, "Pairing complete — ready to receive video")
        }
    }

    private func updateState(_ newState: ConsoleState) {
        currentState = newState
        stateContinuation?.yield(newState)
    }
}
