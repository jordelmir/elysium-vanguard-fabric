import Foundation

// MARK: - Telemetry Snapshot

public struct NodeTelemetrySnapshot: Codable, Sendable {
    public let capturedAtMonotonicNanos: UInt64
    public let cpu: CPUMetrics
    public let memory: MemoryMetrics
    public let disk: DiskMetrics
    public let network: NetworkMetrics
    public let video: VideoMetrics?

    public init(
        capturedAtMonotonicNanos: UInt64,
        cpu: CPUMetrics,
        memory: MemoryMetrics,
        disk: DiskMetrics,
        network: NetworkMetrics,
        video: VideoMetrics? = nil
    ) {
        self.capturedAtMonotonicNanos = capturedAtMonotonicNanos
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.network = network
        self.video = video
    }
}

// MARK: - CPU Metrics

public struct CPUMetrics: Codable, Sendable {
    public let usagePercent: Double
    public let coreCount: Int
    public let loadAverage1m: Double
    public let loadAverage5m: Double
    public let loadAverage15m: Double

    public init(
        usagePercent: Double,
        coreCount: Int,
        loadAverage1m: Double,
        loadAverage5m: Double,
        loadAverage15m: Double
    ) {
        self.usagePercent = usagePercent
        self.coreCount = coreCount
        self.loadAverage1m = loadAverage1m
        self.loadAverage5m = loadAverage5m
        self.loadAverage15m = loadAverage15m
    }
}

// MARK: - Memory Metrics

public struct MemoryMetrics: Codable, Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let availableBytes: UInt64
    public let pressure: MemoryPressure

    public init(
        totalBytes: UInt64,
        usedBytes: UInt64,
        availableBytes: UInt64,
        pressure: MemoryPressure
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.availableBytes = availableBytes
        self.pressure = pressure
    }

    public var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}

public enum MemoryPressure: String, Codable, Sendable {
    case normal
    case warning
    case critical
}

// MARK: - Disk Metrics

public struct DiskMetrics: Codable, Sendable {
    public let totalBytes: UInt64
    public let availableBytes: UInt64
    public let usedBytes: UInt64

    public init(totalBytes: UInt64, availableBytes: UInt64, usedBytes: UInt64) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
        self.usedBytes = usedBytes
    }

    public var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}

// MARK: - Network Metrics

public struct NetworkMetrics: Codable, Sendable {
    public let bytesSent: UInt64
    public let bytesReceived: UInt64
    public let activeConnections: Int
    public let rttMilliseconds: Double?

    public init(
        bytesSent: UInt64,
        bytesReceived: UInt64,
        activeConnections: Int,
        rttMilliseconds: Double? = nil
    ) {
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.activeConnections = activeConnections
        self.rttMilliseconds = rttMilliseconds
    }
}

// MARK: - Video Metrics

public struct VideoMetrics: Codable, Sendable {
    public let framesCaptured: UInt64
    public let framesSent: UInt64
    public let framesDropped: UInt64
    public let currentBitrate: UInt64
    public let encodeP50Nanos: UInt64
    public let encodeP95Nanos: UInt64
    public let decodeP50Nanos: UInt64
    public let decodeP95Nanos: UInt64
    public let keyframeCount: UInt64

    public init(
        framesCaptured: UInt64,
        framesSent: UInt64,
        framesDropped: UInt64,
        currentBitrate: UInt64,
        encodeP50Nanos: UInt64,
        encodeP95Nanos: UInt64,
        decodeP50Nanos: UInt64,
        decodeP95Nanos: UInt64,
        keyframeCount: UInt64
    ) {
        self.framesCaptured = framesCaptured
        self.framesSent = framesSent
        self.framesDropped = framesDropped
        self.currentBitrate = currentBitrate
        self.encodeP50Nanos = encodeP50Nanos
        self.encodeP95Nanos = encodeP95Nanos
        self.decodeP50Nanos = decodeP50Nanos
        self.decodeP95Nanos = decodeP95Nanos
        self.keyframeCount = keyframeCount
    }
}
