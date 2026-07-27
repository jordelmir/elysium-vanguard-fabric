import Foundation
import VanguardDomain
import VanguardCompute

// MARK: - Agent Plan

public struct AgentPlan: Codable, Sendable {
    public let planID: UUID
    public let objective: String
    public let steps: [AgentPlanStep]
    public let requiredCapabilities: Set<FabricCapability>
    public let estimatedRisk: AgentRisk
    public let requiresHumanApproval: Bool
    public let createdAt: Date

    public init(planID: UUID = UUID(), objective: String, steps: [AgentPlanStep], requiredCapabilities: Set<FabricCapability> = [], estimatedRisk: AgentRisk = .low, requiresHumanApproval: Bool = false, createdAt: Date = Date()) {
        self.planID = planID
        self.objective = objective
        self.steps = steps
        self.requiredCapabilities = requiredCapabilities
        self.estimatedRisk = estimatedRisk
        self.requiresHumanApproval = requiresHumanApproval
        self.createdAt = createdAt
    }
}

// MARK: - Agent Plan Step

public struct AgentPlanStep: Codable, Sendable {
    public let stepID: UUID
    public let description: String
    public let action: AgentAction
    public let dependencies: [UUID]
    public let rollbackAction: AgentAction?
    public let timeoutSeconds: TimeInterval
    public let retryCount: Int

    public init(stepID: UUID = UUID(), description: String, action: AgentAction, dependencies: [UUID] = [], rollbackAction: AgentAction? = nil, timeoutSeconds: TimeInterval = 300, retryCount: Int = 0) {
        self.stepID = stepID
        self.description = description
        self.action = action
        self.dependencies = dependencies
        self.rollbackAction = rollbackAction
        self.timeoutSeconds = timeoutSeconds
        self.retryCount = retryCount
    }
}

// MARK: - Plan Validation Result

public struct PlanValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let resolvedCapabilities: Set<FabricCapability>

    public init(isValid: Bool, errors: [String] = [], warnings: [String] = [], resolvedCapabilities: Set<FabricCapability> = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.resolvedCapabilities = resolvedCapabilities
    }
}

// MARK: - Policy Evaluation Result

public struct PolicyEvaluationResult: Sendable {
    public let approved: Bool
    public let reason: String
    public let requiredApprovals: [String]
    public let riskLevel: AgentRisk

    public init(approved: Bool, reason: String = "", requiredApprovals: [String] = [], riskLevel: AgentRisk = .low) {
        self.approved = approved
        self.reason = reason
        self.requiredApprovals = requiredApprovals
        self.riskLevel = riskLevel
    }
}

// MARK: - Execution Context

public struct ExecutionContext: Sendable {
    public let planID: UUID
    public let stepID: UUID
    public let nodeID: NodeID
    public let sessionID: UUID

    public init(planID: UUID, stepID: UUID, nodeID: NodeID, sessionID: UUID) {
        self.planID = planID
        self.stepID = stepID
        self.nodeID = nodeID
        self.sessionID = sessionID
    }
}

// MARK: - Agent Pipeline

public actor AgentPipeline {
    private var activePlan: AgentPlan?
    private var pipelineState: PipelineState = .idle
    private var stepResults: [UUID: StepResult] = [:]

    public init() {}

    public func startPlan(_ plan: AgentPlan) {
        activePlan = plan
        pipelineState = .validating
    }

    public enum PipelineState: Sendable {
        case idle
        case planning
        case validating
        case policyEvaluation
        case awaitingApproval
        case compilingJobs
        case executing
        case completed
        case failed(String)
        case cancelled
    }

    public struct StepResult: Sendable {
        public let stepID: UUID
        public let succeeded: Bool
        public let output: String
        public let error: String?
        public let duration: TimeInterval

        public init(stepID: UUID, succeeded: Bool, output: String = "", error: String? = nil, duration: TimeInterval = 0) {
            self.stepID = stepID
            self.succeeded = succeeded
            self.output = output
            self.error = error
            self.duration = duration
        }
    }

    public func validatePlan(_ plan: AgentPlan) -> PlanValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        if plan.steps.isEmpty {
            errors.append("Plan has no steps")
        }

        let stepIDs = Set(plan.steps.map { $0.stepID })
        for step in plan.steps {
            for dep in step.dependencies {
                if !stepIDs.contains(dep) {
                    errors.append("Step \(step.stepID) depends on non-existent step \(dep)")
                }
            }
        }

        if hasCycle(steps: plan.steps) {
            errors.append("Plan has circular dependencies")
        }

        if plan.steps.count > 100 {
            warnings.append("Plan has more than 100 steps")
        }

        let allCapabilities = Set(plan.steps.flatMap { step -> Set<FabricCapability> in
            switch step.action {
            case .submitJob: return [.jobSubmit]
            case .transferArtifact: return [.artifactWrite]
            case .readFile: return [.fileRead]
            case .writeFile: return [.fileWrite]
            case .deleteFile: return [.fileDelete]
            case .readClipboard: return [.clipboardRead]
            case .writeClipboard: return [.clipboardWrite]
            case .openTerminal: return [.terminalOpen]
            case .captureScreen: return [.screenView]
            case .restartNode: return [.powerControl]
            case .cancelJob: return [.jobCancel]
            case .scheduleJob: return [.jobSubmit]
            default: return []
            }
        })

        return PlanValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            resolvedCapabilities: allCapabilities
        )
    }

    public func evaluatePolicy(plan: AgentPlan, availableCapabilities: Set<FabricCapability>) -> PolicyEvaluationResult {
        let missing = plan.requiredCapabilities.subtracting(availableCapabilities)
        if !missing.isEmpty {
            return PolicyEvaluationResult(
                approved: false,
                reason: "Missing capabilities: \(missing.map(\.displayName).joined(separator: ", "))",
                riskLevel: plan.estimatedRisk
            )
        }

        if plan.requiresHumanApproval {
            return PolicyEvaluationResult(
                approved: false,
                reason: "Plan requires human approval",
                requiredApprovals: [plan.objective],
                riskLevel: plan.estimatedRisk
            )
        }

        if plan.estimatedRisk == .destructive {
            return PolicyEvaluationResult(
                approved: false,
                reason: "Destructive operations require explicit approval",
                requiredApprovals: ["destructive-operation-\(plan.planID)"],
                riskLevel: .destructive
            )
        }

        return PolicyEvaluationResult(approved: true, riskLevel: plan.estimatedRisk)
    }

    public func approvePlan(_ planID: UUID) {
        if activePlan?.planID == planID {
            pipelineState = .executing
        }
    }

    public func cancelPlan() {
        pipelineState = .cancelled
        activePlan = nil
        stepResults.removeAll()
    }

    public func currentState() -> PipelineState { pipelineState }
    public func currentPlan() -> AgentPlan? { activePlan }
    public func results() -> [UUID: StepResult] { stepResults }

    public func recordStepResult(_ result: StepResult) {
        stepResults[result.stepID] = result
    }

    // MARK: - DAG Validation

    private func hasCycle(steps: [AgentPlanStep]) -> Bool {
        var visited = Set<UUID>()
        var stack = Set<UUID>()

        func dfs(_ stepID: UUID) -> Bool {
            if stack.contains(stepID) { return true }
            if visited.contains(stepID) { return false }
            visited.insert(stepID)
            stack.insert(stepID)
            if let step = steps.first(where: { $0.stepID == stepID }) {
                for dep in step.dependencies {
                    if dfs(dep) { return true }
                }
            }
            stack.remove(stepID)
            return false
        }

        for step in steps {
            if dfs(step.stepID) { return true }
        }
        return false
    }
}
