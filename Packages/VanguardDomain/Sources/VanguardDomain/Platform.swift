import Foundation

// MARK: - CPU Architecture

public enum CPUArchitecture: String, Codable, Sendable, CaseIterable {
    case arm64
    case x86_64
    case arm64e
    case unknown

    public var displayName: String {
        switch self {
        case .arm64: return "Apple Silicon (arm64)"
        case .x86_64: return "Intel (x86_64)"
        case .arm64e: return "Apple Silicon Enhanced (arm64e)"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Operating System

public struct OperatingSystemDescriptor: Codable, Sendable, Equatable {
    public let family: OSFamily
    public let version: String
    public let build: String?

    public init(family: OSFamily, version: String, build: String? = nil) {
        self.family = family
        self.version = version
        self.build = build
    }

    public var displayName: String {
        "\(family.displayName) \(version)"
    }
}

public enum OSFamily: String, Codable, Sendable, CaseIterable {
    case macOS
    case linux
    case windows
    case android
    case unknown

    public var displayName: String {
        switch self {
        case .macOS: return "macOS"
        case .linux: return "Linux"
        case .windows: return "Windows"
        case .android: return "Android"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Protocol Version

public struct ProtocolVersion: Codable, Sendable, Hashable, Comparable {
    public let major: UInt16
    public let minor: UInt16

    public init(major: UInt16, minor: UInt16) {
        self.major = major
        self.minor = minor
    }

    public static let v1 = ProtocolVersion(major: 1, minor: 0)

    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        return lhs.minor < rhs.minor
    }

    public var description: String {
        "\(major).\(minor)"
    }
}

// MARK: - Node Capabilities

public enum NodeCapability: String, Codable, CaseIterable, Sendable {
    case screenView
    case screenControl
    case clipboardRead
    case clipboardWrite
    case fileRead
    case fileWrite
    case terminalOpen
    case processExecute
    case processTerminate
    case telemetryRead
    case nodeRestart
    case nodeShutdown

    public var displayName: String {
        switch self {
        case .screenView: return "Screen View"
        case .screenControl: return "Screen Control"
        case .clipboardRead: return "Clipboard Read"
        case .clipboardWrite: return "Clipboard Write"
        case .fileRead: return "File Read"
        case .fileWrite: return "File Write"
        case .terminalOpen: return "Terminal Open"
        case .processExecute: return "Process Execute"
        case .processTerminate: return "Process Terminate"
        case .telemetryRead: return "Telemetry Read"
        case .nodeRestart: return "Node Restart"
        case .nodeShutdown: return "Node Shutdown"
        }
    }
}

// MARK: - Trust State

public enum TrustState: String, Codable, Sendable {
    case untrusted
    case pairing
    case trusted
    case revoked
}
