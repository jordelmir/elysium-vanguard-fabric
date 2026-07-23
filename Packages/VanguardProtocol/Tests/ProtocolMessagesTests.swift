import XCTest
@testable import VanguardProtocol
@testable import VanguardDomain
import VanguardTestSupport

final class ProtocolMessagesTests: XCTestCase {
    func testHelloPayloadCodable() throws {
        let payload = HelloPayload(
            nodeID: NodeID(),
            displayName: "Test",
            architecture: .arm64,
            osFamily: .macOS,
            osVersion: "14.0"
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(HelloPayload.self, from: data)
        XCTAssertEqual(payload.displayName, decoded.displayName)
    }

    func testHelloAckPayloadCodable() throws {
        let payload = HelloAckPayload(
            nodeID: NodeID(),
            acceptedVersion: .v1
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(HelloAckPayload.self, from: data)
        XCTAssertEqual(payload.nodeID, decoded.nodeID)
    }

    func testPairingRequestPayloadCodable() throws {
        let payload = PairingRequestPayload(
            consoleID: NodeID(),
            consoleDisplayName: "Console",
            signingPublicKey: Data(repeating: 0x01, count: 32),
            agreementPublicKey: Data(repeating: 0x02, count: 32)
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PairingRequestPayload.self, from: data)
        XCTAssertEqual(payload.consoleDisplayName, decoded.consoleDisplayName)
    }

    func testPairingChallengePayloadCodable() throws {
        let payload = PairingChallengePayload(
            challengeCode: "123456",
            expiresAtNanos: 1_000_000_000,
            fingerprint: Data(repeating: 0xFF, count: 32)
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PairingChallengePayload.self, from: data)
        XCTAssertEqual(payload.challengeCode, decoded.challengeCode)
    }

    func testVideoConfigurationPayloadCodable() throws {
        let payload = VideoConfigurationPayload(
            width: 1920,
            height: 1080,
            fps: 30,
            bitrate: 8_000_000,
            keyframeInterval: 2
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(VideoConfigurationPayload.self, from: data)
        XCTAssertEqual(payload.width, decoded.width)
        XCTAssertEqual(payload.fps, decoded.fps)
    }

    func testTerminalOpenPayloadCodable() throws {
        let payload = TerminalOpenPayload(
            sessionID: TerminalSessionID(),
            configuration: TerminalConfiguration(columns: 120, rows: 40)
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(TerminalOpenPayload.self, from: data)
        XCTAssertEqual(payload.sessionID, decoded.sessionID)
    }

    func testErrorPayloadCodable() throws {
        let payload = ErrorPayload(
            code: 404,
            message: "Not found",
            relatedOperationID: OperationID()
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ErrorPayload.self, from: data)
        XCTAssertEqual(payload.code, decoded.code)
    }

    func testCapabilityRequestPayloadCodable() throws {
        let payload = CapabilityRequestPayload(
            capabilities: [.screenView, .terminalOpen],
            reason: "Need screen access"
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CapabilityRequestPayload.self, from: data)
        XCTAssertEqual(payload.capabilities, decoded.capabilities)
    }
}
