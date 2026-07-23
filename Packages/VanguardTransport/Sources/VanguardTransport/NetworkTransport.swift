import Foundation
import Network
import VanguardDomain
import VanguardProtocol

@available(macOS 12.0, *)
public final class NetworkTransport: VanguardTransport, @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let useTLS: Bool
    private let heartbeatInterval: TimeInterval
    private let state: IncomingMessageState
    private let lock = NSLock()
    private var _connection: NWConnection?
    private var _listener: NWListener?
    private var _receiveTask: Task<Void, Never>?
    private var _sendTask: Task<Void, Never>?
    private var _isRunning = false

    let frameDecoder = FrameDecoder()
    let multiplexer = ChannelMultiplexer()
    let flowController = FlowController()
    let heartbeatController = HeartbeatController()
    let reconnectionManager = ReconnectionManager()
    let metrics = NetworkMetricsCollector()

    private var connection: NWConnection? {
        get { lock.withLock { _connection } }
        set { lock.withLock { _connection = newValue } }
    }

    private var listener: NWListener? {
        get { lock.withLock { _listener } }
        set { lock.withLock { _listener = newValue } }
    }

    private var receiveTask: Task<Void, Never>? {
        get { lock.withLock { _receiveTask } }
        set { lock.withLock { _receiveTask = newValue } }
    }

    private var sendTask: Task<Void, Never>? {
        get { lock.withLock { _sendTask } }
        set { lock.withLock { _sendTask = newValue } }
    }

    private var isRunning: Bool {
        get { lock.withLock { _isRunning } }
        set { lock.withLock { _isRunning = newValue } }
    }

    public init(
        host: String,
        port: UInt16,
        useTLS: Bool = true,
        heartbeatInterval: TimeInterval = 15.0
    ) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.heartbeatInterval = heartbeatInterval
        self.state = IncomingMessageState()
    }

    public var incomingMessages: AsyncThrowingStream<InboundMessage, Error> {
        let stateRef = self.state
        return AsyncThrowingStream { continuation in
            Task {
                await stateRef.setIncomingContinuation(continuation)
            }
            continuation.onTermination = { @Sendable _ in
                Task {
                    await stateRef.continuationFinished()
                }
            }
        }
    }

    public func connect(to endpoint: NodeEndpoint) async throws {
        let parameters: NWParameters
        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            parameters = NWParameters(tls: tlsOptions)
        } else {
            parameters = NWParameters.tcp
        }

        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            throw TransportError.connectFailed
        }
        let nwEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(endpoint.host),
            port: port
        )

        let newConnection = NWConnection(to: nwEndpoint, using: parameters)
        self.connection = newConnection

        let settledFlag = AtomicFlag()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            newConnection.stateUpdateHandler = { connectionState in
                guard !settledFlag.get() else { return }
                switch connectionState {
                case .ready:
                    settledFlag.set()
                    continuation.resume()
                case .failed:
                    settledFlag.set()
                    continuation.resume()
                default:
                    break
                }
            }
            newConnection.start(queue: .global(qos: .userInitiated))

            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if !settledFlag.get() {
                    settledFlag.set()
                    newConnection.cancel()
                    continuation.resume()
                }
            }
        }

        guard newConnection.state == .ready else {
            throw TransportError.connectFailed
        }

        isRunning = true
        frameDecoder.reset()
        flowController.reset()
        reconnectionManager.markConnected()
        metrics.reset()

        receiveTask = Task { await startReceiving() }
        sendTask = Task { await startSendLoop() }
        await startHeartbeat()
    }

    public func send(_ message: OutboundMessage) async throws {
        guard isRunning else {
            throw TransportError.notConnected
        }

        guard flowController.canSend(channel: message.streamChannel, size: message.payload.count) else {
            throw TransportError.sendFailed(reason: "Flow control: channel backpressure")
        }

        guard multiplexer.enqueue(message) else {
            throw TransportError.sendFailed(reason: "Multiplexer: queue full")
        }

        return try await withCheckedThrowingContinuation { continuation in
            continuation.resume()
        }
    }

    public func disconnect(reason: DisconnectReason) async {
        isRunning = false
        receiveTask?.cancel()
        receiveTask = nil
        sendTask?.cancel()
        sendTask = nil
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        multiplexer.clearAll()
        flowController.reset()
        heartbeatController.reset()
    }

    public func listen(port: UInt16) async throws {
        let parameters: NWParameters
        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            parameters = NWParameters(tls: tlsOptions)
        } else {
            parameters = NWParameters.tcp
        }

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw TransportError.connectFailed
        }
        let newListener = try NWListener(using: parameters, on: nwPort)
        self.listener = newListener

        newListener.newConnectionHandler = { [weak self] newConnection in
            guard let self else { return }
            self.connection = newConnection
            self.isRunning = true
            self.frameDecoder.reset()
            self.flowController.reset()
            self.reconnectionManager.markConnected()
            self.metrics.reset()
            self.receiveTask = Task { await self.startReceiving() }
            self.sendTask = Task { await self.startSendLoop() }
            newConnection.start(queue: .global(qos: .userInitiated))
        }

        newListener.start(queue: .global(qos: .userInitiated))
    }

    private func startReceiving() async {
        while isRunning {
            do {
                let data = try await receiveData(maxSize: 65_536)
                metrics.recordBytesReceived(data.count)
                frameDecoder.append(data: data)

                while let result = frameDecoder.nextFrame() {
                    switch result {
                    case .success(let frame):
                        metrics.recordFrameReceived()
                        let message = InboundMessage(header: frame.header, payload: frame.payload)
                        await state.emitIncoming(message)
                    case .failure(let error):
                        metrics.recordReceiveError()
                        await state.finishIncoming(error)
                    }
                }
            } catch {
                if isRunning {
                    metrics.recordReceiveError()
                    await state.finishIncoming(error)
                    isRunning = false
                }
                break
            }
        }
    }

    private func startSendLoop() async {
        while isRunning {
            guard let item = multiplexer.nextMessage() else {
                try? await Task.sleep(nanoseconds: 1_000_000)
                continue
            }

            guard flowController.canSend(channel: item.message.streamChannel, size: item.message.payload.count) else {
                multiplexer.enqueue(item.message)
                try? await Task.sleep(nanoseconds: 5_000_000)
                continue
            }

            do {
                try await sendRaw(item.message)
                flowController.didSend(channel: item.message.streamChannel, size: item.message.payload.count)
                metrics.recordBytesSent(item.message.payload.count + VanguardProtocolConstants.headerSize)
                metrics.recordFrameSent()
            } catch {
                metrics.recordSendError()
            }
        }
    }

    private func sendRaw(_ message: OutboundMessage) async throws {
        guard let conn = connection else {
            throw TransportError.notConnected
        }

        let header = ProtocolHeader(
            messageType: message.messageType,
            flags: message.flags,
            streamChannel: message.streamChannel
        )
        let frame = ProtocolFrame(header: header, payload: message.payload)
        let data = frame.totalData

        return try await withCheckedThrowingContinuation { continuation in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: TransportError.sendFailed(reason: error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveData(maxSize: Int) async throws -> Data {
        guard let conn = connection else {
            throw TransportError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            conn.receive(minimumIncompleteLength: 1, maximumLength: maxSize) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: TransportError.receiveFailed(reason: error.localizedDescription))
                } else if let data = data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: TransportError.receiveFailed(reason: "Connection closed"))
                } else {
                    continuation.resume(throwing: TransportError.receiveFailed(reason: "No data"))
                }
            }
        }
    }

    private func startHeartbeat() async {
        while isRunning {
            try? await Task.sleep(nanoseconds: UInt64(heartbeatInterval * 1_000_000_000))
            guard isRunning else { break }

            let ping = heartbeatController.createPing()
            let payload = try? JSONEncoder().encode(ping)
            if let data = payload {
                let msg = OutboundMessage(messageType: .heartbeat, streamChannel: .heartbeat, payload: data)
                try? await sendRaw(msg)
            }

            if case .stalled = heartbeatController.currentState {
                isRunning = false
                await state.finishIncoming(TransportError.receiveFailed(reason: "Heartbeat stalled"))
                break
            }
        }
    }

    public func handleHeartbeatAck(_ payload: HeartbeatPayload) {
        heartbeatController.handlePong(payload)
    }

    public func networkSnapshot() -> NetworkMetricsSnapshot {
        metrics.snapshot(
            rtt: heartbeatController.currentSmoothedRTT,
            jitter: heartbeatController.currentJitter,
            state: heartbeatController.currentState,
            queueDepth: multiplexer.totalPendingCount()
        )
    }
}

private final class AtomicFlag: @unchecked Sendable {
    private var locked = false
    private let lock = NSLock()

    func get() -> Bool {
        lock.withLock { locked }
    }

    func set() {
        lock.withLock { locked = true }
    }
}

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

    func finishIncoming(_ error: Error) {
        incomingContinuation?.finish(throwing: error)
    }
}
