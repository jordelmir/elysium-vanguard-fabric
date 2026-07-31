import Foundation
import os
import VanguardDomain

public actor NativeProcessExecutor: JobExecutor {
    private var runningJobs: [JobID: RunningJob] = [:]
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Compute")

    public init() {}

    public func execute(
        spec: JobSpec,
        onOutput: @escaping @Sendable (Data) -> Void,
        onStderr: @escaping @Sendable (Data) -> Void
    ) async throws -> JobResult {
        let jobID = JobID(rawValue: spec.jobID)
        guard runningJobs[jobID] == nil else {
            throw JobError.alreadyRunning(jobID)
        }

        let startTime = Date()
        let sandboxDir = jobSandboxDirectory(for: jobID)
        try FileManager.default.createDirectory(at: sandboxDir, withIntermediateDirectories: true)

        let effectiveWorkingDir = spec.workingDirectoryPolicy == .sandboxOnly
            ? sandboxDir.path
            : FileManager.default.temporaryDirectory.path

        var environment = ProcessInfo.processInfo.environment
        for (key, value) in spec.environment {
            environment[key] = value
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: spec.command.executable)
        process.arguments = spec.command.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: effectiveWorkingDir)
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw JobError.spawnFailed(error.localizedDescription)
        }

        let runningJob = RunningJob(process: process, startDate: Date())
        runningJobs[jobID] = runningJob

        if spec.timeoutSeconds > 0 {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(spec.timeoutSeconds * 1_000_000_000))
                guard let self else { return }
                await self.handleTimeout(jobID: jobID)
            }
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        onOutput(stdoutData)
        onStderr(stderrData)

        let duration = Date().timeIntervalSince(startTime)
        let exitCode = process.terminationStatus

        runningJobs.removeValue(forKey: jobID)
        cleanupSandbox(jobID: jobID)

        let result = JobResult(
            jobID: jobID,
            exitCode: exitCode,
            stdout: stdoutData,
            stderr: stderrData,
            duration: duration
        )

        logger.info("Job \(spec.name) completed: exit=\(exitCode), \(String(format: "%.2f", duration))s")
        return result
    }

    public func cancel(jobID: JobID) async {
        guard let job = runningJobs[jobID] else { return }
        job.process.terminate()
        runningJobs.removeValue(forKey: jobID)
        logger.info("Job \(jobID.rawValue.uuidString) cancelled")
    }

    private func handleTimeout(jobID: JobID) async {
        guard let job = runningJobs[jobID] else { return }
        job.process.terminate()
        runningJobs.removeValue(forKey: jobID)
        logger.warning("Job \(jobID.rawValue.uuidString) timed out")
    }

    private func jobSandboxDirectory(for jobID: JobID) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("ElysiumVanguardFabric")
            .appendingPathComponent("Jobs")
            .appendingPathComponent(jobID.rawValue.uuidString)
    }

    private func cleanupSandbox(jobID: JobID) {
        let dir = jobSandboxDirectory(for: jobID)
        try? FileManager.default.removeItem(at: dir)
    }
}

private struct RunningJob {
    let process: Process
    let startDate: Date
}
