import XCTest
@testable import VanguardProtocol
@testable import VanguardDomain
import VanguardTestSupport

final class ProtocolTypesTests: XCTestCase {
    func testMessageTypeRawValues() {
        XCTAssertEqual(MessageType.hello.rawValue, 0x0001)
        XCTAssertEqual(MessageType.helloAck.rawValue, 0x0002)
        XCTAssertEqual(MessageType.pairingRequest.rawValue, 0x0010)
        XCTAssertEqual(MessageType.videoFrame.rawValue, 0x0101)
        XCTAssertEqual(MessageType.inputEvent.rawValue, 0x0200)
        XCTAssertEqual(MessageType.error.rawValue, 0x0FFF)
    }

    func testMessageFlagsOptionSet() {
        var flags: MessageFlags = [.requiresResponse, .urgent]
        XCTAssertTrue(flags.contains(.requiresResponse))
        XCTAssertTrue(flags.contains(.urgent))
        XCTAssertFalse(flags.contains(.isResponse))
    }

    func testStreamChannelRawValues() {
        XCTAssertEqual(StreamChannel.control.rawValue, 0)
        XCTAssertEqual(StreamChannel.inputReliable.rawValue, 1)
        XCTAssertEqual(StreamChannel.video.rawValue, 3)
        XCTAssertEqual(StreamChannel.terminal.rawValue, 4)
        XCTAssertEqual(StreamChannel.heartbeat.rawValue, 8)
    }

    func testStreamChannelMaxPayloadSizes() {
        XCTAssertEqual(StreamChannel.control.maxPayloadSize, VanguardProtocolConstants.maxControlPayload)
        XCTAssertEqual(StreamChannel.terminal.maxPayloadSize, VanguardProtocolConstants.maxTerminalChunk)
        XCTAssertEqual(StreamChannel.video.maxPayloadSize, VanguardProtocolConstants.maxVideoAccessUnit)
        XCTAssertEqual(StreamChannel.files.maxPayloadSize, VanguardProtocolConstants.maxFileChunk)
        XCTAssertEqual(StreamChannel.heartbeat.maxPayloadSize, 64)
    }

    func testProtocolConstants() {
        XCTAssertEqual(VanguardProtocolConstants.magic, [0x45, 0x56, 0x46, 0x42])
        XCTAssertEqual(VanguardProtocolConstants.headerSize, 25)
        XCTAssertEqual(VanguardProtocolConstants.maxControlPayload, 1 * 1024 * 1024)
        XCTAssertEqual(VanguardProtocolConstants.maxTerminalChunk, 64 * 1024)
        XCTAssertEqual(VanguardProtocolConstants.maxVideoAccessUnit, 8 * 1024 * 1024)
    }
}
