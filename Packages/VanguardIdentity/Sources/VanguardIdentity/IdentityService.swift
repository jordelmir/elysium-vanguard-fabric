import Foundation
import VanguardDomain

// MARK: - Identity Protocol

public protocol IdentityService: Sendable {
    func generateDeviceIdentity() async throws -> DeviceIdentity
    func getOrCreateIdentity() async throws -> DeviceIdentity
    func signData(_ data: Data, identity: DeviceIdentity) async throws -> Data
    func verifySignature(_ signature: Data, data: Data, publicKey: Data) async throws -> Bool
    func saveTrustedPeer(_ peer: TrustedPeer) async throws
    func loadTrustedPeer(nodeID: NodeID) async throws -> TrustedPeer?
    func loadAllTrustedPeers() async throws -> [TrustedPeer]
    func revokePeer(nodeID: NodeID) async throws
    func generateChallenge() async throws -> PairingChallenge
    func validateChallengeCode(_ code: String, challenge: PairingChallenge) async throws -> Bool
}

// MARK: - Device Identity

public struct DeviceIdentity: Sendable, Equatable {
    public let nodeID: NodeID
    public let signingPublicKey: Data
    public let signingPrivateKeyRef: String
    public let agreementPublicKey: Data
    public let agreementPrivateKeyRef: String
    public let certificateFingerprint: Data
    public let createdAt: Date

    public init(
        nodeID: NodeID,
        signingPublicKey: Data,
        signingPrivateKeyRef: String,
        agreementPublicKey: Data,
        agreementPrivateKeyRef: String,
        certificateFingerprint: Data,
        createdAt: Date = Date()
    ) {
        self.nodeID = nodeID
        self.signingPublicKey = signingPublicKey
        self.signingPrivateKeyRef = signingPrivateKeyRef
        self.agreementPublicKey = agreementPublicKey
        self.agreementPrivateKeyRef = agreementPrivateKeyRef
        self.certificateFingerprint = certificateFingerprint
        self.createdAt = createdAt
    }
}

// MARK: - Pairing Challenge

public struct PairingChallenge: Sendable, Equatable {
    public let code: String
    public let expiresAt: Date
    public let fingerprint: Data
    public let maxAttempts: Int

    public init(
        code: String,
        expiresAt: Date,
        fingerprint: Data,
        maxAttempts: Int = 3
    ) {
        self.code = code
        self.expiresAt = expiresAt
        self.fingerprint = fingerprint
        self.maxAttempts = maxAttempts
    }

    public var isExpired: Bool {
        Date() > expiresAt
    }
}
