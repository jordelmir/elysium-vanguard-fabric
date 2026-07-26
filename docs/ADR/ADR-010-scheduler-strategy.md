# ADR-010: Scheduler Strategy

## Status

Accepted

## Context

The Fabric needs a scheduler to select the best node for each job. Naive selection by CPU count is insufficient for a distributed platform.

## Decision

Implement a weighted scoring scheduler with:

1. **Hard constraints** - mandatory requirements that filter out ineligible nodes
2. **Soft scoring** - weighted scoring of eligible nodes

### Hard Constraints
- Architecture match
- OS family match
- Minimum CPU cores
- Minimum memory
- Minimum storage
- Toolchain availability
- Capability requirements
- Thermal state limits
- Power requirements (AC vs battery)
- Excluded nodes

### Soft Scoring Weights (default)
- CPU availability: 25%
- Memory availability: 15%
- Data locality: 20%
- Network latency: 10%
- Reliability history: 15%
- Thermal state: 10%
- Energy state: 5%

### Data Structures
- `NodeResourceDescriptor`: Full node capabilities
- `HardConstraints`: Mandatory requirements
- `SchedulerWeights`: Configurable scoring weights
- `SchedulerScore`: Per-node scoring result with explanation

## Alternatives Considered

1. Simple CPU-count selection - rejected, too naive
2. Round-robin - rejected, ignores node differences
3. Random selection - rejected, no optimization
4. Machine learning - rejected, over-engineering for v1

## Consequences

- Scheduler is deterministic given same inputs
- Weights are configurable and auditable
- All scheduling decisions include explanations
- Historical reliability tracking improves over time

## Risks

- Weight tuning may require adjustment based on real-world usage
- Data locality scoring requires artifact location tracking
