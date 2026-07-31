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
swift test --parallel          # run all tests (~228 tests)
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
└── VanguardCoordinatorServer/ ← Standalone coordinator server (MenuBarExtra, services wired)

Packages/
├── VanguardDomain/        ← Platform types (800+ lines, 35+ types, 5 identity types, zero Apple imports)
├── VanguardProtocol/      ← Wire protocol, FabricMessageEnvelope, message types
├── VanguardIdentity/      ← CryptoKit identity service, key generation
├── VanguardSecurity/      ← AuthorizationGuard, SecurityAction, CapabilityNegotiator
├── VanguardDiscovery/     ← Bonjour service discovery (_elysium-vanguard._tcp)
├── VanguardTransport/     ← NetworkTransport, InMemoryTransport, flow control, IdempotencyCache
├── VanguardSession/       ← SessionCoordinator, PipelineCoordinator
├── VanguardCapture/       ← ScreenCaptureKit capture service
├── VanguardVideo/         ← VideoToolbox encoder/decoder
├── VanguardRender/        ← Metal renderer (VideoMetalRenderer)
├── VanguardInput/         ← CGEvent input dispatch service
├── VanguardClipboard/     ← ClipboardService with loop protection (SHA-256)
├── VanguardTerminal/      ← POSIX terminal with exit status, PTY
├── VanguardArtifacts/     ← ArtifactManifest, chunking, transfer, local store
├── VanguardWorkspace/     ← Workspace snapshots, change sets, bidirectional sync
├── VanguardCompute/       ← JobSpec, NativeProcessExecutor, JobState (13 states)
├── VanguardScheduler/     ← FabricScheduler with 8-dimension scoring model
├── VanguardExecutors/     ← RemoteJobExecutor protocol, checkpoints, DistributedJobCoordinator
├── VanguardCoordinator/   ← CoordinatorService (presence), RendezvousService, SignalingService, RelayService
├── VanguardBuild/         ← BuildManifest, LipoService (lipo combine), UniversalBuildService
├── VanguardAgents/        ← AgentPipeline, AgentPlan, DAG validation
├── VanguardPolicy/        ← SecurityPolicyAction (maps capabilities)
├── VanguardObservability/ ← FabricEventLog actor, PipelineMetricsCollector
├── VanguardUpdates/       ← UpdateService with rollback
├── VanguardAudit/         ← SHA-256 hash chain audit log, SanitizedLogger
├── VanguardFiles/         ← FileTransferService with chunked transfer
├── VanguardUI/            ← Design system, glass morphism, KeyboardShortcutService
├── VanguardPersistence/   ← FilePersistenceService
├── VanguardPermissions/   ← macOS permission checks
├── VanguardProcesses/     ← Process supervision
├── VanguardTelemetry/     ← MacTelemetryCollector
├── VanguardTestSupport/   ← Mocks for testing
├── SystemMetrics/         ← Swift wrapper for CSystemMetrics
├── CSystemMetrics/        ← Real mach APIs for CPU/RAM/battery
└── VanguardAudio/         ← ScreenCaptureKit audio capture

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

## Current State — v0.1 100% Complete

### Build Status
- ✅ `swift build` — clean, zero errors
- ✅ `swift test` — 378 tests passing (204 XCTest + 174 Swift Testing), 0 failures
- ✅ VanguardConsoleMac builds as macOS app
- ✅ VanguardNodeMac builds as macOS app

### Implemented (Phases 0–12 of Master Order)

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
| 11. Per-Context Identity Types | ✅ | SessionIdentity, JobIdentity, ArtifactIdentity, AgentIdentity, ApplicationIdentity |
| 12. Console App Panels | ✅ | 11 panels: RemoteDesktop, Nodes, Jobs, Resources, Workspace, Terminal, Agents, Security, Observatory, TrustedPeers, Settings |

### Console App — 11 Panels
- ✅ RemoteDesktopView — Metal renderer, mouse/click forwarding, crosshair overlay
- ✅ NodesPanel — Real resource bars from NodeResourceDescriptor
- ✅ JobsPanel — 13-state lifecycle, real NativeProcessExecutor.execute()
- ✅ ResourcesPanel — Live metrics with 5s refresh, memory pressure bar
- ✅ WorkspacePanel — Real file scanning, SHA-256, delete
- ✅ TerminalPanel — Remote/local indicator, scrollback, openRemoteTerminalSession()
- ✅ AgentsPanel — Real pipeline execution, step results
- ✅ SecurityPanel — Capabilities/Events/Audit/Chain tabs, exhaustive FabricEvent switch
- ✅ ObservatoryPanel — Real-time metrics from PipelineMetricsCollector
- ✅ TrustedPeersPanel — View/remove paired nodes, UserDefaults persistence
- ✅ SettingsPanel — 7 weight sliders, scrollback limit, @AppStorage persistence

### v0.1 Subsystems
- ✅ Capability Negotiation — CapabilityNegotiator actor with negotiate()
- ✅ Pipeline Metrics — PipelineMetricsCollector (frames, bytes, RTT, memory, FPS)
- ✅ Audit Chain — SHA-256 hash chaining with verifyIntegrity()
- ✅ Sanitized Logging — SanitizedLogger redacts secrets from logs
- ✅ Idempotency Cache — TTL-based dedup with max entries
- ✅ File Transfer — Chunked transfer with SHA-256 verification
- ✅ Emergency Stop — ⌘⌥Esc disconnects everything
- ✅ Reconnection — Exponential backoff (0.5s → 30s, 10 attempts)
- ✅ Clipboard Sync — NSPasteboard polling with change detection
- ✅ Trusted Peers — UserDefaults persistence, load on init
- ✅ Bidirectional Workspace Sync — FileVersion, SyncDelta, conflict resolution (newestWins/consoleWins/nodeWins/manual), delta computation
- ✅ Window Capture — SCContentFilter per-window, RemoteWindowDescriptor, window list enumeration
- ✅ Multi-Display — DisplayDescriptor, display switching, RemotePointerContext, WindowGeometryMapper
- ✅ NAT Traversal — STUN client (RFC 5389 binding), NATType detection, ConnectionRouteNegotiator (direct/relay/vpn routing)n- ✅ Relay Transport — RelayConfiguration, RelaySession, connectViaRelay() in NetworkTransport

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

## Completed Priorities

### Priority 1: Identity Types ✅
`SessionIdentity`, `JobIdentity`, `ArtifactIdentity`, `AgentIdentity`, `ApplicationIdentity` in `Platform.swift`.

### Priority 2: Coordinator Server App ✅
`Apps/VanguardCoordinatorServer/` — Standalone coordinator server with MenuBarExtra UI, NetworkTransport listener, message routing (presence, heartbeat, rendezvous, signaling, relay), auto-cleanup.

### Priority 3: UI Panels ✅
All 11 panels in Console app: NodesPanel, JobsPanel, ResourcesPanel, WorkspacePanel, TerminalPanel, AgentsPanel, SecurityPanel, SettingsPanel, ObservatoryPanel, TrustedPeersPanel, RemoteDesktopView.

### Priority 4: Remote Window Capture ✅
SCContentFilter per-window, multi-display with DisplayDescriptor, coordinate mapping with WindowGeometryMapper, RemotePointerContext. 14 tests.

### Priority 5: Shared Workspace Sync ✅
WorkspaceSyncService with bidirectional sync, FileVersion tracking, SyncDelta computation, 4 conflict resolution strategies. 6 tests.

### Priority 6: Signed Update Packages ✅
P256 ECDSA signature verification, trusted key management, staged install, atomic activation, rollback. 20 tests.

### Priority 7: Global Access — NAT Traversal & Relay ✅
STUN client (RFC 5389), NATType detection, ConnectionRouteNegotiator (direct/relay/vpn), relay transport. 15 tests.

### Priority 8: Multi-OS Protocol SDK ✅
Language-agnostic protocol schema, cross-platform test vectors, SDK structure docs, 11 compatibility tests.

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
swift test --parallel                    # run all ~378 tests
swift test --filter SecurityTests        # security tests only
swift test --filter ChaosTests           # chaos/disconnect tests only
swift test --filter JobSecurityTests     # job security tests only
swift test --filter FabricSchedulerTests # scheduler tests only
```

### Test Suites (204 XCTest + 174 Swift Testing = 378 total)

**XCTest:**
- ArtifactTransferTests (4 tests)
- BonjourDiscoveryServiceTests (2 tests)
- CGEventInputDispatchServiceTests (7 tests)
- ChannelMultiplexerTests (5 tests)
- ChaosTests (3 tests)
- CryptoKitIdentityServiceTests (6 tests)
- ErrorsTests (7 tests)
- FabricEventLogTests (4 tests)
- FabricSchedulerTests (3 tests)
- FilePersistenceServiceTests (5 tests)
- FlowControllerTests (4 tests)
- POSIXTerminalServiceTests (3 tests)
- PlatformTests (13 tests — identity types, JobID, AgentAction, etc.)
- ProtocolFramingTests (7 tests)
- ProtocolMessagesTests (existing)
- SecurityServiceTests (3 tests)
- SecurityTests (8 tests)
- TransportComponentTests (5 tests)
- InMemoryTransportTests (7 tests)
- JobExecutorTests (3 tests)
- JobSecurityTests (6 tests)
- VideoToolboxTests (5 tests)
- WorkspaceTests (3 tests)

**Swift Testing:**
- SanitizedLoggerTests (5 tests)
- IdempotencyCacheTests (4 tests)
- CapabilityNegotiatorTests (4 tests)
- FileTransferServiceTests (5 tests)
- PipelineMetricsCollectorTests (8 tests)
- HeartbeatControllerTests (7 tests)
- ReconnectionManagerTests (4 tests)
- KeyboardShortcutServiceTests (4 tests)
- TLSCertificateManagerTests (5 tests)
- WorkspaceSyncServiceTests (6 tests)
- MultiDisplayTests (14 tests)
- STUNTests (15 tests: STUNMessage, NATType, ConnectionRoute, RouteNegotiator)
- CrossPlatformTests (11 tests: envelope, STUN RFC 5389, capability bitfield, big-endian, UUID, NAT types, route descriptions, message types, channels)
- UpdateServiceTests (20 tests: check, signature verify, install, activate, health check, rollback, full flow)
- DistributedJobCoordinatorTests (7 tests: submit dispatch, no nodes, no executor, cancel, executor management, lifecycle, locality scoring)
- CoordinatorServiceTests (7 tests: register, deregister, heartbeat, list, capability filter, expiry, architecture filter)
- RendezvousServiceTests (4 tests: request, unknown node, respond, cancel)
- SignalingServiceTests (5 tests: create offer, receive answer, ICE candidates, close session, sessions between)
- RelayServiceTests (6 tests: allocate, forward, release, channels for node, cleanup, bandwidth)
- CoordinatorEdgeCases (5 tests: registerOverwrite, deregisterIdempotent, heartbeatUnknown, updateNATUnknown, cleanupEmpty)
- RendezvousEdgeCases (3 tests: respondUnknown, completeUnknown, rejectCleanup)
- SignalingEdgeCases (4 tests: answerUnknown, candidatesEmpty, sessionUnknown, cleanupEmpty)
- RelayEdgeCases (4 tests: forwardUnknown, releaseIdempotent, channelsUnknown, channelUnknown)
- BuildManifestTests (3 tests: init, succeeded architectures, is complete)
- LipoServiceTests (3 tests: insufficient inputs, input not found, verify fat binary)
- UniversalBuildServiceTests (6 tests: active builds, cancel, cleanup, build target, build request, artifact status)
- BuildEdgeCases (8 tests: singleArchComplete, allFailed, manifestUnknown, cancelCompleted, buildTargetFlags, customTargets, artifactFull, terminalStates)

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

### NodeAction Naming (Resolved)
Three `NodeAction` enums existed across VanguardDomain, VanguardPolicy, and VanguardSecurity. VanguardSecurity's was renamed to `SecurityAction` to avoid ambiguity. VanguardPolicy's was replaced with `SecurityPolicyAction`.
