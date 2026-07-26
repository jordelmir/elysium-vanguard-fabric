# ADR-011: Agent Approval Model

## Status

Accepted

## Context

The Intelligence Plane needs to coordinate automated actions while maintaining security and user control.

## Decision

Implement a multi-stage approval pipeline:

```
User Intent → Planner → Policy Evaluator → Plan Validator → Approval Gate → Job Compiler → Observer
```

### Risk Levels
- **readOnly**: Auto-approved, no human intervention
- **low**: Auto-approved with audit logging
- **moderate**: Requires human approval
- **high**: Requires human approval with explicit confirmation
- **destructive**: Requires explicit human approval, never auto-approved

### Pipeline Stages

1. **Planner**: Generates `AgentPlan` with steps, capabilities, and risk assessment
2. **Policy Evaluator**: Checks capabilities, validates against security policy
3. **Plan Validator**: Checks for cycles, missing dependencies, resource limits
4. **Approval Gate**: Based on risk level, either auto-approve or require human
5. **Job Compiler**: Converts approved plan steps to executable jobs
6. **Observer**: Monitors execution, handles failures, triggers rollbacks

### Critical Rule

The AI must never be able to convert free text directly into privileges.

```
Text → Plan → Policy → Capability Validation → Approval → Execution
```

## Alternatives Considered

1. Fully automated approval - rejected, too risky
2. Manual approval for everything - rejected, too slow
3. Whitelist-only actions - rejected, too restrictive

## Consequences

- All agent actions are auditable
- Destructive operations always require human approval
- Plans can be inspected before execution
- Rollback actions are predefined per step

## Risks

- Approval latency may slow time-critical operations
- Policy engine complexity may introduce bugs
