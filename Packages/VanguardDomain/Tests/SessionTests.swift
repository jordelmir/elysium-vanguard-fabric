import XCTest
@testable import VanguardDomain
import VanguardTestSupport

final class SessionTests: XCTestCase {
    func testSessionCreation() {
        let session = TestHelpers.makeSession()
        XCTAssertNotNil(session.id)
        XCTAssertTrue(session.isActive)
    }

    func testConnectionStateDisplayLabels() {
        XCTAssertEqual(ConnectionState.idle.displayLabel, "Idle")
        XCTAssertEqual(ConnectionState.resolving.displayLabel, "Resolving...")
        XCTAssertEqual(ConnectionState.ready.displayLabel, "Connected")
        XCTAssertEqual(ConnectionState.closing.displayLabel, "Closing...")
        XCTAssertEqual(ConnectionState.closed.displayLabel, "Closed")
    }

    func testConnectionStateEquality() {
        XCTAssertEqual(ConnectionState.idle, ConnectionState.idle)
        XCTAssertEqual(ConnectionState.ready, ConnectionState.ready)
        XCTAssertNotEqual(ConnectionState.idle, ConnectionState.ready)
    }

    func testConnectionFailureDescriptions() {
        XCTAssertNotNil(ConnectionFailure.nodeUnreachable.localizedDescription)
        XCTAssertNotNil(ConnectionFailure.tlsHandshakeFailed.localizedDescription)
        XCTAssertNotNil(ConnectionFailure.timeout.localizedDescription)
    }
}
