import Testing
import Foundation
import CryptoKit
@testable import VanguardIdentity

@Suite("TLSCertificateManager")
struct TLSCertificateManagerTests {

    @Test("Ephemeral key pair creation succeeds")
    func ephemeralKeyPair() throws {
        let manager = TLSCertificateManager()
        let (privateKey, pubData, fingerprint) = try manager.createEphemeralKeyPair()
        #expect(pubData.count > 0)
        #expect(fingerprint.count == 32)
        var error: Unmanaged<CFError>?
        let exported = SecKeyCopyExternalRepresentation(privateKey, &error)
        #expect(exported != nil)
    }

    @Test("Ephemeral fingerprint matches computed")
    func fingerprintConsistency() throws {
        let manager = TLSCertificateManager()
        let (_, pubData, fingerprint) = try manager.createEphemeralKeyPair()
        let computed = manager.computeFingerprint(for: pubData)
        #expect(fingerprint == computed)
    }

    @Test("Validate peer fingerprint matches")
    func validateFingerprint() throws {
        let manager = TLSCertificateManager()
        let keyData = "test-peer-key-data".data(using: .utf8)!
        let fingerprint = Data(CryptoKit.SHA256.hash(data: keyData))
        #expect(manager.validatePeerFingerprint(keyData, expectedFingerprint: fingerprint) == true)
        #expect(manager.validatePeerFingerprint(Data("wrong".utf8), expectedFingerprint: fingerprint) == false)
    }

    @Test("Get public key data from ephemeral key")
    func getPublicKeyData() throws {
        let manager = TLSCertificateManager()
        let (privateKey, _, _) = try manager.createEphemeralKeyPair()
        let pubData = try manager.getPublicKeyData(for: privateKey)
        #expect(pubData.count > 0)
    }

    @Test("Two ephemeral keys produce different fingerprints")
    func differentKeys() throws {
        let manager = TLSCertificateManager()
        let (_, _, fp1) = try manager.createEphemeralKeyPair()
        let (_, _, fp2) = try manager.createEphemeralKeyPair()
        #expect(fp1 != fp2)
    }
}
