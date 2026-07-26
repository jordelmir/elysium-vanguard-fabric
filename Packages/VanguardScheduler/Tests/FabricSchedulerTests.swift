import XCTest
@testable import VanguardScheduler
@testable import VanguardDomain

final class FabricSchedulerTests: XCTestCase {
    func testBestNodeSelection() async {
        let scheduler = FabricScheduler()

        let nodeA = NodeResourceDescriptor(
            nodeID: NodeID(),
            architecture: .arm64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0"),
            logicalCPUCount: 8,
            physicalCPUCount: 8,
            totalMemoryBytes: 16 * 1024 * 1024 * 1024,
            availableMemoryBytes: 14 * 1024 * 1024 * 1024,
            totalStorageBytes: 512 * 1024 * 1024 * 1024,
            availableStorageBytes: 400 * 1024 * 1024 * 1024
        )

        let nodeB = NodeResourceDescriptor(
            nodeID: NodeID(),
            architecture: .x86_64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "12.0"),
            logicalCPUCount: 2,
            physicalCPUCount: 2,
            totalMemoryBytes: 4 * 1024 * 1024 * 1024,
            availableMemoryBytes: 1 * 1024 * 1024 * 1024,
            totalStorageBytes: 256 * 1024 * 1024 * 1024,
            availableStorageBytes: 50 * 1024 * 1024 * 1024
        )

        await scheduler.registerNode(nodeA)
        await scheduler.registerNode(nodeB)

        let best = try? await scheduler.selectNode(for: HardConstraints())
        XCTAssertNotNil(best)
        XCTAssertEqual(best?.nodeID, nodeA.nodeID)
    }

    func testHardConstraintFiltering() async {
        let scheduler = FabricScheduler()

        let armNode = NodeResourceDescriptor(
            nodeID: NodeID(),
            architecture: .arm64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0"),
            logicalCPUCount: 4,
            physicalCPUCount: 4,
            totalMemoryBytes: 8 * 1024 * 1024 * 1024,
            availableMemoryBytes: 4 * 1024 * 1024 * 1024,
            totalStorageBytes: 256 * 1024 * 1024 * 1024,
            availableStorageBytes: 128 * 1024 * 1024 * 1024
        )

        await scheduler.registerNode(armNode)

        let constraints = HardConstraints(requiredArchitectures: [.x86_64])
        do {
            _ = try await scheduler.selectNode(for: constraints)
            XCTFail("Should have thrown")
        } catch {
            // expected
        }
    }

    func testUnregisterNode() async {
        let scheduler = FabricScheduler()
        let node = NodeResourceDescriptor(
            nodeID: NodeID(),
            architecture: .arm64,
            operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0"),
            logicalCPUCount: 4,
            physicalCPUCount: 4,
            totalMemoryBytes: 8 * 1024 * 1024 * 1024,
            availableMemoryBytes: 4 * 1024 * 1024 * 1024,
            totalStorageBytes: 256 * 1024 * 1024 * 1024,
            availableStorageBytes: 128 * 1024 * 1024 * 1024
        )

        await scheduler.registerNode(node)
        await scheduler.unregisterNode(node.nodeID)
        let all = await scheduler.allNodes()
        XCTAssertTrue(all.isEmpty)
    }
}
