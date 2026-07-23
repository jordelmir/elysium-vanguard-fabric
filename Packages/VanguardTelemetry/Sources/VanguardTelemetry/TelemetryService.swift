import Foundation
import VanguardDomain

// MARK: - Telemetry Collector Protocol

public protocol TelemetryCollector: Sendable {
    func collectSnapshot() async throws -> NodeTelemetrySnapshot
    func startCollecting(interval: TimeInterval) async throws
    func stopCollecting() async
    var snapshots: AsyncThrowingStream<NodeTelemetrySnapshot, Error> { get }
}
