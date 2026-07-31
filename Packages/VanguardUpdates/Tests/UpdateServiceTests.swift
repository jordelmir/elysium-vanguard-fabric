import Testing
import Foundation
import CryptoKit
@testable import VanguardUpdates
@testable import VanguardDomain

@Suite("UpdateService — Signed Update Packages")
struct UpdateServiceTests {

    private func makeSigningKey() -> P256.Signing.PrivateKey {
        P256.Signing.PrivateKey()
    }

    private func makeManifest(
        version: String = "1.0.1",
        build: UInt64 = 2,
        sha256: Data = Data(repeating: 0xAA, count: 32),
        signature: Data = Data()
    ) -> UpdateManifest {
        UpdateManifest(
            version: version,
            build: build,
            targetOS: "macOS",
            targetArchitecture: .arm64,
            minimumOSVersion: "12.0",
            artifactURL: "https://example.com/update.pkg",
            sha256: sha256,
            signature: signature,
            releaseNotes: "Test"
        )
    }

    @Test("checkForUpdate returns true when build is newer")
    func checkForUpdateNewer() async {
        let service = UpdateService()
        let manifest = makeManifest(build: 2)
        let result = await service.checkForUpdate(manifest: manifest, currentVersion: "1.0.0")
        #expect(result == true)
    }

    @Test("checkForUpdate returns false when build is same or older")
    func checkForUpdateSame() async {
        let service = UpdateService()
        let manifest = makeManifest(build: 1)
        let result = await service.checkForUpdate(manifest: manifest, currentVersion: "1.0.1")
        #expect(result == false)
        let state = await service.state()
        #expect(state == .idle)
    }

    @Test("checkForUpdate returns false when build is older")
    func checkForUpdateOlder() async {
        let service = UpdateService()
        let manifest = makeManifest(build: 0)
        let result = await service.checkForUpdate(manifest: manifest, currentVersion: "1.0.1")
        #expect(result == false)
    }

    @Test("verifySignature rejects empty signature")
    func verifyRejectsEmpty() async {
        let service = UpdateService()
        let key = makeSigningKey()
        await service.addTrustedKey(key.publicKey)
        let data = Data("test".utf8)
        do {
            _ = try await service.verifySignature(data, signature: Data())
            Issue.record("Expected error")
        } catch {
            #expect(error is UpdateError)
        }
    }

    @Test("verifySignature rejects no trusted keys")
    func verifyRejectsNoKeys() async {
        let service = UpdateService()
        let key = makeSigningKey()
        let signature = try! key.signature(for: Data("test".utf8))
        do {
            _ = try await service.verifySignature(Data("test".utf8), signature: signature.derRepresentation)
            Issue.record("Expected error")
        } catch {
            #expect(error is UpdateError)
        }
    }

    @Test("verifySignature accepts valid signature from trusted key")
    func verifyAcceptsValid() async throws {
        let key = makeSigningKey()
        let service = UpdateService(trustedKeys: [key.publicKey])
        let data = Data("update payload".utf8)
        let signature = try key.signature(for: data)
        let verifiedKey = try await service.verifySignature(data, signature: signature.derRepresentation)
        #expect(verifiedKey.rawRepresentation == key.publicKey.rawRepresentation)
    }

    @Test("verifySignature rejects signature from untrusted key")
    func verifyRejectsUntrusted() async throws {
        let trustedKey = makeSigningKey()
        let otherKey = makeSigningKey()
        let service = UpdateService(trustedKeys: [trustedKey.publicKey])
        let data = Data("update payload".utf8)
        let signature = try otherKey.signature(for: data)
        do {
            _ = try await service.verifySignature(data, signature: signature.derRepresentation)
            Issue.record("Expected error")
        } catch {
            #expect(error is UpdateError)
        }
    }

    @Test("verifyManifestSignature uses manifest's signature field")
    func verifyManifestSignature() async throws {
        let key = makeSigningKey()
        let data = Data("update payload".utf8)
        let signature = try key.signature(for: data)
        let manifest = makeManifest(sha256: Data(repeating: 0xBB, count: 32), signature: signature.derRepresentation)
        let service = UpdateService(trustedKeys: [key.publicKey])
        await _ = service.checkForUpdate(manifest: manifest, currentVersion: "1.0.0")
        let verifiedKey = try await service.verifyManifestSignature(data)
        #expect(verifiedKey.rawRepresentation == key.publicKey.rawRepresentation)
    }

    @Test("installUpdate writes data to staging path")
    func installWritesFile() async throws {
        let service = UpdateService()
        let stagingPath = NSTemporaryDirectory() + "elysium-test-update-\(UUID().uuidString)"
        let data = Data("binary content".utf8)
        try await service.installUpdate(data, stagingPath: stagingPath)
        let written = try Data(contentsOf: URL(fileURLWithPath: stagingPath))
        #expect(written == data)
        try? FileManager.default.removeItem(atPath: stagingPath)
    }

    @Test("installUpdate sets failed state on error")
    func installSetsFailed() async {
        let service = UpdateService()
        let invalidPath = "/nonexistent/root/readonly/file"
        do {
            try await service.installUpdate(Data("x".utf8), stagingPath: invalidPath)
            Issue.record("Expected error")
        } catch {
            #expect(error is UpdateError)
        }
        let state = await service.state()
        if case .failed = state {} else {
            Issue.record("Expected .failed state, got \(String(describing: state))")
        }
    }

    @Test("activateUpdate moves staging to active path")
    func activateMovesFile() async throws {
        let service = UpdateService()
        let id = UUID().uuidString
        let stagingPath = NSTemporaryDirectory() + "elysium-staging-\(id)"
        let activePath = NSTemporaryDirectory() + "elysium-active-\(id)"
        let data = Data("new version".utf8)
        try data.write(to: URL(fileURLWithPath: stagingPath))
        try await service.activateUpdate(stagingPath: stagingPath, activePath: activePath)
        let written = try Data(contentsOf: URL(fileURLWithPath: activePath))
        #expect(written == data)
        #expect(!FileManager.default.fileExists(atPath: stagingPath))
        try? FileManager.default.removeItem(atPath: activePath)
    }

    @Test("activateUpdate backs up existing active file")
    func activateBacksUp() async throws {
        let service = UpdateService()
        let id = UUID().uuidString
        let stagingPath = NSTemporaryDirectory() + "elysium-staging-\(id)"
        let activePath = NSTemporaryDirectory() + "elysium-active-\(id)"
        let oldData = Data("old version".utf8)
        let newData = Data("new version".utf8)
        try oldData.write(to: URL(fileURLWithPath: activePath))
        try newData.write(to: URL(fileURLWithPath: stagingPath))
        try await service.activateUpdate(stagingPath: stagingPath, activePath: activePath)
        let written = try Data(contentsOf: URL(fileURLWithPath: activePath))
        #expect(written == newData)
        let backupPath = activePath + ".backup"
        let backup = try Data(contentsOf: URL(fileURLWithPath: backupPath))
        #expect(backup == oldData)
        try? FileManager.default.removeItem(atPath: activePath)
        try? FileManager.default.removeItem(atPath: backupPath)
    }

    @Test("activateUpdate fails when staging file missing")
    func activateFailsNoStaging() async {
        let service = UpdateService()
        do {
            try await service.activateUpdate(
                stagingPath: "/nonexistent/staging",
                activePath: "/tmp/active"
            )
            Issue.record("Expected error")
        } catch {
            #expect(error is UpdateError)
        }
        let state = await service.state()
        if case .failed = state {} else {
            Issue.record("Expected .failed state")
        }
    }

    @Test("healthCheck passes for valid file with content")
    func healthCheckValid() async throws {
        let service = UpdateService()
        let path = NSTemporaryDirectory() + "elysium-health-\(UUID().uuidString)"
        try Data("ELF binary content".utf8).write(to: URL(fileURLWithPath: path))
        let result = await service.healthCheck(binaryPath: path)
        #expect(result == true)
        let state = await service.state()
        #expect(state == .completed)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("healthCheck fails for missing binary")
    func healthCheckMissing() async {
        let service = UpdateService()
        let result = await service.healthCheck(binaryPath: "/nonexistent/binary")
        #expect(result == false)
        let state = await service.state()
        if case .failed = state {} else {
            Issue.record("Expected .failed state")
        }
    }

    @Test("healthCheck fails for empty file")
    func healthCheckEmpty() async {
        let service = UpdateService()
        let path = NSTemporaryDirectory() + "elysium-empty-\(UUID().uuidString)"
        try? Data().write(to: URL(fileURLWithPath: path))
        let result = await service.healthCheck(binaryPath: path)
        #expect(result == false)
        try? FileManager.default.removeItem(atPath: path)
    }

    @Test("rollback removes staging and restores backup")
    func rollbackRestores() async throws {
        let service = UpdateService()
        let id = UUID().uuidString
        let stagingPath = NSTemporaryDirectory() + "elysium-staging-\(id)"
        let activePath = NSTemporaryDirectory() + "elysium-active-\(id)"
        let backupPath = activePath + ".backup"
        let oldData = Data("old".utf8)
        let newData = Data("new".utf8)
        try oldData.write(to: URL(fileURLWithPath: activePath))
        try oldData.write(to: URL(fileURLWithPath: backupPath))
        try newData.write(to: URL(fileURLWithPath: stagingPath))
        await service.rollback(stagingPath: stagingPath, activePath: activePath)
        #expect(!FileManager.default.fileExists(atPath: stagingPath))
        let restored = try Data(contentsOf: URL(fileURLWithPath: activePath))
        #expect(restored == oldData)
        let state = await service.state()
        #expect(state == .rolledBack)
        try? FileManager.default.removeItem(atPath: activePath)
        try? FileManager.default.removeItem(atPath: backupPath)
    }

    @Test("reset returns to idle state")
    func resetClears() async {
        let service = UpdateService()
        let manifest = makeManifest(build: 2)
        _ = await service.checkForUpdate(manifest: manifest, currentVersion: "1.0.0")
        await service.reset()
        let state = await service.state()
        #expect(state == .idle)
    }

    @Test("addTrustedKey and removeTrustedKey manage keys")
    func keyManagement() async {
        let service = UpdateService()
        let key1 = makeSigningKey()
        let key2 = makeSigningKey()
        await service.addTrustedKey(key1.publicKey)
        await service.addTrustedKey(key2.publicKey)
        let data = Data("test".utf8)
        let sig1 = try! key1.signature(for: data)
        let _ = try! await service.verifySignature(data, signature: sig1.derRepresentation)
        await service.removeTrustedKey(key1.publicKey)
        do {
            _ = try await service.verifySignature(data, signature: sig1.derRepresentation)
            Issue.record("Expected error after removing trusted key")
        } catch {
            #expect(error is UpdateError)
        }
    }

    @Test("full update flow: sign, verify, install, activate, health check")
    func fullUpdateFlow() async throws {
        let key = makeSigningKey()
        let service = UpdateService(trustedKeys: [key.publicKey])
        let id = UUID().uuidString
        let stagingPath = NSTemporaryDirectory() + "elysium-flow-staging-\(id)"
        let activePath = NSTemporaryDirectory() + "elysium-flow-active-\(id)"
        let payload = Data("Elysium Vanguard v2.0 binary".utf8)
        let signature = try key.signature(for: payload)
        let manifest = makeManifest(
            version: "1.0.2",
            build: 3,
            sha256: SHA256.hash(data: payload).withUnsafeBytes { Data($0) },
            signature: signature.derRepresentation
        )
        let available = await service.checkForUpdate(manifest: manifest, currentVersion: "1.0.1")
        #expect(available == true)
        let verifiedKey = try await service.verifyManifestSignature(payload)
        #expect(verifiedKey.rawRepresentation == key.publicKey.rawRepresentation)
        try await service.installUpdate(payload, stagingPath: stagingPath)
        try await service.activateUpdate(stagingPath: stagingPath, activePath: activePath)
        let healthy = await service.healthCheck(binaryPath: activePath)
        #expect(healthy == true)
        let state = await service.state()
        #expect(state == .completed)
        try? FileManager.default.removeItem(atPath: activePath)
    }
}
