import Foundation
import ServiceManagement
import os.log
import VanguardDomain

public actor NodeAutonomousService {
    private let nodeID: NodeID
    private var isRunning = false
    private var emergencyStopActive = false
    private var trustedConsoles: [NodeID: TrustedConsole] = [:]
    private let logger = Logger(subsystem: "ElysiumVanguard", category: "NodeAutonomous")

    public init(nodeID: NodeID) {
        self.nodeID = nodeID
    }

    public func startAutonomous() async throws {
        guard !isRunning else { return }
        isRunning = true
        try await enableLaunchAgent()
        logger.info("Node autonomous mode started")
    }

    public func stopAutonomous() async {
        isRunning = false
        logger.info("Node autonomous mode stopped")
    }

    public func activateEmergencyStop() {
        emergencyStopActive = true
        logger.warning("Emergency stop activated")
    }

    public func deactivateEmergencyStop() {
        emergencyStopActive = false
        logger.info("Emergency stop deactivated")
    }

    public func isEmergencyStopActive() -> Bool {
        emergencyStopActive
    }

    public func addTrustedConsole(_ console: TrustedConsole) {
        trustedConsoles[console.nodeID] = console
        logger.info("Added trusted console: \(console.nodeID.rawValue.uuidString)")
    }

    public func removeTrustedConsole(_ nodeID: NodeID) {
        trustedConsoles.removeValue(forKey: nodeID)
        logger.info("Removed trusted console: \(nodeID.rawValue.uuidString)")
    }

    public func isTrustedConsole(_ nodeID: NodeID) -> Bool {
        trustedConsoles[nodeID] != nil
    }

    public func getTrustedConsoles() -> [TrustedConsole] {
        Array(trustedConsoles.values)
    }

    public func getNodeStatus() -> NodeStatus {
        NodeStatus(
            isRunning: isRunning,
            isEmergencyStop: emergencyStopActive,
            trustedConsoleCount: trustedConsoles.count,
            nodeID: nodeID
        )
    }

    private func enableLaunchAgent() throws {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.elysiumvanguard.node.plist")

        let plistContent: [String: Any] = [
            "Label": "com.elysiumvanguard.node",
            "ProgramArguments": [Bundle.main.bundlePath + "/Contents/MacOS/VanguardNodeMac"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": FileManager.default.temporaryDirectory.appendingPathComponent("vanguard-node.log").path,
            "StandardErrorPath": FileManager.default.temporaryDirectory.appendingPathComponent("vanguard-node-error.log").path
        ]

        let plistData = try PropertyListSerialization.data(fromPropertyList: plistContent, format: .xml, options: 0)
        try plistData.write(to: plistPath)

        if #available(macOS 13.0, *) {
            try SMAppService.loginItem(identifier: "com.elysiumvanguard.node").register()
        }

        logger.info("Launch agent installed")
    }

    private func disableLaunchAgent() {
        let plistPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.elysiumvanguard.node.plist")
        try? FileManager.default.removeItem(at: plistPath)

        if #available(macOS 13.0, *) {
            try? SMAppService.loginItem(identifier: "com.elysiumvanguard.node").unregister()
        }

        logger.info("Launch agent removed")
    }
}

public struct TrustedConsole: Sendable, Identifiable {
    public let id: NodeID
    public let nodeID: NodeID
    public let name: String
    public let publicKeyFingerprint: Data
    public let addedAt: Date
    public let capabilities: Set<NodeCapability>

    public init(nodeID: NodeID, name: String, publicKeyFingerprint: Data, capabilities: Set<NodeCapability>) {
        self.id = nodeID
        self.nodeID = nodeID
        self.name = name
        self.publicKeyFingerprint = publicKeyFingerprint
        self.addedAt = Date()
        self.capabilities = capabilities
    }
}

public struct NodeStatus: Sendable {
    public let isRunning: Bool
    public let isEmergencyStop: Bool
    public let trustedConsoleCount: Int
    public let nodeID: NodeID

    public init(isRunning: Bool, isEmergencyStop: Bool, trustedConsoleCount: Int, nodeID: NodeID) {
        self.isRunning = isRunning
        self.isEmergencyStop = isEmergencyStop
        self.trustedConsoleCount = trustedConsoleCount
        self.nodeID = nodeID
    }
}
