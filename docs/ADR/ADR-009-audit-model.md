# ADR-009: Audit Model

## Status

Accepted

## Context

Critical actions must be auditable for security and debugging.

## Decision

- Append-only audit log with hash chain
- Each entry includes: actor, target, action, decision, result, hash
- Previous hash links entries for tamper evidence
- Stored locally, not transmitted by default
- No sensitive data (keys, passwords, clipboard content) logged

## Consequences

- Tamper-evident (not tamper-proof since owner controls system)
- Verifiable chain integrity
- Privacy-preserving (no secrets in log)
- Exportable for external analysis

## Verification

- Chain integrity check passes
- Tampered entry detected
- No secrets found in log via automated scan
