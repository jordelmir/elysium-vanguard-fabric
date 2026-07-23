import Foundation
import VanguardDomain
import VanguardProtocol

public enum MessagePriority: Int, Sendable, Comparable {
    case critical = 0
    case high = 1
    case medium = 2
    case low = 3

    public static func < (lhs: MessagePriority, rhs: MessagePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct PrioritizedMessage: Sendable {
    public let message: OutboundMessage
    public let priority: MessagePriority
    public let enqueuedAt: UInt64

    public init(message: OutboundMessage, priority: MessagePriority) {
        self.message = message
        self.priority = priority
        self.enqueuedAt = UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000)
    }
}

public final class ChannelMultiplexer: @unchecked Sendable {
    private let lock = NSLock()
    private var queues: [StreamChannel: [PrioritizedMessage]] = [:]
    private let maxQueueSize: Int
    private let dropPolicy: DropPolicy

    public enum DropPolicy: Sendable {
        case dropOldest
        case dropNewest
        case reject
    }

    public init(maxQueueSize: Int = 256, dropPolicy: DropPolicy = .dropOldest) {
        self.maxQueueSize = maxQueueSize
        self.dropPolicy = dropPolicy
    }

    public func enqueue(_ message: OutboundMessage) -> Bool {
        let priority = Self.priority(for: message.messageType, channel: message.streamChannel)
        let item = PrioritizedMessage(message: message, priority: priority)

        return lock.withLock {
            var queue = queues[message.streamChannel] ?? []

            if message.streamChannel == .video {
                queue.removeAll { $0.message.messageType == .videoFrame }
            }

            if queue.count >= maxQueueSize {
                switch dropPolicy {
                case .dropOldest:
                    queue.removeFirst()
                case .dropNewest:
                    return false
                case .reject:
                    return false
                }
            }

            queue.append(item)
            queues[message.streamChannel] = queue
            return true
        }
    }

    public func nextMessage() -> PrioritizedMessage? {
        lock.withLock {
            var bestChannel: StreamChannel?
            var bestPriority: MessagePriority = .low

            for (channel, queue) in queues {
                guard let first = queue.first else { continue }
                if first.priority < bestPriority || (first.priority == bestPriority && bestChannel == nil) {
                    bestPriority = first.priority
                    bestChannel = channel
                }
            }

            guard let channel = bestChannel, var queue = queues[channel] else { return nil }
            let item = queue.removeFirst()
            queues[channel] = queue.isEmpty ? nil : queue
            return item
        }
    }

    public func pendingCount(for channel: StreamChannel) -> Int {
        lock.withLock { queues[channel]?.count ?? 0 }
    }

    public func totalPendingCount() -> Int {
        lock.withLock { queues.values.reduce(0) { $0 + $1.count } }
    }

    public func clearAll() {
        lock.withLock { queues.removeAll() }
    }

    public func clearChannel(_ channel: StreamChannel) {
        lock.withLock { queues[channel] = nil }
    }

    public static func priority(for messageType: MessageType, channel: StreamChannel) -> MessagePriority {
        switch messageType {
        case .sessionClose, .authenticate, .capabilityRequest, .capabilityGranted, .capabilityDenied:
            return .critical
        case .hello, .helloAck, .pairingRequest, .pairingChallenge, .pairingResponse, .pairingComplete:
            return .critical
        case .heartbeat, .heartbeatAck:
            return .critical
        case .inputEvent:
            return .high
        case .terminalInput, .terminalOutput:
            return .high
        case .videoFrame, .videoKeyframeRequest:
            return .medium
        case .videoConfiguration:
            return .medium
        case .telemetrySnapshot, .auditEvent:
            return .low
        default:
            return .medium
        }
    }
}
