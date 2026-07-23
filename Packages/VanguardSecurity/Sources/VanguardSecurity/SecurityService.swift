import Foundation
import VanguardDomain

// MARK: - Security Service

public protocol SecurityService: Sendable {
    func authorize(
        _ action: NodeAction,
        context: AuthorizationContext
    ) async throws -> AuthorizationDecision
    func checkCapability(
        _ capability: NodeCapability,
        session: Session
    ) -> Bool
    func rateLimitCheck(identifier: String) async throws
    func validatePayload(_ data: Data, maxPayloadSize: Int) async throws
}

// MARK: - Node Action

public enum NodeAction: Sendable, Equatable {
    case startScreenCapture
    case startScreenControl
    case openTerminal
    case executeProcess(command: String)
    case readFiles(paths: [String])
    case writeFiles(paths: [String])
    case transferFile(name: String, size: Int)
    case shutdown
    case restart
    case revokePeer
    case elevateCapabilities(Set<NodeCapability>)
}

// MARK: - Authorization Context

public struct AuthorizationContext: Sendable, Equatable {
    public let sessionID: SessionID
    public let nodeID: NodeID
    public let remoteNodeID: NodeID
    public let grantedCapabilities: Set<NodeCapability>
    public let sequenceNumber: UInt64

    public init(
        sessionID: SessionID,
        nodeID: NodeID,
        remoteNodeID: NodeID,
        grantedCapabilities: Set<NodeCapability>,
        sequenceNumber: UInt64
    ) {
        self.sessionID = sessionID
        self.nodeID = nodeID
        self.remoteNodeID = remoteNodeID
        self.grantedCapabilities = grantedCapabilities
        self.sequenceNumber = sequenceNumber
    }
}

// MARK: - Authorization Decision

public enum AuthorizationDecision: Sendable, Equatable {
    case allowed
    case denied(reason: String)
    case requiresConfirmation
}
