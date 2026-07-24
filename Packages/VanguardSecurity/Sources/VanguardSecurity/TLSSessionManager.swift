import Foundation
import Network
import CryptoKit
import os.log
import VanguardDomain
import VanguardIdentity
import VanguardProtocol

public actor TLSSessionManager {
    private let identityService: any IdentityService
    private var trustedPeers: [NodeID: Data] = [:]
    private var currentSessionKey: SymmetricKey?
    private var pinningEnabled = true
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "TLS")

    public init(identityService: any IdentityService) {
        self.identityService = identityService
    }

    public func createTLSParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 30

        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, .TLSv13)

        let parameters = NWParameters(tls: tls, tcp: tcp)
        parameters.includePeerToPeer = true
        return parameters
    }

    public func performKeyExchange(
        localPrivateKey: P256.KeyAgreement.PrivateKey,
        peerPublicKeyData: Data,
        transcriptHash: Data
    ) async throws -> HandshakeResult {
        let localPublicKeyData = localPrivateKey.publicKey.compactRepresentation

        guard let peerPublicKey = try? P256.KeyAgreement.PublicKey(compactRepresentation: peerPublicKeyData) else {
            throw TLSError.handshakeFailed(reason: "Invalid peer public key")
        }

        let sharedSecret = try localPrivateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)
        let sessionKey = SessionKeyDerivation.deriveSessionKey(
            sharedSecret: Data(sharedSecret.withUnsafeBytes { Data($0) }),
            transcriptHash: transcriptHash
        )

        await setSessionKey(sessionKey)

        logger.info("Key exchange completed")

        return HandshakeResult(
            peerPublicKey: peerPublicKeyData,
            sessionKey: sessionKey,
            transcriptHash: transcriptHash
        )
    }

    public func validatePeerIdentity(_ peerPublicKey: Data, nodeID: NodeID) async throws -> Bool {
        guard pinningEnabled else { return true }
        let fingerprint = Data(SHA256.hash(data: peerPublicKey))
        if let storedFingerprint = trustedPeers[nodeID] {
            return storedFingerprint == fingerprint
        }
        return false
    }

    public func pinPeerIdentity(_ peerPublicKey: Data, nodeID: NodeID) async {
        let fingerprint = Data(SHA256.hash(data: peerPublicKey))
        trustedPeers[nodeID] = fingerprint
    }

    public func revokePeer(nodeID: NodeID) async {
        trustedPeers.removeValue(forKey: nodeID)
    }

    public func isPeerTrusted(nodeID: NodeID) async -> Bool {
        trustedPeers[nodeID] != nil
    }

    public func deriveChannelKey(transcriptHash: Data, channel: StreamChannel) async -> SymmetricKey? {
        guard let sessionKey = currentSessionKey else { return nil }
        let salt = transcriptHash + Data([channel.rawValue])
        return SymmetricKey(data: SHA256.hash(data: salt + sessionKey.withUnsafeBytes { Data($0) }))
    }

    public func setSessionKey(_ key: SymmetricKey) async {
        currentSessionKey = key
    }

    public func setPinningEnabled(_ enabled: Bool) async {
        pinningEnabled = enabled
    }
}

public struct HandshakeResult: Sendable {
    public let peerPublicKey: Data
    public let sessionKey: SymmetricKey
    public let transcriptHash: Data
}

public enum TLSError: Error, LocalizedError {
    case handshakeFailed(reason: String)
    case identityMismatch(expected: Data, received: Data)
    case keyAgreementFailed

    public var errorDescription: String? {
        switch self {
        case .handshakeFailed(let reason): return "TLS handshake failed: \(reason)"
        case .identityMismatch: return "Peer identity does not match pinned certificate"
        case .keyAgreementFailed: return "Key agreement failed"
        }
    }
}

public struct SessionKeyDerivation {
    public static func deriveSessionKey(sharedSecret: Data, transcriptHash: Data) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: sharedSecret + transcriptHash))
    }

    public static func deriveControlKey(masterKey: SymmetricKey, transcriptHash: Data) -> SymmetricKey {
        let context = "vanguard-control".data(using: .utf8)! + transcriptHash
        return SymmetricKey(data: SHA256.hash(data: context + masterKey.withUnsafeBytes { Data($0) }))
    }

    public static func deriveVideoKey(masterKey: SymmetricKey, transcriptHash: Data) -> SymmetricKey {
        let context = "vanguard-video".data(using: .utf8)! + transcriptHash
        return SymmetricKey(data: SHA256.hash(data: context + masterKey.withUnsafeBytes { Data($0) }))
    }

    public static func deriveInputKey(masterKey: SymmetricKey, transcriptHash: Data) -> SymmetricKey {
        let context = "vanguard-input".data(using: .utf8)! + transcriptHash
        return SymmetricKey(data: SHA256.hash(data: context + masterKey.withUnsafeBytes { Data($0) }))
    }
}

public struct IdentityPinner {
    public static func computeFingerprint(publicKey: Data) -> Data {
        Data(SHA256.hash(data: publicKey))
    }
}
