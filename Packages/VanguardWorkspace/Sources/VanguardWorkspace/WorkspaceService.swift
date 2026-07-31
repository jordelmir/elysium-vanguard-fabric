import Foundation
import VanguardDomain

public struct WorkspaceID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public struct WorkspaceSnapshot: Sendable, Codable {
    public let workspaceID: WorkspaceID
    public let name: String
    public let created: Date
    public let fileHashes: [String: String]
    public let metadata: [String: String]

    public init(workspaceID: WorkspaceID, name: String, created: Date = Date(), fileHashes: [String: String], metadata: [String: String] = [:]) {
        self.workspaceID = workspaceID
        self.name = name
        self.created = created
        self.fileHashes = fileHashes
        self.metadata = metadata
    }
}

public enum WorkspaceOperation: Sendable, Codable, Equatable {
    case create(path: String, content: Data, sha256: Data)
    case modify(path: String, oldSHA256: Data, newContent: Data, newSHA256: Data)
    case delete(path: String, expectedSHA256: Data)
    case rename(from: String, to: String)
    case mkdir(path: String)

    public var path: String {
        switch self {
        case .create(let path, _, _): return path
        case .modify(let path, _, _, _): return path
        case .delete(let path, _): return path
        case .rename(let from, _): return from
        case .mkdir(let path): return path
        }
    }
}

public struct WorkspaceChangeSet: Sendable, Codable {
    public let snapshotID: WorkspaceID
    public let added: [String]
    public let modified: [String]
    public let deleted: [String]

    public init(snapshotID: WorkspaceID, added: [String], modified: [String], deleted: [String]) {
        self.snapshotID = snapshotID
        self.added = added
        self.modified = modified
        self.deleted = deleted
    }

    public var isEmpty: Bool { added.isEmpty && modified.isEmpty && deleted.isEmpty }
    public var totalCount: Int { added.count + modified.count + deleted.count }
}

public actor WorkspaceService {
    private var snapshots: [WorkspaceID: WorkspaceSnapshot] = [:]

    public init() {}

    public func createSnapshot(name: String, fileHashes: [String: String]) -> WorkspaceSnapshot {
        let snapshot = WorkspaceSnapshot(workspaceID: WorkspaceID(), name: name, fileHashes: fileHashes)
        snapshots[snapshot.workspaceID] = snapshot
        return snapshot
    }

    public func getSnapshot(id: WorkspaceID) -> WorkspaceSnapshot? {
        snapshots[id]
    }

    public func listSnapshots() -> [WorkspaceSnapshot] {
        Array(snapshots.values).sorted { $0.created > $1.created }
    }

    public func computeChangeSet(from snapshotID: WorkspaceID, currentHashes: [String: String]) -> WorkspaceChangeSet? {
        guard let snapshot = snapshots[snapshotID] else { return nil }

        var added: [String] = []
        var modified: [String] = []
        var deleted: [String] = []

        for (path, hash) in currentHashes {
            if let oldHash = snapshot.fileHashes[path] {
                if oldHash != hash { modified.append(path) }
            } else {
                added.append(path)
            }
        }

        for path in snapshot.fileHashes.keys where currentHashes[path] == nil {
            deleted.append(path)
        }

        return WorkspaceChangeSet(snapshotID: snapshotID, added: added, modified: modified, deleted: deleted)
    }

    public func deleteSnapshot(id: WorkspaceID) {
        snapshots.removeValue(forKey: id)
    }
}
