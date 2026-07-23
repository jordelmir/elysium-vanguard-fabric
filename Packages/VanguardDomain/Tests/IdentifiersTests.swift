import XCTest
@testable import VanguardDomain
import VanguardTestSupport

final class IdentifiersTests: XCTestCase {
    func testNodeIDEquality() {
        let id1 = NodeID(rawValue: UUID())
        let id2 = NodeID(rawValue: id1.rawValue)
        XCTAssertEqual(id1, id2)
    }

    func testNodeIDUniqueness() {
        let id1 = NodeID()
        let id2 = NodeID()
        XCTAssertNotEqual(id1, id2)
    }

    func testSessionIDRawValue() {
        let uuid = UUID()
        let id = SessionID(rawValue: uuid)
        XCTAssertEqual(id.rawValue, uuid)
    }

    func testOperationIDCodable() throws {
        let id = OperationID()
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(OperationID.self, from: data)
        XCTAssertEqual(id, decoded)
    }

    func testTerminalSessionIDHashable() {
        let id1 = TerminalSessionID()
        let id2 = TerminalSessionID()
        var set = Set<TerminalSessionID>()
        set.insert(id1)
        set.insert(id2)
        XCTAssertEqual(set.count, 2)
    }
}
