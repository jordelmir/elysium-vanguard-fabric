import Foundation
import Network
import VanguardDomain
import VanguardProtocol

@available(macOS 12.0, *)
public final class NetworkTransport: VanguardTransport, @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let useTLS: Bool
    private var connection: NWConnection?
    private var listener: NWListener?
    private var receiveTask: Task<Void, Never>?
    private let heartbeatInterval: TimeInterval
    private var isRunning = false
    private let state: ConnectionState

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
        self.state = ConnectionState()
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

        let nwEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(endpoint.host),
            port: NWEndpoint.Port(rawValue: endpoint.port)!
        )

        let connection = NWConnection(to: nwEndpoint, using: parameters)
        self.connection = connection

        let settledFlag = AtomicFlag()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.stateUpdateHandler = { connectionState in
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
            connection.start(queue: .global(qos: .userInitiated))

            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if !settledFlag.get() {
                    settledFlag.set()
                    connection.cancel()
                    continuation.resume()
                }
            }
        }

        guard connection.state == .ready else {
            throw TransportError.connectFailed
        }

        isRunning = true
        receiveTask = Task { await startReceiving() }
        await startHeartbeat()
    }

    public func send(_ message: OutboundMessage) async throws {
        guard let connection = connection else {
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
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: TransportError.sendFailed(reason: error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func disconnect(reason: DisconnectReason) async {
        isRunning = false
        receiveTask?.cancel()
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
    }

    public func listen(port: UInt16) async throws {
        let parameters: NWParameters
        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            parameters = NWParameters(tls: tlsOptions)
        } else {
            parameters = NWParameters.tcp
        }

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] newConnection in
            guard let self = self else { return }
            self.connection = newConnection
            self.isRunning = true
            self.receiveTask = Task { await self.startReceiving() }
            newConnection.start(queue: .global(qos: .userInitiated))
        }

        listener.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - Private

    private func startReceiving() async {
        while isRunning {
            do {
                let data = try await receiveData(maxSize: 65_536)
                let frameResult = ProtocolFrame.parse(from: data)
                switch frameResult {
                case .success(let frame):
                    let message = InboundMessage(header: frame.header, payload: frame.payload)
                    await state.emitIncoming(message)
                case .failure(let error):
                    await state.finishIncoming(error)
                }
            } catch {
                if isRunning {
                    await state.finishIncoming(error)
                    isRunning = false
                }
                break
            }
        }
    }

    private func receiveData(maxSize: Int) async throws -> Data {
        guard let connection = connection else {
            throw TransportError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxSize) { data, _, isComplete, error in
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
        }
    }
}

// MARK: - Thread-Safe Atomic Flag

private final class AtomicFlag: @unchecked Sendable {
    private var value: Int32 = 0

    func get() -> Bool {
        OSAtomicOr32Barrier(0, &value) != 0
    }

    func set() {
        _ = OSAtomicOr32Barrier(1, &value)
    }
}

// MARK: - Connection State (actor for safe continuation access)

private actor ConnectionState {
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
