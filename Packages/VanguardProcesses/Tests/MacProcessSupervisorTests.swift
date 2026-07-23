import Foundation
import XCTest
@testable import VanguardProcesses

final class MacProcessSupervisorTests: XCTestCase {
    func testListProcesses() async throws {
        let supervisor = MacProcessSupervisor()
        let processes = try await supervisor.listProcesses()
        XCTAssertFalse(processes.isEmpty)
        XCTAssertTrue(processes.contains { $0.pid > 0 })
    }

    func testGetProcessInfo() async throws {
        let supervisor = MacProcessSupervisor()
        let info = try await supervisor.getProcessInfo(pid: 1)
        XCTAssertEqual(info.pid, 1)
        XCTAssertFalse(info.name.isEmpty)
    }

    func testTerminateProcess() async throws {
        let supervisor = MacProcessSupervisor()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["60"]
        try process.run()
        let pid = process.processIdentifier

        try await supervisor.terminateProcess(pid: pid, signal: SIGTERM)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 15)
    }
}
