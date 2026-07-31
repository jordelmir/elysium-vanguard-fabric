# Contributing to Elysium Vanguard Fabric

## Requirements

- macOS 12.0+ (Monterey or later)
- Xcode 16.x
- Swift 6.0

## Development

```bash
./Scripts/bootstrap.sh
```

## Building

```bash
./build.sh
```

This builds all 3 targets: VanguardConsoleMac, VanguardNodeMac, VanguardCoordinatorServer.

## Testing

```bash
swift test --parallel    # 250 tests (76 XCTest + 174 Swift Testing)
```

## Code Standards

- Swift 6 strict concurrency (actors for mutable state, Sendable conformance)
- No force unwraps in production code
- Typed errors for each subsystem (every error is an enum)
- Tests for all new functionality
- No secrets in source code
- Protocol-based abstractions at boundaries
- Domain package minimizes Apple imports (Foundation only; CoreMedia/CoreVideo for CapturedVideoFrame)

## Pull Requests

1. All tests must pass
2. No secrets in diff
3. Domain changes require ADR
4. Breaking protocol changes require version bump
