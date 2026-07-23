import Foundation
import XCTest
@testable import VanguardPersistence
import VanguardDomain

final class FilePersistenceServiceTests: XCTestCase {
    var service: FilePersistenceService!
    var tempDir: URL!

    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = FilePersistenceService(baseDirectory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveAndLoadNode() async throws {
        let node = VanguardNode(
            id: NodeID(),
            displayName: "Test",
            architecture: .arm64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0")
        )
        try await service.saveNode(node)
        let loaded = try await service.loadNode(id: node.id)
        XCTAssertEqual(loaded?.displayName, "Test")
    }

    func testLoadAllNodes() async throws {
        let node1 = VanguardNode(
            id: NodeID(),
            displayName: "A",
            architecture: .arm64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0")
        )
        let node2 = VanguardNode(
            id: NodeID(),
            displayName: "B",
            architecture: .x86_64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0")
        )
        try await service.saveNode(node1)
        try await service.saveNode(node2)
        let all = try await service.loadAllNodes()
        XCTAssertEqual(all.count, 2)
    }

    func testDeleteNode() async throws {
        let node = VanguardNode(
            id: NodeID(),
            displayName: "Del",
            architecture: .arm64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0")
        )
        try await service.saveNode(node)
        try await service.deleteNode(id: node.id)
        let loaded = try await service.loadNode(id: node.id)
        XCTAssertNil(loaded)
    }

    func testSaveAndLoadConfiguration() async throws {
        let data = Data("test-config".utf8)
        try await service.saveConfiguration(data, key: "test")
        let loaded = try await service.loadConfiguration(key: "test")
        XCTAssertEqual(loaded, data)
    }

    func testMigrateIfNeeded() async throws {
        try await service.migrateIfNeeded()
    }
}
