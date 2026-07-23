import XCTest
import Foundation
@testable import VanguardTerminal
@testable import VanguardDomain

@available(macOS 12.3, *)
final class POSIXTerminalServiceTests: XCTestCase {
    func testOpenTerminal() async {
        let service = POSIXTerminalService()
        let config = TerminalConfiguration(
            shell: "/bin/zsh",
            columns: 80,
            rows: 24
        )

        do {
            let handle = try await service.open(configuration: config)
            XCTAssertGreaterThan(handle.pid, 0)
            XCTAssertEqual(handle.state, .open)
            await service.close(sessionID: handle.sessionID, signal: .hangup)
        } catch {
            XCTFail("Open terminal failed: \(error)")
        }
    }

    func testWriteToTerminal() async {
        let service = POSIXTerminalService()
        let config = TerminalConfiguration(
            shell: "/bin/zsh",
            columns: 80,
            rows: 24
        )

        do {
            let handle = try await service.open(configuration: config)
            let echoCommand = "echo hello\n"
            try await service.write(sessionID: handle.sessionID, data: Data(echoCommand.utf8))
            try? await Task.sleep(nanoseconds: 200_000_000)
            await service.close(sessionID: handle.sessionID, signal: .hangup)
        } catch {
            XCTFail("Write terminal failed: \(error)")
        }
    }

    func testResizeTerminal() async {
        let service = POSIXTerminalService()
        let config = TerminalConfiguration(
            shell: "/bin/zsh",
            columns: 80,
            rows: 24
        )

        do {
            let handle = try await service.open(configuration: config)
            try await service.resize(sessionID: handle.sessionID, columns: 120, rows: 40)
            await service.close(sessionID: handle.sessionID, signal: .hangup)
        } catch {
            XCTFail("Resize terminal failed: \(error)")
        }
    }

    func testGetOutput() async {
        let service = POSIXTerminalService()
        let config = TerminalConfiguration(
            shell: "/bin/zsh",
            columns: 80,
            rows: 24
        )

        do {
            let handle = try await service.open(configuration: config)
            let output = service.getOutput(sessionID: handle.sessionID, fromOffset: 0)
            var receivedData = Data()
            for try await data in output {
                receivedData.append(data)
                if receivedData.count > 0 { break }
            }
            await service.close(sessionID: handle.sessionID, signal: .hangup)
        } catch {
            XCTFail("Get output failed: \(error)")
        }
    }

    func testCloseTerminal() async {
        let service = POSIXTerminalService()
        let config = TerminalConfiguration(
            shell: "/bin/zsh",
            columns: 80,
            rows: 24
        )

        do {
            let handle = try await service.open(configuration: config)
            await service.close(sessionID: handle.sessionID, signal: .hangup)
            try? await Task.sleep(nanoseconds: 100_000_000)
        } catch {
            XCTFail("Close terminal failed: \(error)")
        }
    }
}
