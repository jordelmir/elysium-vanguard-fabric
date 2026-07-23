import Foundation
import VanguardDomain

// MARK: - Audit Log Service Protocol

public protocol AuditLogService: Sendable {
    func appendEntry(
        actorNodeID: NodeID,
        targetNodeID: NodeID,
        sessionID: SessionID?,
        action: AuditAction,
        decision: AuditDecision,
        result: AuditResult
    ) async throws

    func getEntries(
        fromSequence: UInt64?,
        limit: Int
    ) async throws -> [AuditEntry]

    func getEntriesForSession(_ sessionID: SessionID) async throws -> [AuditEntry]
    func verifyChainIntegrity() async throws -> Bool
    func exportLog() async throws -> Data
}
