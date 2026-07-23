import Foundation
import VanguardDomain
import VanguardProtocol
import VanguardTransport
import VanguardPermissions
import VanguardIdentity
import VanguardSecurity

// MARK: - Mock Transport Actor

private actor MockTransportState {
    var connected = false
    var sentMessages: [OutboundMessage] = []

    func setConnected(_ value: Bool) { connected = value }
    func isConnected() -> Bool { connected }
    func appendSentMessage(_ msg: OutboundMessage) { sentMessages.append(msg) }
    func getSentMessages() -> [OutboundMessage] { sentMessages }
    func clearSentMessages() { sentMessages.removeAll() }
}

// MARK: - Mock Transport for Testing

public final class MockTransport: VanguardTransport, @unchecked Sendable {
    private let incomingContinuation: AsyncThrowingStream<InboundMessage, Error>.Continuation
    public let incomingMessages: AsyncThrowingStream<InboundMessage, Error>
    private let state = MockTransportState()
    private var connectHandler: ((NodeEndpoint) throws -> Void)?
    private var sendHandler: ((OutboundMessage) throws -> Void)?

    public init() {
        let (stream, continuation) = AsyncThrowingStream<InboundMessage, Error>.makeStream()
        self.incomingMessages = stream
        self.incomingContinuation = continuation
    }

    public func connect(to endpoint: NodeEndpoint) async throws {
        try connectHandler?(endpoint)
        await state.setConnected(true)
    }

    public func listen(port: UInt16) async throws {
        await state.setConnected(true)
    }

    public func send(_ message: OutboundMessage) async throws {
        try sendHandler?(message)
        let isConnected = await state.isConnected()
        guard isConnected else {
            throw TransportError.connectionRefused
        }
        await state.appendSentMessage(message)
    }

    public func disconnect(reason: DisconnectReason) async {
        await state.setConnected(false)
        incomingContinuation.finish()
    }

    // Testing helpers

    public func simulateIncoming(_ message: InboundMessage) {
        incomingContinuation.yield(message)
    }

    public func simulateError(_ error: Error) {
        incomingContinuation.finish(throwing: error)
    }

    public func getSentMessages() async -> [OutboundMessage] {
        return await state.getSentMessages()
    }

    public func setConnectHandler(_ handler: @escaping (NodeEndpoint) throws -> Void) {
        self.connectHandler = handler
    }

    public func setSendHandler(_ handler: @escaping (OutboundMessage) throws -> Void) {
        self.sendHandler = handler
    }

    public func reset() async {
        await state.setConnected(false)
        await state.clearSentMessages()
    }
}

// MARK: - Mock Permission Service

public struct MockPermissionService: PermissionService {
    public var permissionStates: [PermissionKind: PermissionState] = [:]
    public var requestResults: [PermissionKind: PermissionState] = [:]

    public init() {}

    public func checkAllPermissions() async -> [PermissionDescriptor] {
        return PermissionKind.allCases.map { kind in
            PermissionDescriptor(
                kind: kind,
                state: permissionStates[kind] ?? .unknown,
                description: kind.explanation,
                instructions: "Open System Settings to grant permission."
            )
        }
    }

    public func checkPermission(kind: PermissionKind) async -> PermissionState {
        return permissionStates[kind] ?? .unknown
    }

    public func requestPermission(kind: PermissionKind) async -> PermissionState {
        return requestResults[kind] ?? .denied
    }

    public func openSystemSettings(for kind: PermissionKind) async {}
}

// MARK: - Mock Identity Service

public final class MockIdentityService: IdentityService, @unchecked Sendable {
    public var storedIdentity: DeviceIdentity?
    public var trustedPeers: [NodeID: TrustedPeer] = [:]
    public var challengeToReturn: PairingChallenge?

    public init() {}

    public func generateDeviceIdentity() async throws -> DeviceIdentity {
        let nodeID = NodeID()
        return DeviceIdentity(
            nodeID: nodeID,
            signingPublicKey: Data(repeating: 0x01, count: 32),
            signingPrivateKeyRef: "mock-signing-key",
            agreementPublicKey: Data(repeating: 0x02, count: 32),
            agreementPrivateKeyRef: "mock-agreement-key",
            certificateFingerprint: Data(repeating: 0x03, count: 32)
        )
    }

    public func getOrCreateIdentity() async throws -> DeviceIdentity {
        if let identity = storedIdentity {
            return identity
        }
        let identity = try await generateDeviceIdentity()
        storedIdentity = identity
        return identity
    }

    public func signData(_ data: Data, identity: DeviceIdentity) async throws -> Data {
        return Data(repeating: 0xAA, count: 64)
    }

    public func verifySignature(_ signature: Data, data: Data, publicKey: Data) async throws -> Bool {
        return true
    }

    public func saveTrustedPeer(_ peer: TrustedPeer) async throws {
        trustedPeers[peer.nodeID] = peer
    }

    public func loadTrustedPeer(nodeID: NodeID) async throws -> TrustedPeer? {
        return trustedPeers[nodeID]
    }

    public func loadAllTrustedPeers() async throws -> [TrustedPeer] {
        return Array(trustedPeers.values)
    }

    public func revokePeer(nodeID: NodeID) async throws {
        trustedPeers.removeValue(forKey: nodeID)
    }

    public func generateChallenge() async throws -> PairingChallenge {
        if let challenge = challengeToReturn {
            return challenge
        }
        return PairingChallenge(
            code: "123456",
            expiresAt: Date().addingTimeInterval(120),
            fingerprint: Data(repeating: 0xFF, count: 32)
        )
    }

    public func validateChallengeCode(_ code: String, challenge: PairingChallenge) async throws -> Bool {
        return code == challenge.code
    }
}

// MARK: - Mock Security Service

public struct MockSecurityService: SecurityService {
    public var authorizationResult: AuthorizationDecision = .allowed
    public var capabilitiesCheck: Bool = true
    public var rateLimitBlocked = false

    public init() {}

    public func authorize(
        _ action: NodeAction,
        context: AuthorizationContext
    ) async throws -> AuthorizationDecision {
        return authorizationResult
    }

    public func checkCapability(
        _ capability: NodeCapability,
        session: Session
    ) -> Bool {
        return capabilitiesCheck
    }

    public func rateLimitCheck(identifier: String) async throws {
        if rateLimitBlocked {
            throw InputError.rateLimited
        }
    }

    public func validatePayload(_ data: Data, maxPayloadSize: Int) async throws {
        guard data.count <= maxPayloadSize else {
            throw TransportError.messageTooLarge(size: data.count, limit: maxPayloadSize)
        }
    }
}
