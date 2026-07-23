import Foundation
import VanguardDomain

public final class FilePersistenceService: PersistenceService, @unchecked Sendable {
    private let lock = NSLock()
    private let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("ElysiumVanguard", isDirectory: true)
        }
        ensureDirectories()
    }

    private func ensureDirectories() {
        let fm = FileManager.default
        let nodesDir = baseDirectory.appendingPathComponent("nodes")
        let sessionsDir = baseDirectory.appendingPathComponent("sessions")
        let configDir = baseDirectory.appendingPathComponent("config")
        try? fm.createDirectory(at: nodesDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
    }

    private func fileURL(for directory: String, id: String) -> URL {
        baseDirectory.appendingPathComponent(directory).appendingPathComponent(id).appendingPathExtension("json")
    }

    public func saveNode(_ node: VanguardNode) async throws {
        let data = try JSONEncoder().encode(node)
        let url = fileURL(for: "nodes", id: node.id.rawValue.uuidString)
        try data.write(to: url, options: .atomic)
    }

    public func loadNode(id: NodeID) async throws -> VanguardNode? {
        let url = fileURL(for: "nodes", id: id.rawValue.uuidString)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try JSONDecoder().decode(VanguardNode.self, from: data)
    }

    public func loadAllNodes() async throws -> [VanguardNode] {
        let nodesDir = baseDirectory.appendingPathComponent("nodes")
        let files = try? FileManager.default.contentsOfDirectory(at: nodesDir, includingPropertiesForKeys: nil)
        return files?.compactMap { url -> VanguardNode? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(VanguardNode.self, from: data)
        } ?? []
    }

    public func deleteNode(id: NodeID) async throws {
        let url = fileURL(for: "nodes", id: id.rawValue.uuidString)
        try FileManager.default.removeItem(at: url)
    }

    public func saveSession(_ session: Session) async throws {
        let data = try JSONEncoder().encode(session)
        let url = fileURL(for: "sessions", id: session.id.rawValue.uuidString)
        try data.write(to: url, options: .atomic)
    }

    public func loadSession(id: SessionID) async throws -> Session? {
        let url = fileURL(for: "sessions", id: id.rawValue.uuidString)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try JSONDecoder().decode(Session.self, from: data)
    }

    public func loadActiveSessions() async throws -> [Session] {
        let sessionsDir = baseDirectory.appendingPathComponent("sessions")
        let files = try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil)
        return files?.compactMap { url -> Session? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Session.self, from: data)
        } ?? []
    }

    public func deleteSession(id: SessionID) async throws {
        let url = fileURL(for: "sessions", id: id.rawValue.uuidString)
        try FileManager.default.removeItem(at: url)
    }

    public func saveConfiguration(_ config: Data, key: String) async throws {
        let url = baseDirectory.appendingPathComponent("config").appendingPathComponent(key).appendingPathExtension("json")
        try config.write(to: url, options: .atomic)
    }

    public func loadConfiguration(key: String) async throws -> Data? {
        let url = baseDirectory.appendingPathComponent("config").appendingPathComponent(key).appendingPathExtension("json")
        return try? Data(contentsOf: url)
    }

    public func deleteConfiguration(key: String) async throws {
        let url = baseDirectory.appendingPathComponent("config").appendingPathComponent(key).appendingPathExtension("json")
        try FileManager.default.removeItem(at: url)
    }

    public func migrateIfNeeded() async throws {}

    public func backup() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let nodes = try await loadAllNodes()
        let sessions = try await loadActiveSessions()
        var backupData: [String: Any] = [
            "version": 1,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "nodes": try encoder.encode(nodes),
            "sessions": try encoder.encode(sessions)
        ]
        return try JSONSerialization.data(withJSONObject: backupData, options: [])
    }
}
