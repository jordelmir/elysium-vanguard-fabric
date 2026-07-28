import Testing
import Foundation
@testable import VanguardObservability

@Suite("PipelineMetricsCollector")
struct PipelineMetricsCollectorTests {

    @Test("Initial snapshot returns zero metrics")
    func initialSnapshot() async {
        let collector = PipelineMetricsCollector()
        let snap = await collector.snapshot()
        #expect(snap.framesCaptured == 0)
        #expect(snap.framesRendered == 0)
        #expect(snap.bytesTransferred == 0)
        #expect(snap.uptimeSeconds >= 0)
    }

    @Test("Recording frames increments counters")
    func recordFrames() async {
        let collector = PipelineMetricsCollector()
        await collector.recordFrameCaptured()
        await collector.recordFrameCaptured()
        await collector.recordFrameEncoded()
        await collector.recordFrameDecoded()
        await collector.recordFrameRendered()
        await collector.recordFrameDropped()
        let snap = await collector.snapshot()
        #expect(snap.framesCaptured == 2)
        #expect(snap.framesEncoded == 1)
        #expect(snap.framesDecoded == 1)
        #expect(snap.framesRendered == 1)
        #expect(snap.framesDropped == 1)
    }

    @Test("Bytes transferred accumulates")
    func bytesTransferred() async {
        let collector = PipelineMetricsCollector()
        await collector.recordBytesTransferred(1024)
        await collector.recordBytesTransferred(2048)
        let snap = await collector.snapshot()
        #expect(snap.bytesTransferred == 3072)
    }

    @Test("Encode/decode times are averaged")
    func encodeDecodeTimes() async {
        let collector = PipelineMetricsCollector()
        await collector.recordEncodeTime(10.0)
        await collector.recordEncodeTime(20.0)
        await collector.recordDecodeTime(5.0)
        await collector.recordDecodeTime(15.0)
        let snap = await collector.snapshot()
        #expect(snap.averageEncodeTimeMs == 15.0)
        #expect(snap.averageDecodeTimeMs == 10.0)
    }

    @Test("Network stats update")
    func networkStats() async {
        let collector = PipelineMetricsCollector()
        await collector.updateNetworkStats(rtt: 42.0, jitter: 3.5, bitrate: 5000.0)
        let snap = await collector.snapshot()
        #expect(snap.smoothedRTT == 42.0)
        #expect(snap.jitter == 3.5)
        #expect(snap.currentBitrate == 5000.0)
    }

    @Test("Reset clears all metrics")
    func reset() async {
        let collector = PipelineMetricsCollector()
        await collector.recordFrameCaptured()
        await collector.recordBytesTransferred(5000)
        await collector.reset()
        let snap = await collector.snapshot()
        #expect(snap.framesCaptured == 0)
        #expect(snap.bytesTransferred == 0)
    }

    @Test("FPS calculation")
    func fpsCalculation() async {
        let collector = PipelineMetricsCollector()
        await collector.recordFrameRendered()
        await collector.recordFrameRendered()
        let snap = await collector.snapshot()
        if snap.uptimeSeconds > 0 {
            #expect(snap.fps >= 0)
        }
    }

    @Test("Memory usage updates without crash")
    func memoryUsage() async {
        let collector = PipelineMetricsCollector()
        await collector.updateMemoryUsage()
        let snap = await collector.snapshot()
        #expect(snap.memoryUsageBytes > 0)
    }
}
