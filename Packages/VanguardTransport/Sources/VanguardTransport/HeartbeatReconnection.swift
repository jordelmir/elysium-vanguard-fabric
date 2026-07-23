import Foundation
import VanguardDomain
import VanguardProtocol

public enum NetworkConnectionState: Sendable {
    case healthy
    case degraded
    case stalled
    case reconnecting
    case offline
}

public final class HeartbeatController: @unchecked Sendable {
    private let lock = NSLock()
    private var state: NetworkConnectionState = .offline
    private var smoothedRTT: Double = 0
    private var jitter: Double = 0
    private var lastPongNanos: UInt64 = 0
    private var consecutiveMisses: Int = 0
    private var sequenceCounter: UInt64 = 0
    private var pendingPings: [UInt64: UInt64] = [:]
    private var rttHistory: [Double] = []
    private let maxRTTHistory = 50

    public var currentState: NetworkConnectionState {
        lock.withLock { state }
    }

    public var currentSmoothedRTT: Double {
        lock.withLock { smoothedRTT }
    }

    public var currentJitter: Double {
        lock.withLock { jitter }
    }

    public init() {}

    public func createPing() -> HeartbeatPayload {
        let seq: UInt64 = lock.withLock {
            sequenceCounter += 1
            let ts = UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000)
            pendingPings[sequenceCounter] = ts
            return sequenceCounter
        }
        return HeartbeatPayload(timestampNanos: UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000), sequence: seq)
    }

    public func handlePong(_ pong: HeartbeatPayload) {
        lock.withLock {
            let now = UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000)
            if let sentNanos = pendingPings.removeValue(forKey: pong.sequence) {
                let rttNanos = Double(now - sentNanos)
                updateRTT(rttNanos)
            }
            lastPongNanos = now
            consecutiveMisses = 0
            updateState(.healthy)
        }
    }

    public func heartbeatMissed() {
        lock.withLock {
            consecutiveMisses += 1
            if consecutiveMisses >= 3 {
                updateState(.stalled)
            } else if consecutiveMisses >= 1 {
                updateState(.degraded)
            }
        }
    }

    public func markReconnecting() {
        lock.withLock { updateState(.reconnecting) }
    }

    public func markOffline() {
        lock.withLock { updateState(.offline) }
    }

    public func reset() {
        lock.withLock {
            state = .offline
            smoothedRTT = 0
            jitter = 0
            consecutiveMisses = 0
            pendingPings.removeAll()
            rttHistory.removeAll()
        }
    }

    private func updateRTT(_ rttNanos: Double) {
        rttHistory.append(rttNanos)
        if rttHistory.count > maxRTTHistory {
            rttHistory.removeFirst()
        }
        if smoothedRTT == 0 {
            smoothedRTT = rttNanos
        } else {
            smoothedRTT = smoothedRTT * 0.875 + rttNanos * 0.125
        }
        let mean = rttHistory.reduce(0, +) / Double(rttHistory.count)
        let variance = rttHistory.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(rttHistory.count)
        jitter = sqrt(variance)
    }

    private func updateState(_ newState: NetworkConnectionState) {
        guard newState != state else { return }
        state = newState
    }
}

public final class ReconnectionManager: @unchecked Sendable {
    private let lock = NSLock()
    private var attemptCount: Int = 0
    private var lastAttemptTime: UInt64 = 0
    private var isReconnecting = false
    private let maxAttempts: Int
    private let baseDelayNanos: UInt64
    private let maxDelayNanos: UInt64

    public init(
        maxAttempts: Int = 10,
        baseDelayMs: UInt64 = 500,
        maxDelayMs: UInt64 = 30_000
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelayNanos = baseDelayMs * 1_000_000
        self.maxDelayNanos = maxDelayMs * 1_000_000
    }

    public func shouldAttemptReconnect() -> Bool {
        lock.withLock {
            guard attemptCount < maxAttempts else { return false }
            let now = UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000)
            let delay = backoffDelay
            guard now - lastAttemptTime >= delay else { return false }
            attemptCount += 1
            lastAttemptTime = now
            isReconnecting = true
            return true
        }
    }

    public func reset() {
        lock.withLock {
            attemptCount = 0
            lastAttemptTime = 0
            isReconnecting = false
        }
    }

    public func markConnected() {
        lock.withLock {
            attemptCount = 0
            isReconnecting = false
        }
    }

    private var backoffDelay: UInt64 {
        let exponential = min(baseDelayNanos * UInt64(1 << min(attemptCount, 10)), maxDelayNanos)
        let jitterRange = exponential / 4
        let jitterOffset = UInt64.random(in: 0...jitterRange)
        return exponential + jitterOffset
    }
}
