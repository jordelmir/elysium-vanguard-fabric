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
    public static let protocolMajorVersion: UInt16 = 1
    public static let protocolMinorVersion: UInt16 = 0
}

// MARK: - Protocol Version Extensions

extension ProtocolVersion {
    public static let v1_0 = ProtocolVersion(major: 1, minor: 0)
    public static let v1_1 = ProtocolVersion(major: 1, minor: 1)
}

// MARK: - Feature Negotiation

public struct FeatureSet: Codable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let supportedCodecs: Set<String>
    public let extensions: Set<String>

    public init(protocolVersion: ProtocolVersion, supportedCodecs: Set<String>, extensions: Set<String>) {
        self.protocolVersion = protocolVersion
        self.supportedCodecs = supportedCodecs
        self.extensions = extensions
    }
}

// MARK: - Protocol Error

public enum ProtocolError: Sendable, Error {
    case invalidMagic
    case unsupportedVersion(major: UInt16)
    case unknownMessageType(rawValue: UInt16)
    case invalidPayload(reason: String)
    case payloadTooLarge
    case invalidState
    case authenticationFailed
    case authorizationDenied
    case capabilityRequired
    case sessionExpired
    case replayDetected
    case rateLimited
    case codecNotSupported
    case videoConfigRequired
    case keyframeRequired
    case decoderFailed
    case terminalFailed
    case terminalNotFound
    case fileTransferFailed
    case pathTraversal
    case diskFull
    case jobFailed
    case jobNotFound
    case schedulerFailed
    case nodeUnavailable
    case timeout
    case `internal`

    public var errorCode: UInt16 {
        switch self {
        case .invalidMagic: return 0x0001
        case .unsupportedVersion: return 0x0002
        case .unknownMessageType: return 0x0003
        case .invalidPayload: return 0x0004
        case .payloadTooLarge: return 0x0005
        case .invalidState: return 0x0006
        case .authenticationFailed: return 0x0010
        case .authorizationDenied: return 0x0011
        case .capabilityRequired: return 0x0012
        case .sessionExpired: return 0x0013
        case .replayDetected: return 0x0014
        case .rateLimited: return 0x0015
        case .codecNotSupported: return 0x0020
        case .videoConfigRequired: return 0x0021
        case .keyframeRequired: return 0x0022
        case .decoderFailed: return 0x0023
        case .terminalFailed: return 0x0030
        case .terminalNotFound: return 0x0031
        case .fileTransferFailed: return 0x0040
        case .pathTraversal: return 0x0041
        case .diskFull: return 0x0042
        case .jobFailed: return 0x0050
        case .jobNotFound: return 0x0051
        case .schedulerFailed: return 0x0052
        case .nodeUnavailable: return 0x0053
        case .timeout: return 0x0060
        case .internal: return 0x0FFF
        }
    }
}

extension ProtocolError: Equatable {
    public static func == (lhs: ProtocolError, rhs: ProtocolError) -> Bool {
        lhs.errorCode == rhs.errorCode
    }
}

extension ProtocolError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidMagic: return "Invalid magic bytes"
        case .unsupportedVersion(let v): return "Unsupported protocol version \(v)"
        case .unknownMessageType(let raw): return "Unknown message type 0x\(String(raw, radix: 16))"
        case .invalidPayload(let reason): return "Invalid payload: \(reason)"
        case .payloadTooLarge: return "Payload too large"
        case .invalidState: return "Invalid state for this operation"
        case .authenticationFailed: return "Authentication failed"
        case .authorizationDenied: return "Authorization denied"
        case .capabilityRequired: return "Required capability not granted"
        case .sessionExpired: return "Session expired"
        case .replayDetected: return "Replay attack detected"
        case .rateLimited: return "Rate limited"
        case .codecNotSupported: return "Codec not supported"
        case .videoConfigRequired: return "Video configuration required before frames"
        case .keyframeRequired: return "Keyframe required for decoder"
        case .decoderFailed: return "Decoder error"
        case .terminalFailed: return "Terminal operation failed"
        case .terminalNotFound: return "Terminal session not found"
        case .fileTransferFailed: return "File transfer failed"
        case .pathTraversal: return "Path traversal detected"
        case .diskFull: return "Disk full"
        case .jobFailed: return "Job execution failed"
        case .jobNotFound: return "Job not found"
        case .schedulerFailed: return "Scheduler error"
        case .nodeUnavailable: return "Node unavailable"
        case .timeout: return "Operation timed out"
        case .internal: return "Internal error"
        }
    }
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
    case artifactManifest = 0x0700
    case artifactChunk = 0x0701
    case artifactRequest = 0x0702
    case jobSubmit = 0x0800
    case jobAssigned = 0x0801
    case jobProgress = 0x0802
    case jobCompleted = 0x0803
    case jobFailed = 0x0804
    case jobCancelled = 0x0805
    case resourceDescriptor = 0x0900
    case workspaceSync = 0x0A00
    case workspaceChangeSet = 0x0A01

    // Coordinator — Presence
    case presenceRegister = 0x0B00
    case presenceDeregister = 0x0B01
    case presenceHeartbeat = 0x0B02
    case presenceList = 0x0B03
    case presenceListResponse = 0x0B04

    // Coordinator — Rendezvous
    case rendezvousRequest = 0x0B10
    case rendezvousOffer = 0x0B11
    case rendezvousAnswer = 0x0B12
    case rendezvousComplete = 0x0B13
    case rendezvousCancel = 0x0B14

    // Coordinator — Signaling
    case signalingOffer = 0x0B20
    case signalingAnswer = 0x0B21
    case signalingIceCandidate = 0x0B22
    case signalingError = 0x0B23

    // Coordinator — Relay
    case relayAllocate = 0x0B30
    case relayAllocateResponse = 0x0B31
    case relayForward = 0x0B32
    case relayForwardAck = 0x0B33
    case relayRelease = 0x0B34

    // Clipboard
    case clipboardData = 0x0C00
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
