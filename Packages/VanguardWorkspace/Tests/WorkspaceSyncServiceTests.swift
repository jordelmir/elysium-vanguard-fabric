import Testing
import Foundation
import VanguardDomain
@testable import VanguardWorkspace

typealias WSID = VanguardWorkspace.WorkspaceID

@Suite("WorkspaceSyncService")
struct WorkspaceSyncServiceTests {

    @Test("Initialize sync creates state with correct file count")
    func initializeSync() async {
        let service = WorkspaceSyncService()
        let wsID = WSID()
        let files: [String: (sha256: Data, size: UInt64)] = [
            "a.txt": (Data("hash1".utf8), 100),
            "b.txt": (Data("hash2".utf8), 200)
        ]
        let state = await service.initializeSync(workspaceID: wsID, localFiles: files, nodeID: NodeID())
        #expect(state.fileVersions.count == 2)
        #expect(state.fileVersions["a.txt"]?.size == 100)
    }

    @Test("Compute delta detects added and modified files")
    func computeDelta() async {
        let service = WorkspaceSyncService()
        let wsID = WSID()
        let nodeID = NodeID()
        let localFiles: [String: (sha256: Data, size: UInt64)] = [
            "a.txt": (Data("hash1".utf8), 100),
            "b.txt": (Data("hash2".utf8), 200)
        ]
        _ = await service.initializeSync(workspaceID: wsID, localFiles: localFiles, nodeID: nodeID)

        var remoteState = SyncState(workspaceID: wsID)
        remoteState.fileVersions["a.txt"] = FileVersion(path: "a.txt", sha256: Data("hash1".utf8), size: 100, modifiedBy: nodeID, version: 1)
        remoteState.fileVersions["b.txt"] = FileVersion(path: "b.txt", sha256: Data("hash2_modified".utf8), size: 250, modifiedBy: nodeID, version: 2)
        remoteState.fileVersions["c.txt"] = FileVersion(path: "c.txt", sha256: Data("hash3".utf8), size: 300, modifiedBy: nodeID, version: 1)

        let delta = await service.computeDelta(workspaceID: wsID, remoteState: remoteState)
        #expect(delta != nil)
        #expect(delta?.added.count == 1)
        #expect(delta?.modified.count == 1)
        #expect(delta?.added["c.txt"] != nil)
    }

    @Test("Compute delta detects deleted files")
    func detectDeletions() async {
        let service = WorkspaceSyncService()
        let wsID = WSID()
        let nodeID = NodeID()
        let localFiles: [String: (sha256: Data, size: UInt64)] = [
            "a.txt": (Data("hash1".utf8), 100),
            "b.txt": (Data("hash2".utf8), 200)
        ]
        _ = await service.initializeSync(workspaceID: wsID, localFiles: localFiles, nodeID: nodeID)

        var remoteState = SyncState(workspaceID: wsID)
        remoteState.fileVersions["a.txt"] = FileVersion(path: "a.txt", sha256: Data("hash1".utf8), size: 100, modifiedBy: nodeID, version: 1)

        let delta = await service.computeDelta(workspaceID: wsID, remoteState: remoteState)
        #expect(delta?.deleted.count == 1)
        #expect(delta?.deleted.contains("b.txt") == true)
    }

    @Test("Apply delta updates sync state")
    func applyDelta() async {
        let service = WorkspaceSyncService()
        let wsID = WSID()
        let nodeID = NodeID()
        let localFiles: [String: (sha256: Data, size: UInt64)] = [
            "a.txt": (Data("hash1".utf8), 100)
        ]
        _ = await service.initializeSync(workspaceID: wsID, localFiles: localFiles, nodeID: nodeID)

        var remoteState = SyncState(workspaceID: wsID)
        remoteState.fileVersions["a.txt"] = FileVersion(path: "a.txt", sha256: Data("hash1".utf8), size: 100, modifiedBy: nodeID, version: 1)
        remoteState.fileVersions["b.txt"] = FileVersion(path: "b.txt", sha256: Data("hash2".utf8), size: 200, modifiedBy: nodeID, version: 1)

        let delta = await service.computeDelta(workspaceID: wsID, remoteState: remoteState)!
        await service.applyDelta(delta, nodeID: nodeID)

        let state = await service.getSyncState(workspaceID: wsID)
        #expect(state?.fileVersions.count == 2)
        #expect(state?.fileVersions["b.txt"] != nil)
    }

    @Test("Conflict resolution picks newest by default")
    func conflictResolution() async {
        let service = WorkspaceSyncService()
        let wsID = WSID()
        let localNode = NodeID()
        let remoteNode = NodeID()

        let localFiles: [String: (sha256: Data, size: UInt64)] = [
            "conflict.txt": (Data("local_hash".utf8), 100)
        ]
        _ = await service.initializeSync(workspaceID: wsID, localFiles: localFiles, nodeID: localNode)

        var remoteState = SyncState(workspaceID: wsID)
        let olderVersion = FileVersion(path: "conflict.txt", sha256: Data("remote_hash".utf8), size: 150, modifiedBy: remoteNode, modifiedAt: Date().addingTimeInterval(-3600), version: 1)
        remoteState.fileVersions["conflict.txt"] = olderVersion

        let delta = await service.computeDelta(workspaceID: wsID, remoteState: remoteState)
        #expect(delta != nil)
        #expect(delta?.conflicts.count == 1)
        let resolved = delta?.modified["conflict.txt"]
        #expect(resolved?.sha256 == Data("local_hash".utf8))
    }

    @Test("Delete sync state removes workspace")
    func deleteState() async {
        let service = WorkspaceSyncService()
        let wsID = WSID()
        let localFiles: [String: (sha256: Data, size: UInt64)] = [
            "a.txt": (Data("hash1".utf8), 100)
        ]
        _ = await service.initializeSync(workspaceID: wsID, localFiles: localFiles, nodeID: NodeID())
        await service.deleteSyncState(workspaceID: wsID)
        let state = await service.getSyncState(workspaceID: wsID)
        #expect(state == nil)
    }
}
