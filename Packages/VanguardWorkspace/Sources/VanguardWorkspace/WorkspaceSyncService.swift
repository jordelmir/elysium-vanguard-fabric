import Foundation
import CryptoKit
import os.log
import VanguardDomain

public enum ConflictResolution: String, Sendable, Codable {
    case newestWins
    case consoleWins
    case nodeWins
    case manual
}

public struct FileVersion: Sendable, Codable, Identifiable {
    public let id: UUID
    public let path: String
    public let sha256: Data
    public let size: UInt64
    public let modifiedBy: NodeID
    public let modifiedAt: Date
    public let version: UInt64

    public init(path: String, sha256: Data, size: UInt64, modifiedBy: NodeID, modifiedAt: Date = Date(), version: UInt64 = 1) {
        self.id = UUID()
        self.path = path
        self.sha256 = sha256
        self.size = size
        self.modifiedBy = modifiedBy
        self.modifiedAt = modifiedAt
        self.version = version
    }
}

public struct SyncState: Sendable, Codable {
    public let workspaceID: WorkspaceID
    public var fileVersions: [String: FileVersion]
    public var lastSyncAt: Date
    public var lastSyncedBy: NodeID?

    public init(workspaceID: WorkspaceID, fileVersions: [String: FileVersion] = [:], lastSyncAt: Date = Date(), lastSyncedBy: NodeID? = nil) {
        self.workspaceID = workspaceID
        self.fileVersions = fileVersions
        self.lastSyncAt = lastSyncAt
        self.lastSyncedBy = lastSyncedBy
    }
}

public struct SyncDelta: Sendable, Codable {
    public let workspaceID: WorkspaceID
    public let fromVersion: UInt64
    public let toVersion: UInt64
    public let added: [String: FileVersion]
    public let modified: [String: FileVersion]
    public let deleted: [String]
    public let conflicts: [SyncConflict]

    public var isEmpty: Bool { added.isEmpty && modified.isEmpty && deleted.isEmpty && conflicts.isEmpty }
    public var totalCount: Int { added.count + modified.count + deleted.count + conflicts.count }
}

public struct SyncConflict: Sendable, Codable, Identifiable {
    public let id: UUID
    public let path: String
    public let localVersion: FileVersion
    public let remoteVersion: FileVersion
    public let resolution: ConflictResolution

    public init(path: String, localVersion: FileVersion, remoteVersion: FileVersion, resolution: ConflictResolution = .newestWins) {
        self.id = UUID()
        self.path = path
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.resolution = resolution
    }

    public var resolvedVersion: FileVersion {
        switch resolution {
        case .newestWins: return localVersion.modifiedAt > remoteVersion.modifiedAt ? localVersion : remoteVersion
        case .consoleWins: return localVersion
        case .nodeWins: return remoteVersion
        case .manual: return localVersion
        }
    }
}

public actor WorkspaceSyncService {
    private var syncStates: [WorkspaceID: SyncState] = [:]
    private var conflictResolution: ConflictResolution = .newestWins
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "WorkspaceSync")

    public init() {}

    public func setConflictResolution(_ resolution: ConflictResolution) {
        conflictResolution = resolution
    }

    public func initializeSync(workspaceID: WorkspaceID, localFiles: [String: (sha256: Data, size: UInt64)], nodeID: NodeID) -> SyncState {
        var fileVersions: [String: FileVersion] = [:]
        for (path, info) in localFiles {
            fileVersions[path] = FileVersion(
                path: path,
                sha256: info.sha256,
                size: info.size,
                modifiedBy: nodeID,
                modifiedAt: Date(),
                version: 1
            )
        }
        let state = SyncState(workspaceID: workspaceID, fileVersions: fileVersions)
        syncStates[workspaceID] = state
        logger.info("Initialized sync for workspace with \(fileVersions.count) files")
        return state
    }

    public func computeDelta(workspaceID: WorkspaceID, remoteState: SyncState) -> SyncDelta? {
        guard let localState = syncStates[workspaceID] else { return nil }

        var added: [String: FileVersion] = [:]
        var modified: [String: FileVersion] = [:]
        var deleted: [String] = []
        var conflicts: [SyncConflict] = []

        for (path, remoteVersion) in remoteState.fileVersions {
            if let localVersion = localState.fileVersions[path] {
                if localVersion.sha256 != remoteVersion.sha256 {
                    if localVersion.version > remoteVersion.version {
                        modified[path] = localVersion
                    } else if remoteVersion.version > localVersion.version {
                        modified[path] = remoteVersion
                    } else {
                        let conflict = SyncConflict(
                            path: path,
                            localVersion: localVersion,
                            remoteVersion: remoteVersion,
                            resolution: conflictResolution
                        )
                        conflicts.append(conflict)
                        modified[path] = conflict.resolvedVersion
                    }
                }
            } else {
                added[path] = remoteVersion
            }
        }

        for (path, localVersion) in localState.fileVersions {
            if remoteState.fileVersions[path] == nil {
                deleted.append(path)
                _ = localVersion
            }
        }

        let fromVersion = localState.fileVersions.values.map { $0.version }.max() ?? 0
        let toVersion = remoteState.fileVersions.values.map { $0.version }.max() ?? fromVersion

        return SyncDelta(
            workspaceID: workspaceID,
            fromVersion: fromVersion,
            toVersion: toVersion,
            added: added,
            modified: modified,
            deleted: deleted,
            conflicts: conflicts
        )
    }

    public func applyDelta(_ delta: SyncDelta, nodeID: NodeID) {
        guard var state = syncStates[delta.workspaceID] else { return }

        for (path, version) in delta.added {
            state.fileVersions[path] = version
        }
        for (path, version) in delta.modified {
            var v = version
            v = FileVersion(
                path: path,
                sha256: version.sha256,
                size: version.size,
                modifiedBy: nodeID,
                modifiedAt: version.modifiedAt,
                version: version.version + 1
            )
            state.fileVersions[path] = v
        }
        for path in delta.deleted {
            state.fileVersions.removeValue(forKey: path)
        }

        state.lastSyncAt = Date()
        state.lastSyncedBy = nodeID
        syncStates[delta.workspaceID] = state
        logger.info("Applied sync delta: \(delta.added.count) added, \(delta.modified.count) modified, \(delta.deleted.count) deleted, \(delta.conflicts.count) conflicts")
    }

    public func getSyncState(workspaceID: WorkspaceID) -> SyncState? {
        syncStates[workspaceID]
    }

    public func mergeStates(workspaceID: WorkspaceID, remoteState: SyncState) {
        guard var localState = syncStates[workspaceID] else {
            syncStates[workspaceID] = remoteState
            return
        }

        for (path, remoteVersion) in remoteState.fileVersions {
            if let localVersion = localState.fileVersions[path] {
                if remoteVersion.version > localVersion.version {
                    localState.fileVersions[path] = remoteVersion
                }
            } else {
                localState.fileVersions[path] = remoteVersion
            }
        }

        localState.lastSyncAt = Date()
        syncStates[workspaceID] = localState
    }

    public func deleteSyncState(workspaceID: WorkspaceID) {
        syncStates.removeValue(forKey: workspaceID)
    }
}
