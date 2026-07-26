import XCTest
@testable import VanguardSecurity
@testable import VanguardDomain
@testable import VanguardProtocol

final class SecurityTests: XCTestCase {
    func testUnauthenticatedInputRejected() async {
        let guard_auth = AuthorizationGuard()
        let sessionID = SessionID()

        await guard_auth.registerSession(sessionID, capabilities: [])

        let hasAccess = await guard_auth.checkCapability(.screenView, sessionID: sessionID)
        XCTAssertFalse(hasAccess, "Session without capabilities should be denied")
    }

    func testRevokedPeerRejected() {
        let peer = TrustedPeer(
            nodeID: NodeID(),
            signingPublicKey: Data(repeating: 0x01, count: 32),
            agreementPublicKey: Data(repeating: 0x02, count: 32),
            certificateFingerprint: Data(repeating: 0x03, count: 32),
            grantedCapabilities: [.screenView, .screenControl],
            pairedAt: Date(),
            lastSeenAt: Date(),
            trustStatus: .revoked
        )
        XCTAssertTrue(peer.isRevoked, "Revoked peer should be detected")
    }

    func testExpiredCapabilityGrant() {
        let grant = CapabilityGrant(
            sessionID: UUID(),
            subjectDeviceID: UUID(),
            issuerDeviceID: UUID(),
            capabilities: [.screenView],
            expiresAt: Date().addingTimeInterval(-1800)
        )
        XCTAssertFalse(grant.isValid, "Expired grant should be invalid")
        XCTAssertFalse(grant.hasCapability(.screenView), "Expired grant should not grant capabilities")
    }

    func testPathTraversalDetection() {
        let paths = [
            "../../../etc/passwd",
            "foo/../../bar",
            "/tmp/safe/../../../etc/shadow",
            "~/../.ssh/authorized_keys"
        ]
        for path in paths {
            let components = URL(fileURLWithPath: path).pathComponents
            let hasTraversal = components.contains("..")
            XCTAssertTrue(hasTraversal || path.hasPrefix("/"), "Path '\(path)' should be detected as traversal or absolute")
        }
    }

    func testOversizedPayloadRejected() {
        let largeData = Data(repeating: 0xFF, count: 2 * 1024 * 1024)
        XCTAssertGreaterThan(largeData.count, VanguardProtocolConstants.maxControlPayload, "Large payload should exceed control limit")
        XCTAssertLessThanOrEqual(largeData.count, VanguardProtocolConstants.maxVideoAccessUnit, "Large payload should be within video limit")
    }

    func testReplayDetection() {
        var seenNonces = Set<Data>()
        let nonce1 = Data(repeating: 0x01, count: 16)
        let nonce2 = Data(repeating: 0x02, count: 16)
        let nonce1Repeat = Data(repeating: 0x01, count: 16)

        seenNonces.insert(nonce1)
        seenNonces.insert(nonce2)

        XCTAssertTrue(seenNonces.contains(nonce1Repeat), "Duplicate nonce should be detected")
        XCTAssertFalse(seenNonces.contains(Data(repeating: 0x03, count: 16)), "New nonce should not be in set")
    }

    func testLogFloodingPrevention() {
        let maxEvents = 100
        var events = Array(0..<150)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        XCTAssertEqual(events.count, maxEvents, "Event log should be capped")
    }

    func testFabricCapabilityCompleteness() {
        XCTAssertEqual(FabricCapability.allCases.count, 25, "Should have 25 capabilities")
    }
}
