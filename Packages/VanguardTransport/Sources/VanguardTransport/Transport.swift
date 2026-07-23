import Foundation
import VanguardDomain
import VanguardProtocol

// MARK: - Transport Protocol

public protocol VanguardTransport: Sendable {
    var incomingMessages: AsyncThrowingStream<InboundMessage, Error> { get }

    func connect(to endpoint: NodeEndpoint) async throws
    func listen(port: UInt16) async throws
    func send(_ message: OutboundMessage) async throws
    func disconnect(reason: DisconnectReason) async
}

// MARK: - Transport Factory

public protocol TransportFactory: Sendable {
    func createTransport() -> VanguardTransport
}
