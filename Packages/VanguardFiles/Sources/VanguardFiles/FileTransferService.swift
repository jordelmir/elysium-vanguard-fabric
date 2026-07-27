import Foundation
import CryptoKit
import VanguardDomain
import VanguardProtocol

public struct FileTransferManifest: Codable, Sendable {
    public let fileID: UUID
    public let fileName: String
    public let fileSize: UInt64
    public let sha256Hash: Data
    public let chunkSize: Int
    public let totalChunks: Int
    public let mimeType: String

    public init(fileName: String, fileSize: UInt64, sha256Hash: Data, chunkSize: Int = 65536) {
        self.fileID = UUID()
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256Hash = sha256Hash
        self.chunkSize = chunkSize
        self.totalChunks = Int(ceil(Double(fileSize) / Double(chunkSize)))
        self.mimeType = "application/octet-stream"
    }
}

public struct FileTransferChunk: Codable, Sendable {
    public let fileID: UUID
    public let chunkIndex: Int
    public let data: Data
    public let isLast: Bool
}

public struct FileTransferProgress: Sendable {
    public let fileID: UUID
    public let bytesTransferred: UInt64
    public let totalBytes: UInt64
    public var percent: Double {
        totalBytes > 0 ? Double(bytesTransferred) / Double(totalBytes) * 100 : 0
    }
}

public actor FileTransferService {
    private var pendingTransfers: [UUID: FileTransferManifest] = [:]
    private var receivedFiles: [UUID: (manifest: FileTransferManifest, data: Data)] = [:]
    private var progressCallbacks: [UUID: (FileTransferProgress) -> Void] = [:]

    public init() {}

    public func prepareSend(url: URL) throws -> FileTransferManifest {
        let data = try Data(contentsOf: url)
        let hash = Data(SHA256.hash(data: data))
        let manifest = FileTransferManifest(
            fileName: url.lastPathComponent,
            fileSize: UInt64(data.count),
            sha256Hash: hash
        )
        pendingTransfers[manifest.fileID] = manifest
        return manifest
    }

    public func getChunk(fileID: UUID, index: Int, sourceData: Data) -> FileTransferChunk? {
        guard let manifest = pendingTransfers[fileID] else { return nil }
        let start = index * manifest.chunkSize
        let end = min(start + manifest.chunkSize, sourceData.count)
        guard start < sourceData.count else { return nil }
        let chunkData = sourceData[start..<end]
        return FileTransferChunk(fileID: fileID, chunkIndex: index, data: chunkData, isLast: end >= sourceData.count)
    }

    public func receiveChunk(_ chunk: FileTransferChunk) -> FileTransferProgress? {
        if receivedFiles[chunk.fileID] == nil {
            receivedFiles[chunk.fileID] = (manifest: FileTransferManifest(fileName: "", fileSize: 0, sha256Hash: Data()), data: Data())
        }
        receivedFiles[chunk.fileID]?.data.append(chunk.data)
        let progress = FileTransferProgress(
            fileID: chunk.fileID,
            bytesTransferred: UInt64(receivedFiles[chunk.fileID]?.data.count ?? 0),
            totalBytes: 0
        )
        return progress
    }

    public func completeTransfer(fileID: UUID) -> (Data, String)? {
        guard let file = receivedFiles.removeValue(forKey: fileID) else { return nil }
        pendingTransfers.removeValue(forKey: fileID)
        return (file.data, file.manifest.fileName)
    }

    public func cancelTransfer(fileID: UUID) {
        pendingTransfers.removeValue(forKey: fileID)
        receivedFiles.removeValue(forKey: fileID)
    }

    public func verifyIntegrity(fileID: UUID, expectedHash: Data) -> Bool {
        guard let file = receivedFiles[fileID] else { return false }
        let actualHash = Data(SHA256.hash(data: file.data))
        return actualHash == expectedHash
    }
}
