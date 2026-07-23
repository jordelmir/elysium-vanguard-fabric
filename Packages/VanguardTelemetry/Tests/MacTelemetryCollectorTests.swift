import Foundation
import XCTest
@testable import VanguardTelemetry

final class MacTelemetryCollectorTests: XCTestCase {
    func testCollectSnapshot() async throws {
        let collector = MacTelemetryCollector()
        let snapshot = try await collector.collectSnapshot()
        XCTAssertGreaterThan(snapshot.cpu.coreCount, 0)
        XCTAssertGreaterThan(snapshot.memory.totalBytes, 0)
        XCTAssertGreaterThan(snapshot.capturedAtMonotonicNanos, 0)
    }

    func testStartAndStop() async throws {
        let collector = MacTelemetryCollector()
        try await collector.startCollecting(interval: 1.0)
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        await collector.stopCollecting()
    }
}
