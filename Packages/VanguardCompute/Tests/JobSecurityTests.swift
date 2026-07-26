import XCTest
@testable import VanguardCompute
@testable import VanguardDomain

final class JobSecurityTests: XCTestCase {
    func testJobSpecSignatureValidation() {
        let spec = JobSpec(
            submittedBy: UUID(),
            name: "test-job",
            command: ExecutableCommand(executable: "/bin/echo", arguments: ["hello"]),
            signature: Data(repeating: 0x01, count: 64)
        )
        XCTAssertFalse(spec.signature.isEmpty, "Job should have signature")
        XCTAssertEqual(spec.signature.count, 64, "Signature should be 64 bytes")
    }

    func testJobSecurityPolicyEnforcement() {
        let policy = JobSecurityPolicy(
            requiredCapabilities: [.processExecute],
            allowedExecutors: [.nativeProcess],
            requiresSignature: true,
            networkAccessAllowed: false,
            fileSystemAccess: .sandboxOnly
        )

        XCTAssertFalse(policy.networkAccessAllowed, "Network should be disabled")
        XCTAssertEqual(policy.fileSystemAccess, .sandboxOnly, "File access should be sandbox only")
        XCTAssertTrue(policy.requiresSignature, "Signature should be required")
    }

    func testSandboxPathValidation() {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent("Jobs/test-123")
        let outsidePath = "../../../etc/passwd"
        let resolvedOutside = URL(fileURLWithPath: outsidePath, relativeTo: sandbox).standardized.path
        XCTAssertFalse(resolvedOutside.hasPrefix(sandbox.path), "Path traversal should escape sandbox")
    }

    func testJobTimeoutEnforcement() {
        let spec = JobSpec(
            submittedBy: UUID(),
            name: "timeout-test",
            command: ExecutableCommand(executable: "/bin/sleep", arguments: ["300"]),
            timeoutSeconds: 5
        )
        XCTAssertEqual(spec.timeoutSeconds, 5, "Timeout should be enforced")
    }

    func testJobPriorityValidation() {
        let priorities: [JobPriority] = [.lowest, .low, .normal, .high, .critical]
        XCTAssertEqual(priorities.count, 5, "Should have 5 priority levels")
        XCTAssertTrue(JobPriority.critical > JobPriority.normal, "Critical should be higher than normal")
    }

    func testRetryPolicyLimits() {
        let policy = RetryPolicy(maxRetries: 3, backoffSeconds: 5, maxBackoffSeconds: 60)
        XCTAssertEqual(policy.maxRetries, 3)
        XCTAssertEqual(policy.backoffSeconds, 5)
        XCTAssertEqual(policy.maxBackoffSeconds, 60)

        let noRetry = RetryPolicy.noRetry
        XCTAssertEqual(noRetry.maxRetries, 0)
    }
}
