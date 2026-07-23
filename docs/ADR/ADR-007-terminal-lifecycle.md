# ADR-007: Terminal Lifecycle

## Status

Accepted

## Context

Remote terminal must survive network disconnections.

## Decision

- PTY created on node with fork/exec
- Terminal session independent of transport session
- Ring buffer (8-32 MiB configurable) stores output
- Console sends offset on reconnect, node retransmits missing data
- Process continues running during disconnect
- Terminal closed only by user action, process exit, or node shutdown

## Consequences

- Long-running tasks survive network issues
- No duplicate commands on reconnect
- Bounded memory usage
- Scrollback available after reconnect

## Verification

- Terminal opens and runs shell
- Process continues during disconnect
- Output recovered after reconnect
- No duplicate execution
- Terminal closes cleanly
