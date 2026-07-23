import Foundation

// MARK: - Session

public struct Session: Codable, Sendable, Equatable {
    public let id: SessionID
    public let nodeID: NodeID
    public let startedAt: Date
    public let lastActivityAt: Date
    public let isActive: Bool
    public let grantedCapabilities: Set<NodeCapability>

    public init(
        id: SessionID = SessionID(),
        nodeID: NodeID,
        startedAt: Date = Date(),
        lastActivityAt: Date = Date(),
        isActive: Bool = true,
        grantedCapabilities: Set<NodeCapability> = []
    ) {
        self.id = id
        self.nodeID = nodeID
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.isActive = isActive
        self.grantedCapabilities = grantedCapabilities
    }
}

// MARK: - Connection Failure

public enum ConnectionFailure: Codable, Sendable, Equatable, Error, LocalizedError {
    case nodeUnreachable
    case tlsHandshakeFailed
    case authenticationRejected
    case protocolIncompatible
    case peerRevoked
    case timeout
    case networkUnavailable
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .nodeUnreachable: return "Node is unreachable"
        case .tlsHandshakeFailed: return "TLS handshake failed"
        case .authenticationRejected: return "Authentication was rejected"
        case .protocolIncompatible: return "Protocol versions are incompatible"
        case .peerRevoked: return "Peer trust has been revoked"
        case .timeout: return "Connection timed out"
        case .networkUnavailable: return "Network is unavailable"
        case .unknown(let msg): return "Unknown error: \(msg)"
        }
    }
}

// MARK: - Connection State

public enum ConnectionState: Sendable, Equatable {
    case idle
    case resolving
    case connecting(attempt: Int)
    case authenticating
    case ready
    case degraded(reason: String)
    case reconnecting(attempt: Int, nextDelaySeconds: Double)
    case closing
    case closed
    case failed(ConnectionFailure)

    public var displayLabel: String {
        switch self {
        case .idle: return "Idle"
        case .resolving: return "Resolving..."
        case .connecting(let attempt): return "Connecting (attempt \(attempt))..."
        case .authenticating: return "Authenticating..."
        case .ready: return "Connected"
        case .degraded(let reason): return "Degraded: \(reason)"
        case .reconnecting(let attempt, _): return "Reconnecting (attempt \(attempt))..."
        case .closing: return "Closing..."
        case .closed: return "Closed"
        case .failed(let failure): return "Failed: \(failure.localizedDescription)"
        }
    }
}

// MARK: - Disconnect Reason

public enum DisconnectReason: String, Codable, Sendable {
    case userInitiated
    case nodeShutdown
    case nodeRestart
    case networkLost
    case timeout
    case revoked
    case error
    case unknown
}
