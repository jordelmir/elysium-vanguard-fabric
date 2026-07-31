import Testing
import Foundation
import VanguardDomain
@testable import VanguardCoordinator

@Suite("CoordinatorService — Presence Directory")
struct CoordinatorServiceTests {

    @Test("registerNode adds node to directory")
    func registerNode() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID,
            displayName: "Test Node",
            endpoint: NodeEndpoint(host: "192.168.1.1", port: 49494),
            architecture: .arm64,
            capabilities: [.screenView, .screenControl]
        )
        #expect(await coordinator.nodeCount() == 1)
        let node = await coordinator.node(byID: nodeID)
        #expect(node?.displayName == "Test Node")
    }

    @Test("deregisterNode removes node")
    func deregisterNode() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID,
            displayName: "Test",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: []
        )
        await coordinator.deregisterNode(nodeID)
        #expect(await coordinator.nodeCount() == 0)
    }

    @Test("heartbeat updates last seen")
    func heartbeat() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID,
            displayName: "HB",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: []
        )
        let result = await coordinator.heartbeat(nodeID)
        #expect(result == true)
        let missing = await coordinator.heartbeat(NodeID())
        #expect(missing == false)
    }

    @Test("nodeList returns all nodes")
    func nodeList() async {
        let coordinator = CoordinatorService()
        for _ in 0..<3 {
            await coordinator.registerNode(
                nodeID: NodeID(),
                displayName: "Node",
                endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
                architecture: .arm64,
                capabilities: []
            )
        }
        let nodes = await coordinator.nodeList()
        #expect(nodes.count == 3)
    }

    @Test("nodes withCapability filters correctly")
    func nodesWithCapability() async {
        let coordinator = CoordinatorService()
        let nodeA = NodeID()
        let nodeB = NodeID()
        await coordinator.registerNode(
            nodeID: nodeA,
            displayName: "A",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: [.screenView]
        )
        await coordinator.registerNode(
            nodeID: nodeB,
            displayName: "B",
            endpoint: NodeEndpoint(host: "10.0.0.2", port: 49494),
            architecture: .arm64,
            capabilities: [.terminalOpen]
        )
        let withScreen = await coordinator.nodes(withCapability: .screenView)
        #expect(withScreen.count == 1)
        #expect(withScreen.first?.nodeID == nodeA)
    }

    @Test("cleanupExpiredNodes removes old nodes")
    func cleanupExpired() async {
        let coordinator = CoordinatorService(heartbeatTimeout: 0)
        await coordinator.registerNode(
            nodeID: NodeID(),
            displayName: "Old",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: []
        )
        try? await Task.sleep(nanoseconds: 10_000_000)
        let expired = await coordinator.cleanupExpiredNodes()
        #expect(expired.count == 1)
        #expect(await coordinator.nodeCount() == 0)
    }

    @Test("nodes architecture filters correctly")
    func nodesByArch() async {
        let coordinator = CoordinatorService()
        await coordinator.registerNode(
            nodeID: NodeID(),
            displayName: "ARM",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: []
        )
        await coordinator.registerNode(
            nodeID: NodeID(),
            displayName: "Intel",
            endpoint: NodeEndpoint(host: "10.0.0.2", port: 49494),
            architecture: .x86_64,
            capabilities: []
        )
        let armNodes = await coordinator.nodes(architecture: .arm64)
        #expect(armNodes.count == 1)
    }
}

@Suite("RendezvousService — Connection Brokering")
struct RendezvousServiceTests {

    @Test("requestRendezvous creates request")
    func requestRendezvous() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID,
            displayName: "Target",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: []
        )
        let service = RendezvousService(coordinator: coordinator)
        let consoleID = NodeID()
        let request = try? await service.requestRendezvous(consoleID: consoleID, targetNodeID: nodeID)
        #expect(request != nil)
        #expect(request?.consoleID == consoleID)
        #expect(request?.targetNodeID == nodeID)
        #expect(await service.pendingRequestCount() == 1)
    }

    @Test("requestRendezvous fails for unknown node")
    func requestFailsUnknownNode() async {
        let coordinator = CoordinatorService()
        let service = RendezvousService(coordinator: coordinator)
        do {
            _ = try await service.requestRendezvous(
                consoleID: NodeID(),
                targetNodeID: NodeID()
            )
            Issue.record("Expected error")
        } catch {
            #expect(error is RendezvousError)
        }
    }

    @Test("respondToRendezvous creates offer")
    func respondRendezvous() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID,
            displayName: "Target",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: []
        )
        let service = RendezvousService(coordinator: coordinator)
        let request = try? await service.requestRendezvous(
            consoleID: NodeID(),
            targetNodeID: nodeID
        )
        let offer = await service.respondToRendezvous(
            requestID: request!.requestID,
            accepted: true,
            consoleEndpoint: NodeEndpoint(host: "10.0.0.2", port: 5000),
            nodeEndpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            route: .direct(host: "10.0.0.1", port: 49494),
            sessionSecret: Data("secret".utf8)
        )
        #expect(offer != nil)
        #expect(offer?.route.description == "direct://10.0.0.1:49494")
    }

    @Test("cancelRendezvous removes request")
    func cancelRendezvous() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID,
            displayName: "T",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64,
            capabilities: []
        )
        let service = RendezvousService(coordinator: coordinator)
        let request = try? await service.requestRendezvous(
            consoleID: NodeID(),
            targetNodeID: nodeID
        )
        await service.cancelRendezvous(requestID: request!.requestID)
        #expect(await service.pendingRequestCount() == 0)
    }
}

@Suite("SignalingService — NAT Traversal Coordination")
struct SignalingServiceTests {

    @Test("createOffer stores session")
    func createOffer() async {
        let service = SignalingService()
        let offer = SignalingOffer(
            fromNodeID: NodeID(),
            toNodeID: NodeID(),
            sdp: Data("v=0\r\n".utf8)
        )
        let session = await service.createOffer(offer)
        #expect(session.offer != nil)
        #expect(await service.sessionCount() == 1)
    }

    @Test("receiveAnswer updates session")
    func receiveAnswer() async {
        let service = SignalingService()
        let sessionID = UUID()
        let from = NodeID()
        let to = NodeID()
        let offer = SignalingOffer(sessionID: sessionID, fromNodeID: from, toNodeID: to, sdp: Data("offer".utf8))
        _ = await service.createOffer(offer)
        let answer = SignalingAnswer(sessionID: sessionID, fromNodeID: to, toNodeID: from, sdp: Data("answer".utf8))
        let updated = await service.receiveAnswer(answer)
        #expect(updated?.answer != nil)
    }

    @Test("addICECandidate stores candidates")
    func addICECandidate() async {
        let service = SignalingService()
        let sessionID = UUID()
        let offer = SignalingOffer(sessionID: sessionID, fromNodeID: NodeID(), toNodeID: NodeID(), sdp: Data())
        _ = await service.createOffer(offer)
        let candidate = ICECandidate(candidate: "candidate:1 1 UDP 2122252543 10.0.0.1 5000 typ host")
        await service.addICECandidate(candidate, toSession: sessionID)
        let candidates = await service.pendingICECandidates(for: sessionID)
        #expect(candidates.count == 1)
    }

    @Test("closeSession removes session")
    func closeSession() async {
        let service = SignalingService()
        let sessionID = UUID()
        let offer = SignalingOffer(sessionID: sessionID, fromNodeID: NodeID(), toNodeID: NodeID(), sdp: Data())
        _ = await service.createOffer(offer)
        await service.closeSession(sessionID)
        #expect(await service.sessionCount() == 0)
    }

    @Test("sessionsBetween filters correctly")
    func sessionsBetween() async {
        let service = SignalingService()
        let nodeA = NodeID()
        let nodeB = NodeID()
        let nodeC = NodeID()
        _ = await service.createOffer(SignalingOffer(fromNodeID: nodeA, toNodeID: nodeB, sdp: Data()))
        _ = await service.createOffer(SignalingOffer(fromNodeID: nodeA, toNodeID: nodeC, sdp: Data()))
        let sessions = await service.sessionsBetween(nodeA, and: nodeB)
        #expect(sessions.count == 1)
    }
}

@Suite("RelayService — Packet Forwarding")
struct RelayServiceTests {

    @Test("allocateChannel creates channel")
    func allocateChannel() async {
        let service = RelayService()
        let source = NodeID()
        let target = NodeID()
        let channel = await service.allocateChannel(sourceNodeID: source, targetNodeID: target)
        #expect(await service.totalChannels() == 1)
        #expect(channel.sourceNodeID == source)
        #expect(channel.targetNodeID == target)
    }

    @Test("forwardPacket delivers data")
    func forwardPacket() async {
        let service = RelayService()
        let source = NodeID()
        let target = NodeID()
        let channel = await service.allocateChannel(sourceNodeID: source, targetNodeID: target)
        let result = await service.forwardPacket(
            channelID: channel.channelID,
            data: Data("hello".utf8),
            from: source
        )
        #expect(result?.delivered == true)
        #expect(await service.totalPacketsForwarded() == 1)
        #expect(await service.totalBytesForwarded() == 5)
    }

    @Test("releaseChannel removes channel")
    func releaseChannel() async {
        let service = RelayService()
        let channel = await service.allocateChannel(sourceNodeID: NodeID(), targetNodeID: NodeID())
        await service.releaseChannel(channel.channelID)
        #expect(await service.totalChannels() == 0)
    }

    @Test("channelsForNode returns correct channels")
    func channelsForNode() async {
        let service = RelayService()
        let nodeA = NodeID()
        let nodeB = NodeID()
        let nodeC = NodeID()
        _ = await service.allocateChannel(sourceNodeID: nodeA, targetNodeID: nodeB)
        _ = await service.allocateChannel(sourceNodeID: nodeA, targetNodeID: nodeC)
        let channels = await service.channelsForNode(nodeA)
        #expect(channels.count == 2)
    }

    @Test("cleanupInactive removes old channels")
    func cleanupInactive() async {
        let service = RelayService()
        let channel = await service.allocateChannel(sourceNodeID: NodeID(), targetNodeID: NodeID())
        let released = await service.cleanupInactive(maxAge: 0)
        #expect(released.count == 1)
        #expect(await service.totalChannels() == 0)
    }

    @Test("availableBandwidth decreases after allocation")
    func bandwidthTracking() async {
        let service = RelayService(maxBandwidthMbps: 100)
        let initial = await service.availableBandwidthMbps()
        #expect(initial == 100)
    }
}

@Suite("Coordinator Edge Cases")
struct CoordinatorEdgeCases {

    @Test("registerNode overwrites existing node with same ID")
    func registerOverwrite() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID, displayName: "V1",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64, capabilities: []
        )
        await coordinator.registerNode(
            nodeID: nodeID, displayName: "V2",
            endpoint: NodeEndpoint(host: "10.0.0.2", port: 5000),
            architecture: .x86_64, capabilities: [.screenView]
        )
        #expect(await coordinator.nodeCount() == 1)
        let node = await coordinator.node(byID: nodeID)
        #expect(node?.displayName == "V2")
    }

    @Test("deregisterNode is idempotent")
    func deregisterIdempotent() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.deregisterNode(nodeID)
        #expect(await coordinator.nodeCount() == 0)
    }

    @Test("heartbeat returns false for unknown node")
    func heartbeatUnknown() async {
        let coordinator = CoordinatorService()
        let result = await coordinator.heartbeat(NodeID())
        #expect(result == false)
    }

    @Test("updateNATType on unknown node is no-op")
    func updateNATUnknown() async {
        let coordinator = CoordinatorService()
        await coordinator.updateNATType(NodeID(), natType: .symmetricNAT)
        #expect(await coordinator.nodeCount() == 0)
    }

    @Test("cleanupExpiredNodes with no nodes returns empty")
    func cleanupEmpty() async {
        let coordinator = CoordinatorService()
        let expired = await coordinator.cleanupExpiredNodes()
        #expect(expired.isEmpty)
    }
}

@Suite("Rendezvous Edge Cases")
struct RendezvousEdgeCases {

    @Test("respondToRendezvous for unknown request returns nil")
    func respondUnknown() async {
        let coordinator = CoordinatorService()
        let service = RendezvousService(coordinator: coordinator)
        let result = await service.respondToRendezvous(
            requestID: UUID(),
            accepted: true,
            consoleEndpoint: NodeEndpoint(host: "10.0.0.1", port: 5000),
            nodeEndpoint: NodeEndpoint(host: "10.0.0.2", port: 49494),
            route: .direct(host: "10.0.0.2", port: 49494),
            sessionSecret: Data()
        )
        #expect(result == nil)
    }

    @Test("completeRendezvous for unknown request returns nil")
    func completeUnknown() async {
        let coordinator = CoordinatorService()
        let service = RendezvousService(coordinator: coordinator)
        let result = await service.completeRendezvous(requestID: UUID())
        #expect(result == nil)
    }

    @Test("reject respondToRendezvous cleans up request")
    func rejectCleanup() async {
        let coordinator = CoordinatorService()
        let nodeID = NodeID()
        await coordinator.registerNode(
            nodeID: nodeID, displayName: "T",
            endpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            architecture: .arm64, capabilities: []
        )
        let service = RendezvousService(coordinator: coordinator)
        let request = try? await service.requestRendezvous(
            consoleID: NodeID(), targetNodeID: nodeID
        )
        _ = await service.respondToRendezvous(
            requestID: request!.requestID,
            accepted: false,
            consoleEndpoint: NodeEndpoint(host: "10.0.0.2", port: 5000),
            nodeEndpoint: NodeEndpoint(host: "10.0.0.1", port: 49494),
            route: .direct(host: "10.0.0.1", port: 49494),
            sessionSecret: Data()
        )
        #expect(await service.pendingRequestCount() == 0)
        #expect(await service.activeSessionCount() == 0)
    }
}

@Suite("Signaling Edge Cases")
struct SignalingEdgeCases {

    @Test("receiveAnswer for unknown session returns nil")
    func answerUnknown() async {
        let service = SignalingService()
        let result = await service.receiveAnswer(
            SignalingAnswer(
                sessionID: UUID(),
                fromNodeID: NodeID(),
                toNodeID: NodeID(),
                sdp: Data()
            )
        )
        #expect(result == nil)
    }

    @Test("pendingICECandidates for unknown session returns empty")
    func candidatesEmpty() async {
        let service = SignalingService()
        let candidates = await service.pendingICECandidates(for: UUID())
        #expect(candidates.isEmpty)
    }

    @Test("session returns nil for unknown ID")
    func sessionUnknown() async {
        let service = SignalingService()
        let session = await service.session(UUID())
        #expect(session == nil)
    }

    @Test("cleanupStale with no sessions is no-op")
    func cleanupEmpty() async {
        let service = SignalingService()
        await service.cleanupStale(maxAge: 0)
        #expect(await service.sessionCount() == 0)
    }
}

@Suite("Relay Edge Cases")
struct RelayEdgeCases {

    @Test("forwardPacket to unknown channel returns nil")
    func forwardUnknown() async {
        let service = RelayService()
        let result = await service.forwardPacket(
            channelID: UUID(),
            data: Data("test".utf8),
            from: NodeID()
        )
        #expect(result == nil)
    }

    @Test("releaseChannel is idempotent")
    func releaseIdempotent() async {
        let service = RelayService()
        let channel = await service.allocateChannel(sourceNodeID: NodeID(), targetNodeID: NodeID())
        await service.releaseChannel(channel.channelID)
        await service.releaseChannel(channel.channelID)
        #expect(await service.totalChannels() == 0)
    }

    @Test("channelsForNode returns empty for unknown node")
    func channelsUnknown() async {
        let service = RelayService()
        let channels = await service.channelsForNode(NodeID())
        #expect(channels.isEmpty)
    }

    @Test("channel returns nil for unknown ID")
    func channelUnknown() async {
        let service = RelayService()
        let channel = await service.channel(UUID())
        #expect(channel == nil)
    }
}
