import Foundation
import CryptoKit
import Security
import VanguardDomain

// MARK: - CryptoKit Identity Service (macOS implementation)

public final class CryptoKitIdentityService: IdentityService, @unchecked Sendable {
    private let keychainService = "com.elysiumvanguard.fabric.identity"

    public init() {}

    // MARK: - Identity Generation

    public func generateDeviceIdentity() async throws -> DeviceIdentity {
        let nodeID = NodeID()

        let signingKey = Curve25519.Signing.PrivateKey()
        let agreementKey = Curve25519.KeyAgreement.PrivateKey()

        let signingPublicKeyData = signingKey.publicKey.rawRepresentation
        let agreementPublicKeyData = agreementKey.publicKey.rawRepresentation

        let fingerprint = SHA256.hash(data: signingPublicKeyData + agreementPublicKeyData)
        let fingerprintData = Data(fingerprint)

        let signingKeyRef = "signing-\(nodeID.rawValue.uuidString)"
        let agreementKeyRef = "agreement-\(nodeID.rawValue.uuidString)"

        try storeKeyData(signingKey.rawRepresentation, identifier: signingKeyRef)
        try storeKeyData(agreementKey.rawRepresentation, identifier: agreementKeyRef)

        return DeviceIdentity(
            nodeID: nodeID,
            signingPublicKey: signingPublicKeyData,
            signingPrivateKeyRef: signingKeyRef,
            agreementPublicKey: agreementPublicKeyData,
            agreementPrivateKeyRef: agreementKeyRef,
            certificateFingerprint: fingerprintData
        )
    }

    public func getOrCreateIdentity() async throws -> DeviceIdentity {
        let allKeys = try findKeychainItems(service: keychainService)
        if let existingRef = allKeys.first(where: { $0.contains("signing-") }) {
            let signingKeyRef = String(existingRef.dropFirst("signing-".count))
            let nodeIDString = signingKeyRef.replacingOccurrences(of: "signing-", with: "")

            guard let uuid = UUID(uuidString: nodeIDString),
                  let signingData = loadKeyData(identifier: "signing-\(nodeIDString)"),
                  let agreementData = loadKeyData(identifier: "agreement-\(nodeIDString)") else {
                return try await generateDeviceIdentity()
            }

            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: signingData)
            let agreementKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementData)

            let fingerprint = SHA256.hash(data: signingKey.publicKey.rawRepresentation + agreementKey.publicKey.rawRepresentation)

            return DeviceIdentity(
                nodeID: NodeID(rawValue: uuid),
                signingPublicKey: signingKey.publicKey.rawRepresentation,
                signingPrivateKeyRef: "signing-\(nodeIDString)",
                agreementPublicKey: agreementKey.publicKey.rawRepresentation,
                agreementPrivateKeyRef: "agreement-\(nodeIDString)",
                certificateFingerprint: Data(fingerprint)
            )
        }

        return try await generateDeviceIdentity()
    }

    // MARK: - Signing

    public func signData(_ data: Data, identity: DeviceIdentity) async throws -> Data {
        guard let privateKeyData = loadKeyData(identifier: identity.signingPrivateKeyRef) else {
            throw PairingError.keychainFailure(reason: "Signing key not found")
        }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
        let signature = try privateKey.signature(for: data)
        return signature
    }

    public func verifySignature(_ signature: Data, data: Data, publicKey: Data) async throws -> Bool {
        guard let pubKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey) else {
            return false
        }
        return pubKey.isValidSignature(signature, for: data)
    }

    // MARK: - Trusted Peers

    public func saveTrustedPeer(_ peer: TrustedPeer) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(peer)
        let key = "peer-\(peer.nodeID.rawValue.uuidString)"
        try storeKeyData(data, identifier: key)
    }

    public func loadTrustedPeer(nodeID: NodeID) async throws -> TrustedPeer? {
        let key = "peer-\(nodeID.rawValue.uuidString)"
        guard let data = loadKeyData(identifier: key) else { return nil }
        return try JSONDecoder().decode(TrustedPeer.self, from: data)
    }

    public func loadAllTrustedPeers() async throws -> [TrustedPeer] {
        let allKeys = try findKeychainItems(service: keychainService)
        var peers: [TrustedPeer] = []
        for key in allKeys {
            guard key.hasPrefix("peer-") else { continue }
            if let data = loadKeyData(identifier: key),
               let peer = try? JSONDecoder().decode(TrustedPeer.self, from: data) {
                peers.append(peer)
            }
        }
        return peers
    }

    public func revokePeer(nodeID: NodeID) async throws {
        let key = "peer-\(nodeID.rawValue.uuidString)"
        deleteKeychainItem(identifier: key)
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

        return PairingChallenge(
            code: code,
            expiresAt: Date().addingTimeInterval(90),
            fingerprint: fingerprint,
            maxAttempts: 5
        )
    }

    public func validateChallengeCode(_ code: String, challenge: PairingChallenge) async throws -> Bool {
        guard !challenge.isExpired else { return false }
        return code == challenge.code
    }

    // MARK: - Keychain Helpers

    private func storeKeyData(_ data: Data, identifier: String) throws {
        guard let tagData = "\(keychainService).\(identifier)".data(using: .utf8) else {
            throw PairingError.keychainFailure(reason: "Invalid identifier encoding")
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PairingError.keychainFailure(reason: "Failed to store key: \(status)")
        }
    }

    private func loadKeyData(identifier: String) -> Data? {
        guard let tagData = "\(keychainService).\(identifier)".data(using: .utf8) else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private func findKeychainItems(service: String) throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { $0[kSecAttrApplicationTag as String] as? Data }.map { String(data: $0, encoding: .utf8) ?? "" }
    }

    private func deleteKeychainItem(identifier: String) {
        guard let tagData = "\(keychainService).\(identifier)".data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData
        ]
        SecItemDelete(query as CFDictionary)
    }
}
