import Foundation
import os
import VanguardCoordinator
import VanguardProtocol
import VanguardTransport
import VanguardDomain

@MainActor
final class CoordinatorServerState: ObservableObject {
    @Published var isRunning = false
    @Published var registeredNodes = 0
    @Published var activeChannels = 0
    @Published var activeSessions = 0

    let port: UInt16

    private let coordinator = CoordinatorService()
    private let rendezvous: RendezvousService
    private let signaling = SignalingService()
    private let relay = RelayService()
    private var cleanupTask: Task<Void, Never>?
    private var statsTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    private var transport: NetworkTransport?

    init(port: UInt16 = 49495) {
        self.port = port
        self.rendezvous = RendezvousService(coordinator: coordinator)
    }

    nonisolated func start() {
        Task { @MainActor in
            guard !isRunning else { return }
            isRunning = true

            let netTransport = NetworkTransport()
            self.transport = netTransport

            do {
                try await netTransport.listen(port: port)
                print("[CoordinatorServer] Listening on port \(port)")
            } catch {
                print("[CoordinatorServer] Failed to listen: \(error)")
                isRunning = false
                return
            }

            messageTask = Task { [coordinator, rendezvous, signaling, relay, netTransport] in
                do {
                    for try await message in netTransport.incomingMessages {
                        guard !Task.isCancelled else { break }
                        await self.handleMessage(message, via: netTransport)
                    }
                } catch {
                    print("[CoordinatorServer] Message stream error: \(error)")
                }
            }

            cleanupTask = Task { [coordinator, rendezvous, signaling, relay] in
                while !Task.isCancelled {
                    let expired = await coordinator.cleanupExpiredNodes()
                    if !expired.isEmpty {
                        print("[Coordinator] Cleaned up \(expired.count) expired nodes")
                    }
                    await signaling.cleanupStale(maxAge: 300)
                    await rendezvous.cleanupStale(maxAge: 60)
                    let releasedChannels = await relay.cleanupInactive(maxAge: 300)
                    if !releasedChannels.isEmpty {
                        print("[Relay] Released \(releasedChannels.count) inactive channels")
                    }
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                }
            }

            statsTask = Task { [coordinator, relay, signaling] in
                while !Task.isCancelled {
                    registeredNodes = (await coordinator.nodeList()).count
                    activeChannels = await relay.totalChannels()
                    activeSessions = await signaling.sessionCount()
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
            }
        }
    }

    nonisolated func stop() {
        Task { @MainActor in
            guard isRunning else { return }
            isRunning = false
            messageTask?.cancel()
            cleanupTask?.cancel()
            statsTask?.cancel()
            await transport?.disconnect(reason: .userInitiated)
            print("[CoordinatorServer] Stopped")
        }
    }

    private func handleMessage(_ message: InboundMessage, via transport: NetworkTransport) async {
        let msgType = message.header.messageType
        switch msgType {
        case .presenceRegister:
            if let payload = try? JSONDecoder().decode(PresenceRegisterPayload.self, from: message.payload) {
                await coordinator.registerNode(
                    nodeID: payload.nodeID,
                    displayName: payload.displayName,
                    endpoint: NodeEndpoint(host: payload.host, port: payload.port),
                    architecture: payload.architecture,
                    capabilities: payload.capabilities
                )
            }
        case .presenceDeregister:
            if let payload = try? JSONDecoder().decode(PresenceDeregisterPayload.self, from: message.payload) {
                await coordinator.deregisterNode(payload.nodeID)
            }
        case .heartbeat:
            let response = OutboundMessage(
                messageType: .heartbeatAck,
                payload: Data()
            )
            try? await transport.send(response)
        case .presenceList:
            let nodes = await coordinator.nodeList()
            let nodeList = NodeListNodeIDs(nodeIDs: nodes.map { $0.nodeID })
            if let data = try? JSONEncoder().encode(nodeList) {
                let response = OutboundMessage(
                    messageType: .presenceList,
                    payload: data
                )
                try? await transport.send(response)
            }
        case .rendezvousRequest:
            if let payload = try? JSONDecoder().decode(RendezvousRequestPayload.self, from: message.payload) {
                let request = try? await rendezvous.requestRendezvous(
                    consoleID: payload.consoleID,
                    targetNodeID: payload.targetNodeID
                )
                if request != nil {
                    let response = OutboundMessage(
                        messageType: .rendezvousRequest,
                        payload: message.payload
                    )
                    try? await transport.send(response)
                }
            }
        case .rendezvousCancel:
            if let payload = try? JSONDecoder().decode(RendezvousCancelPayload.self, from: message.payload) {
                await rendezvous.cancelRendezvous(requestID: payload.requestID)
            }
        case .rendezvousComplete:
            if let payload = try? JSONDecoder().decode(RendezvousCompletePayload.self, from: message.payload) {
                _ = await rendezvous.completeRendezvous(requestID: payload.requestID)
            }
        case .signalingOffer:
            if let payload = try? JSONDecoder().decode(SignalingOfferPayload.self, from: message.payload) {
                _ = await signaling.createOffer(
                    SignalingOffer(
                        sessionID: payload.sessionID,
                        fromNodeID: payload.fromNodeID,
                        toNodeID: payload.toNodeID,
                        sdp: payload.sdp
                    )
                )
                let response = OutboundMessage(
                    messageType: .signalingOffer,
                    payload: message.payload
                )
                try? await transport.send(response)
            }
        case .signalingAnswer:
            if let payload = try? JSONDecoder().decode(SignalingAnswerPayload.self, from: message.payload) {
                _ = await signaling.receiveAnswer(
                    SignalingAnswer(
                        sessionID: payload.sessionID,
                        fromNodeID: payload.fromNodeID,
                        toNodeID: payload.toNodeID,
                        sdp: payload.sdp
                    )
                )
            }
        case .signalingIceCandidate:
            if let payload = try? JSONDecoder().decode(SignalingICECandidatePayload.self, from: message.payload) {
                let candidate = ICECandidate(
                    candidate: payload.candidate,
                    sdpMLineIndex: payload.sdpMLineIndex,
                    sdpMid: payload.sdpMid
                )
                await signaling.addICECandidate(candidate, toSession: payload.sessionID)
            }
        case .relayAllocate:
            if let payload = try? JSONDecoder().decode(RelayAllocatePayload.self, from: message.payload) {
                let channel = await relay.allocateChannel(
                    sourceNodeID: payload.sourceNodeID,
                    targetNodeID: payload.targetNodeID
                )
                let response = OutboundMessage(
                    messageType: .relayAllocate,
                    payload: message.payload
                )
                try? await transport.send(response)
            }
        case .relayForward:
            if let payload = try? JSONDecoder().decode(RelayForwardPayload.self, from: message.payload) {
                _ = await relay.forwardPacket(
                    channelID: payload.channelID,
                    data: payload.data,
                    from: payload.fromNodeID
                )
            }
        case .relayRelease:
            if let payload = try? JSONDecoder().decode(RelayReleasePayload.self, from: message.payload) {
                await relay.releaseChannel(payload.channelID)
            }
        default:
            os_log(.debug, "Coordinator ignoring message type: 0x%04X", message.header.messageType.rawValue)
        }
    }
}
