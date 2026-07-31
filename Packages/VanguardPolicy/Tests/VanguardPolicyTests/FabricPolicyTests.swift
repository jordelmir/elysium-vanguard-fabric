import XCTest
import VanguardDomain
@testable import VanguardPolicy

final class FabricPolicyTests: XCTestCase {
    func testViewScreenRequiresScreenView() {
        XCTAssertEqual(SecurityPolicyAction.viewScreen.requiredCapability, .screenView)
    }

    func testControlScreenRequiresScreenControl() {
        XCTAssertEqual(SecurityPolicyAction.controlScreen.requiredCapability, .screenControl)
    }

    func testOpenTerminalRequiresTerminalOpen() {
        XCTAssertEqual(SecurityPolicyAction.openTerminal.requiredCapability, .terminalOpen)
    }

    func testReadClipboardRequiresClipboardRead() {
        XCTAssertEqual(SecurityPolicyAction.readClipboard.requiredCapability, .clipboardRead)
    }

    func testWriteClipboardRequiresClipboardWrite() {
        XCTAssertEqual(SecurityPolicyAction.writeClipboard.requiredCapability, .clipboardWrite)
    }

    func testReadFileRequiresFileRead() {
        XCTAssertEqual(SecurityPolicyAction.readFile(path: "/test").requiredCapability, .fileRead)
    }

    func testWriteFileRequiresFileWrite() {
        XCTAssertEqual(SecurityPolicyAction.writeFile(path: "/test").requiredCapability, .fileWrite)
    }

    func testDeleteFileRequiresFileDelete() {
        XCTAssertEqual(SecurityPolicyAction.deleteFile(path: "/test").requiredCapability, .fileDelete)
    }

    func testListProcessesRequiresProcessExecute() {
        XCTAssertEqual(SecurityPolicyAction.listProcesses.requiredCapability, .processExecute)
    }

    func testKillProcessRequiresProcessExecute() {
        XCTAssertEqual(SecurityPolicyAction.killProcess(pid: 1234).requiredCapability, .processExecute)
    }

    func testSubmitJobRequiresJobSubmit() {
        XCTAssertEqual(SecurityPolicyAction.submitJob.requiredCapability, .jobSubmit)
    }

    func testCancelJobRequiresJobCancel() {
        XCTAssertEqual(SecurityPolicyAction.cancelJob.requiredCapability, .jobCancel)
    }

    func testTransferArtifactRequiresArtifactWrite() {
        XCTAssertEqual(SecurityPolicyAction.transferArtifact.requiredCapability, .artifactWrite)
    }

    func testSyncWorkspaceRequiresWorkspaceWrite() {
        XCTAssertEqual(SecurityPolicyAction.syncWorkspace.requiredCapability, .workspaceWrite)
    }

    func testGetSystemInfoRequiresScreenView() {
        XCTAssertEqual(SecurityPolicyAction.getSystemInfo.requiredCapability, .screenView)
    }

    func testCaptureAudioRequiresAudioReceive() {
        XCTAssertEqual(SecurityPolicyAction.captureAudio.requiredCapability, .audioReceive)
    }

    func testGrantCapabilityRequiresPolicyAdmin() {
        XCTAssertEqual(SecurityPolicyAction.grantCapability.requiredCapability, .policyAdmin)
    }

    func testReadAuditRequiresPolicyAdmin() {
        XCTAssertEqual(SecurityPolicyAction.readAudit.requiredCapability, .policyAdmin)
    }
}
