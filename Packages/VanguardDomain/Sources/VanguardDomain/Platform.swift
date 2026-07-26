import Foundation

// MARK: - CPU Architecture

public enum CPUArchitecture: String, Codable, Sendable, CaseIterable {
    case arm64
    case x86_64
    case arm64e
    case aarch64Linux
    case x86_64Linux
    case unknown

    public var displayName: String {
        switch self {
        case .arm64: return "Apple Silicon (arm64)"
        case .x86_64: return "Intel (x86_64)"
        case .arm64e: return "Apple Silicon Enhanced (arm64e)"
        case .aarch64Linux: return "Linux ARM64"
        case .x86_64Linux: return "Linux x86_64"
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
    public static let v1_0 = ProtocolVersion(major: 1, minor: 0)
    public static let v1_1 = ProtocolVersion(major: 1, minor: 1)

    public static func < (lhs: ProtocolVersion, rhs: ProtocolVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        return lhs.minor < rhs.minor
    }

    public func isCompatible(with other: ProtocolVersion) -> Bool {
        major == other.major
    }

    public func negotiate(with supported: [ProtocolVersion]) -> ProtocolVersion? {
        let compatible = supported.filter { $0.isCompatible(with: self) && $0 <= self }
        return compatible.max()
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

// MARK: - Trust Status

public enum TrustStatus: String, Codable, Sendable {
    case trusted
    case suspended
    case revoked

    public var displayName: String {
        switch self {
        case .trusted: return "Trusted"
        case .suspended: return "Suspended"
        case .revoked: return "Revoked"
        }
    }
}

public enum TrustState: String, Codable, Sendable {
    case untrusted
    case pairing
    case trusted
    case revoked
}

// MARK: - Battery State

public enum BatteryState: String, Codable, Sendable {
    case charging
    case discharging
    case full
    case unknown

    public var displayName: String {
        switch self {
        case .charging: return "Charging"
        case .discharging: return "Discharging"
        case .full: return "Full"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Node Thermal State

public enum NodeThermalState: String, Codable, Sendable, Comparable {
    case nominal
    case fair
    case serious
    case critical

    public static func < (lhs: NodeThermalState, rhs: NodeThermalState) -> Bool {
        let order: [NodeThermalState] = [.nominal, .fair, .serious, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

    public var schedulerScore: Double {
        switch self {
        case .nominal: return 1.0
        case .fair: return 0.7
        case .serious: return 0.4
        case .critical: return 0.1
        }
    }
}

// MARK: - GPU Descriptor

public struct GPUDescriptor: Codable, Sendable, Equatable {
    public let name: String
    public let vendor: String
    public let memoryBytes: UInt64

    public init(name: String, vendor: String, memoryBytes: UInt64) {
        self.name = name
        self.vendor = vendor
        self.memoryBytes = memoryBytes
    }
}

// MARK: - Executor Kind

public enum ExecutorKind: String, Codable, Sendable, CaseIterable {
    case nativeProcess
    case shell
    case swiftBuild
    case xcodeBuild
    case nodeBuild
    case gradleBuild
    case python
    case container
    case customToolchain

    public var displayName: String {
        switch self {
        case .nativeProcess: return "Native Process"
        case .shell: return "Shell"
        case .swiftBuild: return "Swift Build"
        case .xcodeBuild: return "Xcode Build"
        case .nodeBuild: return "Node Build"
        case .gradleBuild: return "Gradle Build"
        case .python: return "Python"
        case .container: return "Container"
        case .customToolchain: return "Custom Toolchain"
        }
    }
}

// MARK: - Job Priority

public enum JobPriority: Int, Codable, Sendable, Comparable, CaseIterable {
    case lowest = 0
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4

    public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .lowest: return "Lowest"
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Retry Policy

public struct RetryPolicy: Codable, Sendable, Equatable {
    public let maxRetries: Int
    public let backoffSeconds: TimeInterval
    public let maxBackoffSeconds: TimeInterval

    public init(maxRetries: Int = 0, backoffSeconds: TimeInterval = 5, maxBackoffSeconds: TimeInterval = 60) {
        self.maxRetries = maxRetries
        self.backoffSeconds = backoffSeconds
        self.maxBackoffSeconds = maxBackoffSeconds
    }

    public static let noRetry = RetryPolicy(maxRetries: 0)
}

// MARK: - Working Directory Policy

public enum WorkingDirectoryPolicy: String, Codable, Sendable {
    case sandboxOnly
    case projectDirectory
    case customPath
    case systemDefault

    public var displayName: String {
        switch self {
        case .sandboxOnly: return "Sandbox Only"
        case .projectDirectory: return "Project Directory"
        case .customPath: return "Custom Path"
        case .systemDefault: return "System Default"
        }
    }
}

// MARK: - Job Security Policy

public struct JobSecurityPolicy: Codable, Sendable, Equatable {
    public let requiredCapabilities: Set<NodeCapability>
    public let allowedExecutors: Set<ExecutorKind>
    public let requiresSignature: Bool
    public let networkAccessAllowed: Bool
    public let fileSystemAccess: FileSystemAccessPolicy

    public init(
        requiredCapabilities: Set<NodeCapability> = [],
        allowedExecutors: Set<ExecutorKind> = Set(ExecutorKind.allCases),
        requiresSignature: Bool = false,
        networkAccessAllowed: Bool = true,
        fileSystemAccess: FileSystemAccessPolicy = .sandboxOnly
    ) {
        self.requiredCapabilities = requiredCapabilities
        self.allowedExecutors = allowedExecutors
        self.requiresSignature = requiresSignature
        self.networkAccessAllowed = networkAccessAllowed
        self.fileSystemAccess = fileSystemAccess
    }
}

public enum FileSystemAccessPolicy: String, Codable, Sendable {
    case sandboxOnly
    case projectRead
    case projectReadWrite
    case unrestricted

    public var displayName: String {
        switch self {
        case .sandboxOnly: return "Sandbox Only"
        case .projectRead: return "Project Read"
        case .projectReadWrite: return "Project Read/Write"
        case .unrestricted: return "Unrestricted"
        }
    }
}

// MARK: - Toolchain Requirement

public struct ToolchainRequirement: Codable, Sendable, Equatable {
    public let identifier: String
    public let minimumVersion: String?

    public init(identifier: String, minimumVersion: String? = nil) {
        self.identifier = identifier
        self.minimumVersion = minimumVersion
    }
}

// MARK: - Toolchain Descriptor

public struct ToolchainDescriptor: Codable, Sendable, Equatable {
    public let identifier: String
    public let version: String
    public let executablePath: String
    public let supportedTargets: [String]
    public let fingerprint: Data

    public init(identifier: String, version: String, executablePath: String, supportedTargets: [String] = [], fingerprint: Data = Data()) {
        self.identifier = identifier
        self.version = version
        self.executablePath = executablePath
        self.supportedTargets = supportedTargets
        self.fingerprint = fingerprint
    }
}

// MARK: - Agent Risk

public enum AgentRisk: String, Codable, Sendable, Comparable {
    case readOnly
    case low
    case moderate
    case high
    case destructive

    public static func < (lhs: AgentRisk, rhs: AgentRisk) -> Bool {
        let order: [AgentRisk] = [.readOnly, .low, .moderate, .high, .destructive]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }

    public var requiresApproval: Bool {
        switch self {
        case .readOnly, .low: return false
        case .moderate, .high, .destructive: return true
        }
    }
}

// MARK: - Agent Action

public enum AgentAction: Codable, Sendable {
    case inspectRepository
    case runCommand([String])
    case submitJob(String)
    case transferArtifact(artifactID: String, toNode: String)
    case readClipboard
    case writeClipboard(Data)
    case openTerminal(shell: String?)
    case captureScreen
    case readFile(path: String)
    case writeFile(path: String, data: Data)
    case deleteFile(path: String)
    case scheduleJob(String, onNode: String?)
    case cancelJob(String)
    case restartNode
    case custom(String, parameters: [String: String])

    public var displayName: String {
        switch self {
        case .inspectRepository: return "Inspect Repository"
        case .runCommand: return "Run Command"
        case .submitJob: return "Submit Job"
        case .transferArtifact: return "Transfer Artifact"
        case .readClipboard: return "Read Clipboard"
        case .writeClipboard: return "Write Clipboard"
        case .openTerminal: return "Open Terminal"
        case .captureScreen: return "Capture Screen"
        case .readFile: return "Read File"
        case .writeFile: return "Write File"
        case .deleteFile: return "Delete File"
        case .scheduleJob: return "Schedule Job"
        case .cancelJob: return "Cancel Job"
        case .restartNode: return "Restart Node"
        case .custom: return "Custom Action"
        }
    }
}

// MARK: - Node Action

public enum NodeAction: Sendable {
    case viewScreen
    case controlScreen
    case openTerminal
    case readClipboard
    case writeClipboard
    case readFile(path: String)
    case writeFile(path: String)
    case deleteFile(path: String)
    case listProcesses
    case killProcess(pid: Int32)
    case submitJob
    case cancelJob
    case transferArtifact
    case syncWorkspace
    case getSystemInfo
    case captureAudio
    case grantCapability
    case readAudit
}

// MARK: - Secret Reference

public struct SecretReference: Codable, Sendable, Equatable {
    public let secretID: UUID
    public let requiredScope: String

    public init(secretID: UUID, requiredScope: String) {
        self.secretID = secretID
        self.requiredScope = requiredScope
    }
}

// MARK: - Terminal Session Descriptor

public struct TerminalSessionDescriptor: Codable, Sendable, Equatable {
    public let sessionID: UUID
    public let nodeID: UUID
    public let shellPath: String
    public let workingDirectory: String
    public let createdAt: Date

    public init(sessionID: UUID, nodeID: UUID, shellPath: String, workingDirectory: String, createdAt: Date = Date()) {
        self.sessionID = sessionID
        self.nodeID = nodeID
        self.shellPath = shellPath
        self.workingDirectory = workingDirectory
        self.createdAt = createdAt
    }
}

// MARK: - Remote Application Descriptor

public struct RemoteApplicationDescriptor: Codable, Sendable, Equatable {
    public let appBundleID: String
    public let displayName: String
    public let nodeID: UUID
    public let isRunning: Bool
    public let processID: Int32?

    public init(appBundleID: String, displayName: String, nodeID: UUID, isRunning: Bool, processID: Int32? = nil) {
        self.appBundleID = appBundleID
        self.displayName = displayName
        self.nodeID = nodeID
        self.isRunning = isRunning
        self.processID = processID
    }
}

// MARK: - Remote Window Descriptor

public struct RemoteWindowDescriptor: Codable, Sendable, Equatable {
    public let windowID: UInt32
    public let appBundleID: String
    public let title: String
    public let bounds: WindowBounds
    public let isMinimized: Bool
    public let isMovable: Bool

    public init(windowID: UInt32, appBundleID: String, title: String, bounds: WindowBounds, isMinimized: Bool = false, isMovable: Bool = true) {
        self.windowID = windowID
        self.appBundleID = appBundleID
        self.title = title
        self.bounds = bounds
        self.isMinimized = isMinimized
        self.isMovable = isMovable
    }
}

public struct WindowBounds: Codable, Sendable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - Window Stream Session

public struct WindowStreamSession: Codable, Sendable, Equatable {
    public let sessionID: UUID
    public let windowDescriptor: RemoteWindowDescriptor
    public let streamID: UUID
    public let startedAt: Date

    public init(sessionID: UUID, windowDescriptor: RemoteWindowDescriptor, streamID: UUID = UUID(), startedAt: Date = Date()) {
        self.sessionID = sessionID
        self.windowDescriptor = windowDescriptor
        self.streamID = streamID
        self.startedAt = startedAt
    }
}

// MARK: - Test Matrix

public struct TestMatrix: Codable, Sendable {
    public let projectID: UUID
    public let dimensions: [TestDimension]
    public let testCommand: TestCommand
    public let failFast: Bool

    public init(projectID: UUID = UUID(), dimensions: [TestDimension], testCommand: TestCommand, failFast: Bool = true) {
        self.projectID = projectID
        self.dimensions = dimensions
        self.testCommand = testCommand
        self.failFast = failFast
    }
}

public struct TestDimension: Codable, Sendable {
    public let name: String
    public let values: [String]

    public init(name: String, values: [String]) {
        self.name = name
        self.values = values
    }
}

public struct TestCommand: Codable, Sendable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

// MARK: - Build Cache Key

public struct BuildCacheKey: Codable, Sendable, Hashable {
    public let sourceDigest: Data
    public let toolchainDigest: Data
    public let targetTriple: String
    public let configuration: String
    public let argumentsDigest: Data
    public let dependencyDigest: Data

    public init(sourceDigest: Data, toolchainDigest: Data, targetTriple: String, configuration: String, argumentsDigest: Data, dependencyDigest: Data) {
        self.sourceDigest = sourceDigest
        self.toolchainDigest = toolchainDigest
        self.targetTriple = targetTriple
        self.configuration = configuration
        self.argumentsDigest = argumentsDigest
        self.dependencyDigest = dependencyDigest
    }
}

// MARK: - Update Manifest

public struct UpdateManifest: Codable, Sendable {
    public let version: String
    public let build: UInt64
    public let targetOS: String
    public let targetArchitecture: CPUArchitecture
    public let minimumOSVersion: String
    public let artifactURL: String
    public let sha256: Data
    public let signature: Data
    public let releaseNotes: String

    public init(version: String, build: UInt64, targetOS: String, targetArchitecture: CPUArchitecture, minimumOSVersion: String, artifactURL: String, sha256: Data, signature: Data, releaseNotes: String) {
        self.version = version
        self.build = build
        self.targetOS = targetOS
        self.targetArchitecture = targetArchitecture
        self.minimumOSVersion = minimumOSVersion
        self.artifactURL = artifactURL
        self.sha256 = sha256
        self.signature = signature
        self.releaseNotes = releaseNotes
    }
}

// MARK: - FabricCapability (superset for signed tokens)

public enum FabricCapability: String, Codable, CaseIterable, Sendable {
    case screenView
    case screenControl
    case audioReceive
    case audioSend
    case clipboardRead
    case clipboardWrite
    case terminalOpen
    case terminalWrite
    case fileRead
    case fileWrite
    case fileDelete
    case processInspect
    case processExecute
    case jobSubmit
    case jobExecute
    case jobCancel
    case artifactRead
    case artifactWrite
    case workspaceRead
    case workspaceWrite
    case powerControl
    case softwareUpdate
    case agentPlan
    case agentExecute
    case policyAdmin

    public var displayName: String {
        switch self {
        case .screenView: return "Screen View"
        case .screenControl: return "Screen Control"
        case .audioReceive: return "Audio Receive"
        case .audioSend: return "Audio Send"
        case .clipboardRead: return "Clipboard Read"
        case .clipboardWrite: return "Clipboard Write"
        case .terminalOpen: return "Terminal Open"
        case .terminalWrite: return "Terminal Write"
        case .fileRead: return "File Read"
        case .fileWrite: return "File Write"
        case .fileDelete: return "File Delete"
        case .processInspect: return "Process Inspect"
        case .processExecute: return "Process Execute"
        case .jobSubmit: return "Job Submit"
        case .jobExecute: return "Job Execute"
        case .jobCancel: return "Job Cancel"
        case .artifactRead: return "Artifact Read"
        case .artifactWrite: return "Artifact Write"
        case .workspaceRead: return "Workspace Read"
        case .workspaceWrite: return "Workspace Write"
        case .powerControl: return "Power Control"
        case .softwareUpdate: return "Software Update"
        case .agentPlan: return "Agent Plan"
        case .agentExecute: return "Agent Execute"
        case .policyAdmin: return "Policy Admin"
        }
    }
}

// MARK: - Capability Grant (signed token)

public struct CapabilityGrant: Codable, Sendable {
    public let grantID: UUID
    public let sessionID: UUID
    public let subjectDeviceID: UUID
    public let issuerDeviceID: UUID
    public let capabilities: Set<FabricCapability>
    public let issuedAt: Date
    public let expiresAt: Date
    public let nonce: Data
    public let signature: Data

    public init(grantID: UUID = UUID(), sessionID: UUID, subjectDeviceID: UUID, issuerDeviceID: UUID, capabilities: Set<FabricCapability>, issuedAt: Date = Date(), expiresAt: Date, nonce: Data = Data(), signature: Data = Data()) {
        self.grantID = grantID
        self.sessionID = sessionID
        self.subjectDeviceID = subjectDeviceID
        self.issuerDeviceID = issuerDeviceID
        self.capabilities = capabilities
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.nonce = nonce
        self.signature = signature
    }

    public var isValid: Bool {
        Date() >= issuedAt && Date() < expiresAt
    }

    public func hasCapability(_ capability: FabricCapability) -> Bool {
        isValid && capabilities.contains(capability)
    }
}
