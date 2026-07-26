import XCTest
@testable import VanguardObservability
@testable import VanguardDomain

final class FabricEventLogTests: XCTestCase {
    func testRecordEvent() async {
        let log = FabricEventLog()
        await log.record(.nodeConnected(NodeID()))
        let events = await log.recentEvents(count: 10)
        XCTAssertEqual(events.count, 1)
    }

    func testCategoryFiltering() async {
        let log = FabricEventLog()
        await log.record(.nodeConnected(NodeID()))
        await log.record(.captureStarted)
        await log.record(.nodeDisconnected(NodeID()))

        let nodeEvents = await log.eventsInCategory("node")
        XCTAssertEqual(nodeEvents.count, 2)
    }

    func testClear() async {
        let log = FabricEventLog()
        await log.record(.nodeConnected(NodeID()))
        await log.clear()
        let events = await log.recentEvents()
        XCTAssertTrue(events.isEmpty)
    }

    func testMaxEventsLimit() async {
        let log = FabricEventLog(maxEvents: 5)
        for _ in 0..<10 {
            await log.record(.nodeConnected(NodeID()))
        }
        let events = await log.recentEvents()
        XCTAssertEqual(events.count, 5)
    }
}
