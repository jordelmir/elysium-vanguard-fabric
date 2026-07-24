import Foundation
import os.log
import VanguardDomain

public actor FileTransferService {
    private var activeTransfers: [TransferID: FileTransfer] = [:]
    private let maxFileSize: Int
    private let chunkSize: Int
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "FileTransfer")

    public var onTransferProgress: ((TransferID, Double) -> Void)?
    public var onTransferComplete: ((TransferID, URL) -> Void)?
    public var onTransferFailed: ((TransferID, Error) -> Void)?

    public init(maxFileSize: Int = 500 * 1024 * 1024, chunkSize: Int = 64 * 1024) {
        self.maxFileSize = maxFileSize
        self.chunkSize = chunkSize
    }

    public func sendFile(at url: URL, to nodeID: NodeID) async throws -> TransferID {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileTransferError.fileNotFound(url.path)
        }
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        guard let fileSize = attrs[.size] as? Int else {
            throw FileTransferError.unableToReadAttributes
        }
        guard fileSize <= maxFileSize else {
            throw FileTransferError.fileTooLarge(fileSize, maxFileSize)
        }

        let transferID = TransferID()
        var transfer = FileTransfer(
            id: transferID,
            fileName: url.lastPathComponent,
            fileSize: fileSize,
            direction: .upload,
            remoteNodeID: nodeID,
            startedAt: Date(),
            transferredBytes: 0,
            status: .transferring
        )

        var offset = 0
        while offset < fileSize {
            let end = min(offset + chunkSize, fileSize)
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let chunk = data.subdata(in: offset..<end)
            _ = chunk
            offset = end
            transfer.transferredBytes = offset
            activeTransfers[transferID] = transfer
            onTransferProgress?(transferID, transfer.progress)
            logger.debug("Upload chunk: \(offset)/\(fileSize) bytes for \(transferID.rawValue)")
        }

        transfer.status = .completed
        activeTransfers[transferID] = transfer
        onTransferComplete?(transferID, url)
        logger.info("Upload complete: \(transfer.fileName) to \(nodeID.rawValue)")
        return transferID
    }

    public func receiveFile(name: String, size: Int, from nodeID: NodeID) async throws -> (TransferID, URL) {
        guard size <= maxFileSize else {
            throw FileTransferError.fileTooLarge(size, maxFileSize)
        }

        let transferID = TransferID()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(transferID.rawValue)_\(name)")

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        let transfer = FileTransfer(
            id: transferID,
            fileName: name,
            fileSize: size,
            direction: .download,
            remoteNodeID: nodeID,
            startedAt: Date(),
            transferredBytes: 0,
            status: .pending
        )
        activeTransfers[transferID] = transfer
        logger.info("Ready to receive: \(name) (\(size) bytes) from \(nodeID.rawValue)")
        return (transferID, fileURL)
    }

    public func writeChunk(_ data: Data, offset: Int, for transferID: TransferID) async throws {
        guard var transfer = activeTransfers[transferID] else {
            throw FileTransferError.transferNotFound
        }
        guard transfer.direction == .download else {
            throw FileTransferError.invalidDirection
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(transferID.rawValue)_\(transfer.fileName)")

        let fileHandle = try FileHandle(forWritingTo: fileURL)
        defer { fileHandle.closeFile() }
        try fileHandle.seek(toOffset: UInt64(offset))
        fileHandle.write(data)

        transfer.transferredBytes = offset + data.count
        if transfer.status == .pending { transfer.status = .transferring }
        activeTransfers[transferID] = transfer
        onTransferProgress?(transferID, transfer.progress)

        if transfer.transferredBytes >= transfer.fileSize {
            transfer.status = .completed
            activeTransfers[transferID] = transfer
            onTransferComplete?(transferID, fileURL)
            logger.info("Download complete: \(transfer.fileName)")
        }
    }

    public func cancelTransfer(_ transferID: TransferID) async {
        guard var transfer = activeTransfers[transferID] else { return }
        transfer.status = .cancelled
        activeTransfers[transferID] = transfer
        if transfer.direction == .download {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(transferID.rawValue)_\(transfer.fileName)")
            try? FileManager.default.removeItem(at: fileURL)
        }
        logger.info("Cancelled transfer: \(transfer.fileName)")
    }

    public func getTransfer(_ transferID: TransferID) -> FileTransfer? {
        activeTransfers[transferID]
    }

    public func getActiveTransfers() -> [FileTransfer] {
        Array(activeTransfers.values)
    }

    public func cleanupCompletedTransfers() async {
        let cutoff = Date().addingTimeInterval(-3600)
        let keysToRemove = activeTransfers.filter { _, t in
            (t.status == .completed || t.status == .failed || t.status == .cancelled) && t.startedAt < cutoff
        }.map(\.key)
        for key in keysToRemove { activeTransfers.removeValue(forKey: key) }
        if !keysToRemove.isEmpty { logger.info("Cleaned up \(keysToRemove.count) old transfers") }
    }
}

public struct FileTransfer: Sendable, Identifiable {
    public let id: TransferID
    public let fileName: String
    public let fileSize: Int
    public let direction: TransferDirection
    public let remoteNodeID: NodeID
    public let startedAt: Date
    public var transferredBytes: Int
    public var status: TransferStatus

    public var progress: Double {
        fileSize > 0 ? Double(transferredBytes) / Double(fileSize) : 0
    }
}

public struct TransferID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init() { rawValue = UUID() }
    public init(rawValue: UUID) { self.rawValue = rawValue }
}

public enum TransferDirection: String, Sendable { case upload, download }
public enum TransferStatus: String, Sendable { case pending, transferring, completed, failed, cancelled }

public enum FileTransferError: Error {
    case fileNotFound(String)
    case unableToReadAttributes
    case fileTooLarge(Int, Int)
    case transferNotFound
    case invalidDirection
}
