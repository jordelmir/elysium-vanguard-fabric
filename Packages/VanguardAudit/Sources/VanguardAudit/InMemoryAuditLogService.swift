import Foundation
import CryptoKit
import VanguardDomain

public final class InMemoryAuditLogService: AuditLogService, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [AuditEntry] = []
    private var sequenceCounter: UInt64 = 0
    private var previousHash: Data?

    public init() {}

    public func appendEntry(
        actorNodeID: NodeID,
        targetNodeID: NodeID,
        sessionID: SessionID?,
        action: AuditAction,
        decision: AuditDecision,
        result: AuditResult
    ) async throws {
        lock.withLock {
            sequenceCounter += 1
            var entry = AuditEntry(
                entryID: UUID(),
                previousHash: previousHash,
                sequenceNumber: sequenceCounter,
                occurredAt: Date(),
                actorNodeID: actorNodeID,
                targetNodeID: targetNodeID,
                sessionID: sessionID,
                action: action,
                decision: decision,
                result: result,
                entryHash: Data()
            )
            if let entryData = try? JSONEncoder().encode(entry) {
                let realHash = Data(SHA256.hash(data: entryData))
                entry = AuditEntry(
                    entryID: entry.entryID,
                    previousHash: entry.previousHash,
                    sequenceNumber: entry.sequenceNumber,
                    occurredAt: entry.occurredAt,
                    actorNodeID: entry.actorNodeID,
                    targetNodeID: entry.targetNodeID,
                    sessionID: entry.sessionID,
                    action: entry.action,
                    decision: entry.decision,
                    result: entry.result,
                    entryHash: realHash
                )
                previousHash = realHash
            }
            entries.append(entry)
        }
    }

    public func getEntries(fromSequence: UInt64?, limit: Int) async throws -> [AuditEntry] {
        lock.withLock {
            if let fromSeq = fromSequence {
                return entries.filter { $0.sequenceNumber >= fromSeq }.prefix(limit).map { $0 }
            }
            return Array(entries.suffix(limit))
        }
    }

    public func getEntriesForSession(_ sessionID: SessionID) async throws -> [AuditEntry] {
        lock.withLock {
            entries.filter { $0.sessionID == sessionID }
        }
    }

    public func verifyChainIntegrity() async throws -> Bool {
        lock.withLock {
            var prevHash: Data?
            for entry in entries {
                if let expected = prevHash, entry.previousHash != expected {
                    return false
                }
                prevHash = entry.entryHash
            }
            return true
        }
    }

    public func exportLog() async throws -> Data {
        let snapshot = lock.withLock { entries }
        return try JSONEncoder().encode(snapshot)
    }
}
