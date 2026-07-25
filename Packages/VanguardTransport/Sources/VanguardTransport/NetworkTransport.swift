import Foundation
import Network
import Security
import CryptoKit
import VanguardDomain
import VanguardProtocol
import VanguardIdentity

// MARK: - Transport Errors

public enum NWTransportError: Error, Sendable, LocalizedError {
    case invalidPort(UInt16)
    case connectionTimeout
    case connectionCancelled
    case listenerCancelled
    case notConnected
    case invalidState
    case sendFailed(reason: String)
    case receiveFailed(reason: String)
    case flowControlBackpressure

    public var errorDescription: String? {
        switch self {
        case .invalidPort(let p): return "Invalid port: \(p)"
        case .connectionTimeout: return "Connection timed out"
        case .connectionCancelled: return "Connection cancelled"
        case .listenerCancelled: return "Listener cancelled"
        case .notConnected: return "Not connected"
        case .invalidState: return "Invalid transport state"
        case .sendFailed(let r): return "Send failed: \(r)"
        case .receiveFailed(let r): return "Receive failed: \(r)"
        case .flowControlBackpressure: return "Flow control backpressure"
        }
    }
}

// MARK: - Transport State

public enum TransportState: Sendable, Equatable {
    case idle
    case listening(port: UInt16)
    case connecting
    case ready
    case failed(String)
    case cancelled
}

// MARK: - Disconnect Reason

public enum TransportDisconnectReason: Sendable {
    case userInitiated
    case error(String)
    case timeout
}

// MARK: - One-Shot Continuation Helper

private final class OneShotContinuation<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<T, Error>

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.withLock {
            guard !didResume else { return }
            didResume = true
        }
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.withLock {
            guard !didResume else { return }
            didResume = true
        }
        continuation.resume(throwing: error)
    }
}

// MARK: - Network Transport

@available(macOS 12.0, *)
public final class NetworkTransport: BonjourTransport, @unchecked Sendable {
    private let lock = NSLock()

    private var _connection: NWConnection?
    private var _listener: NWListener?
    private var _state: TransportState = .idle
    private var _isRunning = false

    private var receiveTask: Task<Void, Never>?
    private var sendTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?

    private let heartbeatInterval: TimeInterval
    private let useTLS: Bool
    private let tlsCertificateManager: TLSCertificateManager?
    private let expectedPeerFingerprint: Data?

    let frameDecoder = FrameDecoder()
    let multiplexer = ChannelMultiplexer()
    let flowController = FlowController()
    let heartbeatController = HeartbeatController()
    let metrics = NetworkMetricsCollector()
    private let messageState = IncomingMessageState()

    private var connection: NWConnection? {
        get { lock.withLock { _connection } }
        set { lock.withLock { _connection = newValue } }
    }

    private var listener: NWListener? {
        get { lock.withLock { _listener } }
        set { lock.withLock { _listener = newValue } }
    }

    public var currentState: TransportState {
        lock.withLock { _state }
    }

    private var isRunning: Bool {
        get { lock.withLock { _isRunning } }
        set { lock.withLock { _isRunning = newValue } }
    }

    // MARK: - Init

    public init(
        host: String = "0.0.0.0",
        port: UInt16 = 49494,
        useTLS: Bool = true,
        heartbeatInterval: TimeInterval = 15.0,
        tlsCertificateManager: TLSCertificateManager? = nil,
        expectedPeerFingerprint: Data? = nil
    ) {
        self.useTLS = useTLS
        self.heartbeatInterval = heartbeatInterval
        self.tlsCertificateManager = useTLS ? (tlsCertificateManager ?? TLSCertificateManager()) : nil
        self.expectedPeerFingerprint = expectedPeerFingerprint
    }

    // MARK: - Incoming Messages

    public var incomingMessages: AsyncThrowingStream<InboundMessage, Error> {
        let stateRef = self.messageState
        return AsyncThrowingStream { continuation in
            Task { await stateRef.setIncomingContinuation(continuation) }
            continuation.onTermination = { @Sendable _ in
                Task { await stateRef.continuationFinished() }
            }
        }
    }

    // MARK: - Connect (Client Side)

    public func connect(to endpoint: NodeEndpoint) async throws {
        lock.withLock { _state = .connecting }

        let parameters = try makeClientParameters()

        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            throw NWTransportError.invalidPort(endpoint.port)
        }
        let nwEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(endpoint.host),
            port: port
        )

        let conn = NWConnection(to: nwEndpoint, using: parameters)
        self.connection = conn

        try await waitUntilReady(conn, timeoutSeconds: 10)

        isRunning = true
        frameDecoder.reset()
        flowController.reset()
        metrics.reset()

        lock.withLock { _state = .ready }

        receiveTask = Task { [weak self] in await self?.runReceiveLoop() }
        sendTask = Task { [weak self] in await self?.runSendLoop() }
        heartbeatTask = Task { [weak self] in await self?.runHeartbeatLoop() }
    }

    // MARK: - Listen (Protocol Conformance)

    public func listen(port: UInt16) async throws {
        try await listen(port: port, serviceName: nil, serviceType: nil, txtRecord: nil)
    }

    // MARK: - Listen (Full)

    public func listen(
        port: UInt16,
        serviceName: String?,
        serviceType: String?,
        txtRecord: NWTXTRecord?
    ) async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NWTransportError.invalidPort(port)
        }

        let parameters = try makeServerParameters()
        let newListener = try NWListener(using: parameters, on: nwPort)

        if let name = serviceName, let type = serviceType {
            if #available(macOS 13.0, *), let record = txtRecord {
                newListener.service = NWListener.Service(
                    name: name,
                    type: type,
                    domain: nil,
                    txtRecord: record
                )
            } else {
                newListener.service = NWListener.Service(
                    name: name,
                    type: type
                )
            }
        }

        newListener.newConnectionHandler = { [weak self] newConn in
            guard let self else { return }
            self.handleIncomingConnection(newConn)
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            let completion = OneShotContinuation<Void>(continuation)
            newListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    completion.resume(returning: ())
                case .failed(let error):
                    completion.resume(throwing: error)
                case .cancelled:
                    completion.resume(throwing: NWTransportError.listenerCancelled)
                default:
                    break
                }
            }
            newListener.start(queue: .global(qos: .userInitiated))
        }

        self.listener = newListener
        lock.withLock { _state = .listening(port: port) }
    }

    // MARK: - Bonjour Transport

    public func listenWithBonjour(
        port: UInt16,
        serviceName: String,
        serviceType: String,
        txtRecord: [String: String]
    ) async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NWTransportError.invalidPort(port)
        }

        let parameters = try makeServerParameters()
        let newListener = try NWListener(using: parameters, on: nwPort)

        if #available(macOS 13.0, *) {
            var record = NWTXTRecord()
            for (key, value) in txtRecord {
                record[key] = value
            }
            newListener.service = NWListener.Service(
                name: serviceName,
                type: serviceType,
                domain: nil,
                txtRecord: record
            )
        } else {
            newListener.service = NWListener.Service(
                name: serviceName,
                type: serviceType
            )
        }

        newListener.newConnectionHandler = { [weak self] newConn in
            guard let self else { return }
            self.handleIncomingConnection(newConn)
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            let completion = OneShotContinuation<Void>(continuation)
            newListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    completion.resume(returning: ())
                case .failed(let error):
                    completion.resume(throwing: error)
                case .cancelled:
                    completion.resume(throwing: NWTransportError.listenerCancelled)
                default:
                    break
                }
            }
            newListener.start(queue: .global(qos: .userInitiated))
        }

        self.listener = newListener
        lock.withLock { _state = .listening(port: port) }
    }

    private func handleIncomingConnection(_ newConn: NWConnection) {
        connection?.cancel()
        connection = newConn

        isRunning = true
        frameDecoder.reset()
        flowController.reset()
        metrics.reset()

        newConn.start(queue: .global(qos: .userInitiated))

        lock.withLock { _state = .ready }

        receiveTask?.cancel()
        sendTask?.cancel()
        heartbeatTask?.cancel()

        receiveTask = Task { [weak self] in await self?.runReceiveLoop() }
        sendTask = Task { [weak self] in await self?.runSendLoop() }
        heartbeatTask = Task { [weak self] in await self?.runHeartbeatLoop() }
    }

    // MARK: - Send

    public func send(_ message: OutboundMessage) async throws {
        guard isRunning else { throw NWTransportError.notConnected }

        guard multiplexer.enqueue(message) else {
            throw NWTransportError.sendFailed(reason: "Multiplexer queue full")
        }
    }

    // MARK: - Disconnect

    public func disconnect(reason: TransportDisconnectReason = .userInitiated) async {
        guard isRunning else { return }
        isRunning = false

        receiveTask?.cancel()
        sendTask?.cancel()
        heartbeatTask?.cancel()
        receiveTask = nil
        sendTask = nil
        heartbeatTask = nil

        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil

        multiplexer.clearAll()
        flowController.reset()
        heartbeatController.reset()

        await messageState.finishIncoming(nil)
        lock.withLock { _state = .cancelled }
    }

    // MARK: - Wait Until Ready

    private func waitUntilReady(_ connection: NWConnection, timeoutSeconds: TimeInterval) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    let completion = OneShotContinuation<Void>(continuation)
                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            completion.resume(returning: ())
                        case .failed(let error):
                            completion.resume(throwing: error)
                        case .cancelled:
                            completion.resume(throwing: NWTransportError.connectionCancelled)
                        default:
                            break
                        }
                    }
                    connection.start(queue: .global(qos: .userInitiated))
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw NWTransportError.connectionTimeout
            }

            _ = try await group.next()
            group.cancelAll()
        }
    }

    // MARK: - Receive Loop

    private func runReceiveLoop() async {
        while isRunning {
            do {
                let data = try await receiveRawData(maxSize: 65_536)
                metrics.recordBytesReceived(data.count)
                frameDecoder.append(data: data)

                while let result = frameDecoder.nextFrame() {
                    switch result {
                    case .success(let frame):
                        let msg = InboundMessage(header: frame.header, payload: frame.payload)
                        interceptTransportMessage(msg)
                        metrics.recordFrameReceived()
                    case .failure:
                        metrics.recordReceiveError()
                    }
                }
            } catch {
                if isRunning {
                    metrics.recordReceiveError()
                    isRunning = false
                    await messageState.finishIncoming(error)
                }
                break
            }
        }
    }

    // MARK: - Send Loop

    private func runSendLoop() async {
        while isRunning {
            guard let item = multiplexer.nextMessage() else {
                try? await Task.sleep(nanoseconds: 1_000_000)
                continue
            }

            do {
                try await sendRawFrame(item.message)
                flowController.didSend(channel: item.message.streamChannel, size: item.message.payload.count)
                metrics.recordBytesSent(item.message.payload.count + VanguardProtocolConstants.headerSize)
                metrics.recordFrameSent()
            } catch {
                metrics.recordSendError()
                if isRunning {
                    try? await Task.sleep(nanoseconds: 5_000_000)
                }
            }
        }
    }

    // MARK: - Heartbeat Loop (Separate Task)

    private func runHeartbeatLoop() async {
        while isRunning {
            try? await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))
            guard isRunning else { break }

            let ping = heartbeatController.createPing()
            if let data = try? JSONEncoder().encode(ping) {
                let msg = OutboundMessage(messageType: .heartbeat, streamChannel: .heartbeat, payload: data)
                try? await sendRawFrame(msg)
            }

            if case .stalled = heartbeatController.currentState {
                isRunning = false
                await messageState.finishIncoming(NWTransportError.receiveFailed(reason: "Heartbeat stalled"))
                break
            }
        }
    }

    // MARK: - Intercept Transport-Level Messages

    private func interceptTransportMessage(_ message: InboundMessage) {
        switch message.header.messageType {
        case .heartbeat:
            handleIncomingHeartbeat(message)
        case .heartbeatAck:
            handleIncomingHeartbeatAck(message)
        case .flowControlAck:
            handleIncomingFlowControlAck(message)
        default:
            let channel = message.header.streamChannel
            if channel != .video, channel != .heartbeat {
                sendFlowControlAck(channel: channel, bytesReceived: UInt32(message.payload.count))
            }
            Task { await messageState.emitIncoming(message) }
        }
    }

    private func sendFlowControlAck(channel: StreamChannel, bytesReceived: UInt32) {
        let ack = FlowControlAckPayload(channel: channel.rawValue, bytesReceived: bytesReceived)
        if let data = try? JSONEncoder().encode(ack) {
            let msg = OutboundMessage(messageType: .flowControlAck, streamChannel: .control, payload: data)
            Task { try? await sendRawFrame(msg) }
        }
    }

    private func handleIncomingFlowControlAck(_ message: InboundMessage) {
        guard let ack = try? JSONDecoder().decode(FlowControlAckPayload.self, from: message.payload),
              let channel = StreamChannel(rawValue: ack.channel) else { return }
        flowController.didReceiveAck(channel: channel, size: Int(ack.bytesReceived))
    }

    private func handleIncomingHeartbeat(_ message: InboundMessage) {
        guard let ping = try? JSONDecoder().decode(HeartbeatPayload.self, from: message.payload) else { return }
        let ack = HeartbeatPayload(timestampNanos: ping.timestampNanos, sequence: ping.sequence)
        if let data = try? JSONEncoder().encode(ack) {
            let msg = OutboundMessage(messageType: .heartbeatAck, streamChannel: .heartbeat, payload: data)
            Task { try? await sendRawFrame(msg) }
        }
    }

    private func handleIncomingHeartbeatAck(_ message: InboundMessage) {
        guard let pong = try? JSONDecoder().decode(HeartbeatPayload.self, from: message.payload) else { return }
        heartbeatController.handlePong(pong)
    }

    // MARK: - Raw Send/Receive

    private func sendRawFrame(_ message: OutboundMessage) async throws {
        guard let conn = connection else { throw NWTransportError.notConnected }

        let header = ProtocolHeader(
            messageType: message.messageType,
            flags: message.flags,
            streamChannel: message.streamChannel
        )
        let frame = ProtocolFrame(header: header, payload: message.payload)
        let data = frame.totalData

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: NWTransportError.sendFailed(reason: error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveRawData(maxSize: Int) async throws -> Data {
        guard let conn = connection else { throw NWTransportError.notConnected }

        return try await withCheckedThrowingContinuation { continuation in
            conn.receive(minimumIncompleteLength: 1, maximumLength: maxSize) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: NWTransportError.receiveFailed(reason: error.localizedDescription))
                } else if let data = data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: NWTransportError.receiveFailed(reason: "Connection closed"))
                } else {
                    continuation.resume(throwing: NWTransportError.receiveFailed(reason: "No data"))
                }
            }
        }
    }

    // MARK: - TLS Parameters

    private func makeClientParameters() throws -> NWParameters {
        if useTLS {
            let tls = NWProtocolTLS.Options()
            let tcp = NWProtocolTCP.Options()
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 15
            tcp.keepaliveInterval = 5
            tcp.keepaliveCount = 3
            tcp.noDelay = true

            if let expectedFingerprint = expectedPeerFingerprint, let certManager = tlsCertificateManager {
                let manager = certManager
                sec_protocol_options_set_verify_block(
                    tls.securityProtocolOptions,
                    { metadata, trust, completionHandler in
                        let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
                        let count = SecTrustGetCertificateCount(secTrust)
                        for i in 0..<count {
                            if let cert = SecTrustGetCertificateAtIndex(secTrust, i) {
                                let certData = SecCertificateCopyData(cert) as Data
                                let fingerprint = Data(CryptoKit.SHA256.hash(data: certData))
                                if fingerprint == expectedFingerprint {
                                    completionHandler(true)
                                    return
                                }
                            }
                        }
                        completionHandler(false)
                    },
                    .main
                )
            }

            return NWParameters(tls: tls, tcp: tcp)
        } else {
            return NWParameters.tcp
        }
    }

    private func makeServerParameters() throws -> NWParameters {
        if useTLS {
            let tls = NWProtocolTLS.Options()
            let tcp = NWProtocolTCP.Options()
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 15
            tcp.keepaliveInterval = 5
            tcp.keepaliveCount = 3
            tcp.noDelay = true
            return NWParameters(tls: tls, tcp: tcp)
        } else {
            return NWParameters.tcp
        }
    }

    // MARK: - Metrics

    public func networkSnapshot() -> NetworkMetricsSnapshot {
        metrics.snapshot(
            rtt: heartbeatController.currentSmoothedRTT,
            jitter: heartbeatController.currentJitter,
            state: heartbeatController.currentState,
            queueDepth: multiplexer.totalPendingCount()
        )
    }
}

// MARK: - Incoming Message State (Actor)

private actor IncomingMessageState {
    private var incomingContinuation: AsyncThrowingStream<InboundMessage, Error>.Continuation?

    func setIncomingContinuation(_ cont: AsyncThrowingStream<InboundMessage, Error>.Continuation) {
        self.incomingContinuation = cont
    }

    func continuationFinished() {
        incomingContinuation = nil
    }

    func emitIncoming(_ message: InboundMessage) {
        incomingContinuation?.yield(message)
    }

    func finishIncoming(_ error: Error?) {
        if let error = error {
            incomingContinuation?.finish(throwing: error)
        } else {
            incomingContinuation?.finish()
        }
    }
}
