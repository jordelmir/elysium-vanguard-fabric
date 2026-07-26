import XCTest
@testable import VanguardWorkspace

final class WorkspaceTests: XCTestCase {
    func testSnapshotCreation() async {
        let service = WorkspaceService()
        let snapshot = await service.createSnapshot(name: "v1", fileHashes: ["file.txt": "abc123"])
        XCTAssertEqual(snapshot.name, "v1")
        XCTAssertEqual(snapshot.fileHashes["file.txt"], "abc123")
    }

    func testChangeSetDetection() async {
        let service = WorkspaceService()
        let snapshot = await service.createSnapshot(name: "v1", fileHashes: ["a.txt": "hash1", "b.txt": "hash2"])

        let currentHashes = ["a.txt": "hash1", "c.txt": "hash3"]
        let changeSet = await service.computeChangeSet(from: snapshot.workspaceID, currentHashes: currentHashes)

        XCTAssertNotNil(changeSet)
        XCTAssertEqual(changeSet?.added, ["c.txt"])
        XCTAssertTrue(changeSet?.modified.isEmpty ?? false)
        XCTAssertEqual(changeSet?.deleted, ["b.txt"])
    }

    func testDeleteSnapshot() async {
        let service = WorkspaceService()
        let snapshot = await service.createSnapshot(name: "v1", fileHashes: [:])
        await service.deleteSnapshot(id: snapshot.workspaceID)
        let result = await service.getSnapshot(id: snapshot.workspaceID)
        XCTAssertNil(result)
    }
}
