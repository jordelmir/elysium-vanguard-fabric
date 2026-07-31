import Foundation
import os
import VanguardDomain

public struct RendezvousRequest: Sendable, Equatable {
    public let requestID: UUID
    public let consoleID: NodeID
    public let targetNodeID: NodeID
    public let preferredRoute: ConnectionRoute?
    public let createdAt: Date

    public init(
        requestID: UUID = UUID(),
        consoleID: NodeID,
        targetNodeID: NodeID,
        preferredRoute: ConnectionRoute? = nil,
        createdAt: Date = Date()
    ) {
        self.requestID = requestID
        self.consoleID = consoleID
        self.targetNodeID = targetNodeID
        self.preferredRoute = preferredRoute
        self.createdAt = createdAt
    }
}

public struct RendezvousOffer: Sendable, Equatable {
    public let requestID: UUID
    public let consoleEndpoint: NodeEndpoint
    public let nodeEndpoint: NodeEndpoint
    public let route: ConnectionRoute
    public let sessionSecret: Data

    public init(
        requestID: UUID,
        consoleEndpoint: NodeEndpoint,
        nodeEndpoint: NodeEndpoint,
        route: ConnectionRoute,
        sessionSecret: Data
    ) {
        self.requestID = requestID
        self.consoleEndpoint = consoleEndpoint
        self.nodeEndpoint = nodeEndpoint
        self.route = route
        self.sessionSecret = sessionSecret
    }
}

public struct RendezvousAnswer: Sendable, Equatable {
    public let requestID: UUID
    public let accepted: Bool
    public let selectedRoute: ConnectionRoute?

    public init(requestID: UUID, accepted: Bool, selectedRoute: ConnectionRoute? = nil) {
        self.requestID = requestID
        self.accepted = accepted
        self.selectedRoute = selectedRoute
    }
}

public actor RendezvousService {
    private let coordinator: CoordinatorService
    private var pendingRequests: [UUID: RendezvousRequest] = [:]
    private var activeSessions: [UUID: RendezvousOffer] = [:]
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Rendezvous")

    public init(coordinator: CoordinatorService) {
        self.coordinator = coordinator
    }

    public func requestRendezvous(
        consoleID: NodeID,
        targetNodeID: NodeID,
        preferredRoute: ConnectionRoute? = nil
    ) async throws -> RendezvousRequest {
        guard let node = await coordinator.node(byID: targetNodeID) else {
            throw RendezvousError.nodeNotFound
        }

        let request = RendezvousRequest(
            consoleID: consoleID,
            targetNodeID: targetNodeID,
            preferredRoute: preferredRoute
        )
        pendingRequests[request.requestID] = request
        logger.info("Rendezvous requested: \(consoleID.rawValue.uuidString) → \(targetNodeID.rawValue.uuidString)")
        return request
    }

    public func respondToRendezvous(
        requestID: UUID,
        accepted: Bool,
        consoleEndpoint: NodeEndpoint,
        nodeEndpoint: NodeEndpoint,
        route: ConnectionRoute,
        sessionSecret: Data
    ) async -> RendezvousOffer? {
        guard pendingRequests[requestID] != nil else {
            logger.warning("Rendezvous response for unknown request \(requestID.uuidString)")
            return nil
        }

        let offer = RendezvousOffer(
            requestID: requestID,
            consoleEndpoint: consoleEndpoint,
            nodeEndpoint: nodeEndpoint,
            route: route,
            sessionSecret: sessionSecret
        )

        if accepted {
            activeSessions[requestID] = offer
            pendingRequests.removeValue(forKey: requestID)
            logger.info("Rendezvous accepted: \(requestID.uuidString)")
        } else {
            pendingRequests.removeValue(forKey: requestID)
            logger.info("Rendezvous rejected: \(requestID.uuidString)")
        }

        return offer
    }

    public func completeRendezvous(requestID: UUID) -> RendezvousAnswer? {
        guard let offer = activeSessions[requestID] else { return nil }
        activeSessions.removeValue(forKey: requestID)
        return RendezvousAnswer(requestID: requestID, accepted: true, selectedRoute: offer.route)
    }

    public func cancelRendezvous(requestID: UUID) {
        pendingRequests.removeValue(forKey: requestID)
        activeSessions.removeValue(forKey: requestID)
        logger.info("Rendezvous cancelled: \(requestID.uuidString)")
    }

    public func pendingRequestCount() -> Int {
        pendingRequests.count
    }

    public func activeSessionCount() -> Int {
        activeSessions.count
    }

    public func cleanupStale(maxAge: TimeInterval = 300) {
        let now = Date()
        let stale = pendingRequests.filter { now.timeIntervalSince($0.value.createdAt) > maxAge }
        for id in stale.keys {
            pendingRequests.removeValue(forKey: id)
        }
        if !stale.isEmpty {
            logger.info("Cleaned up \(stale.count) stale rendezvous requests")
        }
    }
}

public enum RendezvousError: Error, Sendable {
    case nodeNotFound
    case requestExpired
    case alreadyConnected
}

extension RendezvousError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .nodeNotFound: return "Target node not found in directory"
        case .requestExpired: return "Rendezvous request expired"
        case .alreadyConnected: return "Already connected to target"
        }
    }
}
