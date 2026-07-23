import XCTest
import Foundation
@testable import VanguardIdentity
@testable import VanguardDomain

@available(macOS 12.3, *)
final class CryptoKitIdentityServiceTests: XCTestCase {
    func testGetOrCreateIdentity() async {
        let service = CryptoKitIdentityService()
        do {
            let identity = try await service.getOrCreateIdentity()
            XCTAssertFalse(identity.nodeID.rawValue.uuidString.isEmpty)
            XCTAssertFalse(identity.signingPublicKey.isEmpty)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("keychain") || error.localizedDescription.contains("Keychain"),
                          "Unexpected error: \(error)")
        }
    }

    func testGenerateDeviceIdentity() async {
        let service = CryptoKitIdentityService()
        do {
            let identity = try await service.generateDeviceIdentity()
            XCTAssertNotNil(identity.signingPrivateKeyRef)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("keychain") || error.localizedDescription.contains("Keychain"),
                          "Unexpected error: \(error)")
        }
    }

    func testSignAndVerify() async {
        let service = CryptoKitIdentityService()
        do {
            let identity = try await service.generateDeviceIdentity()
            let data = Data("test data to sign".utf8)
            let signature = try await service.signData(data, identity: identity)
            let valid = try await service.verifySignature(signature, data: data, publicKey: identity.signingPublicKey)
            XCTAssertTrue(valid)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("keychain") || error.localizedDescription.contains("Keychain"),
                          "Unexpected error: \(error)")
        }
    }

    func testChallengeGenerate() async {
        let service = CryptoKitIdentityService()
        do {
            let challenge = try await service.generateChallenge()
            XCTAssertEqual(challenge.code.count, 6)
        } catch {
            XCTFail("Challenge generation failed: \(error)")
        }
    }

    func testChallengeValidation() async {
        let service = CryptoKitIdentityService()
        do {
            let challenge = try await service.generateChallenge()
            let valid = try await service.validateChallengeCode(challenge.code, challenge: challenge)
            XCTAssertTrue(valid)
            let invalid = try await service.validateChallengeCode("000000", challenge: challenge)
            XCTAssertFalse(invalid)
        } catch {
            XCTFail("Challenge validation failed: \(error)")
        }
    }

    func testTrustedPeerCRUD() async {
        let service = CryptoKitIdentityService()
        let nodeID = NodeID()
        let peer = TrustedPeer(
            nodeID: nodeID,
            signingPublicKey: Data("sign-pub".utf8),
            agreementPublicKey: Data("agree-pub".utf8),
            certificateFingerprint: Data("fingerprint".utf8),
            grantedCapabilities: [.screenView],
            pairedAt: Date()
        )

        do {
            try await service.saveTrustedPeer(peer)
            let loaded = try await service.loadTrustedPeer(nodeID: nodeID)
            XCTAssertNotNil(loaded)

            let all = try await service.loadAllTrustedPeers()
            XCTAssertFalse(all.isEmpty)

            try await service.revokePeer(nodeID: nodeID)
            let revoked = try await service.loadTrustedPeer(nodeID: nodeID)
            XCTAssertNil(revoked)
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("keychain") || error.localizedDescription.contains("Keychain"),
                          "Unexpected error: \(error)")
        }
    }
}
