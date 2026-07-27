import SwiftUI
import VanguardUI
import VanguardDomain
import VanguardAgents

struct AgentsPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var showSubmitPlan = false
    @State private var planObjective = ""
    @State private var planSteps = ""

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            agentContent
        }
        .sheet(isPresented: $showSubmitPlan) { submitPlanSheet }
    }

    private var panelHeader: some View {
        HStack {
            Label("AGENTS", systemImage: "brain.head.profile")
                .font(DS.Typography.micro)
                .foregroundColor(Color.purple)
            Spacer()
            Text("\(state.agentPlans.count) plans")
                .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            ElysiumButton(title: "New Plan", icon: "plus", color: Color.purple, style: .bordered) { showSubmitPlan = true }
                .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
    }

    private var agentContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                pipelineStatus
                Divider().background(Color.white.opacity(0.04))
                if state.agentPlans.isEmpty {
                    emptyState
                } else {
                    ForEach(state.agentPlans) { plan in
                        PlanCard(plan: plan)
                    }
                }
            }.padding(DS.Spacing.md)
        }
    }

    private var pipelineStatus: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Text("PIPELINE STATUS").font(DS.Typography.micro).foregroundColor(Color.purple)
                Spacer()
            }
            HStack(spacing: DS.Spacing.xs) {
                PipelineStep(name: "Planner", icon: "brain", color: Color.purple)
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(DS.Colors.textQuaternary)
                PipelineStep(name: "Policy", icon: "lock.shield", color: DS.Colors.info)
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(DS.Colors.textQuaternary)
                PipelineStep(name: "Validator", icon: "checkmark.seal", color: DS.Colors.success)
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(DS.Colors.textQuaternary)
                PipelineStep(name: "Approval", icon: "person.badge.key", color: DS.Colors.warning)
                Image(systemName: "arrow.right").font(.system(size: 10)).foregroundColor(DS.Colors.textQuaternary)
                PipelineStep(name: "Compiler", icon: "gearshape.2", color: DS.Colors.accent)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 40)
            Image(systemName: "brain.head.profile").font(.system(size: 28)).foregroundColor(DS.Colors.textQuaternary)
            Text("No agent plans").font(DS.Typography.subheadline).foregroundColor(DS.Colors.textTertiary)
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private var submitPlanSheet: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("SUBMIT AGENT PLAN").font(DS.Typography.micro).foregroundColor(Color.purple)
            TextField("Objective (e.g. deploy v2.1 to all nodes)", text: $planObjective).textFieldStyle(.roundedBorder)
            TextField("Steps (comma separated)", text: $planSteps).textFieldStyle(.roundedBorder)
            HStack {
                ElysiumButton(title: "Cancel", icon: "xmark", color: DS.Colors.textTertiary, style: .bordered) { showSubmitPlan = false }
                ElysiumButton(title: "Submit", icon: "brain.head.profile", color: Color.purple) {
                    guard !planObjective.isEmpty else { return }
                    let steps = planSteps.isEmpty ? [] : planSteps.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    state.submitAgentPlan(objective: planObjective, steps: steps)
                    planObjective = ""; planSteps = ""; showSubmitPlan = false
                }
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 450)
    }
}

struct PipelineStep: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
            }
            Text(name).font(DS.Typography.micro).foregroundColor(DS.Colors.textQuaternary)
        }
    }
}

struct PlanCard: View {
    let plan: ConsoleAppState.TrackedAgentPlan
    @State private var isHovered = false

    private var stateColor: Color {
        switch plan.state {
        case .idle: return DS.Colors.textTertiary
        case .validating, .planning, .policyEvaluation: return DS.Colors.info
        case .awaitingApproval, .compilingJobs: return DS.Colors.warning
        case .executing: return Color.purple
        case .completed: return DS.Colors.success
        case .failed: return DS.Colors.error
        case .cancelled: return DS.Colors.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: iconForState(plan.state))
                .font(.system(size: 14)).foregroundColor(stateColor)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(plan.plan.objective).font(DS.Typography.headline).foregroundColor(DS.Colors.textPrimary)
                Text(stateLabel(plan.state)).font(DS.Typography.micro).foregroundColor(stateColor)
            }
            Spacer()
        }
        .padding(DS.Spacing.md)
        .glass(style: isHovered ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.lg)
        .adaptiveBorder(highlighted: isHovered)
        .onHover { isHovered = $0 }
        .animation(DS.Animation.springFast, value: isHovered)
    }

    private func iconForState(_ s: AgentPipeline.PipelineState) -> String {
        switch s {
        case .completed: return "checkmark.circle.fill"
        case .failed, .cancelled: return "xmark.circle.fill"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private func stateLabel(_ s: AgentPipeline.PipelineState) -> String {
        switch s {
        case .idle: return "IDLE"
        case .planning: return "PLANNING"
        case .validating: return "VALIDATING"
        case .policyEvaluation: return "POLICY EVAL"
        case .awaitingApproval: return "AWAITING APPROVAL"
        case .compilingJobs: return "COMPILING"
        case .executing: return "EXECUTING"
        case .completed: return "COMPLETED"
        case .failed(let err): return "FAILED: \(err)"
        case .cancelled: return "CANCELLED"
        }
    }
}
