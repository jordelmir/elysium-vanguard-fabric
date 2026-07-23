# ADR-001: Platform Boundaries

## Status

Accepted

## Context

Elysium Vanguard Fabric needs to support multiple platforms (macOS Intel, macOS Apple Silicon, Linux, Windows, Android, cloud servers). The domain logic must remain portable and not coupled to any specific platform framework.

## Decision

- Domain package (`VanguardDomain`) has zero imports from Apple frameworks
- All platform-specific code lives in adapter packages or app targets
- Protocols define service boundaries; concrete implementations are platform-specific
- UI packages import domain but not vice versa

## Consequences

- Domain logic is testable on any platform
- New platforms require new adapter implementations, not domain changes
- Clear separation of concerns
- Slightly more boilerplate for protocol definitions

## Verification

- `VanguardDomain` compiles without any `import SwiftUI`, `import AppKit`, `import ScreenCaptureKit`, etc.
- All domain models are `Codable` and `Sendable`
