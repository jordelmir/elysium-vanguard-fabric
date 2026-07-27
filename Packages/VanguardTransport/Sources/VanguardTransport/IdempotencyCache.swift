import Foundation

public final class IdempotencyCache: @unchecked Sendable {
    private let lock = NSLock()
    private var processedIDs: [UInt64: Date] = [:]
    private let maxAge: TimeInterval
    private let maxEntries: Int

    public init(maxAge: TimeInterval = 300, maxEntries: Int = 10000) {
        self.maxAge = maxAge
        self.maxEntries = maxEntries
    }

    public func isDuplicate(operationID: UInt64) -> Bool {
        lock.withLock {
            prune()
            return processedIDs[operationID] != nil
        }
    }

    public func markProcessed(operationID: UInt64) {
        lock.withLock {
            processedIDs[operationID] = Date()
            prune()
        }
    }

    public func reset() {
        lock.withLock { processedIDs.removeAll() }
    }

    private func prune() {
        let now = Date()
        processedIDs = processedIDs.filter { now.timeIntervalSince($0.value) < maxAge }
        if processedIDs.count > maxEntries {
            let sorted = processedIDs.sorted { $0.value < $1.value }
            let toRemove = sorted.prefix(processedIDs.count - maxEntries)
            for entry in toRemove {
                processedIDs.removeValue(forKey: entry.key)
            }
        }
    }
}
