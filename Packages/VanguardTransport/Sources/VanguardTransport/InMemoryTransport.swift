import Foundation
import VanguardDomain
import VanguardProtocol

// MARK: - In-Memory Transport Actor (for testing)

public actor InMemoryTransportActor {
    private var connected = false
    private var sentMessages: [OutboundMessage] = []
    private let incomingContinuation: AsyncThrowingStream<InboundMessage, Error>.Continuation

    init(incomingContinuation: AsyncThrowingStream<InboundMessage, Error>.Continuation) {
        self.incomingContinuation = incomingContinuation
    }

    func setConnected(_ value: Bool) {
        connected = value
    }

    func isConnected() -> Bool {
        return connected
    }

    func appendSentMessage(_ message: OutboundMessage) {
        sentMessages.append(message)
    }

    func getSentMessages() -> [OutboundMessage] {
        return sentMessages
    }
}

// MARK: - In-Memory Transport (for testing)

public final class InMemoryTransport: VanguardTransport, @unchecked Sendable {
    private let incomingContinuation: AsyncThrowingStream<InboundMessage, Error>.Continuation
    public let incomingMessages: AsyncThrowingStream<InboundMessage, Error>
    private let state: InMemoryTransportActor

    public init() {
        let (stream, continuation) = AsyncThrowingStream<InboundMessage, Error>.makeStream()
        self.incomingMessages = stream
        self.incomingContinuation = continuation
        self.state = InMemoryTransportActor(incomingContinuation: continuation)
    }

    public func connect(to endpoint: NodeEndpoint) async throws {
        await state.setConnected(true)
    }

    public func listen(port: UInt16) async throws {
        await state.setConnected(true)
    }

    public func send(_ message: OutboundMessage) async throws {
        let isConnected = await state.isConnected()
        guard isConnected else {
            throw TransportError.connectionRefused
        }
        await state.appendSentMessage(message)
    }

    public func disconnect(reason: DisconnectReason) async {
        await state.setConnected(false)
        incomingContinuation.finish()
    }

    // Testing helpers

    public func simulateIncoming(_ message: InboundMessage) {
        incomingContinuation.yield(message)
    }

    public func simulateError(_ error: Error) {
        incomingContinuation.finish(throwing: error)
    }

    public func getSentMessages() async -> [OutboundMessage] {
        return await state.getSentMessages()
    }

    public func isConnected() async -> Bool {
        return await state.isConnected()
    }
}

// MARK: - In-Memory Transport Factory

public struct InMemoryTransportFactory: TransportFactory {
    public init() {}

    public func createTransport() -> VanguardTransport {
        return InMemoryTransport()
    }
}
