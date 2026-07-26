import XCTest
@testable import VanguardTransport
@testable import VanguardDomain
@testable import VanguardProtocol
import VanguardTestSupport

final class InMemoryTransportTests: XCTestCase {
    func testConnectAndDisconnect() async throws {
        let transport = InMemoryTransport()
        let endpoint = TestHelpers.makeEndpoint()

        try await transport.connect(to: endpoint)
        let connected = await transport.isConnected()
        XCTAssertTrue(connected)

        await transport.disconnect(reason: .userInitiated)
        let disconnected = await transport.isConnected()
        XCTAssertFalse(disconnected)
    }

    func testSendMessageWhenConnected() async throws {
        let transport = InMemoryTransport()
        let endpoint = TestHelpers.makeEndpoint()

        try await transport.connect(to: endpoint)
        let message = OutboundMessage(messageType: .hello)
        try await transport.send(message)

        let sent = await transport.getSentMessages()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].messageType, .hello)
    }

    func testSendMessageWhenDisconnectedThrows() async throws {
        let transport = InMemoryTransport()
        let message = OutboundMessage(messageType: .hello)

        do {
            try await transport.send(message)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is NWTransportError)
        }
    }

    func testSimulateIncomingMessage() async throws {
        let transport = InMemoryTransport()
        let endpoint = TestHelpers.makeEndpoint()
        try await transport.connect(to: endpoint)

        let header = ProtocolHeader(messageType: .hello, payloadLength: 0)
        let inbound = InboundMessage(header: header, payload: Data())
        transport.simulateIncoming(inbound)

        var received = false
        for try await message in transport.incomingMessages {
            XCTAssertEqual(message.header.messageType, .hello)
            received = true
            break
        }
        XCTAssertTrue(received)
    }

    func testMultipleSentMessages() async throws {
        let transport = InMemoryTransport()
        try await transport.connect(to: TestHelpers.makeEndpoint())

        for i in 0..<5 {
            let msg = OutboundMessage(messageType: .hello, payload: Data([UInt8(i)]))
            try await transport.send(msg)
        }

        let sent = await transport.getSentMessages()
        XCTAssertEqual(sent.count, 5)
    }
}
