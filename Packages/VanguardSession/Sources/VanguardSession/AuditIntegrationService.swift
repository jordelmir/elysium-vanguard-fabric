import Foundation
import os.log
import VanguardDomain
import VanguardAudit

public actor AuditIntegrationService {
    private let auditLog: any AuditLogService
    private var pendingEntries: [AuditEntry] = []
    private var flushTask: Task<Void, Never>?
    private let flushInterval: TimeInterval
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Audit")

    public init(auditLog: any AuditLogService, flushInterval: TimeInterval = 5.0) {
        self.auditLog = auditLog
        self.flushInterval = flushInterval
    }

    public func startAutoFlush() {
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.flushInterval ?? 5.0 * 1_000_000_000))
                await self?.flushPending()
            }
        }
        logger.info("Audit auto-flush started (interval: \(self.flushInterval)s)")
    }

    public func stopAutoFlush() {
        flushTask?.cancel()
        flushTask = nil
    }

    public func logAction(
        actorNodeID: NodeID,
        targetNodeID: NodeID,
        sessionID: SessionID?,
        action: AuditAction,
        decision: AuditDecision,
        result: AuditResult
    ) async {
        do {
            try await auditLog.appendEntry(
                actorNodeID: actorNodeID,
                targetNodeID: targetNodeID,
                sessionID: sessionID,
                action: action,
                decision: decision,
                result: result
            )
            logger.info("Audit: \(action.rawValue) by \(actorNodeID.rawValue.uuidString)")
        } catch {
            logger.error("Failed to append audit entry: \(error.localizedDescription)")
        }
    }

    public func logSecurityEvent(
        actorNodeID: NodeID,
        targetNodeID: NodeID,
        sessionID: SessionID?,
        action: AuditAction
    ) async {
        await logAction(
            actorNodeID: actorNodeID,
            targetNodeID: targetNodeID,
            sessionID: sessionID,
            action: action,
            decision: .allowed,
            result: .success
        )
    }

    public func logDeniedAction(
        actorNodeID: NodeID,
        targetNodeID: NodeID,
        sessionID: SessionID?,
        action: AuditAction,
        reason: String
    ) async {
        await logAction(
            actorNodeID: actorNodeID,
            targetNodeID: targetNodeID,
            sessionID: sessionID,
            action: action,
            decision: .denied,
            result: .failure
        )
        logger.warning("Denied: \(action.rawValue) — \(reason)")
    }

    public func verifyIntegrity() async -> Bool {
        do {
            let valid = try await auditLog.verifyChainIntegrity()
            if !valid {
                logger.error("Audit chain integrity check FAILED")
            }
            return valid
        } catch {
            logger.error("Audit integrity check error: \(error.localizedDescription)")
            return false
        }
    }

    public func getRecentEntries(limit: Int = 50) async throws -> [AuditEntry] {
        try await auditLog.getEntries(fromSequence: nil, limit: limit)
    }

    public func exportLog() async throws -> Data {
        try await auditLog.exportLog()
    }

    private func flushPending() async {
        let entries = pendingEntries
        pendingEntries = []
        for entry in entries {
            do {
                try await auditLog.appendEntry(
                    actorNodeID: entry.actorNodeID,
                    targetNodeID: entry.targetNodeID,
                    sessionID: entry.sessionID,
                    action: entry.action,
                    decision: entry.decision,
                    result: entry.result
                )
            } catch {
                logger.error("Failed to flush audit entry: \(error.localizedDescription)")
            }
        }
        if !entries.isEmpty {
            logger.info("Flushed \(entries.count) audit entries")
        }
    }
}
