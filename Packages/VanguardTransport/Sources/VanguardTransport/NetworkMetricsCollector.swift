import Foundation
import VanguardDomain

public struct NetworkMetricsSnapshot: Sendable {
    public let bytesSent: UInt64
    public let bytesReceived: UInt64
    public let framesSent: UInt64
    public let framesReceived: UInt64
    public let sendErrors: UInt64
    public let receiveErrors: UInt64
    public let smoothedRTT: Double
    public let jitter: Double
    public let connectionState: NetworkConnectionState
    public let queueDepth: Int
    public let droppedFrames: UInt64
}

public final class NetworkMetricsCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _bytesSent: UInt64 = 0
    private var _bytesReceived: UInt64 = 0
    private var _framesSent: UInt64 = 0
    private var _framesReceived: UInt64 = 0
    private var _sendErrors: UInt64 = 0
    private var _receiveErrors: UInt64 = 0
    private var _droppedFrames: UInt64 = 0

    public init() {}

    public func recordBytesSent(_ count: Int) {
        lock.withLock { _bytesSent += UInt64(count) }
    }

    public func recordBytesReceived(_ count: Int) {
        lock.withLock { _bytesReceived += UInt64(count) }
    }

    public func recordFrameSent() {
        lock.withLock { _framesSent += 1 }
    }

    public func recordFrameReceived() {
        lock.withLock { _framesReceived += 1 }
    }

    public func recordSendError() {
        lock.withLock { _sendErrors += 1 }
    }

    public func recordReceiveError() {
        lock.withLock { _receiveErrors += 1 }
    }

    public func recordDroppedFrame() {
        lock.withLock { _droppedFrames += 1 }
    }

    public func snapshot(rtt: Double, jitter: Double, state: NetworkConnectionState, queueDepth: Int) -> NetworkMetricsSnapshot {
        lock.withLock {
            NetworkMetricsSnapshot(
                bytesSent: _bytesSent,
                bytesReceived: _bytesReceived,
                framesSent: _framesSent,
                framesReceived: _framesReceived,
                sendErrors: _sendErrors,
                receiveErrors: _receiveErrors,
                smoothedRTT: rtt,
                jitter: jitter,
                connectionState: state,
                queueDepth: queueDepth,
                droppedFrames: _droppedFrames
            )
        }
    }

    public func reset() {
        lock.withLock {
            _bytesSent = 0
            _bytesReceived = 0
            _framesSent = 0
            _framesReceived = 0
            _sendErrors = 0
            _receiveErrors = 0
            _droppedFrames = 0
        }
    }
}
