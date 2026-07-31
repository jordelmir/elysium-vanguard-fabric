import Foundation
import os
import VanguardDomain
import VanguardCompute
import VanguardScheduler

public enum DistributedJobState: Sendable, Equatable {
    case pending
    case scheduling
    case dispatched(nodeID: NodeID)
    case transferring
    case running(progress: Double?)
    case collecting
    case succeeded
    case failed(String)
    case cancelled
    case timedOut
}

public actor DistributedJobCoordinator {
    private let scheduler: FabricScheduler
    private var activeJobs: [JobID: DistributedJobState] = [:]
    private var jobResults: [JobID: JobResult] = [:]
    private var jobSpecs: [JobID: JobSpec] = [:]
    private var executors: [NodeID: RemoteJobExecutor] = [:]
    private var progressCallbacks: [JobID: @Sendable (DistributedJobState) -> Void] = [:]
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Distributed")

    public init(scheduler: FabricScheduler) {
        self.scheduler = scheduler
    }

    public func registerExecutor(_ executor: RemoteJobExecutor, for nodeID: NodeID) {
        executors[nodeID] = executor
        logger.info("Registered executor for node \(nodeID.rawValue.uuidString)")
    }

    public func unregisterExecutor(for nodeID: NodeID) {
        executors.removeValue(forKey: nodeID)
        logger.info("Unregistered executor for node \(nodeID.rawValue.uuidString)")
    }

    public func submitJob(
        _ spec: JobSpec,
        requiredArtifactIDs: [UUID] = [],
        onProgress: @Sendable @escaping (DistributedJobState) -> Void = { _ in }
    ) async throws -> JobID {
        let jobID = JobID(rawValue: spec.jobID)
        activeJobs[jobID] = .pending
        jobSpecs[jobID] = spec
        progressCallbacks[jobID] = onProgress
        notifyProgress(jobID, state: .pending)

        activeJobs[jobID] = .scheduling
        notifyProgress(jobID, state: .scheduling)

        let constraints = HardConstraints(
            requiredArchitectures: spec.requirements.allowedArchitectures,
            minimumLogicalCPUs: spec.requirements.minimumLogicalCPUs,
            minimumMemoryBytes: spec.requirements.minimumMemoryBytes,
            minimumStorageBytes: spec.requirements.minimumStorageBytes,
            requiredToolchains: spec.requirements.requiredToolchains,
            requiredCapabilities: spec.requirements.requiredCapabilities,
            requiresGPU: spec.requirements.requiresGPU,
            maximumThermalState: spec.requirements.maximumThermalState,
            requiresACPower: spec.requirements.requiresACPower,
            excludedNodeIDs: Set(spec.requirements.excludedNodeIDs.map { NodeID(rawValue: $0) })
        )

        let score: SchedulerScore
        do {
            score = try await scheduler.selectNode(for: constraints, requiredArtifactIDs: requiredArtifactIDs)
        } catch {
            activeJobs[jobID] = .failed("No eligible node: \(error)")
            notifyProgress(jobID, state: .failed("No eligible node: \(error)"))
            throw error
        }

        let nodeID = score.nodeID
        activeJobs[jobID] = .dispatched(nodeID: nodeID)
        notifyProgress(jobID, state: .dispatched(nodeID: nodeID))
        logger.info("Job \(spec.name) dispatched to node \(nodeID.rawValue.uuidString) (score: \(String(format: "%.3f", score.total)))")

        guard let executor = executors[nodeID] else {
            let error = "No executor registered for node \(nodeID.rawValue.uuidString)"
            activeJobs[jobID] = .failed(error)
            notifyProgress(jobID, state: .failed(error))
            throw DistributedJobError.noExecutorForNode(nodeID)
        }

        activeJobs[jobID] = .transferring
        notifyProgress(jobID, state: .transferring)

        do {
            let remoteJobID = try await executor.submitJob(
                name: spec.name,
                command: [spec.command.executable] + spec.command.arguments,
                workingDirectory: nil,
                timeoutSeconds: TimeInterval(spec.timeoutSeconds)
            )

            activeJobs[jobID] = .running(progress: 0)
            notifyProgress(jobID, state: .running(progress: 0))
            logger.info("Job \(spec.name) running remotely as \(remoteJobID)")

            let result = try await monitorJob(
                executor: executor,
                remoteJobID: remoteJobID,
                localJobID: jobID,
                timeoutSeconds: spec.timeoutSeconds
            )

            activeJobs[jobID] = .collecting
            notifyProgress(jobID, state: .collecting)

            jobResults[jobID] = result
            activeJobs[jobID] = result.succeeded ? .succeeded : .failed("Exit code \(result.exitCode)")
            notifyProgress(jobID, state: result.succeeded ? .succeeded : .failed("Exit code \(result.exitCode)"))

            await scheduler.recordJobResult(nodeID: nodeID, succeeded: result.succeeded)

            logger.info("Job \(spec.name) completed: exit=\(result.exitCode)")
            return jobID

        } catch {
            activeJobs[jobID] = .failed(error.localizedDescription)
            notifyProgress(jobID, state: .failed(error.localizedDescription))
            await scheduler.recordJobResult(nodeID: nodeID, succeeded: false)
            throw error
        }
    }

    public func cancelJob(_ jobID: JobID) async {
        guard let state = activeJobs[jobID], !state.isTerminal else { return }
        if case .dispatched(let nodeID) = state, let executor = executors[nodeID] {
            try? await executor.cancelJob(jobID: jobID.rawValue.uuidString)
        }
        activeJobs[jobID] = .cancelled
        notifyProgress(jobID, state: .cancelled)
        progressCallbacks.removeValue(forKey: jobID)
        logger.info("Job \(jobID.rawValue.uuidString) cancelled")
    }

    public func jobState(_ jobID: JobID) -> DistributedJobState? {
        activeJobs[jobID]
    }

    public func jobResult(_ jobID: JobID) -> JobResult? {
        jobResults[jobID]
    }

    public func activeJobIDs() -> [JobID] {
        activeJobs.keys.filter { id in
            if let state = activeJobs[id] { return !state.isTerminal }
            return false
        }.map { $0 }
    }

    public func completedJobIDs() -> [JobID] {
        activeJobs.keys.filter { id in
            if let state = activeJobs[id] { return state.isTerminal }
            return false
        }.map { $0 }
    }

    private func monitorJob(
        executor: RemoteJobExecutor,
        remoteJobID: String,
        localJobID: JobID,
        timeoutSeconds: UInt64
    ) async throws -> JobResult {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        var lastProgress: Double = 0

        while Date() < deadline {
            try await Task.sleep(nanoseconds: 500_000_000)

            let status = await executor.getJobStatus(jobID: remoteJobID)

            if let status, status == "completed" {
                let result = JobResult(
                    jobID: localJobID,
                    exitCode: 0,
                    stdout: Data(),
                    stderr: Data(),
                    duration: 0
                )
                return result
            }

            if let status, status == "failed" {
                let result = JobResult(
                    jobID: localJobID,
                    exitCode: 1,
                    stdout: Data(),
                    stderr: Data("Remote job failed".utf8),
                    duration: 0
                )
                return result
            }

            lastProgress += 0.1
            activeJobs[localJobID] = .running(progress: min(lastProgress, 0.99))
            notifyProgress(localJobID, state: .running(progress: min(lastProgress, 0.99)))
        }

        activeJobs[localJobID] = .timedOut
        notifyProgress(localJobID, state: .timedOut)
        throw DistributedJobError.jobTimedOut(localJobID)
    }

    private func notifyProgress(_ jobID: JobID, state: DistributedJobState) {
        progressCallbacks[jobID]?(state)
    }
}

public enum DistributedJobError: Error, Sendable {
    case noExecutorForNode(NodeID)
    case jobTimedOut(JobID)
    case jobFailed(String)
}

extension DistributedJobError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noExecutorForNode(let nodeID):
            return "No executor registered for node \(nodeID.rawValue.uuidString)"
        case .jobTimedOut(let jobID):
            return "Job \(jobID.rawValue.uuidString) timed out"
        case .jobFailed(let reason):
            return "Job failed: \(reason)"
        }
    }
}

extension DistributedJobState {
    var isTerminal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled, .timedOut: return true
        default: return false
        }
    }
}
