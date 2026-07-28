import Testing
import Foundation
import CryptoKit
@testable import VanguardFiles

@Suite("FileTransferService")
struct FileTransferServiceTests {

    @Test("Prepare send creates manifest with correct fields")
    func prepareSend() async throws {
        let service = FileTransferService()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).bin")
        let payload = Data(repeating: 0xAB, count: 200000)
        try payload.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let manifest = try await service.prepareSend(url: tmp)
        #expect(manifest.fileName == tmp.lastPathComponent)
        #expect(manifest.fileSize == 200000)
        #expect(manifest.totalChunks == 4)
        #expect(manifest.chunkSize == 65536)
        #expect(manifest.sha256Hash.count == 32)
    }

    @Test("Get chunk returns correct slices")
    func getChunk() async throws {
        let service = FileTransferService()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).bin")
        let payload = Data(repeating: 0xCC, count: 100)
        try payload.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let manifest = try await service.prepareSend(url: tmp)
        let chunk0 = await service.getChunk(fileID: manifest.fileID, index: 0, sourceData: payload)
        #expect(chunk0 != nil)
        #expect(chunk0?.data.count == 100)
        #expect(chunk0?.isLast == true)

        let chunk1 = await service.getChunk(fileID: manifest.fileID, index: 1, sourceData: payload)
        #expect(chunk1 == nil)
    }

    @Test("Receive chunks and complete transfer")
    func receiveAndComplete() async throws {
        let service = FileTransferService()
        let fileID = UUID()
        let payload = Data(repeating: 0xDD, count: 50)
        let chunk = FileTransferChunk(fileID: fileID, chunkIndex: 0, data: payload, isLast: true)

        let progress = await service.receiveChunk(chunk)
        #expect(progress?.bytesTransferred == 50)

        let result = await service.completeTransfer(fileID: fileID)
        #expect(result?.0 == payload)
    }

    @Test("Cancel transfer removes state")
    func cancelTransfer() async {
        let service = FileTransferService()
        let fileID = UUID()
        let chunk = FileTransferChunk(fileID: fileID, chunkIndex: 0, data: Data([1, 2, 3]), isLast: true)
        _ = await service.receiveChunk(chunk)
        await service.cancelTransfer(fileID: fileID)
        let result = await service.completeTransfer(fileID: fileID)
        #expect(result == nil)
    }

    @Test("Verify integrity matches SHA-256")
    func verifyIntegrity() async throws {
        let service = FileTransferService()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).bin")
        let payload = Data("integrity check".utf8)
        try payload.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let manifest = try await service.prepareSend(url: tmp)
        let chunk = FileTransferChunk(fileID: manifest.fileID, chunkIndex: 0, data: payload, isLast: true)
        _ = await service.receiveChunk(chunk)

        let expectedHash = Data(SHA256.hash(data: payload))
        let valid = await service.verifyIntegrity(fileID: manifest.fileID, expectedHash: expectedHash)
        #expect(valid == true)

        let badHash = Data([0x00, 0x01, 0x02])
        let invalid = await service.verifyIntegrity(fileID: manifest.fileID, expectedHash: badHash)
        #expect(invalid == false)
    }
}
