import Foundation

// MARK: - Vanguard Node

public struct VanguardNode: Codable, Equatable, Sendable {
    public let id: NodeID
    public let displayName: String
    public let architecture: CPUArchitecture
    public let operatingSystem: OperatingSystemDescriptor
    public let protocolVersions: Set<ProtocolVersion>
    public let capabilities: Set<NodeCapability>
    public let trustState: TrustState
    public let lastSeenAt: Date?

    public init(
        id: NodeID,
        displayName: String,
        architecture: CPUArchitecture,
        operatingSystem: OperatingSystemDescriptor,
        protocolVersions: Set<ProtocolVersion> = [.v1],
        capabilities: Set<NodeCapability> = [],
        trustState: TrustState = .untrusted,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.architecture = architecture
        self.operatingSystem = operatingSystem
        self.protocolVersions = protocolVersions
        self.capabilities = capabilities
        self.trustState = trustState
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - Trusted Peer

public struct TrustedPeer: Codable, Sendable, Equatable {
    public let nodeID: NodeID
    public let signingPublicKey: Data
    public let agreementPublicKey: Data
    public let certificateFingerprint: Data
    public let grantedCapabilities: Set<NodeCapability>
    public let pairedAt: Date
    public let lastSeenAt: Date?
    public let trustStatus: TrustStatus
    public let revokedAt: Date?

    public init(
        nodeID: NodeID,
        signingPublicKey: Data,
        agreementPublicKey: Data,
        certificateFingerprint: Data,
        grantedCapabilities: Set<NodeCapability>,
        pairedAt: Date,
        lastSeenAt: Date? = nil,
        trustStatus: TrustStatus = .trusted,
        revokedAt: Date? = nil
    ) {
        self.nodeID = nodeID
        self.signingPublicKey = signingPublicKey
        self.agreementPublicKey = agreementPublicKey
        self.certificateFingerprint = certificateFingerprint
        self.grantedCapabilities = grantedCapabilities
        self.pairedAt = pairedAt
        self.lastSeenAt = lastSeenAt
        self.trustStatus = trustStatus
        self.revokedAt = revokedAt
    }

    public var isRevoked: Bool {
        trustStatus == .revoked || revokedAt != nil
    }
}

// MARK: - Node Endpoint

public struct NodeEndpoint: Codable, Sendable, Equatable {
    public let host: String
    public let port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
}

// MARK: - Node Advertisement (Bonjour)

public struct NodeAdvertisement: Codable, Sendable, Equatable {
    public let nodeIDHash: Data
    public let displayName: String
    public let architecture: CPUArchitecture
    public let osFamily: OSFamily
    public let osVersion: String
    public let protocolVersion: ProtocolVersion
    public let pairingState: TrustState
    public let endpoint: NodeEndpoint

    public init(
        nodeIDHash: Data,
        displayName: String,
        architecture: CPUArchitecture,
        osFamily: OSFamily,
        osVersion: String,
        protocolVersion: ProtocolVersion,
        pairingState: TrustState,
        endpoint: NodeEndpoint
    ) {
        self.nodeIDHash = nodeIDHash
        self.displayName = displayName
        self.architecture = architecture
        self.osFamily = osFamily
        self.osVersion = osVersion
        self.protocolVersion = protocolVersion
        self.pairingState = pairingState
        self.endpoint = endpoint
    }
}
