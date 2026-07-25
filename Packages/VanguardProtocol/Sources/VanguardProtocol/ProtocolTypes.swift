import Foundation
import VanguardDomain

// MARK: - Protocol Constants

public enum VanguardProtocolConstants {
    public static let magic: [UInt8] = [0x45, 0x56, 0x46, 0x42] // "EVFB"
    public static let headerSize: Int = 25
    public static let maxControlPayload: Int = 1 * 1024 * 1024       // 1 MiB
    public static let maxTerminalChunk: Int = 64 * 1024              // 64 KiB
    public static let maxTelemetryPayload: Int = 256 * 1024          // 256 KiB
    public static let maxVideoAccessUnit: Int = 8 * 1024 * 1024     // 8 MiB
    public static let maxFileChunk: Int = 4 * 1024 * 1024           // 4 MiB
}

// MARK: - Message Type

public enum MessageType: UInt16, Sendable, CaseIterable {
    case hello = 0x0001
    case helloAck = 0x0002
    case pairingRequest = 0x0010
    case pairingChallenge = 0x0011
    case pairingResponse = 0x0012
    case pairingComplete = 0x0013
    case authenticate = 0x0020
    case authenticated = 0x0021
    case capabilityRequest = 0x0030
    case capabilityGranted = 0x0031
    case capabilityDenied = 0x0032
    case sessionOpen = 0x0040
    case sessionClose = 0x0041
    case heartbeat = 0x0050
    case heartbeatAck = 0x0051
    case videoConfiguration = 0x0100
    case videoFrame = 0x0101
    case videoKeyframeRequest = 0x0102
    case videoAccessUnit = 0x0103
    case inputEvent = 0x0200
    case terminalOpen = 0x0300
    case terminalOpened = 0x0301
    case terminalInput = 0x0302
    case terminalOutput = 0x0303
    case terminalResize = 0x0304
    case terminalClose = 0x0305
    case telemetrySnapshot = 0x0400
    case error = 0x0FFF
    case auditEvent = 0x0500
    case flowControlAck = 0x0600
}

// MARK: - Message Flags

public struct MessageFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let none = MessageFlags([])
    public static let requiresResponse = MessageFlags(rawValue: 1 << 0)
    public static let isResponse = MessageFlags(rawValue: 1 << 1)
    public static let isFragment = MessageFlags(rawValue: 1 << 2)
    public static let isLastFragment = MessageFlags(rawValue: 1 << 3)
    public static let urgent = MessageFlags(rawValue: 1 << 4)
}

// MARK: - Stream Channel

public enum StreamChannel: UInt8, Sendable, CaseIterable {
    case control = 0
    case inputReliable = 1
    case inputEphemeral = 2
    case video = 3
    case terminal = 4
    case telemetry = 5
    case files = 6
    case audit = 7
    case heartbeat = 8

    public var maxPayloadSize: Int {
        switch self {
        case .control: return VanguardProtocolConstants.maxControlPayload
        case .inputReliable, .inputEphemeral: return 256
        case .video: return VanguardProtocolConstants.maxVideoAccessUnit
        case .terminal: return VanguardProtocolConstants.maxTerminalChunk
        case .telemetry: return VanguardProtocolConstants.maxTelemetryPayload
        case .files: return VanguardProtocolConstants.maxFileChunk
        case .audit: return VanguardProtocolConstants.maxTelemetryPayload
        case .heartbeat: return 64
        }
    }
}
