import Foundation
import VanguardDomain
import VanguardProtocol

public struct CapabilityNegotiation: Codable, Sendable {
    public let offeredByConsole: Set<NodeCapability>
    public let requiredByNode: Set<NodeCapability>
    public let agreedUpon: Set<NodeCapability>
    public let rejectedByNode: Set<NodeCapability>
    public let rejectedByConsole: Set<NodeCapability>

    public init(
        offeredByConsole: Set<NodeCapability>,
        requiredByNode: Set<NodeCapability>,
        agreedUpon: Set<NodeCapability>,
        rejectedByNode: Set<NodeCapability>,
        rejectedByConsole: Set<NodeCapability>
    ) {
        self.offeredByConsole = offeredByConsole
        self.requiredByNode = requiredByNode
        self.agreedUpon = agreedUpon
        self.rejectedByNode = rejectedByNode
        self.rejectedByConsole = rejectedByConsole
    }

    public var isFullyAgreed: Bool {
        rejectedByNode.isEmpty && rejectedByConsole.isEmpty
    }
}

public actor CapabilityNegotiator {
    public init() {}

    public func negotiate(
        consoleOffered: Set<NodeCapability>,
        nodeRequired: Set<NodeCapability>,
        nodeOffered: Set<NodeCapability>
    ) -> CapabilityNegotiation {
        let agreedByBoth = consoleOffered.intersection(nodeOffered).union(consoleOffered.intersection(nodeRequired))
        let rejectedByNode = consoleOffered.subtracting(nodeOffered).subtracting(nodeRequired)
        let rejectedByConsole = nodeRequired.subtracting(consoleOffered)

        return CapabilityNegotiation(
            offeredByConsole: consoleOffered,
            requiredByNode: nodeRequired,
            agreedUpon: agreedByBoth,
            rejectedByNode: rejectedByNode,
            rejectedByConsole: rejectedByConsole
        )
    }

    public func defaultConsoleCapabilities() -> Set<NodeCapability> {
        [.screenView, .screenControl, .clipboardRead, .clipboardWrite,
         .terminalOpen, .fileRead, .fileWrite, .processExecute,
         .processTerminate, .nodeRestart, .nodeShutdown]
    }

    public func defaultNodeCapabilities() -> Set<NodeCapability> {
        [.screenView, .screenControl, .clipboardRead, .clipboardWrite,
         .terminalOpen, .fileRead, .fileWrite, .processExecute]
    }
}
