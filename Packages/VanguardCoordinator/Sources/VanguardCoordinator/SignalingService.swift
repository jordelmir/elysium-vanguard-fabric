import Foundation
import os
import VanguardDomain

public struct SignalingOffer: Sendable, Equatable {
    public let sessionID: UUID
    public let fromNodeID: NodeID
    public let toNodeID: NodeID
    public let sdp: Data
    public let iceCandidates: [ICECandidate]
    public let createdAt: Date

    public init(
        sessionID: UUID = UUID(),
        fromNodeID: NodeID,
        toNodeID: NodeID,
        sdp: Data,
        iceCandidates: [ICECandidate] = [],
        createdAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.sdp = sdp
        self.iceCandidates = iceCandidates
        self.createdAt = createdAt
    }
}

public struct SignalingAnswer: Sendable, Equatable {
    public let sessionID: UUID
    public let fromNodeID: NodeID
    public let toNodeID: NodeID
    public let sdp: Data
    public let iceCandidates: [ICECandidate]
    public let accepted: Bool

    public init(
        sessionID: UUID,
        fromNodeID: NodeID,
        toNodeID: NodeID,
        sdp: Data,
        iceCandidates: [ICECandidate] = [],
        accepted: Bool = true
    ) {
        self.sessionID = sessionID
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.sdp = sdp
        self.iceCandidates = iceCandidates
        self.accepted = accepted
    }
}

public struct ICECandidate: Sendable, Equatable {
    public let candidate: String
    public let sdpMLineIndex: Int32
    public let sdpMid: String?

    public init(candidate: String, sdpMLineIndex: Int32 = 0, sdpMid: String? = nil) {
        self.candidate = candidate
        self.sdpMLineIndex = sdpMLineIndex
        self.sdpMid = sdpMid
    }
}

public struct SignalingSession: Sendable, Equatable {
    public let sessionID: UUID
    public let fromNodeID: NodeID
    public let toNodeID: NodeID
    public let offer: SignalingOffer?
    public let answer: SignalingAnswer?
    public let createdAt: Date
    public var lastActivityAt: Date

    public init(
        sessionID: UUID,
        fromNodeID: NodeID,
        toNodeID: NodeID,
        offer: SignalingOffer? = nil,
        answer: SignalingAnswer? = nil,
        createdAt: Date = Date(),
        lastActivityAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.offer = offer
        self.answer = answer
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
    }
}

public actor SignalingService {
    private var sessions: [UUID: SignalingSession] = [:]
    private var pendingCandidates: [UUID: [ICECandidate]] = [:]
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Signaling")

    public init() {}

    public func createOffer(_ offer: SignalingOffer) -> SignalingSession {
        let session = SignalingSession(
            sessionID: offer.sessionID,
            fromNodeID: offer.fromNodeID,
            toNodeID: offer.toNodeID,
            offer: offer
        )
        sessions[offer.sessionID] = session
        logger.info("Signaling offer created: \(offer.sessionID.uuidString)")
        return session
    }

    public func receiveAnswer(_ answer: SignalingAnswer) -> SignalingSession? {
        guard var session = sessions[answer.sessionID] else {
            logger.warning("Signaling answer for unknown session \(answer.sessionID.uuidString)")
            return nil
        }
        session = SignalingSession(
            sessionID: session.sessionID,
            fromNodeID: session.fromNodeID,
            toNodeID: session.toNodeID,
            offer: session.offer,
            answer: answer,
            lastActivityAt: Date()
        )
        sessions[answer.sessionID] = session
        logger.info("Signaling answer received: \(answer.sessionID.uuidString)")
        return session
    }

    public func addICECandidate(_ candidate: ICECandidate, toSession sessionID: UUID) {
        var candidates = pendingCandidates[sessionID] ?? []
        candidates.append(candidate)
        pendingCandidates[sessionID] = candidates
        if var session = sessions[sessionID] {
            session = SignalingSession(
                sessionID: session.sessionID,
                fromNodeID: session.fromNodeID,
                toNodeID: session.toNodeID,
                offer: session.offer,
                answer: session.answer,
                lastActivityAt: Date()
            )
            sessions[sessionID] = session
        }
        logger.debug("ICE candidate added to session \(sessionID.uuidString)")
    }

    public func pendingICECandidates(for sessionID: UUID) -> [ICECandidate] {
        pendingCandidates[sessionID] ?? []
    }

    public func session(_ sessionID: UUID) -> SignalingSession? {
        sessions[sessionID]
    }

    public func sessionsBetween(_ nodeA: NodeID, and nodeB: NodeID) -> [SignalingSession] {
        sessions.values.filter { session in
            (session.fromNodeID == nodeA && session.toNodeID == nodeB) ||
            (session.fromNodeID == nodeB && session.toNodeID == nodeA)
        }
    }

    public func closeSession(_ sessionID: UUID) {
        sessions.removeValue(forKey: sessionID)
        pendingCandidates.removeValue(forKey: sessionID)
        logger.info("Signaling session closed: \(sessionID.uuidString)")
    }

    public func cleanupStale(maxAge: TimeInterval = 600) {
        let now = Date()
        let stale = sessions.filter { now.timeIntervalSince($0.value.lastActivityAt) > maxAge }
        for id in stale.keys {
            sessions.removeValue(forKey: id)
            pendingCandidates.removeValue(forKey: id)
        }
        if !stale.isEmpty {
            logger.info("Cleaned up \(stale.count) stale signaling sessions")
        }
    }

    public func sessionCount() -> Int {
        sessions.count
    }
}
