import Foundation
import VanguardDomain

public final class MacTelemetryCollector: TelemetryCollector, @unchecked Sendable {
    private let lock = NSLock()
    private var _isCollecting = false
    private var _snapshotContinuation: AsyncThrowingStream<NodeTelemetrySnapshot, Error>.Continuation?
    private var collectTask: Task<Void, Never>?

    public init() {}

    public var snapshots: AsyncThrowingStream<NodeTelemetrySnapshot, Error> {
        AsyncThrowingStream { continuation in
            self.lock.withLock {
                self._snapshotContinuation = continuation
            }
        }
    }

    public func collectSnapshot() async throws -> NodeTelemetrySnapshot {
        let processInfo = ProcessInfo.processInfo

        let physicalMemory = processInfo.physicalMemory
        let cpuCount = processInfo.activeProcessorCount

        var cpuUsage: Double = 0
        var ramUsed: UInt64 = 0

        let host = mach_host_self()
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = host_cpu_load_info_data_t()

        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &size)
            }
        }

        if result == KERN_SUCCESS {
            let total = Double(hostInfo.cpu_ticks.0 + hostInfo.cpu_ticks.1 + hostInfo.cpu_ticks.2 + hostInfo.cpu_ticks.3)
            let idle = Double(hostInfo.cpu_ticks.3)
            cpuUsage = total > 0 ? ((total - idle) / total) * 100.0 : 0
        }

        var vmStats = vm_statistics64()
        var vmSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmSize)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &vmSize)
            }
        }

        var availableBytes: UInt64 = 0
        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(sysconf(Int32(_SC_PAGESIZE)))
            ramUsed = UInt64(vmStats.active_count + vmStats.wire_count) * pageSize
            availableBytes = UInt64(vmStats.free_count) * pageSize
        }

        let pressure: MemoryPressure
        let usageRatio = physicalMemory > 0 ? Double(ramUsed) / Double(physicalMemory) : 0
        if usageRatio > 0.9 {
            pressure = .critical
        } else if usageRatio > 0.7 {
            pressure = .warning
        } else {
            pressure = .normal
        }

        let diskTotal: UInt64
        let diskAvailable: UInt64
        let diskUsed: UInt64

        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
            )
            diskTotal = UInt64(values.volumeTotalCapacity ?? 0)
            diskAvailable = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            diskUsed = diskTotal > diskAvailable ? diskTotal - diskAvailable : 0
        } catch {
            diskTotal = 0
            diskAvailable = 0
            diskUsed = 0
        }

        return NodeTelemetrySnapshot(
            capturedAtMonotonicNanos: UInt64(ProcessInfo.processInfo.systemUptime * 1_000_000_000),
            cpu: CPUMetrics(usagePercent: cpuUsage, coreCount: cpuCount, loadAverage1m: 0, loadAverage5m: 0, loadAverage15m: 0),
            memory: MemoryMetrics(totalBytes: physicalMemory, usedBytes: ramUsed, availableBytes: availableBytes, pressure: pressure),
            disk: DiskMetrics(totalBytes: diskTotal, availableBytes: diskAvailable, usedBytes: diskUsed),
            network: NetworkMetrics(bytesSent: 0, bytesReceived: 0, activeConnections: 0),
            video: nil
        )
    }

    public func startCollecting(interval: TimeInterval) async throws {
        lock.withLock {
            guard !_isCollecting else { return }
            _isCollecting = true
        }

        collectTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                do {
                    let snapshot = try await self.collectSnapshot()
                    self.lock.withLock {
                        self._snapshotContinuation?.yield(snapshot)
                    }
                } catch {
                    self.lock.withLock {
                        self._snapshotContinuation?.finish(throwing: error)
                    }
                    break
                }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopCollecting() async {
        lock.withLock {
            _isCollecting = false
        }
        collectTask?.cancel()
        collectTask = nil
        lock.withLock {
            _snapshotContinuation?.finish()
            _snapshotContinuation = nil
        }
    }
}
