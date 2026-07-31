import Foundation
import VanguardDomain

public enum BuildStatus: String, Codable, Sendable, Equatable {
    case pending
    case building
    case succeeded
    case failed
    case cancelled
}

public struct ArchitectureArtifact: Codable, Sendable, Equatable {
    public let architecture: CPUArchitecture
    public let binaryPath: String
    public let sha256: Data
    public let sizeBytes: UInt64
    public let buildDuration: TimeInterval
    public let status: BuildStatus
    public let errorMessage: String?

    public init(
        architecture: CPUArchitecture,
        binaryPath: String,
        sha256: Data = Data(),
        sizeBytes: UInt64 = 0,
        buildDuration: TimeInterval = 0,
        status: BuildStatus = .pending,
        errorMessage: String? = nil
    ) {
        self.architecture = architecture
        self.binaryPath = binaryPath
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
        self.buildDuration = buildDuration
        self.status = status
        self.errorMessage = errorMessage
    }
}

public struct UniversalBinaryArtifact: Codable, Sendable, Equatable {
    public let outputPath: String
    public let architectures: [CPUArchitecture]
    public let sha256: Data
    public let sizeBytes: UInt64
    public let lipoDuration: TimeInterval

    public init(
        outputPath: String,
        architectures: [CPUArchitecture],
        sha256: Data = Data(),
        sizeBytes: UInt64 = 0,
        lipoDuration: TimeInterval = 0
    ) {
        self.outputPath = outputPath
        self.architectures = architectures
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
        self.lipoDuration = lipoDuration
    }
}

public struct BuildManifest: Codable, Sendable, Equatable {
    public let buildID: UUID
    public let productName: String
    public let version: String
    public let buildNumber: UInt64
    public let targetArchitectures: [CPUArchitecture]
    public var artifacts: [ArchitectureArtifact]
    public var universalArtifact: UniversalBinaryArtifact?
    public let createdAt: Date
    public var completedAt: Date?
    public var status: BuildStatus

    public init(
        buildID: UUID = UUID(),
        productName: String,
        version: String,
        buildNumber: UInt64 = 1,
        targetArchitectures: [CPUArchitecture] = [.arm64, .x86_64],
        artifacts: [ArchitectureArtifact] = [],
        universalArtifact: UniversalBinaryArtifact? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        status: BuildStatus = .pending
    ) {
        self.buildID = buildID
        self.productName = productName
        self.version = version
        self.buildNumber = buildNumber
        self.targetArchitectures = targetArchitectures
        self.artifacts = artifacts
        self.universalArtifact = universalArtifact
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.status = status
    }

    public var isComplete: Bool {
        status == .succeeded || status == .failed || status == .cancelled
    }

    public var succeededArchitectures: [CPUArchitecture] {
        artifacts.filter { $0.status == .succeeded }.map { $0.architecture }
    }

    public var failedArchitectures: [CPUArchitecture] {
        artifacts.filter { $0.status == .failed }.map { $0.architecture }
    }
}
