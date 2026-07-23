import Foundation

// MARK: - Audit Action

public enum AuditAction: String, Codable, Sendable, CaseIterable {
    case pairingInitiated
    case pairingCompleted
    case pairingRejected
    case connected
    case disconnected
    case capabilityRequested
    case capabilityGranted
    case capabilityDenied
    case screenCaptureStarted
    case screenControlStarted
    case terminalOpened
    case terminalClosed
    case operationDeduplicated
    case peerRevoked
    case panicShortcut
    case nodeShutdown
    case nodeRestart
}

// MARK: - Audit Decision

public enum AuditDecision: String, Codable, Sendable {
    case allowed
    case denied
    case error
}

// MARK: - Audit Result

public enum AuditResult: String, Codable, Sendable {
    case success
    case failure
    case partial
}

// MARK: - Audit Entry

public struct AuditEntry: Codable, Sendable, Equatable {
    public let entryID: UUID
    public let previousHash: Data?
    public let sequenceNumber: UInt64
    public let occurredAt: Date
    public let actorNodeID: NodeID
    public let targetNodeID: NodeID
    public let sessionID: SessionID?
    public let action: AuditAction
    public let decision: AuditDecision
    public let result: AuditResult
    public let entryHash: Data

    public init(
        entryID: UUID = UUID(),
        previousHash: Data? = nil,
        sequenceNumber: UInt64,
        occurredAt: Date = Date(),
        actorNodeID: NodeID,
        targetNodeID: NodeID,
        sessionID: SessionID? = nil,
        action: AuditAction,
        decision: AuditDecision,
        result: AuditResult,
        entryHash: Data
    ) {
        self.entryID = entryID
        self.previousHash = previousHash
        self.sequenceNumber = sequenceNumber
        self.occurredAt = occurredAt
        self.actorNodeID = actorNodeID
        self.targetNodeID = targetNodeID
        self.sessionID = sessionID
        self.action = action
        self.decision = decision
        self.result = result
        self.entryHash = entryHash
    }
}
