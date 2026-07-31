import Foundation
import os
import VanguardDomain

public struct RegisteredNode: Sendable, Equatable {
    public let nodeID: NodeID
    public let displayName: String
    public let endpoint: NodeEndpoint
    public let architecture: CPUArchitecture
    public let capabilities: Set<FabricCapability>
    public let registeredAt: Date
    public var lastHeartbeatAt: Date
    public var natType: NATType

    public init(
        nodeID: NodeID,
        displayName: String,
        endpoint: NodeEndpoint,
        architecture: CPUArchitecture,
        capabilities: Set<FabricCapability>,
        registeredAt: Date = Date(),
        lastHeartbeatAt: Date = Date(),
        natType: NATType = .unknown
    ) {
        self.nodeID = nodeID
        self.displayName = displayName
        self.endpoint = endpoint
        self.architecture = architecture
        self.capabilities = capabilities
        self.registeredAt = registeredAt
        self.lastHeartbeatAt = lastHeartbeatAt
        self.natType = natType
    }
}

public actor CoordinatorService {
    private var registeredNodes: [NodeID: RegisteredNode] = [:]
    private var heartbeatTimeout: TimeInterval
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Coordinator")

    public init(heartbeatTimeout: TimeInterval = 60) {
        self.heartbeatTimeout = heartbeatTimeout
    }

    public func registerNode(
        nodeID: NodeID,
        displayName: String,
        endpoint: NodeEndpoint,
        architecture: CPUArchitecture,
        capabilities: Set<FabricCapability>,
        natType: NATType = .unknown
    ) {
        let node = RegisteredNode(
            nodeID: nodeID,
            displayName: displayName,
            endpoint: endpoint,
            architecture: architecture,
            capabilities: capabilities,
            natType: natType
        )
        registeredNodes[nodeID] = node
        logger.info("Node registered: \(displayName) (\(nodeID.rawValue.uuidString))")
    }

    public func deregisterNode(_ nodeID: NodeID) {
        registeredNodes.removeValue(forKey: nodeID)
        logger.info("Node deregistered: \(nodeID.rawValue.uuidString)")
    }

    public func heartbeat(_ nodeID: NodeID) -> Bool {
        guard var node = registeredNodes[nodeID] else {
            return false
        }
        node.lastHeartbeatAt = Date()
        registeredNodes[nodeID] = node
        return true
    }

    public func nodeList() -> [RegisteredNode] {
        Array(registeredNodes.values)
    }

    public func node(byID nodeID: NodeID) -> RegisteredNode? {
        registeredNodes[nodeID]
    }

    public func nodes(withCapability capability: FabricCapability) -> [RegisteredNode] {
        registeredNodes.values.filter { $0.capabilities.contains(capability) }
    }

    public func nodes(architecture: CPUArchitecture) -> [RegisteredNode] {
        registeredNodes.values.filter { $0.architecture == architecture }
    }

    public func cleanupExpiredNodes() -> [NodeID] {
        let now = Date()
        let expired = registeredNodes.filter { node in
            now.timeIntervalSince(node.value.lastHeartbeatAt) > heartbeatTimeout
        }
        let expiredIDs = Array(expired.keys)
        for id in expiredIDs {
            registeredNodes.removeValue(forKey: id)
        }
        if !expiredIDs.isEmpty {
            logger.warning("Cleaned up \(expiredIDs.count) expired nodes")
        }
        return expiredIDs
    }

    public func nodeCount() -> Int {
        registeredNodes.count
    }

    public func updateNATType(_ nodeID: NodeID, natType: NATType) {
        guard var node = registeredNodes[nodeID] else { return }
        node.natType = natType
        registeredNodes[nodeID] = node
    }
}
