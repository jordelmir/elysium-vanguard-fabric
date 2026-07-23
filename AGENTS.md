# AGENTS.md

## Project

Elysium Vanguard Fabric — Sovereign local-first remote control platform.

## Code Style

- Swift 6 with strict concurrency
- No comments unless requested
- No force unwraps in production code
- Typed errors per subsystem
- Actors for concurrent state
- Protocols at boundaries
- Value types by default

## Build & Test

```bash
swift build
swift test --parallel
```

## Rules

1. Domain package has zero Apple framework imports
2. Every error is typed and surfaced
3. No silent failures
4. No secrets in logs
5. Capability-based authorization
6. Audit all critical actions
7. Test before marking complete
