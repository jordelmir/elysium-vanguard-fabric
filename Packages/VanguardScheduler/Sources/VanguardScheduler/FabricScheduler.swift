import Foundation
import VanguardDomain

// MARK: - Node Resource Descriptor (full)

public struct NodeResourceDescriptor: Codable, Sendable, Equatable {
    public let nodeID: NodeID
    public let architecture: CPUArchitecture
    public let operatingSystem: OperatingSystemDescriptor
    public let logicalCPUCount: Int
    public let physicalCPUCount: Int
    public let totalMemoryBytes: UInt64
    public let availableMemoryBytes: UInt64
    public let gpuDescriptors: [GPUDescriptor]
    public let totalStorageBytes: UInt64
    public let availableStorageBytes: UInt64
    public let batteryState: BatteryState?
    public let thermalState: NodeThermalState
    public let currentCPULoad: Double
    public let currentMemoryPressure: Double
    public let currentJobCount: Int
    public let installedToolchains: [ToolchainDescriptor]
    public let supportedExecutors: Set<ExecutorKind>
    public let supportedCapabilities: Set<FabricCapability>
    public let measuredAt: Date

    public init(
        nodeID: NodeID,
        architecture: CPUArchitecture,
        operatingSystem: OperatingSystemDescriptor,
        logicalCPUCount: Int,
        physicalCPUCount: Int,
        totalMemoryBytes: UInt64,
        availableMemoryBytes: UInt64,
        gpuDescriptors: [GPUDescriptor] = [],
        totalStorageBytes: UInt64,
        availableStorageBytes: UInt64,
        batteryState: BatteryState? = nil,
        thermalState: NodeThermalState = .nominal,
        currentCPULoad: Double = 0,
        currentMemoryPressure: Double = 0,
        currentJobCount: Int = 0,
        installedToolchains: [ToolchainDescriptor] = [],
        supportedExecutors: Set<ExecutorKind> = Set(ExecutorKind.allCases),
        supportedCapabilities: Set<FabricCapability> = Set(FabricCapability.allCases),
        measuredAt: Date = Date()
    ) {
        self.nodeID = nodeID
        self.architecture = architecture
        self.operatingSystem = operatingSystem
        self.logicalCPUCount = logicalCPUCount
        self.physicalCPUCount = physicalCPUCount
        self.totalMemoryBytes = totalMemoryBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.gpuDescriptors = gpuDescriptors
        self.totalStorageBytes = totalStorageBytes
        self.availableStorageBytes = availableStorageBytes
        self.batteryState = batteryState
        self.thermalState = thermalState
        self.currentCPULoad = currentCPULoad
        self.currentMemoryPressure = currentMemoryPressure
        self.currentJobCount = currentJobCount
        self.installedToolchains = installedToolchains
        self.supportedExecutors = supportedExecutors
        self.supportedCapabilities = supportedCapabilities
        self.measuredAt = measuredAt
    }
}

// MARK: - Scheduler Score

public struct SchedulerScore: Sendable, Codable {
    public let nodeID: NodeID
    public let total: Double
    public let computeScore: Double
    public let memoryScore: Double
    public let localityScore: Double
    public let latencyScore: Double
    public let reliabilityScore: Double
    public let thermalScore: Double
    public let energyScore: Double
    public let explanation: String

    public init(nodeID: NodeID, total: Double, computeScore: Double, memoryScore: Double, localityScore: Double, latencyScore: Double, reliabilityScore: Double, thermalScore: Double, energyScore: Double, explanation: String = "") {
        self.nodeID = nodeID
        self.total = total
        self.computeScore = computeScore
        self.memoryScore = memoryScore
        self.localityScore = localityScore
        self.latencyScore = latencyScore
        self.reliabilityScore = reliabilityScore
        self.thermalScore = thermalScore
        self.energyScore = energyScore
        self.explanation = explanation
    }
}

// MARK: - Scheduler Error

public enum SchedulerError: Error, Sendable {
    case noEligibleNode
    case noNodesRegistered
    case invalidRequirements
}

extension SchedulerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noEligibleNode: return "No eligible node found for job requirements"
        case .noNodesRegistered: return "No nodes registered in the scheduler"
        case .invalidRequirements: return "Invalid job requirements"
        }
    }
}

// MARK: - Scheduler Weights

public struct SchedulerWeights: Sendable, Codable {
    public let cpuWeight: Double
    public let memoryWeight: Double
    public let localityWeight: Double
    public let latencyWeight: Double
    public let reliabilityWeight: Double
    public let thermalWeight: Double
    public let energyWeight: Double

    public init(
        cpuWeight: Double = 0.25,
        memoryWeight: Double = 0.15,
        localityWeight: Double = 0.20,
        latencyWeight: Double = 0.10,
        reliabilityWeight: Double = 0.15,
        thermalWeight: Double = 0.10,
        energyWeight: Double = 0.05
    ) {
        self.cpuWeight = cpuWeight
        self.memoryWeight = memoryWeight
        self.localityWeight = localityWeight
        self.latencyWeight = latencyWeight
        self.reliabilityWeight = reliabilityWeight
        self.thermalWeight = thermalWeight
        self.energyWeight = energyWeight
    }
}

// MARK: - Hard Constraints

public struct HardConstraints: Sendable, Codable {
    public let requiredArchitectures: Set<CPUArchitecture>
    public let requiredOSFamily: OSFamily?
    public let minimumLogicalCPUs: Int
    public let minimumMemoryBytes: UInt64
    public let minimumStorageBytes: UInt64
    public let requiredToolchains: [ToolchainRequirement]
    public let requiredCapabilities: Set<FabricCapability>
    public let requiresGPU: Bool
    public let maximumThermalState: NodeThermalState
    public let requiresACPower: Bool
    public let excludedNodeIDs: Set<NodeID>

    public init(
        requiredArchitectures: Set<CPUArchitecture> = Set(CPUArchitecture.allCases),
        requiredOSFamily: OSFamily? = nil,
        minimumLogicalCPUs: Int = 1,
        minimumMemoryBytes: UInt64 = 0,
        minimumStorageBytes: UInt64 = 0,
        requiredToolchains: [ToolchainRequirement] = [],
        requiredCapabilities: Set<FabricCapability> = [],
        requiresGPU: Bool = false,
        maximumThermalState: NodeThermalState = .critical,
        requiresACPower: Bool = false,
        excludedNodeIDs: Set<NodeID> = []
    ) {
        self.requiredArchitectures = requiredArchitectures
        self.requiredOSFamily = requiredOSFamily
        self.minimumLogicalCPUs = minimumLogicalCPUs
        self.minimumMemoryBytes = minimumMemoryBytes
        self.minimumStorageBytes = minimumStorageBytes
        self.requiredToolchains = requiredToolchains
        self.requiredCapabilities = requiredCapabilities
        self.requiresGPU = requiresGPU
        self.maximumThermalState = maximumThermalState
        self.requiresACPower = requiresACPower
        self.excludedNodeIDs = excludedNodeIDs
    }
}

// MARK: - Fabric Scheduler

public actor FabricScheduler {
    private var nodeDescriptors: [NodeID: NodeResourceDescriptor] = [:]
    private var weights: SchedulerWeights
    private var historicalReliability: [NodeID: [Double]] = [:]
    private var measuredLatency: [NodeID: TimeInterval] = [:]
    private var artifactLocations: [UUID: Set<NodeID>] = [:]

    public init(weights: SchedulerWeights = SchedulerWeights()) {
        self.weights = weights
    }

    public func registerNode(_ descriptor: NodeResourceDescriptor) {
        nodeDescriptors[descriptor.nodeID] = descriptor
    }

    public func unregisterNode(_ nodeID: NodeID) {
        nodeDescriptors.removeValue(forKey: nodeID)
        historicalReliability.removeValue(forKey: nodeID)
        measuredLatency.removeValue(forKey: nodeID)
    }

    public func updateWeights(_ weights: SchedulerWeights) {
        self.weights = weights
    }

    public func recordLatency(_ latency: TimeInterval, for nodeID: NodeID) {
        measuredLatency[nodeID] = latency
    }

    public func recordJobResult(nodeID: NodeID, succeeded: Bool) {
        var history = historicalReliability[nodeID] ?? []
        history.append(succeeded ? 1.0 : 0.0)
        if history.count > 50 { history.removeFirst() }
        historicalReliability[nodeID] = history
    }

    public func registerArtifactLocation(artifactID: UUID, onNode nodeID: NodeID) {
        var locations = artifactLocations[artifactID] ?? Set<NodeID>()
        locations.insert(nodeID)
        artifactLocations[artifactID] = locations
    }

    public func selectNode(for constraints: HardConstraints) throws -> SchedulerScore {
        return try selectNode(for: constraints, requiredArtifactIDs: [])
    }

    public func selectNode(for constraints: HardConstraints, requiredArtifactIDs: [UUID]) throws -> SchedulerScore {
        guard !nodeDescriptors.isEmpty else {
            throw SchedulerError.noNodesRegistered
        }

        let eligible = nodeDescriptors.values.filter { isEligible(node: $0, for: constraints) }
        guard !eligible.isEmpty else {
            throw SchedulerError.noEligibleNode
        }

        let scores = eligible.map { score(node: $0, constraints: constraints, requiredArtifactIDs: requiredArtifactIDs) }
        guard let best = scores.max(by: { $0.total < $1.total }) else {
            throw SchedulerError.noEligibleNode
        }

        return best
    }

    public func allNodes() -> [NodeResourceDescriptor] {
        Array(nodeDescriptors.values)
    }

    // MARK: - Eligibility

    private func isEligible(node: NodeResourceDescriptor, for constraints: HardConstraints) -> Bool {
        if !constraints.requiredArchitectures.contains(node.architecture) { return false }
        if let reqOS = constraints.requiredOSFamily, node.operatingSystem.family != reqOS { return false }
        if node.logicalCPUCount < constraints.minimumLogicalCPUs { return false }
        if node.availableMemoryBytes < constraints.minimumMemoryBytes { return false }
        if node.availableStorageBytes < constraints.minimumStorageBytes { return false }
        if constraints.requiresGPU && node.gpuDescriptors.isEmpty { return false }
        if node.thermalState > constraints.maximumThermalState { return false }
        if constraints.requiresACPower, let battery = node.batteryState, battery == .discharging { return false }
        if constraints.excludedNodeIDs.contains(node.nodeID) { return false }

        for requirement in constraints.requiredToolchains {
            if !node.installedToolchains.contains(where: { $0.identifier == requirement.identifier }) { return false }
        }

        if !node.supportedCapabilities.isSuperset(of: constraints.requiredCapabilities) { return false }

        return true
    }

    // MARK: - Scoring

    private func score(node: NodeResourceDescriptor, constraints: HardConstraints, requiredArtifactIDs: [UUID] = []) -> SchedulerScore {
        let cpuScore = max(0, 1 - node.currentCPULoad)
        let memoryScore = node.totalMemoryBytes == 0 ? 0 : Double(node.availableMemoryBytes) / Double(node.totalMemoryBytes)
        let latency = measuredLatency[node.nodeID] ?? 100
        let latencyScore = 1 / max(latency / 1000, 0.001)
        let reliability = averageReliability(for: node.nodeID)
        let thermalScore = node.thermalState.schedulerScore
        let energyScore = energyScore(for: node)

        let localityScore: Double
        if requiredArtifactIDs.isEmpty {
            localityScore = 0.5
        } else {
            let locatedCount = requiredArtifactIDs.filter { artifactID in
                artifactLocations[artifactID]?.contains(node.nodeID) ?? false
            }.count
            localityScore = Double(locatedCount) / Double(requiredArtifactIDs.count)
        }

        let total = cpuScore * weights.cpuWeight
            + memoryScore * weights.memoryWeight
            + localityScore * weights.localityWeight
            + latencyScore * weights.latencyWeight
            + reliability * weights.reliabilityWeight
            + thermalScore * weights.thermalWeight
            + energyScore * weights.energyWeight

        let explanation = "CPU:\(String(format: "%.2f", cpuScore)) MEM:\(String(format: "%.2f", memoryScore)) LOC:\(String(format: "%.2f", localityScore)) LAT:\(String(format: "%.2f", latencyScore)) REL:\(String(format: "%.2f", reliability)) THM:\(String(format: "%.2f", thermalScore)) NRG:\(String(format: "%.2f", energyScore))"

        return SchedulerScore(
            nodeID: node.nodeID,
            total: total,
            computeScore: cpuScore,
            memoryScore: memoryScore,
            localityScore: localityScore,
            latencyScore: latencyScore,
            reliabilityScore: reliability,
            thermalScore: thermalScore,
            energyScore: energyScore,
            explanation: explanation
        )
    }

    private func averageReliability(for nodeID: NodeID) -> Double {
        guard let history = historicalReliability[nodeID], !history.isEmpty else { return 0.5 }
        return history.reduce(0, +) / Double(history.count)
    }

    private func energyScore(for node: NodeResourceDescriptor) -> Double {
        switch node.batteryState {
        case .full, .charging: return 1.0
        case .discharging: return 0.5
        case .unknown, .none: return 0.7
        }
    }
}
