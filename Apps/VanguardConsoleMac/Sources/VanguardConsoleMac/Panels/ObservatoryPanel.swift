import SwiftUI
import VanguardUI
import VanguardObservability

struct ObservatoryPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var metrics = ObservatoryMetrics()
    @State private var refreshTask: Task<Void, Never>?
    @State private var isLive = false

    struct ObservatoryMetrics {
        var uptime: TimeInterval = 0
        var framesCaptured: UInt64 = 0
        var framesEncoded: UInt64 = 0
        var framesDecoded: UInt64 = 0
        var framesRendered: UInt64 = 0
        var framesDropped: UInt64 = 0
        var fps: Double = 0
        var bitrate: Double = 0
        var rtt: Double = 0
        var jitter: Double = 0
        var bandwidth: Double = 0
        var encodeTimeMs: Double = 0
        var decodeTimeMs: Double = 0
        var memoryUsage: UInt64 = 0
        var cpuLoad: Double = 0
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    connectionSection
                    mediaSection
                    networkSection
                    performanceSection
                    systemSection
                }
                .padding(DS.Spacing.md)
            }
        }
        .onAppear { startLiveUpdates() }
        .onDisappear { stopLiveUpdates() }
    }

    private var panelHeader: some View {
        HStack {
            Label("OBSERVATORY", systemImage: "gauge.with.dots.needle.67percent")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.info)
            Spacer()
            if isLive {
                HStack(spacing: DS.Spacing.xs) {
                    Circle().fill(DS.Colors.error)
                        .frame(width: 6, height: 6)
                        .opacity(blinkOpacity)
                    Text("LIVE")
                        .font(DS.Typography.micro)
                        .foregroundColor(DS.Colors.error)
                }
            }
            Button {
                isLive.toggle()
                if isLive { startLiveUpdates() } else { stopLiveUpdates() }
            } label: {
                Text(isLive ? "Stop" : "Start")
                    .font(DS.Typography.caption)
                    .foregroundColor(isLive ? DS.Colors.error : DS.Colors.success)
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
    }

    @State private var blinkOpacity: Double = 1.0

    private var connectionSection: some View {
        metricSection(title: "CONNECTION", icon: "network") {
            metricRow(label: "Connected Nodes", value: "\(state.discoveredNodes.filter { $0.status == .online }.count)")
            metricRow(label: "Active Sessions", value: "\(state.terminalSessions.filter { $0.isActive }.count)")
            metricRow(label: "Active Jobs", value: "\(state.activeJobs.filter { !$0.state.isTerminal }.count)")
            metricRow(label: "RTT", value: "\(String(format: "%.1f", metrics.rtt))ms", color: metrics.rtt < 50 ? DS.Colors.success : DS.Colors.warning)
            metricRow(label: "Jitter", value: "\(String(format: "%.1f", metrics.jitter))ms", color: metrics.jitter < 10 ? DS.Colors.success : DS.Colors.warning)
        }
    }

    private var mediaSection: some View {
        metricSection(title: "MEDIA PIPELINE", icon: "film") {
            metricRow(label: "FPS", value: "\(String(format: "%.1f", metrics.fps))", color: metrics.fps >= 30 ? DS.Colors.success : DS.Colors.warning)
            metricRow(label: "Bitrate", value: "\(String(format: "%.2f", metrics.bitrate / 1_000_000)) Mbps")
            metricRow(label: "Frames Captured", value: "\(metrics.framesCaptured)")
            metricRow(label: "Frames Encoded", value: "\(metrics.framesEncoded)")
            metricRow(label: "Frames Decoded", value: "\(metrics.framesDecoded)")
            metricRow(label: "Frames Rendered", value: "\(metrics.framesRendered)")
            metricRow(label: "Frames Dropped", value: "\(metrics.framesDropped)", color: metrics.framesDropped > 0 ? DS.Colors.error : DS.Colors.success)
            metricRow(label: "Encode Time", value: "\(String(format: "%.2f", metrics.encodeTimeMs))ms")
            metricRow(label: "Decode Time", value: "\(String(format: "%.2f", metrics.decodeTimeMs))ms")
        }
    }

    private var networkSection: some View {
        metricSection(title: "NETWORK", icon: "wifi") {
            metricRow(label: "Bandwidth", value: "\(String(format: "%.2f", metrics.bandwidth)) Mbps")
            metricRow(label: "Bytes Transferred", value: formatBytes(metrics.memoryUsage))
        }
    }

    private var performanceSection: some View {
        metricSection(title: "PERFORMANCE", icon: "speedometer") {
            metricRow(label: "Uptime", value: formatDuration(metrics.uptime))
            metricRow(label: "CPU Load", value: "\(String(format: "%.1f", metrics.cpuLoad * 100))%", color: metrics.cpuLoad < 0.8 ? DS.Colors.success : DS.Colors.warning)
            metricRow(label: "Memory", value: formatBytes(metrics.memoryUsage))
        }
    }

    private var systemSection: some View {
        metricSection(title: "SYSTEM", icon: "desktopcomputer") {
            let localMetrics = ConsoleAppState.gatherLocalSystemMetrics()
            metricRow(label: "CPU Cores", value: "\(localMetrics.physicalCPUCount)")
            metricRow(label: "Total RAM", value: formatBytes(localMetrics.totalMemoryBytes))
            metricRow(label: "Available RAM", value: formatBytes(localMetrics.availableMemoryBytes))
            metricRow(label: "Storage", value: formatBytes(localMetrics.totalStorageBytes))
            metricRow(label: "Available Storage", value: formatBytes(localMetrics.availableStorageBytes))
            metricRow(label: "Memory Pressure", value: "\(String(format: "%.1f", localMetrics.memoryPressure * 100))%", color: localMetrics.memoryPressure < 0.8 ? DS.Colors.success : DS.Colors.warning)
        }
    }

    private func metricSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(DS.Colors.accent)
                Text(title).font(DS.Typography.micro).foregroundColor(DS.Colors.accent)
            }
            VStack(spacing: DS.Spacing.xxs) {
                content()
            }
            .padding(DS.Spacing.md)
            .glass(style: .ultraThin, cornerRadius: DS.Radius.md)
        }
    }

    private func metricRow(label: String, value: String, color: Color = DS.Colors.textPrimary) -> some View {
        HStack {
            Text(label).font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            Spacer()
            Text(value).font(DS.Typography.mono).foregroundColor(color)
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = Int(seconds) % 3600 / 60
        let s = Int(seconds) % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m \(s)s"
    }

    private func startLiveUpdates() {
        isLive = true
        refreshTask = Task {
            while !Task.isCancelled {
                let sys = ConsoleAppState.gatherLocalSystemMetrics()
                let pm = state.pipelineMetrics
                metrics = sys.toObservatoryMetrics(metrics, pipeline: pm)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopLiveUpdates() {
        refreshTask?.cancel()
        refreshTask = nil
        isLive = false
    }
}

private extension ConsoleAppState.LocalSystemMetrics {
    func toObservatoryMetrics(_ existing: ObservatoryPanel.ObservatoryMetrics, pipeline: PipelineMetrics) -> ObservatoryPanel.ObservatoryMetrics {
        var m = existing
        m.cpuLoad = cpuLoad
        m.memoryUsage = totalMemoryBytes - availableMemoryBytes
        m.framesCaptured = pipeline.framesCaptured
        m.framesEncoded = pipeline.framesEncoded
        m.framesDecoded = pipeline.framesDecoded
        m.framesRendered = pipeline.framesRendered
        m.framesDropped = pipeline.framesDropped
        m.fps = pipeline.fps
        m.bitrate = pipeline.currentBitrate
        m.rtt = pipeline.smoothedRTT / 1_000_000
        m.jitter = pipeline.jitter / 1_000_000
        m.bandwidth = pipeline.effectiveBandwidthMbps
        m.encodeTimeMs = pipeline.averageEncodeTimeMs
        m.decodeTimeMs = pipeline.averageDecodeTimeMs
        m.uptime = pipeline.uptimeSeconds
        return m
    }
}
