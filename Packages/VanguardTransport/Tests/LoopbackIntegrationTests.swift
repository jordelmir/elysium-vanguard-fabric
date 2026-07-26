import XCTest
import Foundation
@testable import VanguardTransport
@testable import VanguardProtocol
@testable import VanguardDomain

@available(macOS 12.0, *)
final class LoopbackIntegrationTests: XCTestCase {

    func testListenAndConnect() async throws {
        let port: UInt16 = 49500
        let listener = NetworkTransport(port: port, useTLS: false)
        let client = NetworkTransport(useTLS: false)

        defer {
            Task { await listener.disconnect(reason: .userInitiated) }
            Task { await client.disconnect(reason: .userInitiated) }
        }

        let listenExp = expectation(description: "listener ready")
        let messageExp = expectation(description: "message received")

        Task {
            try await listener.listen(port: port)
            listenExp.fulfill()

            for try await msg in await listener.incomingMessages {
                if msg.header.messageType == .hello {
                    messageExp.fulfill()
                    break
                }
            }
        }

        await fulfillment(of: [listenExp], timeout: 5)

        let connectExp = expectation(description: "client connected")

        Task {
            let endpoint = NodeEndpoint(host: "127.0.0.1", port: port)
            try await client.connect(to: endpoint)
            connectExp.fulfill()

            let helloPayload = HelloPayload(
                protocolVersion: .v1,
                nodeID: NodeID(),
                displayName: "TestConsole",
                architecture: .arm64,
                osFamily: .macOS,
                osVersion: "14.0"
            )
            let data = try JSONEncoder().encode(helloPayload)
            let msg = OutboundMessage(messageType: .hello, payload: data)
            try await client.send(msg)
        }

        await fulfillment(of: [connectExp, messageExp], timeout: 10)
    }

    func testBidirectionalMessaging() async throws {
        let port: UInt16 = 49501
        let listener = NetworkTransport(port: port, useTLS: false)
        let client = NetworkTransport(useTLS: false)

        defer {
            Task { await listener.disconnect(reason: .userInitiated) }
            Task { await client.disconnect(reason: .userInitiated) }
        }

        let listenExp = expectation(description: "listener ready")
        let nodeReceivedExp = expectation(description: "node received hello")
        let clientReceivedExp = expectation(description: "client received ack")

        Task {
            try await listener.listen(port: port)
            listenExp.fulfill()

            for try await msg in await listener.incomingMessages {
                if msg.header.messageType == .hello {
                    let ackPayload = HelloAckPayload(
                        protocolVersion: .v1,
                        nodeID: NodeID(),
                        acceptedVersion: .v1
                    )
                    let data = try JSONEncoder().encode(ackPayload)
                    let ackMsg = OutboundMessage(messageType: .helloAck, payload: data)
                    try await listener.send(ackMsg)
                    nodeReceivedExp.fulfill()
                    break
                }
            }
        }

        await fulfillment(of: [listenExp], timeout: 5)

        Task {
            let endpoint = NodeEndpoint(host: "127.0.0.1", port: port)
            try await client.connect(to: endpoint)

            let helloPayload = HelloPayload(
                protocolVersion: .v1,
                nodeID: NodeID(),
                displayName: "TestConsole",
                architecture: .arm64,
                osFamily: .macOS,
                osVersion: "14.0"
            )
            let data = try JSONEncoder().encode(helloPayload)
            let msg = OutboundMessage(messageType: .hello, payload: data)
            try await client.send(msg)

            for try await msg in await client.incomingMessages {
                if msg.header.messageType == .helloAck {
                    clientReceivedExp.fulfill()
                    break
                }
            }
        }

        await fulfillment(of: [nodeReceivedExp, clientReceivedExp], timeout: 10)
    }

    func testLargePayloadRoundtrip() async throws {
        let port: UInt16 = 49502
        let listener = NetworkTransport(port: port, useTLS: false)
        let client = NetworkTransport(useTLS: false)

        defer {
            Task { await listener.disconnect(reason: .userInitiated) }
            Task { await client.disconnect(reason: .userInitiated) }
        }

        let largeData = Data(repeating: 0xAB, count: 100_000)
        let listenExp = expectation(description: "listener ready")
        let receivedExp = expectation(description: "large payload received")

        Task {
            try await listener.listen(port: port)
            listenExp.fulfill()

            for try await msg in await listener.incomingMessages {
                if msg.header.messageType == .videoConfiguration {
                    XCTAssertEqual(msg.payload.count, 100_000)
                    XCTAssertEqual(msg.payload, largeData)
                    receivedExp.fulfill()
                    break
                }
            }
        }

        await fulfillment(of: [listenExp], timeout: 5)

        Task {
            let endpoint = NodeEndpoint(host: "127.0.0.1", port: port)
            try await client.connect(to: endpoint)

            let msg = OutboundMessage(
                messageType: .videoConfiguration,
                streamChannel: .video,
                payload: largeData
            )
            try await client.send(msg)
        }

        await fulfillment(of: [receivedExp], timeout: 10)
    }

    func testDisconnectCleansUp() async throws {
        let port: UInt16 = 49503
        let listener = NetworkTransport(port: port, useTLS: false)
        let client = NetworkTransport(useTLS: false)

        let listenExp = expectation(description: "listener ready")

        Task {
            try await listener.listen(port: port)
            listenExp.fulfill()
        }

        await fulfillment(of: [listenExp], timeout: 5)

        Task {
            let endpoint = NodeEndpoint(host: "127.0.0.1", port: port)
            try await client.connect(to: endpoint)
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        await client.disconnect(reason: .userInitiated)
        XCTAssertEqual(client.currentState, .cancelled)

        await listener.disconnect(reason: .userInitiated)
        XCTAssertEqual(listener.currentState, .cancelled)
    }
}
