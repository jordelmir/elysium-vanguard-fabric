import Foundation
import XCTest
@testable import VanguardSecurity
import VanguardDomain

final class CapabilityNegotiatorTests: XCTestCase {
    func testNegotiationAgreesOnCommonCapabilities() async {
        let negotiator = CapabilityNegotiator()
        let consoleOffered: Set<NodeCapability> = [.screenView, .screenControl, .terminalOpen, .fileRead]
        let nodeRequired: Set<NodeCapability> = [.screenView, .terminalOpen]
        let nodeOffered: Set<NodeCapability> = [.screenView, .screenControl, .clipboardRead]

        let result = await negotiator.negotiate(
            consoleOffered: consoleOffered,
            nodeRequired: nodeRequired,
            nodeOffered: nodeOffered
        )

        XCTAssertTrue(result.agreedUpon.contains(.screenView), "screenView should be agreed")
        XCTAssertTrue(result.agreedUpon.contains(.screenControl), "screenControl should be agreed")
        XCTAssertTrue(result.agreedUpon.contains(.terminalOpen), "terminalOpen should be agreed (in nodeRequired)")
        XCTAssertFalse(result.agreedUpon.contains(.clipboardRead), "clipboardRead not in consoleOffered, so not agreed")
        XCTAssertFalse(result.rejectedByNode.contains(.screenView))
    }

    func testRejectsCapabilitiesNotOfferedByEither() async {
        let negotiator = CapabilityNegotiator()
        let consoleOffered: Set<NodeCapability> = [.screenView]
        let nodeRequired: Set<NodeCapability> = [.processExecute]
        let nodeOffered: Set<NodeCapability> = [.screenView]

        let result = await negotiator.negotiate(
            consoleOffered: consoleOffered,
            nodeRequired: nodeRequired,
            nodeOffered: nodeOffered
        )

        XCTAssertTrue(result.rejectedByConsole.contains(.processExecute))
    }

    func testDefaultCapabilities() async {
        let negotiator = CapabilityNegotiator()
        let consoleCaps = await negotiator.defaultConsoleCapabilities()
        let nodeCaps = await negotiator.defaultNodeCapabilities()

        XCTAssertTrue(consoleCaps.contains(.screenView))
        XCTAssertTrue(consoleCaps.contains(.screenControl))
        XCTAssertTrue(nodeCaps.contains(.screenView))
        XCTAssertFalse(nodeCaps.contains(.nodeShutdown))
    }

    func testFullyAgreedWhenNoRejections() async {
        let negotiator = CapabilityNegotiator()
        let result = await negotiator.negotiate(
            consoleOffered: [.screenView],
            nodeRequired: [.screenView],
            nodeOffered: [.screenView]
        )
        XCTAssertTrue(result.isFullyAgreed)
    }
}
