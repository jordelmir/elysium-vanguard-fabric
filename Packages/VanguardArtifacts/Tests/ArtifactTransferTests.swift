import XCTest
@testable import VanguardArtifacts
@testable import VanguardDomain

final class ArtifactTransferTests: XCTestCase {
    func testManifestRoundTrip() async throws {
        let store = LocalArtifactStore(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("ArtifactTests_\(UUID().uuidString)"))
        let service = ArtifactTransferService(store: store)

        let data = Data(repeating: 0xAB, count: 1024)
        let manifest = try await service.buildManifest(from: data, name: "TestArtifact", version: "1.0.0", chunkSize: 256)

        XCTAssertEqual(manifest.name, "TestArtifact")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertEqual(manifest.totalSize, 1024)
        XCTAssertEqual(manifest.chunkCount, 4)

        let assembled = try await service.assembleArtifact(artifactID: manifest.artifactID)
        XCTAssertEqual(assembled, data)
    }

    func testChunkHashValidation() async throws {
        let store = LocalArtifactStore(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("ArtifactTests_\(UUID().uuidString)"))
        let service = ArtifactTransferService(store: store)

        let data = Data(repeating: 0xCD, count: 512)
        let manifest = try await service.buildManifest(from: data, name: "HashTest", version: "1.0.0", chunkSize: 256)

        let badChunk = ArtifactChunk(artifactID: manifest.artifactID, index: 0, data: Data(repeating: 0xFF, count: 256), sha256Hash: Data(repeating: 0x00, count: 32))

        do {
            try await service.receiveChunk(badChunk)
            XCTFail("Should have thrown chunkHashMismatch")
        } catch let error as ArtifactTransferError {
            if case .chunkHashMismatch = error {} else {
                XCTFail("Expected chunkHashMismatch, got \(error)")
            }
        }
    }

    func testDeleteArtifact() async throws {
        let store = LocalArtifactStore(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("ArtifactTests_\(UUID().uuidString)"))
        let service = ArtifactTransferService(store: store)

        let data = Data(repeating: 0xDE, count: 256)
        let manifest = try await service.buildManifest(from: data, name: "ToDelete", version: "1.0.0")

        try await service.deleteArtifact(artifactID: manifest.artifactID)
        let result = await store.getManifest(artifactID: manifest.artifactID)
        XCTAssertNil(result)
    }

    func testListArtifacts() async throws {
        let store = LocalArtifactStore(baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("ArtifactTests_\(UUID().uuidString)"))
        let service = ArtifactTransferService(store: store)

        let data = Data(repeating: 0xAA, count: 100)
        _ = try await service.buildManifest(from: data, name: "Artifact1", version: "1.0.0")
        _ = try await service.buildManifest(from: data, name: "Artifact2", version: "2.0.0")

        let artifacts = await store.listArtifacts()
        XCTAssertEqual(artifacts.count, 2)
    }
}
