import Foundation
import os
import VanguardDomain

public struct RelayChannel: Sendable, Equatable {
    public let channelID: UUID
    public let sourceNodeID: NodeID
    public let targetNodeID: NodeID
    public let allocatedAt: Date
    public var lastActivityAt: Date
    public var bytesForwarded: UInt64
    public var packetsForwarded: UInt64
    public let isActive: Bool

    public init(
        channelID: UUID = UUID(),
        sourceNodeID: NodeID,
        targetNodeID: NodeID,
        allocatedAt: Date = Date(),
        lastActivityAt: Date = Date(),
        bytesForwarded: UInt64 = 0,
        packetsForwarded: UInt64 = 0,
        isActive: Bool = true
    ) {
        self.channelID = channelID
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.allocatedAt = allocatedAt
        self.lastActivityAt = lastActivityAt
        self.bytesForwarded = bytesForwarded
        self.packetsForwarded = packetsForwarded
        self.isActive = isActive
    }
}

public struct RelayForwardResult: Sendable, Equatable {
    public let channelID: UUID
    public let delivered: Bool
    public let latencyMs: Double

    public init(channelID: UUID, delivered: Bool, latencyMs: Double = 0) {
        self.channelID = channelID
        self.delivered = delivered
        self.latencyMs = latencyMs
    }
}

public actor RelayService {
    private var channels: [UUID: RelayChannel] = [:]
    private var nodeToChannels: [NodeID: Set<UUID>] = [:]
    private var maxBandwidthMbps: Double
    private var activeBandwidthMbps: Double = 0
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "Relay")

    public init(maxBandwidthMbps: Double = 100) {
        self.maxBandwidthMbps = maxBandwidthMbps
    }

    public func allocateChannel(
        sourceNodeID: NodeID,
        targetNodeID: NodeID
    ) -> RelayChannel {
        let channel = RelayChannel(
            sourceNodeID: sourceNodeID,
            targetNodeID: targetNodeID
        )
        channels[channel.channelID] = channel

        var sourceChannels = nodeToChannels[sourceNodeID] ?? Set<UUID>()
        sourceChannels.insert(channel.channelID)
        nodeToChannels[sourceNodeID] = sourceChannels

        var targetChannels = nodeToChannels[targetNodeID] ?? Set<UUID>()
        targetChannels.insert(channel.channelID)
        nodeToChannels[targetNodeID] = targetChannels

        logger.info("Relay channel allocated: \(channel.channelID.uuidString) (\(sourceNodeID.rawValue.uuidString) → \(targetNodeID.rawValue.uuidString))")
        return channel
    }

    public func forwardPacket(
        channelID: UUID,
        data: Data,
        from sourceNodeID: NodeID
    ) -> RelayForwardResult? {
        guard var channel = channels[channelID], channel.isActive else {
            return nil
        }

        let start = Date()
        channel = RelayChannel(
            channelID: channel.channelID,
            sourceNodeID: channel.sourceNodeID,
            targetNodeID: channel.targetNodeID,
            allocatedAt: channel.allocatedAt,
            lastActivityAt: Date(),
            bytesForwarded: channel.bytesForwarded + UInt64(data.count),
            packetsForwarded: channel.packetsForwarded + 1,
            isActive: channel.isActive
        )
        channels[channelID] = channel

        let latency = Date().timeIntervalSince(start) * 1000
        return RelayForwardResult(
            channelID: channelID,
            delivered: true,
            latencyMs: latency
        )
    }

    public func releaseChannel(_ channelID: UUID) {
        guard let channel = channels[channelID] else { return }
        channels.removeValue(forKey: channelID)
        nodeToChannels[channel.sourceNodeID]?.remove(channelID)
        nodeToChannels[channel.targetNodeID]?.remove(channelID)
        logger.info("Relay channel released: \(channelID.uuidString)")
    }

    public func channelsForNode(_ nodeID: NodeID) -> [RelayChannel] {
        let channelIDs = nodeToChannels[nodeID] ?? Set<UUID>()
        return channelIDs.compactMap { channels[$0] }
    }

    public func channel(_ channelID: UUID) -> RelayChannel? {
        channels[channelID]
    }

    public func totalChannels() -> Int {
        channels.count
    }

    public func totalBytesForwarded() -> UInt64 {
        channels.values.reduce(0) { $0 + $1.bytesForwarded }
    }

    public func totalPacketsForwarded() -> UInt64 {
        channels.values.reduce(0) { $0 + $1.packetsForwarded }
    }

    public func cleanupInactive(maxAge: TimeInterval = 300) -> [UUID] {
        let now = Date()
        let inactive = channels.filter { channel in
            !channel.value.isActive || now.timeIntervalSince(channel.value.lastActivityAt) > maxAge
        }
        let inactiveIDs = Array(inactive.keys)
        for id in inactiveIDs {
            releaseChannel(id)
        }
        if !inactiveIDs.isEmpty {
            logger.info("Cleaned up \(inactiveIDs.count) inactive relay channels")
        }
        return inactiveIDs
    }

    public func updateMaxBandwidth(_ mbps: Double) {
        maxBandwidthMbps = mbps
    }

    public func availableBandwidthMbps() -> Double {
        max(0, maxBandwidthMbps - activeBandwidthMbps)
    }
}
