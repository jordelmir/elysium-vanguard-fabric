import Foundation
import VanguardDomain

public actor AuthorizationGuard {
    private var sessionCapabilities: [SessionID: Set<NodeCapability>] = [:]

    public init() {}

    public func registerSession(_ sessionID: SessionID, capabilities: Set<NodeCapability>) {
        sessionCapabilities[sessionID] = capabilities
    }

    public func revokeSession(_ sessionID: SessionID) {
        sessionCapabilities.removeValue(forKey: sessionID)
    }

    public func authorize(
        _ action: SecurityAction,
        sessionID: SessionID
    ) async throws -> AuthorizationDecision {
        guard let capabilities = sessionCapabilities[sessionID] else {
            return .denied(reason: "No session registered")
        }

        guard let required = requiredCapability(for: action) else {
            return .allowed
        }

        if capabilities.contains(required) {
            return .allowed
        }

        AppLogger.logCapability(required.rawValue, granted: false, reason: "Missing capability for \(action)")
        return .denied(reason: "Missing capability: \(required.displayName)")
    }

    public func checkCapability(_ capability: NodeCapability, sessionID: SessionID) -> Bool {
        guard let capabilities = sessionCapabilities[sessionID] else { return false }
        return capabilities.contains(capability)
    }

    public func elevateCapabilities(_ capabilities: Set<NodeCapability>, sessionID: SessionID) {
        guard var existing = sessionCapabilities[sessionID] else { return }
        existing.formUnion(capabilities)
        sessionCapabilities[sessionID] = existing
    }

    public func revokeCapabilities(_ capabilities: Set<NodeCapability>, sessionID: SessionID) {
        guard var existing = sessionCapabilities[sessionID] else { return }
        existing.subtract(capabilities)
        sessionCapabilities[sessionID] = existing
    }

    private func requiredCapability(for action: SecurityAction) -> NodeCapability? {
        switch action {
        case .startScreenCapture:
            return .screenView
        case .startScreenControl:
            return .screenControl
        case .openTerminal:
            return .terminalOpen
        case .executeProcess:
            return .processExecute
        case .readFiles:
            return .fileRead
        case .writeFiles:
            return .fileWrite
        case .transferFile:
            return .fileWrite
        case .shutdown:
            return .nodeShutdown
        case .restart:
            return .nodeRestart
        case .revokePeer:
            return nil
        case .elevateCapabilities:
            return nil
        }
    }
}
