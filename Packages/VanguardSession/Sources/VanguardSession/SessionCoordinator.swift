import Foundation
import os
import CoreVideo
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
import VanguardAudit

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
    private var auditService: AuditIntegrationService?
    private var isCapturing = false
    private var captureTask: Task<Void, Never>?

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

    private var _pipelineStats = PipelineStats(
        framesCaptured: 0,
        framesEncoded: 0,
        framesDecoded: 0,
        framesRendered: 0,
        averageEncodeTimeMs: 0,
        averageDecodeTimeMs: 0,
        averageRenderLatencyMs: 0,
        currentBitrate: 0
    )
    public var pipelineStats: PipelineStats? {
        _pipelineStats
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

    public func setAuditService(_ service: AuditIntegrationService) {
        self.auditService = service
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

        AppLogger.info(.node, "Starting node: \(hostname) (\(arch.rawValue))")
        AppLogger.info(.node, "Node ID: \(nodeID.rawValue.uuidString.prefix(8))")

        try await discoveryService.publishAdvertisement(advertisement)
        AppLogger.info(.node, "Advertisement published via Bonjour")

        try await transport.listen(port: 49494)
        AppLogger.info(.node, "Listening on port 49494")

        Task { await listenForMessages() }
    }

    public func stop() async {
        AppLogger.info(.node, "Stopping node")
        stopCapture()
        await discoveryService.unpublish()
        await transport.disconnect(reason: .userInitiated)
        updateState(.idle)
        AppLogger.info(.node, "Node stopped")
    }

    public func approvePairing() async throws {
        guard let code = currentChallengeCode, let consoleID = consoleNodeID else { return }

        AppLogger.info(.pairing, "Approving pairing with console: \(consoleID.rawValue.uuidString.prefix(8))")

        let identity = try await identityService.getOrCreateIdentity()
        let completePayload = PairingCompletePayload(
            nodeID: identity.nodeID,
            trustedPeer: Data(),
            signature: Data()
        )
        let data = try JSONEncoder().encode(completePayload)
        let message = OutboundMessage(messageType: .pairingComplete, payload: data)
        try await transport.send(message)

        updateState(.capturing)
        AppLogger.info(.pairing, "Pairing approved and complete — starting video capture")
        await startCaptureLoop()
    }

    private func startCaptureLoop() async {
        guard !isCapturing else { return }
        isCapturing = true

        captureTask = Task { [weak self] in
            guard let self else { return }

            do {
                let sources = try await self.captureService.availableSources()
                guard let source = sources.first else {
                    AppLogger.error(.capture, "No display source available")
                    await self.updateState(.error("No display available"))
                    return
                }

                let config = CaptureConfiguration(maxWidth: 1920, maxHeight: 1080, fps: 30)
                let frameStream = try await self.captureService.startCapture(source: source, configuration: config)
                AppLogger.info(.capture, "Screen capture started on \(source.name)")

                let encoderWidth = 1920
                let encoderHeight = 1080
                try await self.encoderService.configure(width: encoderWidth, height: encoderHeight, fps: 30, bitrate: 8_000_000)
                AppLogger.info(.capture, "Encoder configured: \(encoderWidth)x\(encoderHeight)@30fps, 8Mbps")

                var frameCount: UInt64 = 0

                for try await frameData in frameStream {
                    guard !Task.isCancelled else { break }

                    frameCount += 1
                    let startEncode = Date()

                    if let encodedFrame = try? await self.encoderService.encodeFrame(frameData, width: encoderWidth, height: encoderHeight) {
                        let encodeTime = Date().timeIntervalSince(startEncode) * 1000

                        let framePayload = VideoFramePayload(
                            frameID: encodedFrame.frameID,
                            presentationTimestampNanos: encodedFrame.presentationTimestampNanos,
                            isKeyframe: encodedFrame.isKeyframe,
                            codecConfigurationRevision: encodedFrame.codecConfigurationRevision,
                            payload: encodedFrame.payload
                        )
                        let payloadData = try JSONEncoder().encode(framePayload)
                        let message = OutboundMessage(messageType: .videoFrame, payload: payloadData)
                        try? await self.transport.send(message)

                        await self.updatePipelineStats(
                            framesCaptured: frameCount,
                            framesEncoded: frameCount,
                            encodeTimeMs: encodeTime
                        )
                    }
                }
            } catch {
                if !Task.isCancelled {
                    AppLogger.error(.capture, "Capture stream ended: \(error.localizedDescription)")
                }
            }

            await self.setCapturing(false)
            AppLogger.info(.capture, "Capture loop exited")
        }
    }

    private func updatePipelineStats(framesCaptured: UInt64, framesEncoded: UInt64, encodeTimeMs: Double) {
        _pipelineStats = PipelineStats(
            framesCaptured: framesCaptured,
            framesEncoded: framesEncoded,
            framesDecoded: 0,
            framesRendered: 0,
            averageEncodeTimeMs: encodeTimeMs,
            averageDecodeTimeMs: 0,
            averageRenderLatencyMs: 0,
            currentBitrate: 8_000_000
        )
    }

    private func setCapturing(_ value: Bool) {
        isCapturing = value
    }

    public func stopCapture() {
        captureTask?.cancel()
        captureTask = nil
        isCapturing = false
        Task {
            await captureService.stopCapture()
            await encoderService.reset()
        }
        AppLogger.info(.capture, "Capture stopped")
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
            do {
                let event = try JSONDecoder().decode(RemoteInputEvent.self, from: message.payload)
                try await handleInputEvent(event)
            } catch {
                os_log(.error, "Failed to handle input event: %{public}@", error.localizedDescription)
            }
        case .terminalInput:
            do {
                let payload = try JSONDecoder().decode(TerminalInputPayload.self, from: message.payload)
                try await handleTerminalInput(payload.sessionID, data: payload.data)
            } catch {
                os_log(.error, "Failed to handle terminal input: %{public}@", error.localizedDescription)
            }
        case .terminalOpen:
            do {
                let payload = try JSONDecoder().decode(TerminalOpenPayload.self, from: message.payload)
                let _ = try await handleTerminalOpen(payload.configuration)
            } catch {
                os_log(.error, "Failed to handle terminal open: %{public}@", error.localizedDescription)
            }
        case .terminalResize:
            do {
                let payload = try JSONDecoder().decode(TerminalResizePayload.self, from: message.payload)
                try await handleTerminalResize(payload.sessionID, columns: payload.columns, rows: payload.rows)
            } catch {
                os_log(.error, "Failed to handle terminal resize: %{public}@", error.localizedDescription)
            }
        case .terminalClose:
            if let payload = try? JSONDecoder().decode(TerminalClosePayload.self, from: message.payload) {
                await handleTerminalClose(payload.sessionID)
            }
        case .heartbeat:
            let ackPayload = HeartbeatPayload(timestampNanos: UInt64(Date().timeIntervalSince1970 * 1_000_000_000), sequence: 0)
            do {
                let data = try JSONEncoder().encode(ackPayload)
                let msg = OutboundMessage(messageType: .heartbeatAck, payload: data)
                try await transport.send(msg)
            } catch {
                os_log(.error, "Failed to send heartbeat ack: %{public}@", error.localizedDescription)
            }
        case .videoKeyframeRequest:
            AppLogger.info(.capture, "Console requested keyframe")
            Task { await encoderService.requestKeyframe() }
        default:
            break
        }
    }

    private func handleHello(_ message: InboundMessage) async {
        guard let helloPayload = try? JSONDecoder().decode(HelloPayload.self, from: message.payload) else { return }

        do {
            let identity = try await identityService.getOrCreateIdentity()
            let nodeID = identity.nodeID

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
    private let decoderService: any VideoDecoderService

    private var currentState: ConsoleState = .idle
    private var currentSession: ConsoleSession?
    private var discoveredNodes: [NodeAdvertisement] = []
    private var stateContinuation: AsyncStream<ConsoleState>.Continuation?
    private var frameContinuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var terminalContinuation: AsyncStream<TerminalOutputPayload>.Continuation?
    private var pendingChallengeCode: String?
    private var isDecoderConfigured = false

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
        AppLogger.info(.session, "Connecting to node: \(node.displayName)")

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

        AppLogger.info(.session, "Hello message sent to \(node.displayName)")

        Task { await listenForMessages() }
    }

    public func disconnect() async {
        AppLogger.info(.session, "Disconnecting from node")
        await transport.disconnect(reason: .userInitiated)
        currentSession = nil
        isDecoderConfigured = false
        updateState(.idle)
        AppLogger.info(.session, "Disconnected")
    }

    public func requestKeyframe() async throws {
        let message = OutboundMessage(messageType: .videoKeyframeRequest, payload: Data())
        try await transport.send(message)
        AppLogger.info(.session, "Keyframe requested from node")
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
            do {
                let frame = try JSONDecoder().decode(VideoFramePayload.self, from: message.payload)

                let encodedFrame = EncodedVideoFrame(
                    frameID: frame.frameID,
                    presentationTimestampNanos: frame.presentationTimestampNanos,
                    isKeyframe: frame.isKeyframe,
                    codecConfigurationRevision: frame.codecConfigurationRevision,
                    payload: frame.payload
                )

                if !isDecoderConfigured {
                    do {
                        try await decoderService.configure(codecConfiguration: frame.payload)
                        isDecoderConfigured = true
                        AppLogger.info(.session, "Decoder configured from first frame")
                    } catch {
                        AppLogger.warning(.session, "Decoder config from frame failed, trying decode anyway: \(error.localizedDescription)")
                    }
                }

                _ = try? await decoderService.decodeFrame(encodedFrame)

                if let pixelBuffer = await decoderService.getLastDecodedPixelBuffer() {
                    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

                    if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                        let width = CVPixelBufferGetWidth(pixelBuffer)
                        let height = CVPixelBufferGetHeight(pixelBuffer)
                        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                        let data = Data(bytes: baseAddress, count: height * bytesPerRow)
                        frameContinuation?.yield(data)
                    }
                } else {
                    frameContinuation?.yield(frame.payload)
                }
            } catch {
                os_log(.error, "Failed to decode video frame: %{public}@", error.localizedDescription)
            }
        case .terminalOutput:
            do {
                let payload = try JSONDecoder().decode(TerminalOutputPayload.self, from: message.payload)
                terminalContinuation?.yield(payload)
            } catch {
                os_log(.error, "Failed to decode terminal output: %{public}@", error.localizedDescription)
            }
        case .terminalOpened:
            break
        case .heartbeatAck:
            break
        case .error:
            do {
                let payload = try JSONDecoder().decode(ErrorPayload.self, from: message.payload)
                updateState(.error(payload.message))
            } catch {
                os_log(.error, "Failed to decode error payload: %{public}@", error.localizedDescription)
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
            AppLogger.info(.session, "Pairing complete — ready to receive video frames")
        }
    }

    private func updateState(_ newState: ConsoleState) {
        currentState = newState
        stateContinuation?.yield(newState)
    }
}
