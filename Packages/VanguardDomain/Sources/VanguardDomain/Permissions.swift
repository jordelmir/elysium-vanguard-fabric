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
