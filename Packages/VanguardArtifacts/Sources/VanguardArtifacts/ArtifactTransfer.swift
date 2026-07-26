import Foundation
import os
import CryptoKit
import VanguardDomain

public protocol ArtifactStore: Sendable {
    func saveManifest(_ manifest: ArtifactManifest) async throws
    func saveChunk(_ chunk: ArtifactChunk) async throws
    func getManifest(artifactID: ArtifactID) async -> ArtifactManifest?
    func getChunk(artifactID: ArtifactID, index: Int) async -> Data?
    func deleteArtifact(artifactID: ArtifactID) async throws
    func listArtifacts() async -> [ArtifactManifest]
    func markComplete(artifactID: ArtifactID) async throws
    func isComplete(artifactID: ArtifactID) async -> Bool
}

public actor ArtifactTransferService {
    private let store: ArtifactStore
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Artifacts")

    public init(store: ArtifactStore) {
        self.store = store
    }

    public func receiveManifest(_ manifest: ArtifactManifest) async throws {
        try await store.saveManifest(manifest)
        logger.info("Received manifest: \(manifest.name) v\(manifest.version) (\(manifest.chunkCount) chunks)")
    }

    public func receiveChunk(_ chunk: ArtifactChunk) async throws {
        guard let manifest = await store.getManifest(artifactID: chunk.artifactID) else {
            throw ArtifactTransferError.manifestNotFound(chunk.artifactID)
        }

        guard chunk.index < manifest.chunkCount else {
            throw ArtifactTransferError.chunkMissing(index: chunk.index)
        }

        let expectedHash = manifest.chunkHashes[chunk.index]
        let computedHash = sha256(chunk.data)
        guard computedHash == expectedHash else {
            throw ArtifactTransferError.chunkHashMismatch(expected: expectedHash, received: computedHash)
        }

        try await store.saveChunk(chunk)
        logger.debug("Received chunk \(chunk.index)/\(manifest.chunkCount) for \(manifest.name)")

        let allReceived = await verifyComplete(artifactID: chunk.artifactID)
        if allReceived {
            try await finalizeArtifact(artifactID: chunk.artifactID)
        }
    }

    public func buildManifest(from data: Data, name: String, version: String, chunkSize: Int = 4 * 1024 * 1024, metadata: [String: String] = [:]) async throws -> ArtifactManifest {
        let totalChunks = data.count > 0 ? Int(ceil(Double(data.count) / Double(chunkSize))) : 0
        var chunkHashes: [Data] = []

        for i in 0..<totalChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, data.count)
            let chunkData = data[start..<end]
            chunkHashes.append(sha256(Data(chunkData)))
        }

        let manifest = ArtifactManifest(
            artifactID: ArtifactID(),
            name: name,
            version: version,
            chunkSize: chunkSize,
            totalSize: data.count,
            sha256Hash: sha256(data),
            chunkHashes: chunkHashes,
            metadata: metadata
        )

        try await store.saveManifest(manifest)

        for i in 0..<totalChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, data.count)
            let chunkData = Data(data[start..<end])
            let chunk = ArtifactChunk(artifactID: manifest.artifactID, index: i, data: chunkData, sha256Hash: chunkHashes[i])
            try await store.saveChunk(chunk)
        }

        logger.info("Built manifest: \(name) v\(version) (\(totalChunks) chunks, \(data.count) bytes)")
        return manifest
    }

    public func assembleArtifact(artifactID: ArtifactID) async throws -> Data? {
        guard let manifest = await store.getManifest(artifactID: artifactID) else {
            return nil
        }

        var data = Data()
        for i in 0..<manifest.chunkCount {
            guard let chunkData = await store.getChunk(artifactID: artifactID, index: i) else {
                throw ArtifactTransferError.chunkMissing(index: i)
            }
            data.append(chunkData)
        }

        let computedHash = sha256(data)
        guard computedHash == manifest.sha256Hash else {
            throw ArtifactTransferError.manifestHashMismatch
        }

        return data
    }

    public func deleteArtifact(artifactID: ArtifactID) async throws {
        try await store.deleteArtifact(artifactID: artifactID)
        logger.info("Deleted artifact: \(artifactID.rawValue)")
    }

    private func verifyComplete(artifactID: ArtifactID) async -> Bool {
        guard let manifest = await store.getManifest(artifactID: artifactID) else { return false }
        for i in 0..<manifest.chunkCount {
            if await store.getChunk(artifactID: artifactID, index: i) == nil {
                return false
            }
        }
        return true
    }

    private func finalizeArtifact(artifactID: ArtifactID) async throws {
        guard let manifest = await store.getManifest(artifactID: artifactID) else { return }
        guard let data = try await assembleArtifact(artifactID: artifactID) else { return }
        let finalHash = sha256(data)
        guard finalHash == manifest.sha256Hash else {
            throw ArtifactTransferError.manifestHashMismatch
        }
        try await store.markComplete(artifactID: artifactID)
        logger.info("Artifact finalized: \(manifest.name) v\(manifest.version)")
    }

    private func sha256(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
}
