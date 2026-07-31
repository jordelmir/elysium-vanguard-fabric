import Foundation
import os
import VanguardDomain

public enum FabricEventCategory: String, Sendable, CaseIterable, Codable {
    case identity
    case pairing
    case transport
    case session
    case capture
    case video
    case audio
    case input
    case terminal
    case clipboard
    case files
    case workspace
    case artifact
    case scheduler
    case job
    case agent
    case security
    case update
    case performance
    case error
}

public enum FabricSeverity: String, Sendable, Codable, Comparable {
    case debug
    case info
    case notice
    case warning
    case error
    case critical

    public static func < (lhs: FabricSeverity, rhs: FabricSeverity) -> Bool {
        let order: [FabricSeverity] = [.debug, .info, .notice, .warning, .error, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

public enum FabricEvent: Sendable {
    case nodeDiscovered(NodeID)
    case nodeConnected(NodeID)
    case nodeDisconnected(NodeID)
    case pairingStarted(NodeID)
    case pairingCompleted(NodeID)
    case sessionOpened(SessionID)
    case sessionClosed(SessionID)
    case captureStarted
    case captureStopped
    case frameDropped(reason: String)
    case inputDispatched(action: String)
    case terminalOpened(TerminalSessionID)
    case terminalClosed(TerminalSessionID)
    case clipboardSynced
    case clipboardChanged
    case artifactReceived(name: String, version: String)
    case jobStarted(String)
    case jobCompleted(String, exitCode: Int32)
    case jobFailed(String, error: String)
    case emergencyStop
    case error(String)

    public var category: String {
        switch self {
        case .nodeDiscovered, .nodeConnected, .nodeDisconnected: return "node"
        case .pairingStarted, .pairingCompleted: return "pairing"
        case .sessionOpened, .sessionClosed: return "session"
        case .captureStarted, .captureStopped, .frameDropped: return "capture"
        case .inputDispatched: return "input"
        case .terminalOpened, .terminalClosed: return "terminal"
        case .clipboardSynced, .clipboardChanged: return "clipboard"
        case .artifactReceived: return "artifact"
        case .jobStarted, .jobCompleted, .jobFailed: return "job"
        case .emergencyStop: return "security"
        case .error: return "error"
        }
    }
}

public actor FabricEventLog {
    private var events: [FabricEventEntry] = []
    private let maxEvents: Int
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Events")

    public struct FabricEventEntry: Sendable {
        public let event: FabricEvent
        public let timestamp: Date
        public let sourceNodeID: NodeID?

        public init(event: FabricEvent, timestamp: Date = Date(), sourceNodeID: NodeID? = nil) {
            self.event = event
            self.timestamp = timestamp
            self.sourceNodeID = sourceNodeID
        }
    }

    public init(maxEvents: Int = 10000) {
        self.maxEvents = maxEvents
    }

    public func record(_ event: FabricEvent, source: NodeID? = nil) {
        let entry = FabricEventEntry(event: event, sourceNodeID: source)
        events.append(entry)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        logger.info("[\(event.category)] \(String(describing: event))")
    }

    public func recentEvents(count: Int = 100) -> [FabricEventEntry] {
        Array(events.suffix(count))
    }

    public func eventsInCategory(_ category: String) -> [FabricEventEntry] {
        events.filter { $0.event.category == category }
    }

    public func clear() {
        events.removeAll()
    }
}
