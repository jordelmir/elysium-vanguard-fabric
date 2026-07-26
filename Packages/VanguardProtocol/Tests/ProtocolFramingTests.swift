import XCTest
@testable import VanguardProtocol
@testable import VanguardDomain
import VanguardTestSupport

final class ProtocolFramingTests: XCTestCase {
    func testHeaderCreation() {
        let header = ProtocolHeader(
            messageType: .hello,
            flags: .none,
            streamChannel: .control,
            sequenceNumber: 0,
            payloadLength: 100
        )
        XCTAssertEqual(header.protocolVersion, 1)
        XCTAssertEqual(header.messageType, .hello)
        XCTAssertEqual(header.payloadLength, 100)
    }

    func testHeaderSerialization() {
        let header = ProtocolHeader(
            messageType: .hello,
            streamChannel: .control,
            sequenceNumber: 42,
            payloadLength: 0
        )
        let data = header.headerData
        XCTAssertEqual(data.count, VanguardProtocolConstants.headerSize)
    }

    func testHeaderRoundTrip() throws {
        let original = ProtocolHeader(
            messageType: .videoFrame,
            flags: .urgent,
            streamChannel: .video,
            sequenceNumber: 12345,
            payloadLength: 1024
        )
        let data = original.headerData
        let result = ProtocolHeader.parse(from: data)
        switch result {
        case .success(let parsed):
            XCTAssertEqual(parsed.messageType, .videoFrame)
            XCTAssertEqual(parsed.flags, .urgent)
            XCTAssertEqual(parsed.streamChannel, .video)
            XCTAssertEqual(parsed.sequenceNumber, 12345)
            XCTAssertEqual(parsed.payloadLength, 1024)
        case .failure(let error):
            XCTFail("Parse failed: \(error)")
        }
    }

    func testFrameRoundTrip() throws {
        let payload = Data(repeating: 0xCC, count: 256)
        let header = ProtocolHeader(
            messageType: .hello,
            streamChannel: .control,
            payloadLength: UInt32(payload.count)
        )
        let frame = ProtocolFrame(header: header, payload: payload)
        let data = frame.totalData
        let parsed = try ProtocolFrame.parse(from: data).get()
        XCTAssertEqual(parsed.payload, payload)
    }

    func testInvalidMagic() {
        var data = Data(repeating: 0, count: VanguardProtocolConstants.headerSize)
        data[0] = 0xFF
        data[1] = 0xFF
        data[2] = 0xFF
        data[3] = 0xFF
        let result = ProtocolHeader.parse(from: data)
        if case .failure(let error) = result {
            XCTAssertEqual(error, .invalidMagic)
        } else {
            XCTFail("Expected invalidMagic error")
        }
    }

    func testUnsupportedVersion() {
        var data = Data(count: VanguardProtocolConstants.headerSize)
        // Write magic
        data[0] = 0x45; data[1] = 0x56; data[2] = 0x46; data[3] = 0x42
        // Write version 99
        data.writeUInt16(99, at: 4)
        // Fill rest
        for i in 6..<VanguardProtocolConstants.headerSize {
            data[i] = 0
        }
        let result = ProtocolHeader.parse(from: data)
        if case .failure(let error) = result {
            if case .unsupportedVersion(let major) = error {
                XCTAssertEqual(major, 99)
            } else {
                XCTFail("Expected unsupportedVersion error")
            }
        } else {
            XCTFail("Expected error")
        }
    }

    func testHeaderTooShort() {
        let data = Data(repeating: 0, count: 10)
        let result = ProtocolHeader.parse(from: data)
        if case .failure(let error) = result {
            XCTAssertEqual(error.errorCode, 0x0004)
            XCTAssertTrue(error.description.contains("short"))
        } else {
            XCTFail("Expected error for short header")
        }
    }

    func testFrameTooShort() {
        let header = ProtocolHeader(
            messageType: .hello,
            payloadLength: 100
        )
        let data = header.headerData
        let result = ProtocolFrame.parse(from: data)
        if case .failure(let error) = result {
            XCTAssertEqual(error.errorCode, 0x0004)
            XCTAssertTrue(error.description.contains("short"))
        } else {
            XCTFail("Expected error for short frame")
        }
    }

    func testVersionNegotiation() {
        let ver10 = ProtocolVersion(major: 1, minor: 0)
        let ver12 = ProtocolVersion(major: 1, minor: 2)
        let ver20 = ProtocolVersion(major: 2, minor: 0)

        XCTAssertTrue(ver10.isCompatible(with: ver12))
        XCTAssertFalse(ver10.isCompatible(with: ver20))
        XCTAssertTrue(ver10 < ver12)
        XCTAssertTrue(ver12 > ver10)

        let supported = [ver10, ver12, ver20]
        let negotiated = ver12.negotiate(with: supported)
        XCTAssertEqual(negotiated, ver12)
    }

    func testVersionNegotiationIncompatible() {
        let ver10 = ProtocolVersion(major: 1, minor: 0)
        let ver30 = ProtocolVersion(major: 3, minor: 0)
        let supported = [ver10]
        let negotiated = ver30.negotiate(with: supported)
        XCTAssertNil(negotiated)
    }

    func testProtocolErrorDescriptions() {
        XCTAssertEqual(ProtocolError.invalidMagic.description, "Invalid magic bytes")
        XCTAssertEqual(ProtocolError.unknownMessageType(rawValue: 0x0001).description, "Unknown message type 0x1")
        XCTAssertEqual(ProtocolError.authenticationFailed.description, "Authentication failed")
        XCTAssertEqual(ProtocolError.replayDetected.description, "Replay attack detected")
        XCTAssertEqual(ProtocolError.internal.description, "Internal error")
    }

    func testProtocolErrorCodes() {
        XCTAssertEqual(ProtocolError.invalidMagic.errorCode, 0x0001)
        XCTAssertEqual(ProtocolError.authenticationFailed.errorCode, 0x0010)
        XCTAssertEqual(ProtocolError.internal.errorCode, 0x0FFF)
    }

    func testTestVectorHelloFrame() throws {
        let payload = Data(repeating: 0x41, count: 10)
        let header = ProtocolHeader(
            messageType: .hello,
            streamChannel: .control,
            payloadLength: UInt32(payload.count)
        )
        let frame = ProtocolFrame(header: header, payload: payload)
        let data = frame.totalData

        XCTAssertEqual(Array(data[0..<4]), VanguardProtocolConstants.magic)
        XCTAssertEqual(data.count, VanguardProtocolConstants.headerSize + 10)
    }

    func testTestVectorVideoFrame() throws {
        let payload = Data(repeating: 0xFF, count: 1024)
        let header = ProtocolHeader(
            messageType: .videoAccessUnit,
            flags: .urgent,
            streamChannel: .video,
            sequenceNumber: 999,
            payloadLength: UInt32(payload.count)
        )
        let frame = ProtocolFrame(header: header, payload: payload)
        let data = frame.totalData
        let parsed = try ProtocolFrame.parse(from: data).get()
        XCTAssertEqual(parsed.header.messageType, .videoAccessUnit)
        XCTAssertEqual(parsed.header.flags, .urgent)
        XCTAssertEqual(parsed.header.sequenceNumber, 999)
    }
}
