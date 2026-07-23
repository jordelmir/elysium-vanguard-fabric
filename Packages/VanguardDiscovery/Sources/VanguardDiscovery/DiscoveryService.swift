import Foundation
import VanguardDomain

// MARK: - Discovery Service Protocol

public protocol DiscoveryService: Sendable {
    var stateUpdates: AsyncThrowingStream<DiscoveryState, Error> { get }

    func startBrowsing() async throws
    func stopBrowsing() async
    func publishAdvertisement(_ advertisement: NodeAdvertisement) async throws
    func unpublish() async
}

// MARK: - Discovery State

public enum DiscoveryState: Sendable, Equatable {
    case idle
    case browsing
    case nodeFound(NodeAdvertisement)
    case nodeUpdated(NodeAdvertisement)
    case nodeLost(nodeIDHash: Data)
    case failed(DiscoveryError)

    public static func == (lhs: DiscoveryState, rhs: DiscoveryState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.browsing, .browsing): return true
        case (.nodeFound(let a), .nodeFound(let b)): return a == b
        case (.nodeUpdated(let a), .nodeUpdated(let b)): return a == b
        case (.nodeLost(let a), .nodeLost(let b)): return a == b
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Discovery Configuration

public struct DiscoveryConfiguration: Sendable, Equatable {
    public let serviceName: String
    public let serviceType: String
    public let browseTimeout: TimeInterval
    public let nodeExpiration: TimeInterval

    public init(
        serviceName: String = "Elysium Vanguard Node",
        serviceType: String = "_elysium-vanguard._tcp",
        browseTimeout: TimeInterval = 10,
        nodeExpiration: TimeInterval = 30
    ) {
        self.serviceName = serviceName
        self.serviceType = serviceType
        self.browseTimeout = browseTimeout
        self.nodeExpiration = nodeExpiration
    }

    public static let `default` = DiscoveryConfiguration()
}
