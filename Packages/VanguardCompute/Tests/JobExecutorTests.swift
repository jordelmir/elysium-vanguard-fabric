import XCTest
@testable import VanguardCompute
@testable import VanguardDomain

final class JobExecutorTests: XCTestCase {
    func testEchoJob() async throws {
        let executor = NativeProcessExecutor()
        let spec = JobSpec(
            submittedBy: UUID(),
            name: "echo-test",
            command: ExecutableCommand(executable: "/bin/echo", arguments: ["hello world"]),
            timeoutSeconds: 10
        )

        let result = try await executor.execute(spec: spec, onOutput: { _ in }, onStderr: { _ in })

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdoutString?.trimmingCharacters(in: .whitespacesAndNewlines), "hello world")
    }

    func testFailingJob() async throws {
        let executor = NativeProcessExecutor()
        let spec = JobSpec(
            submittedBy: UUID(),
            name: "fail-test",
            command: ExecutableCommand(executable: "/bin/sh", arguments: ["-c", "exit 42"]),
            timeoutSeconds: 10
        )

        let result = try await executor.execute(spec: spec, onOutput: { _ in }, onStderr: { _ in })

        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.exitCode, 42)
    }

    func testJobCancellation() async throws {
        let executor = NativeProcessExecutor()
        let spec = JobSpec(
            submittedBy: UUID(),
            name: "sleep-test",
            command: ExecutableCommand(executable: "/bin/sleep", arguments: ["5"]),
            timeoutSeconds: 300
        )

        let task = Task {
            try await executor.execute(spec: spec, onOutput: { _ in }, onStderr: { _ in })
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        await executor.cancel(jobID: JobID(rawValue: spec.jobID))

        let result = await task.result
        if case .failure(let error) = result {
            XCTAssertTrue(error is JobError)
        }
    }

    func testJobPriorityComparison() {
        XCTAssertTrue(JobPriority.critical > JobPriority.high)
        XCTAssertTrue(JobPriority.high > JobPriority.normal)
        XCTAssertTrue(JobPriority.normal > JobPriority.low)
        XCTAssertTrue(JobPriority.low > JobPriority.lowest)
    }
}
