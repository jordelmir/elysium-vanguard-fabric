import Foundation
import os.log

public enum LogCategory: String, CaseIterable, Sendable {
    case transport = "Transport"
    case capture = "Capture"
    case encode = "Encode"
    case decode = "Decode"
    case render = "Render"
    case input = "Input"
    case terminal = "Terminal"
    case clipboard = "Clipboard"
    case pairing = "Pairing"
    case security = "Security"
    case session = "Session"
    case pipeline = "Pipeline"
    case node = "Node"
    case fileTransfer = "FileTransfer"
    case audio = "Audio"
    case workspace = "Workspace"
    case telemetry = "Telemetry"
    case audit = "Audit"
    case permissions = "Permissions"
    case ui = "UI"
    case network = "Network"
    case discovery = "Discovery"

    public var logger: Logger {
        Logger(subsystem: "ElysiumVanguard", category: rawValue)
    }
}

public struct AppLogger: Sendable {
    private static let enabled = true

    public static func debug(_ category: LogCategory, _ message: String) {
        guard enabled else { return }
        category.logger.debug("\(message, privacy: .public)")
    }

    public static func info(_ category: LogCategory, _ message: String) {
        guard enabled else { return }
        category.logger.info("\(message, privacy: .public)")
    }

    public static func warning(_ category: LogCategory, _ message: String) {
        guard enabled else { return }
        category.logger.warning("\(message, privacy: .public)")
    }

    public static func error(_ category: LogCategory, _ message: String) {
        guard enabled else { return }
        category.logger.error("\(message, privacy: .public)")
    }

    public static func critical(_ category: LogCategory, _ message: String) {
        guard enabled else { return }
        category.logger.critical("\(message, privacy: .public)")
    }

    public static func logMetric(_ name: String, value: Double, unit: String = "") {
        let msg = "\(name)=\(String(format: "%.3f", value))\(unit)"
        LogCategory.telemetry.logger.info("\(msg, privacy: .public)")
    }

    public static func logPerformance(_ operation: String, durationMs: Double) {
        let msg = "\(operation) completed in \(String(format: "%.2f", durationMs))ms"
        LogCategory.session.logger.info("\(msg, privacy: .public)")
    }

    public static func logSecurity(_ event: String, nodeID: String? = nil) {
        let msg = nodeID.map { "[\($0)] \(event)" } ?? event
        LogCategory.security.logger.notice("\(msg, privacy: .public)")
    }

    public static func logPipeline(_ stage: String, frameID: UInt64, durationMs: Double? = nil) {
        let duration = durationMs.map { " in \(String(format: "%.2f", $0))ms" } ?? ""
        let msg = "[Frame \(frameID)] \(stage)\(duration)"
        LogCategory.pipeline.logger.info("\(msg, privacy: .public)")
    }

    public static func logTransport(_ event: String, host: String? = nil, port: UInt16? = nil) {
        let endpoint = host.map { h in
            let p = port.map { ":\($0)" } ?? ""
            return " → \(h)\(p)"
        } ?? ""
        let msg = "\(event)\(endpoint)"
        LogCategory.transport.logger.info("\(msg, privacy: .public)")
    }

    public static func logStateTransition(_ component: String, from: String, to: String) {
        let msg = "\(component): \(from) → \(to)"
        LogCategory.session.logger.info("\(msg, privacy: .public)")
    }

    public static func logCapability(_ capability: String, granted: Bool, reason: String? = nil) {
        let status = granted ? "GRANTED" : "DENIED"
        let reasonStr = reason.map { " (\($0))" } ?? ""
        let msg = "\(capability): \(status)\(reasonStr)"
        LogCategory.security.logger.info("\(msg, privacy: .public)")
    }

    public static func logFrameStats(captured: UInt64, encoded: UInt64, decoded: UInt64, rendered: UInt64) {
        let msg = "Frames - Captured:\(captured) Encoded:\(encoded) Decoded:\(decoded) Rendered:\(rendered)"
        LogCategory.pipeline.logger.info("\(msg, privacy: .public)")
    }

    public static func logMemory(_ component: String, bytes: Int64) {
        let mb = Double(bytes) / 1_048_576
        let msg = "\(component) memory: \(String(format: "%.2f", mb))MB"
        LogCategory.telemetry.logger.info("\(msg, privacy: .public)")
    }

    public static func logNetworkSnapshot(
        rtt: Double?,
        jitter: Double?,
        bytesIn: UInt64,
        bytesOut: UInt64,
        framesIn: UInt64,
        framesOut: UInt64
    ) {
        let rttStr = rtt.map { String(format: "%.1f", $0) } ?? "N/A"
        let jitterStr = jitter.map { String(format: "%.1f", $0) } ?? "N/A"
        let msg = "Network - RTT:\(rttStr)ms Jitter:\(jitterStr)ms In:\(bytesIn)B/\(framesIn)F Out:\(bytesOut)B/\(framesOut)F"
        LogCategory.network.logger.info("\(msg, privacy: .public)")
    }
}
