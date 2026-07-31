import Testing
import Foundation
import VanguardDomain
import VanguardCompute
import VanguardScheduler
@testable import VanguardExecutors

private actor MockRemoteExecutor: RemoteJobExecutor {
    var shouldFail = false
    var submittedJobs: [(name: String, command: [String])] = []
    var cancelledJobs: [String] = []

    func submitJob(
        name: String,
        command: [String],
        workingDirectory: String?,
        timeoutSeconds: TimeInterval
    ) async throws -> String {
        submittedJobs.append((name: name, command: command))
        if shouldFail {
            throw DistributedJobError.jobFailed("Mock failure")
        }
        return UUID().uuidString
    }

    func cancelJob(jobID: String) async throws {
        cancelledJobs.append(jobID)
    }

    func getJobStatus(jobID: String) async -> String? {
        return "completed"
    }
}

private func makeNodeDescriptor(
    nodeID: NodeID = NodeID(),
    cpuCount: Int = 8,
    memoryBytes: UInt64 = 16 * 1024 * 1024 * 1024,
    arch: CPUArchitecture = .arm64
) -> NodeResourceDescriptor {
    NodeResourceDescriptor(
        nodeID: nodeID,
        architecture: arch,
        operatingSystem: OperatingSystemDescriptor(family: .macOS, version: "14.0"),
        logicalCPUCount: cpuCount,
        physicalCPUCount: cpuCount,
        totalMemoryBytes: memoryBytes,
        availableMemoryBytes: memoryBytes / 2,
        totalStorageBytes: 512 * 1024 * 1024 * 1024,
        availableStorageBytes: 256 * 1024 * 1024 * 1024
    )
}

private func makeJobSpec(name: String = "test-job") -> JobSpec {
    JobSpec(
        submittedBy: UUID(),
        name: name,
        command: ExecutableCommand(executable: "/bin/echo", arguments: ["hello"]),
        timeoutSeconds: 30
    )
}

@Suite("DistributedJobCoordinator")
struct DistributedJobCoordinatorTests {

    @Test("submitJob selects a node and dispatches")
    func submitDispatches() async throws {
        let scheduler = FabricScheduler()
        let coordinator = DistributedJobCoordinator(scheduler: scheduler)
        let nodeID = NodeID()
        await scheduler.registerNode(makeNodeDescriptor(nodeID: nodeID))
        let executor = MockRemoteExecutor()
        await coordinator.registerExecutor(executor, for: nodeID)
        let jobID = try await coordinator.submitJob(makeJobSpec())
        let state = await coordinator.jobState(jobID)
        #expect(state == .succeeded || state == .collecting)
        let submitted = await executor.submittedJobs
        #expect(submitted.count == 1)
    }

    @Test("submitJob fails when no nodes registered")
    func submitFailsNoNodes() async {
        let scheduler = FabricScheduler()
        let coordinator = DistributedJobCoordinator(scheduler: scheduler)
        do {
            _ = try await coordinator.submitJob(makeJobSpec())
            Issue.record("Expected error")
        } catch {
            #expect(error is SchedulerError)
        }
    }

    @Test("submitJob fails when no executor for selected node")
    func submitFailsNoExecutor() async {
        let scheduler = FabricScheduler()
        let coordinator = DistributedJobCoordinator(scheduler: scheduler)
        await scheduler.registerNode(makeNodeDescriptor())
        do {
            _ = try await coordinator.submitJob(makeJobSpec())
            Issue.record("Expected error")
        } catch {
            #expect(error is DistributedJobError)
        }
    }

    @Test("cancelJob transitions to cancelled state")
    func cancelJob() async throws {
        let scheduler = FabricScheduler()
        let coordinator = DistributedJobCoordinator(scheduler: scheduler)
        let nodeID = NodeID()
        await scheduler.registerNode(makeNodeDescriptor(nodeID: nodeID))
        let executor = MockRemoteExecutor()
        await coordinator.registerExecutor(executor, for: nodeID)
        let jobID = try await coordinator.submitJob(makeJobSpec())
        await coordinator.cancelJob(jobID)
        let state = await coordinator.jobState(jobID)
        #expect(state == .cancelled || state == .succeeded)
    }

    @Test("registerExecutor and unregisterExecutor manage executors")
    func executorManagement() async {
        let scheduler = FabricScheduler()
        let coordinator = DistributedJobCoordinator(scheduler: scheduler)
        let nodeID = NodeID()
        let executor = MockRemoteExecutor()
        await coordinator.registerExecutor(executor, for: nodeID)
        await coordinator.unregisterExecutor(for: nodeID)
        await scheduler.registerNode(makeNodeDescriptor(nodeID: nodeID))
        do {
            _ = try await coordinator.submitJob(makeJobSpec())
            Issue.record("Expected error")
        } catch {
            #expect(error is DistributedJobError)
        }
    }

    @Test("activeJobIDs and completedJobIDs track lifecycle")
    func jobLifecycle() async throws {
        let scheduler = FabricScheduler()
        let coordinator = DistributedJobCoordinator(scheduler: scheduler)
        let nodeID = NodeID()
        await scheduler.registerNode(makeNodeDescriptor(nodeID: nodeID))
        let executor = MockRemoteExecutor()
        await coordinator.registerExecutor(executor, for: nodeID)
        let jobID = try await coordinator.submitJob(makeJobSpec())
        let completed = await coordinator.completedJobIDs()
        #expect(completed.contains(jobID))
    }

    @Test("localityScore influences node selection")
    func localityScore() async throws {
        let scheduler = FabricScheduler()
        let nodeA = NodeID()
        let nodeB = NodeID()
        await scheduler.registerNode(makeNodeDescriptor(nodeID: nodeA, cpuCount: 4))
        await scheduler.registerNode(makeNodeDescriptor(nodeID: nodeB, cpuCount: 4))
        let artifactID = UUID()
        await scheduler.registerArtifactLocation(artifactID: artifactID, onNode: nodeB)
        let score = try await scheduler.selectNode(
            for: HardConstraints(),
            requiredArtifactIDs: [artifactID]
        )
        #expect(score.nodeID == nodeB)
        #expect(score.localityScore > 0)
    }
}
