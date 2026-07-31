import Foundation
import Security
import CryptoKit
import VanguardDomain

public final class TLSCertificateManager: @unchecked Sendable {
    private static let serviceName = "com.elysiumvanguard.fabric.tls"
    private static let keyTag = "tls-ec-key"

    private let lock = NSLock()

    public init() {}

    // MARK: - Public API

    public func getOrCreateSigningKey() throws -> SecKey {
        if let existing = loadKeyFromKeychain() {
            return existing
        }
        let key = try generateKeyPair()
        storeKeyToKeychain(key)
        return key
    }

    public func createEphemeralKeyPair() throws -> (privateKey: SecKey, publicKeyData: Data, fingerprint: Data) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw TLSError.keyGenerationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown")
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey),
              let pubData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw TLSError.keyExportFailed("Failed to export ephemeral public key")
        }
        let fingerprint = Data(CryptoKit.SHA256.hash(data: pubData))
        return (privateKey, pubData, fingerprint)
    }

    public func getLocalFingerprint() throws -> Data {
        let key = try getOrCreateSigningKey()
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) else {
            throw TLSError.keyExportFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown")
        }
        return Data(CryptoKit.SHA256.hash(data: keyData as Data))
    }

    public func getPublicKeyData(for key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw TLSError.keyExportFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown")
        }
        return data
    }

    public func validatePeerFingerprint(_ peerKeyData: Data, expectedFingerprint: Data) -> Bool {
        let fingerprint = Data(CryptoKit.SHA256.hash(data: peerKeyData))
        return fingerprint == expectedFingerprint
    }

    public func computeFingerprint(for publicKeyData: Data) -> Data {
        Data(CryptoKit.SHA256.hash(data: publicKeyData))
    }

    // MARK: - Key Generation

    private func generateKeyPair() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Self.serviceName.data(using: .utf8)!
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw TLSError.keyGenerationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown")
        }
        return privateKey
    }

    // MARK: - Keychain Storage

    private func storeKeyToKeychain(_ key: SecKey) {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.keyTag
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = keyData as Data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadKeyFromKeychain() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256
        ]
        return SecKeyCreateWithData(data as CFData, attributes as CFDictionary, nil)
    }
}

public enum TLSError: Error, Sendable, LocalizedError {
    case keyGenerationFailed(String)
    case keyExportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let r): return "TLS key generation failed: \(r)"
        case .keyExportFailed(let r): return "TLS key export failed: \(r)"
        }
    }
}
