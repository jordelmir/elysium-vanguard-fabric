import Foundation
import os
import CryptoKit
import VanguardDomain

public enum UpdateState: Sendable, Equatable {
    case idle
    case checking
    case downloading(progress: Double)
    case verifying
    case installing
    case activating
    case healthCheck
    case completed
    case rolledBack
    case failed(String)
}

public actor UpdateService {
    private var currentState: UpdateState = .idle
    private var currentManifest: UpdateManifest?
    private var trustedKeys: [P256.Signing.PublicKey] = []
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Update")

    public init(trustedKeys: [P256.Signing.PublicKey] = []) {
        self.trustedKeys = trustedKeys
    }

    public func addTrustedKey(_ key: P256.Signing.PublicKey) {
        trustedKeys.append(key)
    }

    public func removeTrustedKey(_ key: P256.Signing.PublicKey) {
        trustedKeys.removeAll { $0.rawRepresentation == key.rawRepresentation }
    }

    public func checkForUpdate(manifest: UpdateManifest, currentVersion: String) -> Bool {
        currentState = .checking
        let currentBuild = parseBuild(currentVersion)
        if manifest.build > currentBuild {
            currentManifest = manifest
            logger.info("Update available: \(manifest.version) build \(manifest.build)")
            return true
        }
        currentState = .idle
        return false
    }

    public func downloadUpdate(from url: String) async throws -> Data {
        currentState = .downloading(progress: 0)
        guard let manifest = currentManifest else {
            currentState = .failed("No manifest")
            throw UpdateError.noManifest
        }

        let downloadURL = URL(string: url) ?? URL(string: manifest.artifactURL)
        guard let resolvedURL = downloadURL else {
            currentState = .failed("Invalid URL")
            throw UpdateError.downloadFailed("Invalid URL")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: resolvedURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                currentState = .failed("HTTP error")
                throw UpdateError.downloadFailed("HTTP error")
            }

            let computedHash = sha256(data)
            guard computedHash == manifest.sha256 else {
                currentState = .failed("Hash mismatch")
                throw UpdateError.hashMismatch
            }

            currentState = .downloading(progress: 1.0)
            return data
        } catch let error as UpdateError {
            throw error
        } catch {
            currentState = .failed("Download error: \(error.localizedDescription)")
            throw UpdateError.downloadFailed(error.localizedDescription)
        }
    }

    public func verifySignature(_ data: Data, signature: Data) throws -> P256.Signing.PublicKey {
        currentState = .verifying
        logger.info("Verifying update signature")

        guard !trustedKeys.isEmpty else {
            currentState = .failed("No trusted keys")
            throw UpdateError.signatureInvalid
        }

        guard !signature.isEmpty else {
            currentState = .failed("Empty signature")
            throw UpdateError.signatureInvalid
        }

        let ecdaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)

        for key in trustedKeys {
            if key.isValidSignature(ecdaSignature, for: data) {
                logger.info("Signature verified against trusted key")
                return key
            }
        }

        currentState = .failed("Signature not from trusted key")
        throw UpdateError.signatureInvalid
    }

    public func verifyManifestSignature(_ data: Data) throws -> P256.Signing.PublicKey {
        guard let manifest = currentManifest else {
            currentState = .failed("No manifest")
            throw UpdateError.noManifest
        }
        return try verifySignature(data, signature: manifest.signature)
    }

    public func installUpdate(_ data: Data, stagingPath: String) throws {
        currentState = .installing
        do {
            let stagingURL = URL(fileURLWithPath: stagingPath)
            try FileManager.default.createDirectory(
                at: stagingURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: stagingURL)
            logger.info("Update installed to staging: \(stagingPath)")
        } catch {
            currentState = .failed("Install failed: \(error.localizedDescription)")
            throw UpdateError.installFailed(error.localizedDescription)
        }
    }

    public func activateUpdate(stagingPath: String, activePath: String) throws {
        currentState = .activating
        let stagingURL = URL(fileURLWithPath: stagingPath)
        let activeURL = URL(fileURLWithPath: activePath)
        let backupURL = URL(fileURLWithPath: activePath + ".backup")

        guard FileManager.default.fileExists(atPath: stagingPath) else {
            currentState = .failed("Staging file not found")
            throw UpdateError.installFailed("Staging file not found")
        }

        do {
            if FileManager.default.fileExists(atPath: activePath) {
                try FileManager.default.copyItem(at: activeURL, to: backupURL)
            }
            if FileManager.default.fileExists(atPath: activePath) {
                try FileManager.default.removeItem(at: activeURL)
            }
            try FileManager.default.moveItem(at: stagingURL, to: activeURL)
            logger.info("Update activated: \(activePath)")
        } catch {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.removeItem(at: activeURL)
                try? FileManager.default.moveItem(at: backupURL, to: activeURL)
                logger.warning("Rolled back to previous version after activation failure")
            }
            currentState = .failed("Activation failed: \(error.localizedDescription)")
            throw UpdateError.installFailed(error.localizedDescription)
        }
    }

    public func healthCheck(binaryPath: String) -> Bool {
        currentState = .healthCheck
        logger.info("Running health check after update")

        let fileExists = FileManager.default.fileExists(atPath: binaryPath)
        if !fileExists {
            currentState = .failed("Binary not found at \(binaryPath)")
            logger.error("Health check failed: binary not found")
            return false
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: binaryPath)),
              data.count > 0 else {
            currentState = .failed("Binary is empty")
            logger.error("Health check failed: binary is empty")
            return false
        }

        currentState = .completed
        logger.info("Health check passed")
        return true
    }

    public func rollback(stagingPath: String, activePath: String) {
        let stagingURL = URL(fileURLWithPath: stagingPath)
        let backupURL = URL(fileURLWithPath: activePath + ".backup")
        let activeURL = URL(fileURLWithPath: activePath)

        try? FileManager.default.removeItem(at: stagingURL)

        if FileManager.default.fileExists(atPath: backupURL.path) {
            try? FileManager.default.removeItem(at: activeURL)
            try? FileManager.default.moveItem(at: backupURL, to: activeURL)
            logger.warning("Rolled back to backup: \(activePath)")
        }

        currentState = .rolledBack
        logger.warning("Update rolled back")
    }

    public func state() -> UpdateState { currentState }

    public func getManifest() -> UpdateManifest? { currentManifest }

    public func reset() {
        currentState = .idle
        currentManifest = nil
    }

    private func parseBuild(_ version: String) -> UInt64 {
        let parts = version.split(separator: ".")
        guard parts.count >= 3 else { return 0 }
        return UInt64(parts[2]) ?? 0
    }

    private func sha256(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
}

public enum UpdateError: Error, Sendable, Equatable {
    case noManifest
    case hashMismatch
    case signatureInvalid
    case downloadFailed(String)
    case installFailed(String)
    case healthCheckFailed
}

extension UpdateError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noManifest: return "No update manifest available"
        case .hashMismatch: return "Downloaded artifact hash mismatch"
        case .signatureInvalid: return "Invalid update signature"
        case .downloadFailed(let reason): return "Download failed: \(reason)"
        case .installFailed(let reason): return "Install failed: \(reason)"
        case .healthCheckFailed: return "Health check failed after update"
        }
    }
}
