import XCTest
@testable import VanguardDomain
import VanguardTestSupport

final class NodeTests: XCTestCase {
    func testNodeCreation() {
        let node = TestHelpers.makeNode()
        XCTAssertEqual(node.displayName, "Test Node")
        XCTAssertEqual(node.architecture, .arm64)
        XCTAssertFalse(node.capabilities.isEmpty)
    }

    func testNodeCodable() throws {
        let node = TestHelpers.makeNode()
        let data = try JSONEncoder().encode(node)
        let decoded = try JSONDecoder().decode(VanguardNode.self, from: data)
        XCTAssertEqual(node.id, decoded.id)
        XCTAssertEqual(node.displayName, decoded.displayName)
    }

    func testTrustedPeerCreation() {
        let peer = TrustedPeer(
            nodeID: NodeID(),
            signingPublicKey: Data(repeating: 0x01, count: 32),
            agreementPublicKey: Data(repeating: 0x02, count: 32),
            certificateFingerprint: Data(repeating: 0x03, count: 32),
            grantedCapabilities: [.screenView, .terminalOpen],
            pairedAt: Date()
        )
        XCTAssertFalse(peer.isRevoked)
    }

    func testTrustedPeerRevoked() {
        let peer = TrustedPeer(
            nodeID: NodeID(),
            signingPublicKey: Data(),
            agreementPublicKey: Data(),
            certificateFingerprint: Data(),
            grantedCapabilities: [],
            pairedAt: Date(),
            revokedAt: Date()
        )
        XCTAssertTrue(peer.isRevoked)
    }

    func testNodeAdvertisementCodable() throws {
        let ad = TestHelpers.makeAdvertisement()
        let data = try JSONEncoder().encode(ad)
        let decoded = try JSONDecoder().decode(NodeAdvertisement.self, from: data)
        XCTAssertEqual(ad.displayName, decoded.displayName)
    }
}
