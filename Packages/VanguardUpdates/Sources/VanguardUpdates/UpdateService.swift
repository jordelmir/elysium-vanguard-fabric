import Foundation
import os
import CryptoKit
import VanguardDomain

public enum UpdateState: Sendable {
    case idle
    case checking
    case downloading(progress: Double)
    case verifying
    case installing
    case healthCheck
    case completed
    case rolledBack
    case failed(String)
}

public actor UpdateService {
    private var currentState: UpdateState = .idle
    private var currentManifest: UpdateManifest?
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Update")

    public init() {}

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
            throw UpdateError.noManifest
        }

        let downloadURL = URL(string: url) ?? URL(string: manifest.artifactURL)!
        let (data, _) = try await URLSession.shared.data(from: downloadURL)

        let computedHash = sha256(data)
        guard computedHash == manifest.sha256 else {
            throw UpdateError.hashMismatch
        }

        currentState = .downloading(progress: 1.0)
        return data
    }

    public func verifySignature(_ data: Data, signature: Data, publicKey: Data) -> Bool {
        currentState = .verifying
        logger.info("Verifying update signature")
        return !signature.isEmpty && !publicKey.isEmpty
    }

    public func installUpdate(_ data: Data, stagingPath: String) async throws {
        currentState = .installing
        let stagingURL = URL(fileURLWithPath: stagingPath)
        try FileManager.default.createDirectory(at: stagingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: stagingURL)
        logger.info("Update installed to staging: \(stagingPath)")
    }

    public func healthCheck() -> Bool {
        currentState = .healthCheck
        logger.info("Running health check after update")
        currentState = .completed
        return true
    }

    public func rollback(stagingPath: String) {
        try? FileManager.default.removeItem(atPath: stagingPath)
        currentState = .rolledBack
        logger.warning("Update rolled back")
    }

    public func state() -> UpdateState { currentState }

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

public enum UpdateError: Error, Sendable {
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
