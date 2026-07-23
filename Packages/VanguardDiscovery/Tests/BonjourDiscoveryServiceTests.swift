import XCTest
import Foundation
@testable import VanguardDiscovery
@testable import VanguardDomain

@available(macOS 12.3, *)
final class BonjourDiscoveryServiceTests: XCTestCase {
    func testPublishAdvertisement() async {
        let service = BonjourDiscoveryService()
        let ad = NodeAdvertisement(
            nodeIDHash: Data("test-hash".utf8),
            displayName: "Test Node",
            architecture: .arm64,
            osFamily: .macOS,
            osVersion: "14.0",
            protocolVersion: .v1,
            pairingState: .untrusted,
            endpoint: NodeEndpoint(host: "localhost", port: 49494)
        )

        do {
            try await service.publishAdvertisement(ad)
            try await Task.sleep(nanoseconds: 200_000_000)
            await service.unpublish()
        } catch {
            XCTFail("Publish failed: \(error)")
        }
    }

    func testStartStopBrowsing() async {
        let service = BonjourDiscoveryService()

        do {
            try await service.startBrowsing()
            try await Task.sleep(nanoseconds: 200_000_000)
            await service.stopBrowsing()
        } catch {
            XCTFail("Browse failed: \(error)")
        }
    }
}

private final class StateCollector<T>: @unchecked Sendable {
    private(set) var states: [T] = []
    private let lock = NSLock()

    func add(_ state: T) {
        lock.withLock {
            states.append(state)
        }
    }
}
