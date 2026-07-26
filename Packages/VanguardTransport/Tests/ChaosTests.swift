import XCTest
@testable import VanguardTransport
@testable import VanguardDomain
@testable import VanguardProtocol

final class ChaosTests: XCTestCase {
    func testInMemoryTransportDisconnectReconnect() async throws {
        let transport = InMemoryTransport()
        let endpoint = NodeEndpoint(host: "127.0.0.1", port: 49494)
        try await transport.listen(port: 49494)
        try await transport.connect(to: endpoint)

        let message = OutboundMessage(messageType: .hello, payload: Data(repeating: 0x01, count: 100))
        try await transport.send(message)

        await transport.disconnect(reason: .userInitiated)

        try await transport.connect(to: endpoint)
        try await transport.send(OutboundMessage(messageType: .heartbeat, payload: Data()))

        await transport.disconnect(reason: .userInitiated)
    }

    func testMultipleRapidConnectDisconnect() async throws {
        let transport = InMemoryTransport()
        let endpoint = NodeEndpoint(host: "127.0.0.1", port: 49494)
        try await transport.listen(port: 49494)

        for _ in 0..<5 {
            try await transport.connect(to: endpoint)
            try await transport.send(OutboundMessage(messageType: .hello, payload: Data()))
            await transport.disconnect(reason: .userInitiated)
        }
    }

    func testLargeMessageHandling() async throws {
        let transport = InMemoryTransport()
        let endpoint = NodeEndpoint(host: "127.0.0.1", port: 49494)
        try await transport.listen(port: 49494)
        try await transport.connect(to: endpoint)

        let largePayload = Data(repeating: 0xAB, count: 1024 * 1024)
        let message = OutboundMessage(messageType: .videoFrame, streamChannel: .video, payload: largePayload)
        try await transport.send(message)

        await transport.disconnect(reason: .userInitiated)
    }
}
