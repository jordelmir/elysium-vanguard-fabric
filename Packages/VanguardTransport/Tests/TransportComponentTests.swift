import Foundation
import XCTest
@testable import VanguardTransport
import VanguardProtocol

final class FrameDecoderTests: XCTestCase {
    func testCompleteFrame() {
        let decoder = FrameDecoder()
        let header = ProtocolHeader(
            messageType: .hello,
            streamChannel: .control,
            sequenceNumber: 1,
            payloadLength: 5
        )
        var frameData = header.headerData
        frameData.append(Data("hello".utf8))
        decoder.append(data: frameData)

        let result = decoder.nextFrame()
        switch result {
        case .success(let frame):
            XCTAssertEqual(frame.header.messageType, .hello)
            XCTAssertEqual(frame.payload, Data("hello".utf8))
        case .failure, .none:
            XCTFail("Expected successful frame parse")
        }
    }

    func testFragmentedHeader() {
        let decoder = FrameDecoder()
        let header = ProtocolHeader(messageType: .hello, streamChannel: .control)
        let fullData = header.headerData

        decoder.append(data: Data(fullData[0..<10]))
        XCTAssertNil(decoder.nextFrame())

        decoder.append(data: Data(fullData[10...]))
        let result = decoder.nextFrame()
        if case .success = result {} else { XCTFail("Expected frame after header complete") }
    }

    func testMultipleFramesConcatenated() {
        let decoder = FrameDecoder()
        var combined = Data()

        let h1 = ProtocolHeader(messageType: .hello, streamChannel: .control, payloadLength: 3)
        combined.append(h1.headerData)
        combined.append(Data("abc".utf8))

        let h2 = ProtocolHeader(messageType: .heartbeatAck, streamChannel: .heartbeat, payloadLength: 2)
        combined.append(h2.headerData)
        combined.append(Data("xy".utf8))

        decoder.append(data: combined)

        let f1 = decoder.nextFrame()
        if case .success(let frame) = f1 {
            XCTAssertEqual(frame.header.messageType, .hello)
            XCTAssertEqual(frame.payload, Data("abc".utf8))
        } else {
            XCTFail("Expected first frame")
        }

        let f2 = decoder.nextFrame()
        if case .success(let frame) = f2 {
            XCTAssertEqual(frame.header.messageType, .heartbeatAck)
        } else {
            XCTFail("Expected second frame")
        }
    }

    func testFrameAndAHalf() {
        let decoder = FrameDecoder()
        let h1 = ProtocolHeader(messageType: .hello, streamChannel: .control, payloadLength: 3)
        var data = h1.headerData
        data.append(Data("abc".utf8))

        let h2 = ProtocolHeader(messageType: .heartbeat, streamChannel: .heartbeat)
        data.append(h2.headerData)

        decoder.append(data: data)

        let f1 = decoder.nextFrame()
        if case .success(let frame) = f1 {
            XCTAssertEqual(frame.header.messageType, .hello)
        } else {
            XCTFail("Expected first frame")
        }

        XCTAssertNil(decoder.nextFrame())

        let rest = h2.headerData
        decoder.append(data: rest)
        let f2 = decoder.nextFrame()
        if case .success(let frame) = f2 {
            XCTAssertEqual(frame.header.messageType, .heartbeat)
        } else {
            XCTFail("Expected second frame")
        }
    }

    func testInvalidMagic() {
        let decoder = FrameDecoder()
        var badData = Data([0x00, 0x00, 0x00, 0x00])
        badData.append(Data(count: 21))
        decoder.append(data: badData)

        let result = decoder.nextFrame()
        if case .failure(.invalidMagic) = result {} else {
            XCTFail("Expected invalidMagic error")
        }
    }

    func testPayloadTooLarge() {
        let decoder = FrameDecoder()
        let header = ProtocolHeader(
            messageType: .videoFrame,
            streamChannel: .video,
            payloadLength: UInt32(VanguardProtocolConstants.maxVideoAccessUnit + 1)
        )
        decoder.append(data: header.headerData)

        let result = decoder.nextFrame()
        if case .failure(.payloadTooLarge) = result {} else {
            XCTFail("Expected payloadTooLarge error")
        }
    }

    func testFrameTruncated() {
        let decoder = FrameDecoder()
        let header = ProtocolHeader(messageType: .hello, streamChannel: .control, payloadLength: 100)
        var data = header.headerData
        data.append(Data(count: 10))
        decoder.append(data: data)

        XCTAssertNil(decoder.nextFrame())
    }

    func testReset() {
        let decoder = FrameDecoder()
        let header = ProtocolHeader(messageType: .hello, streamChannel: .control)
        decoder.append(data: header.headerData)

        decoder.reset()
        XCTAssertNil(decoder.nextFrame())
    }
}

final class ChannelMultiplexerTests: XCTestCase {
    func testEnqueueAndDequeue() {
        let mux = ChannelMultiplexer()
        let msg = OutboundMessage(messageType: .hello, streamChannel: .control)
        XCTAssertTrue(mux.enqueue(msg))

        let item = mux.nextMessage()
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.message.messageType, .hello)
    }

    func testPriorityOrdering() {
        let mux = ChannelMultiplexer()
        let low = OutboundMessage(messageType: .telemetrySnapshot, streamChannel: .telemetry)
        let high = OutboundMessage(messageType: .inputEvent, streamChannel: .inputReliable)
        let critical = OutboundMessage(messageType: .heartbeat, streamChannel: .heartbeat)

        mux.enqueue(low)
        mux.enqueue(high)
        mux.enqueue(critical)

        XCTAssertEqual(mux.nextMessage()?.message.messageType, .heartbeat)
        XCTAssertEqual(mux.nextMessage()?.message.messageType, .inputEvent)
        XCTAssertEqual(mux.nextMessage()?.message.messageType, .telemetrySnapshot)
    }

    func testVideoFrameDeduplication() {
        let mux = ChannelMultiplexer(maxQueueSize: 10)
        let f1 = OutboundMessage(messageType: .videoFrame, streamChannel: .video, payload: Data([1]))
        let f2 = OutboundMessage(messageType: .videoFrame, streamChannel: .video, payload: Data([2]))
        let f3 = OutboundMessage(messageType: .videoFrame, streamChannel: .video, payload: Data([3]))

        mux.enqueue(f1)
        mux.enqueue(f2)
        mux.enqueue(f3)

        let item = mux.nextMessage()
        XCTAssertEqual(item?.message.payload, Data([3]))
        XCTAssertNil(mux.nextMessage())
    }

    func testQueueFullDropOldest() {
        let mux = ChannelMultiplexer(maxQueueSize: 2, dropPolicy: .dropOldest)
        for i in 0..<5 {
            let msg = OutboundMessage(messageType: .telemetrySnapshot, streamChannel: .telemetry, payload: Data([UInt8(i)]))
            mux.enqueue(msg)
        }
        XCTAssertEqual(mux.pendingCount(for: .telemetry), 2)
    }

    func testClearAll() {
        let mux = ChannelMultiplexer()
        mux.enqueue(OutboundMessage(messageType: .hello, streamChannel: .control))
        mux.enqueue(OutboundMessage(messageType: .heartbeat, streamChannel: .heartbeat))
        mux.clearAll()
        XCTAssertEqual(mux.totalPendingCount(), 0)
    }
}

final class HeartbeatControllerTests: XCTestCase {
    func testCreatePing() {
        let controller = HeartbeatController()
        let ping = controller.createPing()
        XCTAssertGreaterThan(ping.sequence, 0)
    }

    func testHandlePong() {
        let controller = HeartbeatController()
        let ping = controller.createPing()
        let pong = HeartbeatPayload(timestampNanos: ping.timestampNanos, sequence: ping.sequence)
        controller.handlePong(pong)
        XCTAssertEqual(controller.currentState, .healthy)
        XCTAssertGreaterThan(controller.currentSmoothedRTT, 0)
    }

    func testHeartbeatMissed() {
        let controller = HeartbeatController()
        controller.heartbeatMissed()
        XCTAssertEqual(controller.currentState, .degraded)

        controller.heartbeatMissed()
        controller.heartbeatMissed()
        XCTAssertEqual(controller.currentState, .stalled)
    }

    func testReset() {
        let controller = HeartbeatController()
        let _ = controller.createPing()
        controller.heartbeatMissed()
        controller.reset()
        XCTAssertEqual(controller.currentState, .offline)
        XCTAssertEqual(controller.currentSmoothedRTT, 0)
    }
}

final class FlowControllerTests: XCTestCase {
    func testCanSend() {
        let fc = FlowController()
        XCTAssertTrue(fc.canSend(channel: .control, size: 100))
    }

    func testBackpressure() {
        let fc = FlowController()
        fc.didSend(channel: .video, size: 4 * 1024 * 1024)
        XCTAssertFalse(fc.canSend(channel: .video, size: 1))
    }

    func testAckReleasesBackpressure() {
        let fc = FlowController()
        fc.didSend(channel: .video, size: 1000)
        fc.didReceiveAck(channel: .video, size: 1000)
        XCTAssertTrue(fc.canSend(channel: .video, size: 100))
    }

    func testPauseResume() {
        let fc = FlowController()
        fc.pause()
        XCTAssertFalse(fc.canSend(channel: .control, size: 1))
        fc.resume()
        XCTAssertTrue(fc.canSend(channel: .control, size: 1))
    }
}

final class ReconnectionManagerTests: XCTestCase {
    func testShouldAttemptReconnect() {
        let rm = ReconnectionManager(maxAttempts: 3, baseDelayMs: 1, maxDelayMs: 10)
        XCTAssertTrue(rm.shouldAttemptReconnect())
    }

    func testMaxAttempts() {
        let rm = ReconnectionManager(maxAttempts: 2, baseDelayMs: 1, maxDelayMs: 10)
        _ = rm.shouldAttemptReconnect()
        _ = rm.shouldAttemptReconnect()
        XCTAssertFalse(rm.shouldAttemptReconnect())
    }

    func testReset() {
        let rm = ReconnectionManager(maxAttempts: 2, baseDelayMs: 1, maxDelayMs: 10)
        _ = rm.shouldAttemptReconnect()
        _ = rm.shouldAttemptReconnect()
        rm.reset()
        XCTAssertTrue(rm.shouldAttemptReconnect())
    }
}
