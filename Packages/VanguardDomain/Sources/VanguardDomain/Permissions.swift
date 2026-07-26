import Foundation

// MARK: - Permission State

public enum PermissionState: String, Codable, Sendable, Equatable {
    case unknown
    case notDetermined
    case denied
    case granted
    case requiresRestart
    case unsupported

    public var isGranted: Bool {
        self == .granted
    }

    public var requiresAction: Bool {
        switch self {
        case .notDetermined, .denied, .requiresRestart: return true
        default: return false
        }
    }
}

// MARK: - Permission Descriptor

public struct PermissionDescriptor: Codable, Sendable, Equatable {
    public let kind: PermissionKind
    public let state: PermissionState
    public let description: String
    public let instructions: String

    public init(
        kind: PermissionKind,
        state: PermissionState,
        description: String,
        instructions: String
    ) {
        self.kind = kind
        self.state = state
        self.description = description
        self.instructions = instructions
    }
}

// MARK: - Permission Kind

public enum PermissionKind: String, Codable, Sendable, CaseIterable {
    case screenRecording
    case accessibility
    case localNetwork
    case loginItem

    public var displayName: String {
        switch self {
        case .screenRecording: return "Screen Recording"
        case .accessibility: return "Accessibility"
        case .localNetwork: return "Local Network"
        case .loginItem: return "Login Item"
        }
    }

    public var explanation: String {
        switch self {
        case .screenRecording: return "Required to capture the screen for remote viewing"
        case .accessibility: return "Required to control mouse and keyboard remotely"
        case .localNetwork: return "Required to discover and connect to other Vanguard devices"
        case .loginItem: return "Required to start the node automatically at login"
        }
    }
}

// MARK: - Capture State

public enum CaptureState: Equatable, Sendable {
    case idle
    case requestingPermission
    case ready
    case starting
    case streaming
    case stopping
    case stopped
    case failed(CaptureError)
}

// MARK: - Capture Configuration

public struct CaptureConfiguration: Codable, Sendable, Equatable {
    public let maxWidth: Int
    public let maxHeight: Int
    public let fps: Int
    public let includeCursor: Bool

    public init(
        maxWidth: Int = 1920,
        maxHeight: Int = 1080,
        fps: Int = 30,
        includeCursor: Bool = true
    ) {
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.fps = fps
        self.includeCursor = includeCursor
    }

    public static let defaultConfig = CaptureConfiguration()
}

// MARK: - Capture Source

public struct CaptureSource: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let type: CaptureSourceType
    public let width: Int
    public let height: Int

    public init(
        id: String,
        name: String,
        type: CaptureSourceType,
        width: Int,
        height: Int
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.width = width
        self.height = height
    }
}

public enum CaptureSourceType: String, Codable, Sendable {
    case display
    case window
    case application
}

// MARK: - Captured Frame

public struct CapturedFrame: @unchecked Sendable {
    public let frameID: UInt64
    public let timestampNanos: UInt64
    public let width: Int
    public let height: Int
    public let pixelBuffer: UnsafeRawBufferPointer

    public init(
        frameID: UInt64,
        timestampNanos: UInt64,
        width: Int,
        height: Int,
        pixelBuffer: UnsafeRawBufferPointer
    ) {
        self.frameID = frameID
        self.timestampNanos = timestampNanos
        self.width = width
        self.height = height
        self.pixelBuffer = pixelBuffer
    }
}

// MARK: - Encoded Video Frame

public struct EncodedVideoFrame: Codable, Sendable {
    public let frameID: UInt64
    public let presentationTimestampNanos: UInt64
    public let isKeyframe: Bool
    public let codecConfigurationRevision: UInt32
    public let payload: Data

    public init(
        frameID: UInt64,
        presentationTimestampNanos: UInt64,
        isKeyframe: Bool,
        codecConfigurationRevision: UInt32,
        payload: Data
    ) {
        self.frameID = frameID
        self.presentationTimestampNanos = presentationTimestampNanos
        self.isKeyframe = isKeyframe
        self.codecConfigurationRevision = codecConfigurationRevision
        self.payload = payload
    }
}

public enum VideoCodec: String, Codable, Sendable {
    case h264
}

public struct VideoCodecConfigurationPayload: Codable, Sendable {
    public let codec: VideoCodec
    public let revision: UInt32
    public let width: UInt32
    public let height: UInt32
    public let nalLengthSize: UInt8
    public let sps: Data
    public let pps: Data

    public init(codec: VideoCodec, revision: UInt32, width: UInt32, height: UInt32, nalLengthSize: UInt8, sps: Data, pps: Data) {
        self.codec = codec
        self.revision = revision
        self.width = width
        self.height = height
        self.nalLengthSize = nalLengthSize
        self.sps = sps
        self.pps = pps
    }
}

public struct VideoAccessUnitPayload: Codable, Sendable {
    public let frameID: UInt64
    public let presentationTimestampNanos: UInt64
    public let durationNanos: UInt64
    public let isKeyframe: Bool
    public let configurationRevision: UInt32
    public let avccData: Data

    public init(frameID: UInt64, presentationTimestampNanos: UInt64, durationNanos: UInt64, isKeyframe: Bool, configurationRevision: UInt32, avccData: Data) {
        self.frameID = frameID
        self.presentationTimestampNanos = presentationTimestampNanos
        self.durationNanos = durationNanos
        self.isKeyframe = isKeyframe
        self.configurationRevision = configurationRevision
        self.avccData = avccData
    }
}

import CoreMedia
import CoreVideo

public struct SendablePixelBuffer: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public init(_ pixelBuffer: CVPixelBuffer) { self.pixelBuffer = pixelBuffer }
}

public struct CapturedVideoFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let presentationTimeStamp: CMTime
    public let displayID: CGDirectDisplayID
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int

    public init(
        pixelBuffer: CVPixelBuffer,
        presentationTimeStamp: CMTime,
        displayID: CGDirectDisplayID
    ) {
        self.pixelBuffer = pixelBuffer
        self.presentationTimeStamp = presentationTimeStamp
        self.displayID = displayID
        self.width = CVPixelBufferGetWidth(pixelBuffer)
        self.height = CVPixelBufferGetHeight(pixelBuffer)
        self.bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    }
}
