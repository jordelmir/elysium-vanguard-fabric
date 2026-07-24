import Foundation
import AppKit
import os.log
import VanguardDomain

public actor ClipboardService {
    private var lastChangeCount: Int = 0
    private var isWatching = false
    private var watchTask: Task<Void, Never>?
    private let maxClipboardSize: Int
    private let allowedTypes: Set<ClipboardContentType>
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Clipboard")

    public var onClipboardChanged: ((ClipboardContent) -> Void)?

    public init(maxClipboardSize: Int = 10 * 1024 * 1024, allowedTypes: Set<ClipboardContentType> = [.text, .image]) {
        self.maxClipboardSize = maxClipboardSize
        self.allowedTypes = allowedTypes
    }

    public func startWatching() {
        guard !isWatching else { return }
        isWatching = true
        lastChangeCount = NSPasteboard.general.changeCount
        watchTask = Task { [weak self] in
            while !Task.isCancelled, let self = self {
                try? await Task.sleep(for: .milliseconds(500))
                await self.checkClipboard()
            }
        }
        logger.info("Clipboard watching started")
    }

    public func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
        isWatching = false
        logger.info("Clipboard watching stopped")
    }

    public func getClipboardContent() -> ClipboardContent? {
        let pasteboard = NSPasteboard.general
        if let imageData = pasteboard.data(forType: .tiff) {
            return ClipboardContent(type: .image, data: imageData, timestamp: Date(), sourceNodeID: nil)
        }
        if let stringData = pasteboard.string(forType: .string)?.data(using: .utf8) {
            return ClipboardContent(type: .text, data: stringData, timestamp: Date(), sourceNodeID: nil)
        }
        return nil
    }

    public func setClipboardContent(_ content: ClipboardContent) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch content.type {
        case .text, .richText:
            if let string = String(data: content.data, encoding: .utf8) {
                pasteboard.setString(string, forType: .string)
                logger.info("Set clipboard text: \(string.prefix(50))...")
            }
        case .image:
            pasteboard.setData(content.data, forType: .tiff)
            logger.info("Set clipboard image: \(content.data.count) bytes")
        case .fileURL:
            if let url = URL(dataRepresentation: content.data, relativeTo: nil) {
                pasteboard.writeObjects([url as NSURL])
                logger.info("Set clipboard file: \(url.path)")
            }
        }
        lastChangeCount = pasteboard.changeCount
    }

    public func syncFromRemote(_ data: Data, type: ClipboardContentType) {
        let content = ClipboardContent(type: type, data: data, timestamp: Date(), sourceNodeID: nil)
        setClipboardContent(content)
        logger.info("Synced remote clipboard content of type \(type.rawValue)")
    }

    public func getFilteredContent(maxSize: Int? = nil) -> ClipboardContent? {
        guard let content = getClipboardContent() else { return nil }
        guard allowedTypes.contains(content.type) else {
            logger.debug("Clipboard type \(content.type.rawValue) not in allowed types")
            return nil
        }
        let limit = maxSize ?? maxClipboardSize
        guard content.data.count <= limit else {
            logger.warning("Clipboard content size \(content.data.count) exceeds limit \(limit)")
            return nil
        }
        return content
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        if let content = getFilteredContent() {
            logger.info("Clipboard changed, type: \(content.type.rawValue), size: \(content.data.count)")
            onClipboardChanged?(content)
        }
    }
}

public struct ClipboardContent: Sendable {
    public let type: ClipboardContentType
    public let data: Data
    public let timestamp: Date
    public let sourceNodeID: NodeID?

    public init(type: ClipboardContentType, data: Data, timestamp: Date = Date(), sourceNodeID: NodeID? = nil) {
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self.sourceNodeID = sourceNodeID
    }
}

public enum ClipboardContentType: String, Codable, Sendable {
    case text
    case image
    case richText
    case fileURL
}
