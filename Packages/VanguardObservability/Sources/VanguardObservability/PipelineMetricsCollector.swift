import Foundation

public struct PipelineMetrics: Sendable {
    public var framesCaptured: UInt64 = 0
    public var framesEncoded: UInt64 = 0
    public var framesDecoded: UInt64 = 0
    public var framesRendered: UInt64 = 0
    public var framesDropped: UInt64 = 0
    public var bytesTransferred: UInt64 = 0
    public var currentBitrate: Double = 0
    public var smoothedRTT: Double = 0
    public var jitter: Double = 0
    public var averageEncodeTimeMs: Double = 0
    public var averageDecodeTimeMs: Double = 0
    public var uptimeSeconds: TimeInterval = 0
    public var connectedNodes: Int = 0
    public var activeSessions: Int = 0
    public var activeJobs: Int = 0
    public var memoryUsageBytes: UInt64 = 0

    public var fps: Double {
        guard uptimeSeconds > 0 else { return 0 }
        return Double(framesRendered) / uptimeSeconds
    }

    public var effectiveBandwidthMbps: Double {
        guard uptimeSeconds > 0 else { return 0 }
        return Double(bytesTransferred) * 8.0 / uptimeSeconds / 1_000_000.0
    }
}

public actor PipelineMetricsCollector {
    private var metrics = PipelineMetrics()
    private var startTime = Date()
    private var encodeTimes: [Double] = []
    private var decodeTimes: [Double] = []
    private let maxSamples = 100

    public init() {}

    public func recordFrameCaptured() { metrics.framesCaptured += 1 }
    public func recordFrameEncoded() { metrics.framesEncoded += 1 }
    public func recordFrameDecoded() { metrics.framesDecoded += 1 }
    public func recordFrameRendered() { metrics.framesRendered += 1 }
    public func recordFrameDropped() { metrics.framesDropped += 1 }

    public func recordBytesTransferred(_ bytes: Int) {
        metrics.bytesTransferred += UInt64(bytes)
    }

    public func recordEncodeTime(_ ms: Double) {
        encodeTimes.append(ms)
        if encodeTimes.count > maxSamples { encodeTimes.removeFirst() }
        metrics.averageEncodeTimeMs = encodeTimes.reduce(0, +) / Double(encodeTimes.count)
    }

    public func recordDecodeTime(_ ms: Double) {
        decodeTimes.append(ms)
        if decodeTimes.count > maxSamples { decodeTimes.removeFirst() }
        metrics.averageDecodeTimeMs = decodeTimes.reduce(0, +) / Double(decodeTimes.count)
    }

    public func updateNetworkStats(rtt: Double, jitter: Double, bitrate: Double) {
        metrics.smoothedRTT = rtt
        metrics.jitter = jitter
        metrics.currentBitrate = bitrate
    }

    public func updateCounts(connectedNodes: Int, activeSessions: Int, activeJobs: Int) {
        metrics.connectedNodes = connectedNodes
        metrics.activeSessions = activeSessions
        metrics.activeJobs = activeJobs
    }

    public func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            metrics.memoryUsageBytes = info.resident_size
        }
    }

    public func snapshot() -> PipelineMetrics {
        var snap = metrics
        snap.uptimeSeconds = Date().timeIntervalSince(startTime)
        return snap
    }

    public func reset() {
        metrics = PipelineMetrics()
        startTime = Date()
        encodeTimes.removeAll()
        decodeTimes.removeAll()
    }
}
