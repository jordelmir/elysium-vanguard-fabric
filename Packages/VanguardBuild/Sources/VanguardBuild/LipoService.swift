import Foundation
import os
import CryptoKit
import VanguardDomain

public struct LipoResult: Sendable, Equatable {
    public let outputPath: String
    public let architectures: [CPUArchitecture]
    public let sizeBytes: UInt64
    public let sha256: Data
    public let duration: TimeInterval

    public init(outputPath: String, architectures: [CPUArchitecture], sizeBytes: UInt64, sha256: Data, duration: TimeInterval) {
        self.outputPath = outputPath
        self.architectures = architectures
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.duration = duration
    }
}

public actor LipoService {
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Lipo")

    public init() {}

    public func combine(
        inputPaths: [String],
        outputPath: String
    ) async throws -> LipoResult {
        let start = Date()

        guard inputPaths.count >= 2 else {
            throw LipoError.insufficientInputs
        }

        for path in inputPaths {
            guard FileManager.default.fileExists(atPath: path) else {
                throw LipoError.inputNotFound(path)
            }
        }

        let outputDir = (outputPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-create", "-output", outputPath] + inputPaths

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw LipoError.executionFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: stderr, encoding: .utf8) ?? "Unknown error"
            throw LipoError.lipoFailed(msg)
        }

        guard FileManager.default.fileExists(atPath: outputPath) else {
            throw LipoError.outputNotFound
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let digest = SHA256.hash(data: data)
        let duration = Date().timeIntervalSince(start)

        let archs = try await extractArchitectures(from: outputPath)

        let result = LipoResult(
            outputPath: outputPath,
            architectures: archs,
            sizeBytes: UInt64(data.count),
            sha256: Data(digest),
            duration: duration
        )

        logger.info("Universal binary created: \(outputPath) (\(archs.count) archs, \(data.count) bytes)")
        return result
    }

    public func extractArchitectures(from binaryPath: String) async throws -> [CPUArchitecture] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-info", binaryPath]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        process.waitUntilExit()

        let output = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let info = String(data: output, encoding: .utf8) else { return [] }

        var archs: [CPUArchitecture] = []
        if info.contains("arm64") { archs.append(.arm64) }
        if info.contains("x86_64") { archs.append(.x86_64) }
        return archs
    }

    public func verifyFatBinary(_ path: String, expectedArchs: [CPUArchitecture]) async throws -> Bool {
        let archs = try await extractArchitectures(from: path)
        return Set(archs) == Set(expectedArchs)
    }
}

public enum LipoError: Error, Sendable {
    case insufficientInputs
    case inputNotFound(String)
    case outputNotFound
    case executionFailed(String)
    case lipoFailed(String)
}

extension LipoError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .insufficientInputs: return "At least 2 input binaries required"
        case .inputNotFound(let path): return "Input binary not found: \(path)"
        case .outputNotFound: return "Output binary not created"
        case .executionFailed(let reason): return "Process execution failed: \(reason)"
        case .lipoFailed(let reason): return "lipo failed: \(reason)"
        }
    }
}
