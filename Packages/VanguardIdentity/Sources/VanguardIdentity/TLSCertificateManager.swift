import Foundation
import Security
import CryptoKit
import VanguardDomain

public final class TLSCertificateManager: @unchecked Sendable {
    private static let serviceName = "com.elysiumvanguard.fabric.tls"
    private static let keyTag = "tls-ec-key"

    private let lock = NSLock()

    public init() {}

    public func getOrCreateSigningKey() throws -> SecKey {
        if let existing = loadKeyFromKeychain() {
            return existing
        }
        return try generateKeyPair()
    }

    public func getLocalFingerprint() throws -> Data {
        let key = try getOrCreateSigningKey()
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) else {
            throw TLSError.keyExportFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown")
        }
        return Data(SHA256.hash(data: keyData as Data))
    }

    public func validatePeerFingerprint(_ peerKeyData: Data, expectedFingerprint: Data) -> Bool {
        let fingerprint = Data(SHA256.hash(data: peerKeyData))
        return fingerprint == expectedFingerprint
    }

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

        storeKeyToKeychain(privateKey)
        return privateKey
    }

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
