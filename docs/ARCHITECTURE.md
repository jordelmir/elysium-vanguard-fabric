# Elysium Vanguard Fabric — Architecture

## Overview

Elysium Vanguard Fabric is a sovereign local-first platform for controlling multiple computers from a central console, converting them into a distributed logical work infrastructure under the user's control.

## Core Principles

1. **Local-first**: All communication happens over LAN, Thunderbolt Bridge, or direct Ethernet
2. **Zero Trust**: Every action requires authentication and authorization
3. **No silent failures**: All errors are typed and surfaced
4. **Strict concurrency**: Swift 6 concurrency with actors and structured tasks
5. **Platform-portable**: Domain logic has zero Apple framework dependencies

## System Architecture

```
┌──────────────────────────────────────────────────────┐
│                 Vanguard Console                     │
│                                                      │
│  SwiftUI/AppKit UI                                  │
│  Remote Display (Metal renderer)                    │
│  Terminal UI                                        │
│  Node List & Management                            │
│  Telemetry Dashboard                               │
│  Session Controller                                 │
└───────────────────────┬──────────────────────────────┘
                        │
                  Vanguard Link
                        │
       authenticated + encrypted + versioned
                        │
┌───────────────────────▼──────────────────────────────┐
│                    Vanguard Node                     │
│                                                      │
│  ScreenCaptureKit → VideoToolbox H.264              │
│  CGEvent input dispatch                             │
│  PTY terminal + process supervisor                  │
│  Telemetry agent                                    │
│  Capability enforcement                             │
│  Audit log                                          │
└──────────────────────────────────────────────────────┘
```

## Package Structure

```
VanguardDomain        — Pure domain models, zero dependencies
VanguardProtocol      — Wire protocol framing and message types
VanguardTransport     — Transport abstraction and implementations
VanguardDiscovery     — Bonjour/mDNS service discovery
VanguardIdentity      — Device identity, keychain, pairing
VanguardSecurity      — Authorization and capability enforcement
VanguardPermissions   — macOS permission management
VanguardCapture       — Screen capture service
VanguardVideo         — Video encoding/decoding
VanguardInput         — Input capture and dispatch
VanguardTerminal      — PTY terminal management
VanguardProcesses     — Process supervision
VanguardTelemetry     — System metrics collection
VanguardAudit         — Audit logging
VanguardPersistence   — SQLite persistence layer
VanguardTestSupport   — Test helpers and mocks
```

## Dependency Direction

```
UI → Application → Domain ← Infrastructure adapters
```

The domain package never imports SwiftUI, AppKit, ScreenCaptureKit, VideoToolbox, Network, Metal, CoreGraphics, Security, or OSLog.

## Concurrency Model

- All mutable state lives in actors
- Transport uses `AsyncThrowingStream` for message delivery
- Capture streams are bounded with backpressure
- Terminal output uses ring buffers with configurable limits
- Input events are rate-limited and validated

## Transport Protocol

- Binary framing with magic bytes, version, type, flags, channel, sequence, and payload
- Network byte order (big-endian)
- TLS encryption (QUIC preferred, TCP fallback)
- Versioned protocol with incompatibility rejection
- Per-channel sequence numbers for deduplication

## Security Model

- Ed25519 signing keys for identity
- X25519 for key agreement
- Challenge-response pairing with 6-digit code
- Capability-based authorization
- Audit trail with hash chain
- No secrets in logs
