import Foundation
import VanguardDomain

public struct ArtifactID: Hashable, Sendable, Codable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct ArtifactManifest: Sendable, Codable {
    public let artifactID: ArtifactID
    public let name: String
    public let version: String
    public let chunkSize: Int
    public let totalSize: Int
    public let sha256Hash: Data
    public let chunkHashes: [Data]
    public let metadata: [String: String]

    public var chunkCount: Int { chunkHashes.count }

    public init(artifactID: ArtifactID, name: String, version: String, chunkSize: Int, totalSize: Int, sha256Hash: Data, chunkHashes: [Data], metadata: [String: String] = [:]) {
        self.artifactID = artifactID
        self.name = name
        self.version = version
        self.chunkSize = chunkSize
        self.totalSize = totalSize
        self.sha256Hash = sha256Hash
        self.chunkHashes = chunkHashes
        self.metadata = metadata
    }
}

public struct ArtifactChunk: Sendable, Codable {
    public let artifactID: ArtifactID
    public let index: Int
    public let data: Data
    public let sha256Hash: Data

    public init(artifactID: ArtifactID, index: Int, data: Data, sha256Hash: Data) {
        self.artifactID = artifactID
        self.index = index
        self.data = data
        self.sha256Hash = sha256Hash
    }
}

public struct ArtifactRequest: Sendable, Codable {
    public let artifactID: ArtifactID
    public let chunkIndices: [Int]?

    public init(artifactID: ArtifactID, chunkIndices: [Int]? = nil) {
        self.artifactID = artifactID
        self.chunkIndices = chunkIndices
    }
}

public enum ArtifactTransferError: Error, Sendable {
    case manifestNotFound(ArtifactID)
    case chunkHashMismatch(expected: Data, received: Data)
    case manifestHashMismatch
    case diskFull
    case writeFailed(String)
    case chunkMissing(index: Int)
    case invalidChunkSize(Int)
}

extension ArtifactTransferError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .manifestNotFound(let id): return "Manifest not found: \(id.rawValue)"
        case .chunkHashMismatch: return "Chunk hash mismatch"
        case .manifestHashMismatch: return "Manifest hash mismatch"
        case .diskFull: return "Disk full"
        case .writeFailed(let reason): return "Write failed: \(reason)"
        case .chunkMissing(let index): return "Chunk \(index) missing"
        case .invalidChunkSize(let size): return "Invalid chunk size: \(size)"
        }
    }
}
