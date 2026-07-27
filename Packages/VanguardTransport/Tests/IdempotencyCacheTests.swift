import Foundation
import XCTest
@testable import VanguardTransport

final class IdempotencyCacheTests: XCTestCase {
    func testDuplicateDetection() {
        let cache = IdempotencyCache()
        XCTAssertFalse(cache.isDuplicate(operationID: 1))
        cache.markProcessed(operationID: 1)
        XCTAssertTrue(cache.isDuplicate(operationID: 1))
    }

    func testDifferentIDsNotDuplicate() {
        let cache = IdempotencyCache()
        cache.markProcessed(operationID: 1)
        XCTAssertFalse(cache.isDuplicate(operationID: 2))
    }

    func testReset() {
        let cache = IdempotencyCache()
        cache.markProcessed(operationID: 1)
        cache.reset()
        XCTAssertFalse(cache.isDuplicate(operationID: 1))
    }

    func testPruneOldEntries() {
        let cache = IdempotencyCache(maxAge: 0.1)
        cache.markProcessed(operationID: 1)
        XCTAssertTrue(cache.isDuplicate(operationID: 1))
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertFalse(cache.isDuplicate(operationID: 1))
    }
}
