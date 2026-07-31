import Foundation
import os
import CryptoKit
import VanguardDomain
import VanguardCompute

public struct BuildTarget: Sendable, Equatable {
    public let architecture: CPUArchitecture
    public let sdk: String
    public let extraFlags: [String]

    public init(architecture: CPUArchitecture, sdk: String = "macosx", extraFlags: [String] = []) {
        self.architecture = architecture
        self.sdk = sdk
        self.extraFlags = extraFlags
    }
}

public struct UniversalBuildRequest: Sendable, Equatable {
    public let productName: String
    public let version: String
    public let buildNumber: UInt64
    public let sourcePath: String
    public let outputPath: String
    public let targets: [BuildTarget]
    public let signingIdentity: String?
    public let entitlements: String?

    public init(
        productName: String,
        version: String,
        buildNumber: UInt64 = 1,
        sourcePath: String,
        outputPath: String,
        targets: [BuildTarget] = [
            BuildTarget(architecture: .arm64),
            BuildTarget(architecture: .x86_64)
        ],
        signingIdentity: String? = nil,
        entitlements: String? = nil
    ) {
        self.productName = productName
        self.version = version
        self.buildNumber = buildNumber
        self.sourcePath = sourcePath
        self.outputPath = outputPath
        self.targets = targets
        self.signingIdentity = signingIdentity
        self.entitlements = entitlements
    }
}

public actor UniversalBuildService {
    private let lipoService: LipoService
    private var activeBuilds: [UUID: BuildManifest] = [:]
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "UniversalBuild")

    public init(lipoService: LipoService = LipoService()) {
        self.lipoService = lipoService
    }

    public func startBuild(_ request: UniversalBuildRequest) async throws -> BuildManifest {
        let manifest = BuildManifest(
            productName: request.productName,
            version: request.version,
            buildNumber: request.buildNumber,
            targetArchitectures: request.targets.map { $0.architecture }
        )
        activeBuilds[manifest.buildID] = manifest
        logger.info("Starting universal build: \(request.productName) v\(request.version)")

        for target in request.targets {
            let artifact = try await buildArchitecture(
                request: request,
                target: target,
                buildID: manifest.buildID
            )
            activeBuilds[manifest.buildID]?.artifacts.append(artifact)
        }

        let succeeded = activeBuilds[manifest.buildID]?.artifacts.filter { $0.status == .succeeded } ?? []
        let inputPaths = succeeded.map { $0.binaryPath }

        if inputPaths.count >= 2 {
            let outputPath = "\(request.outputPath)/\(request.productName)-universal"
            let lipoResult = try await lipoService.combine(
                inputPaths: inputPaths,
                outputPath: outputPath
            )
            let universalArtifact = UniversalBinaryArtifact(
                outputPath: lipoResult.outputPath,
                architectures: lipoResult.architectures,
                sha256: lipoResult.sha256,
                sizeBytes: lipoResult.sizeBytes,
                lipoDuration: lipoResult.duration
            )
            activeBuilds[manifest.buildID]?.universalArtifact = universalArtifact
            activeBuilds[manifest.buildID]?.status = .succeeded
        } else if inputPaths.count == 1, let single = succeeded.first {
            let universalArtifact = UniversalBinaryArtifact(
                outputPath: single.binaryPath,
                architectures: [single.architecture],
                sha256: single.sha256,
                sizeBytes: single.sizeBytes,
                lipoDuration: 0
            )
            activeBuilds[manifest.buildID]?.universalArtifact = universalArtifact
            activeBuilds[manifest.buildID]?.status = .succeeded
        } else {
            activeBuilds[manifest.buildID]?.status = .failed
        }

        activeBuilds[manifest.buildID]?.completedAt = Date()

        guard let finalManifest = activeBuilds[manifest.buildID] else {
            throw BuildServiceError.buildNotFound
        }

        logger.info("Universal build \(manifest.productName) completed: \(finalManifest.status.rawValue)")
        return finalManifest
    }

    public func cancelBuild(_ buildID: UUID) {
        guard var manifest = activeBuilds[buildID], !manifest.isComplete else { return }
        manifest.status = .cancelled
        manifest.completedAt = Date()
        activeBuilds[buildID] = manifest
        logger.info("Build cancelled: \(manifest.productName)")
    }

    public func buildManifest(_ buildID: UUID) -> BuildManifest? {
        activeBuilds[buildID]
    }

    public func activeBuildIDs() -> [UUID] {
        activeBuilds.keys.filter { id in
            !(activeBuilds[id]?.isComplete ?? true)
        }.map { $0 }
    }

    public func cleanupCompletedBuilds(olderThan interval: TimeInterval = 3600) {
        let now = Date()
        let stale = activeBuilds.filter { id, manifest in
            guard let completed = manifest.completedAt else { return false }
            return now.timeIntervalSince(completed) > interval
        }
        for id in stale.keys {
            activeBuilds.removeValue(forKey: id)
        }
        if !stale.isEmpty {
            logger.info("Cleaned up \(stale.count) completed builds")
        }
    }

    private func buildArchitecture(
        request: UniversalBuildRequest,
        target: BuildTarget,
        buildID: UUID
    ) async throws -> ArchitectureArtifact {
        let startTime = Date()
        let archName = target.architecture == .arm64 ? "arm64" : "x86_64"
        let outputPath = "\(request.outputPath)/\(request.productName)-\(archName)"

        var arguments = [
            "build",
            "-project", "\(request.productName).xcodeproj",
            "-scheme", request.productName,
            "-configuration", "Release",
            "-arch", archName,
            "-sdk", target.sdk,
            "CONFIGURATION_BUILD_DIR=\(outputPath)",
            "MARKETING_VERSION=\(request.version)",
            "CURRENT_PROJECT_VERSION=\(request.buildNumber)"
        ]
        arguments.append(contentsOf: target.extraFlags)

        if let signing = request.signingIdentity {
            arguments.append(contentsOf: ["CODE_SIGN_IDENTITY=\(signing)"])
        }
        if let ent = request.entitlements {
            arguments.append(contentsOf: ["CODE_SIGN_ENTITLEMENTS=\(ent)"])
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: request.sourcePath)

        let stderrPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            return ArchitectureArtifact(
                architecture: target.architecture,
                binaryPath: outputPath,
                buildDuration: duration,
                status: .failed,
                errorMessage: error.localizedDescription
            )
        }

        process.waitUntilExit()
        let duration = Date().timeIntervalSince(startTime)

        if process.terminationStatus == 0 {
            let binaryPath = "\(outputPath)/\(request.productName)"
            let size: UInt64
            let hash: Data
            if let attrs = try? FileManager.default.attributesOfItem(atPath: binaryPath),
               let fileSize = attrs[.size] as? UInt64 {
                size = fileSize
                let data = try? Data(contentsOf: URL(fileURLWithPath: binaryPath))
                hash = data.map { Data(SHA256.hash(data: $0)) } ?? Data()
            } else {
                size = 0
                hash = Data()
            }
            return ArchitectureArtifact(
                architecture: target.architecture,
                binaryPath: binaryPath,
                sha256: hash,
                sizeBytes: size,
                buildDuration: duration,
                status: .succeeded
            )
        } else {
            let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: stderr, encoding: .utf8) ?? "Build failed"
            return ArchitectureArtifact(
                architecture: target.architecture,
                binaryPath: outputPath,
                buildDuration: duration,
                status: .failed,
                errorMessage: String(msg.prefix(500))
            )
        }
    }
}

public enum BuildServiceError: Error, Sendable {
    case buildNotFound
    case noArchitecturesSucceeded
}

extension BuildServiceError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .buildNotFound: return "Build manifest not found"
        case .noArchitecturesSucceeded: return "No architecture builds succeeded"
        }
    }
}
