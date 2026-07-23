import Foundation
import VanguardDomain

// MARK: - Persistence Service Protocol

public protocol PersistenceService: Sendable {
    func saveNode(_ node: VanguardNode) async throws
    func loadNode(id: NodeID) async throws -> VanguardNode?
    func loadAllNodes() async throws -> [VanguardNode]
    func deleteNode(id: NodeID) async throws

    func saveSession(_ session: Session) async throws
    func loadSession(id: SessionID) async throws -> Session?
    func loadActiveSessions() async throws -> [Session]
    func deleteSession(id: SessionID) async throws

    func saveConfiguration(_ config: Data, key: String) async throws
    func loadConfiguration(key: String) async throws -> Data?
    func deleteConfiguration(key: String) async throws

    func migrateIfNeeded() async throws
    func backup() async throws -> Data
}
