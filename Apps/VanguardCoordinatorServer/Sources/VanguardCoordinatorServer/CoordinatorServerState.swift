import Foundation
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
            await coordinator.registerNode(
                nodeID: NodeID(),
                displayName: "Remote Node",
                endpoint: NodeEndpoint(host: "unknown", port: 0),
                architecture: .arm64,
                capabilities: []
            )
        case .presenceDeregister:
            break
        case .heartbeat:
            let response = OutboundMessage(
                messageType: .heartbeatAck,
                payload: Data()
            )
            try? await transport.send(response)
        case .rendezvousRequest:
            let request = try? await rendezvous.requestRendezvous(
                consoleID: NodeID(),
                targetNodeID: NodeID()
            )
            if request != nil {
                let response = OutboundMessage(
                    messageType: .rendezvousRequest,
                    payload: message.payload
                )
                try? await transport.send(response)
            }
        case .rendezvousCancel:
            await rendezvous.cancelRendezvous(requestID: UUID())
        case .signalingOffer:
            let session = await signaling.createOffer(
                SignalingOffer(
                    sessionID: UUID(),
                    fromNodeID: NodeID(),
                    toNodeID: NodeID(),
                    sdp: message.payload
                )
            )
            let response = OutboundMessage(
                messageType: .signalingOffer,
                payload: message.payload
            )
            try? await transport.send(response)
        case .signalingAnswer:
            _ = await signaling.receiveAnswer(
                SignalingAnswer(
                    sessionID: UUID(),
                    fromNodeID: NodeID(),
                    toNodeID: NodeID(),
                    sdp: message.payload
                )
            )
        case .relayAllocate:
            let channel = await relay.allocateChannel(
                sourceNodeID: NodeID(),
                targetNodeID: NodeID()
            )
            let response = OutboundMessage(
                messageType: .relayAllocate,
                payload: message.payload
            )
            try? await transport.send(response)
        default:
            break
        }
    }
}
