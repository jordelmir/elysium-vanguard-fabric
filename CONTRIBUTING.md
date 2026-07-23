# Contributing to Elysium Vanguard Fabric

## Requirements

- macOS 12.3+
- Xcode 14+
- Swift 6

## Development

```bash
./Scripts/bootstrap.sh
```

## Building

```bash
./Scripts/build-all.sh
```

## Testing

```bash
./Scripts/test-all.sh
```

## Code Standards

- Swift 6 strict concurrency
- No force unwraps in production code
- Typed errors for each subsystem
- Tests for all new functionality
- No secrets in source code
- Protocol-based abstractions at boundaries

## Pull Requests

1. All tests must pass
2. No secrets in diff
3. Domain changes require ADR
4. Breaking protocol changes require version bump
