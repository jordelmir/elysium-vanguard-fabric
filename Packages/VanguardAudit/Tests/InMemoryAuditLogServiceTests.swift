import Foundation
import XCTest
@testable import VanguardAudit
import VanguardDomain

final class InMemoryAuditLogServiceTests: XCTestCase {
    func testAppendAndGetEntries() async throws {
        let service = InMemoryAuditLogService()
        let actorID = NodeID()
        let targetID = NodeID()

        try await service.appendEntry(
            actorNodeID: actorID,
            targetNodeID: targetID,
            sessionID: nil,
            action: .connected,
            decision: .allowed,
            result: .success
        )

        let entries = try await service.getEntries(fromSequence: nil, limit: 10)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.actorNodeID, actorID)
    }

    func testVerifyChainIntegrity() async throws {
        let service = InMemoryAuditLogService()

        for _ in 0..<5 {
            try await service.appendEntry(
                actorNodeID: NodeID(),
                targetNodeID: NodeID(),
                sessionID: nil,
                action: .connected,
                decision: .allowed,
                result: .success
            )
        }

        let valid = try await service.verifyChainIntegrity()
        XCTAssertTrue(valid)
    }

    func testGetEntriesForSession() async throws {
        let service = InMemoryAuditLogService()
        let sessionID = SessionID()

        try await service.appendEntry(
            actorNodeID: NodeID(),
            targetNodeID: NodeID(),
            sessionID: sessionID,
            action: .connected,
            decision: .allowed,
            result: .success
        )

        let entries = try await service.getEntriesForSession(sessionID)
        XCTAssertEqual(entries.count, 1)
    }
}
