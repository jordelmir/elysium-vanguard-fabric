# AGENTS.md — Master Guide for Elysium Vanguard Fabric

## Project Overview

Elysium Vanguard Fabric is a sovereign local-first remote desktop and distributed computing platform. It unifies screens, applications, files, terminals, CPU/GPU/memory, compilers, and AI agents across authorized devices.

**Repository:** `jordelmir/elysium-vanguard-fabric` (private, SSH)
**Owner:** Jorge David Del Valle Miranda
**License:** Proprietary — Copyright © 2026

---

## Quick Start — Clone, Build, Run

### 1. Clone

```bash
git clone git@github.com:jordelmir/elysium-vanguard-fabric.git
cd elysium-vanguard-fabric
```

### 2. Build (CLI)

```bash
swift build                    # debug build
swift build -c release         # release build
swift test --parallel          # run all tests (~105 tests)
```

Both apps also build as macOS applications:

```bash
swift build --target VanguardConsoleMac   # builds the Console (M1 controller)
swift build --target VanguardNodeMac      # builds the Node (MacBook Pro 2016)
```

### 3. Open in Xcode

```bash
open Package.swift
```

In Xcode:
- Select `VanguardConsoleMac` scheme to build/run the Console app
- Select `VanguardNodeMac` scheme to build/run the Node app

### 4. Run the Apps

**Console (runs on Mac M1):**
```bash
open .build/arm64-apple-macosx/debug/VanguardConsoleMac.app
# OR open Xcode and press Cmd+R on VanguardConsoleMac scheme
```

**Node (runs on MacBook Pro 2016):**
```bash
open .build/arm64-apple-macosx/debug/VanguardNodeMac.app
# OR open Xcode and press Cmd+R on VanguardNodeMac scheme
```

### 5. Physical Test (Two Machines Required)

1. Start VanguardNodeMac on MacBook Pro 2016 (IP: local network)
2. Start VanguardConsoleMac on Mac M1
3. Console discovers Node via Bonjour (`_elysium-vanguard._tcp`)
4. Click "Pair" → Node shows pairing request → Approve
5. Console shows Node screen → Control with mouse/keyboard
6. Run for 30+ minutes → Disconnect network → Reconnect → Verify recovery

---

## Architecture — 8 Planes

```
1. Identity Plane    — Cryptographic identity, pairing, mTLS, capabilities
2. Control Plane     — Sessions, handshake, input, terminal, clipboard
3. Media Plane       — Screen capture, H.264 encode/decode, Metal render
4. Data Plane        — Files, artifacts, workspaces, chunks, hashes
5. Compute Plane     — Jobs, executors, scheduling, sandboxes
6. Intelligence Plane — AI agents, planners, policy, approval gates
7. Observability Plane — Events, metrics, traces, audit
8. Distribution Plane  — Updates, rollback, signing
```

---

## Repository Structure

```
Apps/
├── VanguardConsoleMac/    ← M1 controller app (SwiftUI, MenuBarExtra)
├── VanguardNodeMac/       ← MacBook Pro 2016 node app (SwiftUI, MenuBarExtra)
└── (VanguardCoordinatorServer/ — future, not yet created)

Packages/
├── VanguardDomain/        ← Platform types (720 lines, 30+ types, zero Apple imports)
├── VanguardProtocol/      ← Wire protocol, FabricMessageEnvelope, message types
├── VanguardIdentity/      ← CryptoKit identity service, key generation
├── VanguardSecurity/      ← AuthorizationGuard, SecurityAction, capability checks
├── VanguardDiscovery/     ← Bonjour service discovery (_elysium-vanguard._tcp)
├── VanguardTransport/     ← NetworkTransport, InMemoryTransport, flow control
├── VanguardSession/       ← SessionCoordinator, PipelineCoordinator
├── VanguardCapture/       ← ScreenCaptureKit capture service
├── VanguardVideo/         ← VideoToolbox encoder/decoder
├── VanguardRender/        ← Metal renderer (VideoMetalRenderer)
├── VanguardInput/         ← CGEvent input dispatch service
├── VanguardClipboard/     ← ClipboardService with loop protection (SHA-256)
├── VanguardTerminal/      ← POSIX terminal with exit status, PTY
├── VanguardArtifacts/     ← ArtifactManifest, chunking, transfer, local store
├── VanguardWorkspace/     ← Workspace snapshots, change sets
├── VanguardCompute/       ← JobSpec, NativeProcessExecutor, JobState (13 states)
├── VanguardScheduler/     ← FabricScheduler with 8-dimension scoring model
├── VanguardExecutors/     ← RemoteJobExecutor protocol, checkpoints
├── VanguardAgents/        ← AgentPipeline, AgentPlan, DAG validation
├── VanguardPolicy/        ← SecurityPolicyAction (maps capabilities)
├── VanguardObservability/ ← FabricEventLog actor, 19 event types
├── VanguardUpdates/       ← UpdateService with rollback
├── VanguardTestSupport/   ← Mocks for testing
└── [12 more packages]     ← Audio, Audit, Files, Permissions, Persistence, etc.

Protocol/
├── specification.md       ← Full protocol spec (112 lines)
├── versioning.md          ← Version negotiation rules
├── framing.md             ← Header/envelope structures
├── security.md            ← TLS, identity, pairing, capability tokens
├── errors.md              ← 27 error codes
└── test-vectors/README.md ← Binary test vectors

Docs/
├── ADR/                   ← ADR-001 through ADR-013
├── physical-validation/   ← 8 test categories with sign-off
├── ARCHITECTURE.md, SECURITY_MODEL.md, ROADMAP.md, etc.
└── KNOWN_LIMITATIONS.md
```

---

## Current State — What Works

### Build Status
- ✅ `swift build` — clean, zero errors
- ✅ `swift test` — 105 tests passing, 0 failures
- ✅ VanguardConsoleMac builds as macOS app
- ✅ VanguardNodeMac builds as macOS app

### Implemented (Phases 0–9 of Master Order)

| Block | Status | Description |
|-------|--------|-------------|
| 1. Domain Types | ✅ | 30+ types in Platform.swift (720 lines): TrustStatus, BatteryState, NodeThermalState, GPUDescriptor, ExecutorKind (9 cases), JobPriority, RetryPolicy, JobSecurityPolicy, ToolchainRequirement, AgentRisk, AgentAction (15 cases), SecretReference, etc. |
| 2. JobSpec + NodeResourceDescriptor | ✅ | Full types with all fields from master order |
| 3. Scheduler | ✅ | FabricScheduler with 8-dimension scoring: CPU, memory, locality, latency, reliability, thermal, energy, configurable weights |
| 4. Agent Pipeline | ✅ | AgentPipeline actor: Planner → Policy → Validator → Approval → Compiler, DAG cycle detection, AgentRisk (5 levels) |
| 5. FabricMessageEnvelope | ✅ | 48-byte binary envelope, magic 0x45564642, big-endian, sessionID routing |
| 6. Protocol Docs | ✅ | specification.md, versioning.md, framing.md, security.md, errors.md, test-vectors/ |
| 7. ADR-010 to ADR-013 | ✅ | Scheduler strategy, agent approval, relay E2E, update/rollback |
| 8. VanguardUpdates | ✅ | UpdateService actor with state machine and rollback |
| 9. Security + Chaos Tests | ✅ | 16 new tests: path traversal, replay, oversized payload, log flooding, capability completeness, disconnect/reconnect, rapid cycling, large messages, job security |
| 10. Physical Validation | ✅ | 8 test categories with sign-off checklist |

### Media Pipeline
- ✅ ScreenCaptureKit capture (SCStream, SCContentFilter)
- ✅ VideoToolbox H.264 encoder (VTCompressionSession)
- ✅ VideoToolbox decoder (VTDecompressionSession)
- ✅ Metal rendering (MTLDevice, MTKView, MTLRenderPipelineState)
- ✅ CGEvent input dispatch with coordinate mapping
- ✅ Flow control with ACK-based backpressure

### Identity & Security
- ✅ CryptoKit identity service (Ed25519, P256)
- ✅ TLS certificate manager with fingerprint pinning
- ✅ AuthorizationGuard with capability-based access control
- ✅ CapabilityGrant (signed token with expiration, nonce, signature)
- ✅ FabricCapability (25 cases)

### Transport
- ✅ NetworkTransport (TCP + TLS 1.3)
- ✅ InMemoryTransport (for testing)
- ✅ Bonjour discovery (_elysium-vanguard._tcp)
- ✅ Flow control with window-based backpressure
- ✅ Heartbeat with RTT measurement

---

## What's Missing — Next Steps

### Priority 1: Identity Types (5 types)
The master order specifies dedicated identity types that don't exist yet:
- `SessionIdentity` — per-session cryptographic identity
- `JobIdentity` — per-job signed identity
- `ArtifactIdentity` — per-artifact producer identity
- `AgentIdentity` — per-agent signed identity
- `ApplicationIdentity` — per-app signed identity

These should go in `Packages/VanguardDomain/Sources/VanguardDomain/Platform.swift`.

### Priority 2: Coordinator Server App
`Apps/VanguardCoordinatorServer/` does not exist. This is the Oracle Free server component (Rendezvous, relay, job coordinator). Can be deferred since LAN-only mode works without it.

### Priority 3: UI Panels (Section 40)
The Console app has a flat node sidebar but lacks the dedicated panels from the master order:
- **Nodos panel** — node list with status indicators
- **Jobs panel** — active/queued/completed jobs
- **Resources panel** — CPU, RAM, storage per node
- **Workspace panel** — shared project view
- **Terminal panel** — terminal sessions
- **Agents panel** — AI agent status
- **Security panel** — capabilities, audit log
- **Settings panel** — configuration

### Priority 4: Remote Window Capture (Section 22)
Currently captures full displays. Need:
- Per-window capture (SCContentFilter with window list)
- WindowGeometryMapper for coordinate mapping
- RemoteApplicationDescriptor, RemoteWindowDescriptor

### Priority 5: Shared Workspace Sync (Section 21)
WorkspaceSnapshot exists but bidirectional sync with conflict resolution is not implemented. Currently one-directional (owner → workers).

### Priority 6: Distributed Builds (Section 18)
The job execution pipeline exists but the actual multi-node build workflow (ARM + Intel → universal binary → lipo) needs physical testing and integration.

---

## Code Style Rules

1. **Swift 6 strict concurrency** — actors for state, `Sendable` conformance, no data races
2. **No comments** unless explicitly requested
3. **No force unwraps** in production code
4. **Typed errors** per subsystem (every error is an enum)
5. **Protocols at boundaries** — test with mocks
6. **Value types by default** — structs, not classes
7. **Domain package has zero Apple framework imports** (except CapturedVideoFrame)
8. **Every error is typed and surfaced** — no silent failures
9. **No secrets in logs** — redact sensitive data
10. **Capability-based authorization** — every sensitive action requires a capability
11. **Audit all critical actions** — log to FabricEventLog
12. **Test before marking complete** — unit + integration + security tests

---

## Testing

```bash
swift test --parallel                    # run all ~105 tests
swift test --filter SecurityTests        # security tests only
swift test --filter ChaosTests           # chaos/disconnect tests only
swift test --filter JobSecurityTests     # job security tests only
swift test --filter FabricSchedulerTests # scheduler tests only
```

### Test Suites
- ArtifactTransferTests (4 tests)
- BonjourDiscoveryServiceTests (2 tests)
- CGEventInputDispatchServiceTests (7 tests)
- ChannelMultiplexerTests (5 tests)
- ChaosTests (3 tests)
- CryptoKitIdentityServiceTests (5 tests)
- ErrorsTests (5 tests)
- FabricEventLogTests (4 tests)
- FabricSchedulerTests (3 tests)
- FilePersistenceServiceTests (5 tests)
- FlowControllerTests (4 tests)
- POSIXTerminalServiceTests (3 tests)
- PlatformTests (5 tests)
- ProtocolFramingTests (7 tests)
- SecurityServiceTests (3 tests)
- SecurityTests (8 tests)
- TransportComponentTests (5 tests)
- InMemoryTransportTests (7 tests)
- JobExecutorTests (3 tests)
- JobSecurityTests (6 tests)
- VideoToolboxTests (5 tests)
- WorkspaceTests (3 tests)

---

## Key Design Decisions

### Protocol
- **Magic:** `0x45 0x56 0x46 0x42` ("EVFB")
- **Envelope:** 48 bytes, big-endian
- **Service type:** `_elysium-vanguard._tcp`
- **Node port:** 49494
- **Version:** 1.0 (major.minor)

### Security
- **Zero Trust** — every action requires identity + capability
- **mTLS** with certificate pinning
- **CapabilityGrant** signed tokens with expiration
- **No command concatenation** — use Process.executableURL/arguments
- **Sandboxed jobs** in `~/Library/Application Support/ElysiumVanguardFabric/Jobs/<id>/`

### Concurrency
- **Actors** for all mutable state (FabricScheduler, AgentPipeline, FabricEventLog, UpdateService, etc.)
- **AsyncThrowingStream** for video frames, job events, transport messages
- **NSLock.withLock** for non-actor synchronous critical sections (deprecated pattern — prefer actors)

---

## Environment

- **Deployment target:** macOS 12.0 (Monterey) — MacBook Pro 2016 maxes out at Monterey 12.x
- **Swift version:** 6.0
- **Xcode:** 16.x
- **Hardware:** Mac M1 (Console) + MacBook Pro 2016 (Node)
- **Network:** LAN only for v0.1

---

## Git Convention

```
feat:      new feature
fix:       bug fix
security:  security improvement
protocol:  protocol change
video:     media pipeline
compute:   job execution
scheduler: scheduling logic
agent:     AI agent
test:      test addition
docs:      documentation
refactor:  code restructuring
```

Every commit must:
- Compile
- Pass all tests
- Resolve one coherent unit
- Not introduce duplication
- Include tests when applicable

---

## Common Issues

### Signal 5 (SIGTRAP) in FrameDecoderTests
Pre-existing crash in test subprocess. Does not affect test results. The test framework catches the signal and reports "unexpected signal code 5" but no tests fail.

### Bonjour Continuation Misuse Warnings
Pre-existing warnings from NWBrowser/NWListener continuation handling. Does not affect functionality.

### Data Extension Conflicts
`FabricMessageEnvelope.swift` previously conflicted with `ProtocolFraming.swift` Data extensions. Now uses `withUnsafeBytes` instead of custom Data extensions to avoid naming conflicts.

### NodeAction Naming
Three `NodeAction` enums existed across VanguardDomain, VanguardPolicy, and VanguardSecurity. VanguardSecurity's was renamed to `SecurityAction` to avoid ambiguity. VanguardPolicy's was replaced with `SecurityPolicyAction`.
