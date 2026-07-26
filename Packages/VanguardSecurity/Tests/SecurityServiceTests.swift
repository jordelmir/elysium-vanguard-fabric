import Foundation
import XCTest
@testable import VanguardSecurity
import VanguardDomain

final class SecurityServiceTests: XCTestCase {
    func testAuthorizationContext() {
        let context = AuthorizationContext(
            sessionID: SessionID(),
            nodeID: NodeID(),
            remoteNodeID: NodeID(),
            grantedCapabilities: [.screenView],
            sequenceNumber: 1
        )
        XCTAssertEqual(context.grantedCapabilities, [.screenView])
        XCTAssertEqual(context.sequenceNumber, 1)
    }

    func testAuthorizationDecision() {
        let allowed = AuthorizationDecision.allowed
        let denied = AuthorizationDecision.denied(reason: "test")
        let confirm = AuthorizationDecision.requiresConfirmation

        if case .allowed = allowed {} else { XCTFail("Expected allowed") }
        if case .denied(let reason) = denied { XCTAssertEqual(reason, "test") } else { XCTFail("Expected denied") }
        if case .requiresConfirmation = confirm {} else { XCTFail("Expected requiresConfirmation") }
    }

    func testNodeAction() {
        let actions: [SecurityAction] = [
            .startScreenCapture,
            .openTerminal,
            .executeProcess(command: "ls"),
            .shutdown
        ]
        XCTAssertEqual(actions.count, 4)
    }
}
