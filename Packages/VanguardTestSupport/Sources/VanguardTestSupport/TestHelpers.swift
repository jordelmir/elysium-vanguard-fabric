import Foundation
import VanguardDomain
import VanguardProtocol
import VanguardTransport
import VanguardPermissions
import VanguardIdentity
import VanguardSecurity

// MARK: - Test Helpers

public enum TestHelpers {
    public static func makeNode(
        id: NodeID = NodeID(),
        name: String = "Test Node",
        arch: CPUArchitecture = .arm64,
        os: OperatingSystemDescriptor = OperatingSystemDescriptor(family: .macOS, version: "14.0"),
        caps: Set<NodeCapability> = [.screenView, .screenControl, .terminalOpen],
        trust: TrustState = .trusted
    ) -> VanguardNode {
        return VanguardNode(
            id: id,
            displayName: name,
            architecture: arch,
            operatingSystem: os,
            capabilities: caps,
            trustState: trust,
            lastSeenAt: Date()
        )
    }

    public static func makeSession(
        id: SessionID = SessionID(),
        nodeID: NodeID = NodeID(),
        caps: Set<NodeCapability> = [.screenView, .screenControl]
    ) -> Session {
        return Session(
            id: id,
            nodeID: nodeID,
            grantedCapabilities: caps
        )
    }

    public static func makeEndpoint(host: String = "127.0.0.1", port: UInt16 = 9100) -> NodeEndpoint {
        return NodeEndpoint(host: host, port: port)
    }

    public static func makeAdvertisement(
        name: String = "Test Node",
        arch: CPUArchitecture = .arm64,
        endpoint: NodeEndpoint = NodeEndpoint(host: "127.0.0.1", port: 9100)
    ) -> NodeAdvertisement {
        return NodeAdvertisement(
            nodeIDHash: Data(repeating: 0xAA, count: 32),
            displayName: name,
            architecture: arch,
            osFamily: .macOS,
            osVersion: "14.0",
            protocolVersion: .v1,
            pairingState: .trusted,
            endpoint: endpoint
        )
    }

    public static func makeTelemetrySnapshot() -> NodeTelemetrySnapshot {
        return NodeTelemetrySnapshot(
            capturedAtMonotonicNanos: 0,
            cpu: CPUMetrics(
                usagePercent: 25.0,
                coreCount: 8,
                loadAverage1m: 1.5,
                loadAverage5m: 1.2,
                loadAverage15m: 1.0
            ),
            memory: MemoryMetrics(
                totalBytes: 16 * 1024 * 1024 * 1024,
                usedBytes: 8 * 1024 * 1024 * 1024,
                availableBytes: 8 * 1024 * 1024 * 1024,
                pressure: .normal
            ),
            disk: DiskMetrics(
                totalBytes: 500 * 1024 * 1024 * 1024,
                availableBytes: 250 * 1024 * 1024 * 1024,
                usedBytes: 250 * 1024 * 1024 * 1024
            ),
            network: NetworkMetrics(
                bytesSent: 1024,
                bytesReceived: 2048,
                activeConnections: 1,
                rttMilliseconds: 2.5
            )
        )
    }

    public static func makeAuditEntry(
        sequenceNumber: UInt64 = 0,
        action: AuditAction = .connected,
        decision: AuditDecision = .allowed,
        result: AuditResult = .success
    ) -> AuditEntry {
        return AuditEntry(
            sequenceNumber: sequenceNumber,
            actorNodeID: NodeID(),
            targetNodeID: NodeID(),
            action: action,
            decision: decision,
            result: result,
            entryHash: Data(repeating: 0xBB, count: 32)
        )
    }
}
