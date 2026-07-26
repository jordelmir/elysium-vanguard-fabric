import Foundation
import VanguardDomain

public enum SecurityPolicyAction: Sendable {
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

    public var requiredCapability: FabricCapability {
        switch self {
        case .viewScreen: return .screenView
        case .controlScreen: return .screenControl
        case .openTerminal: return .terminalOpen
        case .readClipboard: return .clipboardRead
        case .writeClipboard: return .clipboardWrite
        case .readFile: return .fileRead
        case .writeFile: return .fileWrite
        case .deleteFile: return .fileDelete
        case .listProcesses, .killProcess: return .processExecute
        case .submitJob: return .jobSubmit
        case .cancelJob: return .jobCancel
        case .transferArtifact: return .artifactWrite
        case .syncWorkspace: return .workspaceWrite
        case .getSystemInfo: return .screenView
        case .captureAudio: return .audioReceive
        case .grantCapability: return .policyAdmin
        case .readAudit: return .policyAdmin
        }
    }
}
