import Foundation
import VanguardProtocol

public final class FlowController: @unchecked Sendable {
    private let lock = NSLock()
    private var bytesInFlight: [StreamChannel: Int] = [:]
    private let channelLimits: [StreamChannel: Int]
    private var isPaused = false

    public init() {
        self.channelLimits = [
            .control: 256 * 1024,
            .inputReliable: 16 * 1024,
            .inputEphemeral: 8 * 1024,
            .video: 4 * 1024 * 1024,
            .terminal: 256 * 1024,
            .telemetry: 128 * 1024,
            .files: 2 * 1024 * 1024,
            .audit: 128 * 1024,
            .heartbeat: 256
        ]
    }

    public func canSend(channel: StreamChannel, size: Int) -> Bool {
        lock.withLock {
            guard !isPaused else { return false }
            let current = bytesInFlight[channel] ?? 0
            let limit = channelLimits[channel] ?? 256 * 1024
            return current + size <= limit
        }
    }

    public func didSend(channel: StreamChannel, size: Int) {
        lock.withLock { bytesInFlight[channel, default: 0] += size }
    }

    public func didReceiveAck(channel: StreamChannel, size: Int) {
        lock.withLock {
            let current = bytesInFlight[channel] ?? 0
            bytesInFlight[channel] = max(0, current - size)
        }
    }

    public func pause() {
        lock.withLock { isPaused = true }
    }

    public func resume() {
        lock.withLock { isPaused = false }
    }

    public func bytesInFlight(for channel: StreamChannel) -> Int {
        lock.withLock { bytesInFlight[channel] ?? 0 }
    }

    public func totalBytesInFlight() -> Int {
        lock.withLock { bytesInFlight.values.reduce(0, +) }
    }

    public func reset() {
        lock.withLock {
            bytesInFlight.removeAll()
            isPaused = false
        }
    }
}
