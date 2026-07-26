import Foundation
import os

public actor LocalArtifactStore: ArtifactStore {
    private let baseDirectory: URL
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "ArtifactStore")

    public init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory ?? Self.defaultDirectory()
    }

    public func saveManifest(_ manifest: ArtifactManifest) throws {
        let dir = artifactDirectory(for: manifest.artifactID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let manifestURL = dir.appendingPathComponent("manifest.json")
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL)
    }

    public func saveChunk(_ chunk: ArtifactChunk) throws {
        let dir = artifactDirectory(for: chunk.artifactID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let chunkURL = dir.appendingPathComponent("chunk_\(chunk.index).bin")
        try chunk.data.write(to: chunkURL)
    }

    public func getManifest(artifactID: ArtifactID) -> ArtifactManifest? {
        let manifestURL = artifactDirectory(for: artifactID).appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(ArtifactManifest.self, from: data)
    }

    public func getChunk(artifactID: ArtifactID, index: Int) -> Data? {
        let chunkURL = artifactDirectory(for: artifactID).appendingPathComponent("chunk_\(index).bin")
        return try? Data(contentsOf: chunkURL)
    }

    public func deleteArtifact(artifactID: ArtifactID) throws {
        let dir = artifactDirectory(for: artifactID)
        try FileManager.default.removeItem(at: dir)
    }

    public func listArtifacts() -> [ArtifactManifest] {
        let artifactsDir = baseDirectory.appendingPathComponent("Artifacts")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: artifactsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return contents.compactMap { url in
            let manifestURL = url.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL) else { return nil }
            return try? JSONDecoder().decode(ArtifactManifest.self, from: data)
        }
    }

    public func markComplete(artifactID: ArtifactID) throws {
        let flagURL = artifactDirectory(for: artifactID).appendingPathComponent(".complete")
        try Data().write(to: flagURL)
    }

    public func isComplete(artifactID: ArtifactID) -> Bool {
        let flagURL = artifactDirectory(for: artifactID).appendingPathComponent(".complete")
        return FileManager.default.fileExists(atPath: flagURL.path)
    }

    private func artifactDirectory(for artifactID: ArtifactID) -> URL {
        baseDirectory.appendingPathComponent("Artifacts").appendingPathComponent(artifactID.rawValue.uuidString)
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("ElysiumVanguardFabric")
    }
}
