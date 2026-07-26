import Foundation
import CryptoKit
import Security
import VanguardDomain

// MARK: - CryptoKit Identity Service

public final class CryptoKitIdentityService: IdentityService, @unchecked Sendable {
    private static let serviceName = "com.elysiumvanguard.fabric.identity"
    private static let metadataAccount = "device-identity-metadata"

    public init() {}

    // MARK: - Identity

    public func generateDeviceIdentity() async throws -> DeviceIdentity {
        let nodeID = NodeID()
        let signingKey = Curve25519.Signing.PrivateKey()
        let agreementKey = Curve25519.KeyAgreement.PrivateKey()

        let signingTag = "signing-\(nodeID.rawValue.uuidString)"
        let agreementTag = "agreement-\(nodeID.rawValue.uuidString)"

        try Self.storeKey(signingKey.rawRepresentation, tag: signingTag)
        try Self.storeKey(agreementKey.rawRepresentation, tag: agreementTag)

        let fingerprint = Data(SHA256.hash(
            data: signingKey.publicKey.rawRepresentation + agreementKey.publicKey.rawRepresentation
        ))

        let metadata = PersistedIdentityMetadata(
            nodeID: nodeID.rawValue,
            signingKeyTag: signingTag,
            agreementKeyTag: agreementTag,
            certificateFingerprint: fingerprint
        )
        try Self.storeMetadata(metadata)

        return DeviceIdentity(
            nodeID: nodeID,
            signingPublicKey: signingKey.publicKey.rawRepresentation,
            signingPrivateKeyRef: signingTag,
            agreementPublicKey: agreementKey.publicKey.rawRepresentation,
            agreementPrivateKeyRef: agreementTag,
            certificateFingerprint: fingerprint
        )
    }

    public func getOrCreateIdentity() async throws -> DeviceIdentity {
        if let metadata = Self.loadMetadata(),
           let signingData = Self.loadKey(tag: metadata.signingKeyTag),
           let agreementData = Self.loadKey(tag: metadata.agreementKeyTag) {
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: signingData)
            let agreementKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementData)
            let fingerprint = Data(SHA256.hash(
                data: signingKey.publicKey.rawRepresentation + agreementKey.publicKey.rawRepresentation
            ))

            return DeviceIdentity(
                nodeID: NodeID(rawValue: metadata.nodeID),
                signingPublicKey: signingKey.publicKey.rawRepresentation,
                signingPrivateKeyRef: metadata.signingKeyTag,
                agreementPublicKey: agreementKey.publicKey.rawRepresentation,
                agreementPrivateKeyRef: metadata.agreementKeyTag,
                certificateFingerprint: fingerprint
            )
        }

        return try await generateDeviceIdentity()
    }

    // MARK: - Signing

    public func signData(_ data: Data, identity: DeviceIdentity) async throws -> Data {
        guard let keyData = Self.loadKey(tag: identity.signingPrivateKeyRef) else {
            throw PairingError.keychainFailure(reason: "Signing key not found")
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        return try privateKey.signature(for: data)
    }

    public func verifySignature(_ signature: Data, data: Data, publicKey: Data) async throws -> Bool {
        guard let pubKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey) else { return false }
        return pubKey.isValidSignature(signature, for: data)
    }

    // MARK: - Trusted Peers

    public func saveTrustedPeer(_ peer: TrustedPeer) async throws {
        let data = try JSONEncoder().encode(peer)
        try Self.storeKey(data, tag: "peer-\(peer.nodeID.rawValue.uuidString)")
    }

    public func loadTrustedPeer(nodeID: NodeID) async throws -> TrustedPeer? {
        guard let data = Self.loadKey(tag: "peer-\(nodeID.rawValue.uuidString)") else { return nil }
        return try JSONDecoder().decode(TrustedPeer.self, from: data)
    }

    public func loadAllTrustedPeers() async throws -> [TrustedPeer] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: Self.serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [] }

        return items.compactMap { item -> TrustedPeer? in
            guard let tagData = item[kSecAttrApplicationTag as String] as? Data,
                  let tag = String(data: tagData, encoding: .utf8),
                  tag.hasPrefix("peer-") else { return nil }
            guard let data = Self.loadKey(tag: tag) else { return nil }
            return try? JSONDecoder().decode(TrustedPeer.self, from: data)
        }
    }

    public func revokePeer(nodeID: NodeID) async throws {
        Self.deleteKey(tag: "peer-\(nodeID.rawValue.uuidString)")
    }

    // MARK: - Pairing Challenge

    public func generateChallenge() async throws -> PairingChallenge {
        var bytes = [UInt8](repeating: 0, count: 3)
        let status = SecRandomCopyBytes(kSecRandomDefault, 3, &bytes)
        guard status == errSecSuccess else {
            throw PairingError.keychainFailure(reason: "Failed to generate random bytes")
        }
        let code = String(format: "%06d", (Int(bytes[0]) << 16 | Int(bytes[1]) << 8 | Int(bytes[2])) % 1_000_000)
        let fingerprint = Data(SHA256.hash(data: Data(bytes)))
        return PairingChallenge(code: code, expiresAt: Date().addingTimeInterval(120), fingerprint: fingerprint, maxAttempts: 3)
    }

    public func validateChallengeCode(_ code: String, challenge: PairingChallenge) async throws -> Bool {
        guard !challenge.isExpired else { return false }
        return code == challenge.code
    }

    // MARK: - Keychain Helpers

    private struct PersistedIdentityMetadata: Codable {
        let nodeID: UUID
        let signingKeyTag: String
        let agreementKeyTag: String
        let certificateFingerprint: Data
    }

    private static func storeMetadata(_ metadata: PersistedIdentityMetadata) throws {
        let data = try JSONEncoder().encode(metadata)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: metadataAccount
        ]
        SecItemDelete(query as CFDictionary)

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PairingError.keychainFailure(reason: "Failed to store identity metadata: \(status)")
        }
    }

    private static func loadMetadata() -> PersistedIdentityMetadata? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: metadataAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(PersistedIdentityMetadata.self, from: data)
    }

    private static func storeKey(_ data: Data, tag: String) throws {
        guard let tagData = tag.data(using: .utf8) else {
            throw PairingError.keychainFailure(reason: "Invalid tag encoding")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrService as String: serviceName,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PairingError.keychainFailure(reason: "Failed to store key \(tag): \(status)")
        }
    }

    private static func loadKey(tag: String) -> Data? {
        guard let tagData = tag.data(using: .utf8) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrService as String: serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private static func deleteKey(tag: String) {
        guard let tagData = tag.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrService as String: serviceName
        ]
        SecItemDelete(query as CFDictionary)
    }
}
