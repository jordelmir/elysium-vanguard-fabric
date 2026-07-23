import XCTest
@testable import VanguardTestSupport
@testable import VanguardDomain

final class TestHelpersTests: XCTestCase {
    func testMakeNode() {
        let node = TestHelpers.makeNode()
        XCTAssertNotNil(node.id)
        XCTAssertEqual(node.displayName, "Test Node")
    }

    func testMakeSession() {
        let session = TestHelpers.makeSession()
        XCTAssertNotNil(session.id)
        XCTAssertTrue(session.isActive)
    }

    func testMakeEndpoint() {
        let endpoint = TestHelpers.makeEndpoint()
        XCTAssertEqual(endpoint.host, "127.0.0.1")
        XCTAssertEqual(endpoint.port, 9100)
    }

    func testMakeAdvertisement() {
        let ad = TestHelpers.makeAdvertisement()
        XCTAssertEqual(ad.displayName, "Test Node")
        XCTAssertEqual(ad.protocolVersion, .v1)
    }

    func testMakeTelemetrySnapshot() {
        let snapshot = TestHelpers.makeTelemetrySnapshot()
        XCTAssertEqual(snapshot.cpu.coreCount, 8)
        XCTAssertEqual(snapshot.memory.pressure, .normal)
    }

    func testMakeAuditEntry() {
        let entry = TestHelpers.makeAuditEntry()
        XCTAssertEqual(entry.action, .connected)
        XCTAssertEqual(entry.decision, .allowed)
    }
}

final class MockTransportTests: XCTestCase {
    func testMockTransportBasic() async throws {
        let mock = MockTransport()
        try await mock.connect(to: TestHelpers.makeEndpoint())

        let msg = OutboundMessage(messageType: .heartbeat)
        try await mock.send(msg)

        let sent = await mock.getSentMessages()
        XCTAssertEqual(sent.count, 1)
    }
}

final class MockPermissionServiceTests: XCTestCase {
    func testCheckAllPermissions() async {
        let mock = MockPermissionService()
        let results = await mock.checkAllPermissions()
        XCTAssertEqual(results.count, PermissionKind.allCases.count)
    }

    func testCheckPermission() async {
        var mock = MockPermissionService()
        mock.permissionStates = [.screenRecording: .granted]
        let state = await mock.checkPermission(kind: .screenRecording)
        XCTAssertEqual(state, .granted)
    }
}

final class MockIdentityServiceTests: XCTestCase {
    func testGetOrCreateIdentity() async throws {
        let mock = MockIdentityService()
        let identity = try await mock.getOrCreateIdentity()
        XCTAssertNotNil(identity.signingPublicKey)
        XCTAssertNotNil(identity.agreementPublicKey)
    }

    func testGenerateChallenge() async throws {
        let mock = MockIdentityService()
        let challenge = try await mock.generateChallenge()
        XCTAssertEqual(challenge.code, "123456")
    }
}

final class MockSecurityServiceTests: XCTestCase {
    func testAuthorize() async throws {
        let mock = MockSecurityService()
        let context = AuthorizationContext(
            sessionID: SessionID(),
            nodeID: NodeID(),
            remoteNodeID: NodeID(),
            grantedCapabilities: [.screenView],
            sequenceNumber: 0
        )
        let decision = try await mock.authorize(.startScreenCapture, context: context)
        XCTAssertEqual(decision, .allowed)
    }

    func testRateLimitBlocked() async {
        var mock = MockSecurityService()
        mock.rateLimitBlocked = true
        do {
            try await mock.rateLimitCheck(identifier: "test")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertTrue(error is InputError)
        }
    }
}
