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

### Core
- **VanguardDomain** — Pure domain models, zero Apple framework dependencies
- **VanguardProtocol** — Wire protocol framing, 69 message types, binary envelope

### Infrastructure
- **VanguardTransport** — NetworkTransport (TCP + TLS 1.3), InMemoryTransport, flow control
- **VanguardDiscovery** — Bonjour/mDNS service discovery (`_elysium-vanguard._tcp`)
- **VanguardIdentity** — CryptoKit identity service (Ed25519, P256), keychain
- **VanguardSecurity** — AuthorizationGuard, capability negotiation, SecurityAction
- **VanguardPermissions** — macOS permission checks (Screen Recording, Accessibility)
- **VanguardAudit** — SHA-256 hash chain audit log, SanitizedLogger
- **VanguardPersistence** — FilePersistenceService
- **VanguardProcesses** — Process supervision

### Media Pipeline
- **VanguardCapture** — ScreenCaptureKit capture service (per-window, multi-display)
- **VanguardVideo** — VideoToolbox H.264 encoder/decoder
- **VanguardRender** — Metal renderer (VideoMetalRenderer, MTKView)
- **VanguardInput** — CGEvent input dispatch with coordinate mapping
- **VanguardClipboard** — NSPasteboard polling with change detection
- **VanguardAudio** — ScreenCaptureKit audio capture

### Session & Control
- **VanguardSession** — SessionCoordinator, PipelineCoordinator, ConsoleSessionCoordinator, NodeSessionCoordinator
- **VanguardTerminal** — POSIX PTY terminal with exit status

### Data & Workspace
- **VanguardFiles** — FileTransferService with chunked transfer and SHA-256 verification
- **VanguardArtifacts** — ArtifactManifest, chunking, transfer, local store
- **VanguardWorkspace** — Workspace snapshots, bidirectional sync, conflict resolution

### Compute & Scheduling
- **VanguardCompute** — JobSpec, NativeProcessExecutor, JobState (13 states)
- **VanguardScheduler** — FabricScheduler with 8-dimension scoring model
- **VanguardExecutors** — RemoteJobExecutor, DistributedJobCoordinator

### Intelligence
- **VanguardAgents** — AgentPipeline, AgentPlan, DAG validation
- **VanguardPolicy** — SecurityPolicyAction (maps capabilities to actions)

### Coordination
- **VanguardCoordinator** — CoordinatorService, RendezvousService, SignalingService, RelayService

### Observability & Distribution
- **VanguardObservability** — FabricEventLog actor, PipelineMetricsCollector
- **VanguardTelemetry** — MacTelemetryCollector
- **VanguardUpdates** — UpdateService with rollback, P256 signature verification

### Build & UI
- **VanguardBuild** — BuildManifest, LipoService, UniversalBuildService
- **VanguardUI** — Design system, glass morphism, KeyboardShortcutService

### System
- **CSystemMetrics** — Real mach APIs for CPU/RAM/battery
- **SystemMetrics** — Swift wrapper for CSystemMetrics
- **VanguardTestSupport** — Mocks for testing

## 8 Architectural Planes

| Plane | Packages | Responsibility |
|-------|----------|----------------|
| **Identity** | VanguardIdentity, VanguardSecurity | Cryptographic identity, pairing, mTLS, capabilities |
| **Control** | VanguardSession, VanguardTerminal, VanguardInput, VanguardClipboard | Sessions, handshake, input, terminal, clipboard |
| **Media** | VanguardCapture, VanguardVideo, VanguardRender, VanguardAudio | Screen capture, H.264 encode/decode, Metal render |
| **Data** | VanguardFiles, VanguardArtifacts, VanguardWorkspace | Files, artifacts, workspaces, chunks, hashes |
| **Compute** | VanguardCompute, VanguardScheduler, VanguardExecutors | Jobs, executors, scheduling, sandboxes |
| **Intelligence** | VanguardAgents, VanguardPolicy | AI agents, planners, policy, approval gates |
| **Observability** | VanguardObservability, VanguardAudit, VanguardTelemetry | Events, metrics, traces, audit |
| **Distribution** | VanguardUpdates, VanguardBuild | Updates, rollback, signing, builds |

## Message Types (69 total)

The protocol defines 69 message types in `MessageType` enum, grouped by function:

- **Session**: hello, helloAck, authenticate, authenticated, capabilityRequest, capabilityGranted, capabilityDenied, sessionOpen, sessionClose
- **Pairing**: pairingRequest, pairingChallenge, pairingResponse, pairingComplete
- **Media**: videoConfiguration, videoFrame, flowControlAck
- **Terminal**: terminalOpen, terminalOpened, terminalInput, terminalOutput, terminalResize, terminalClose
- **Clipboard**: clipboardData (bidirectional)
- **Compute**: jobSubmit, jobAssigned, jobProgress, jobCompleted, jobFailed, jobCancelled
- **Artifacts**: artifactManifest, artifactChunk, artifactRequest
- **Agent**: agentSubmit, agentProgress, agentCompleted, agentFailed
- **Workspace**: workspaceRequest, workspaceResponse
- **Emergency**: emergencyStop
- **Telemetry**: telemetrySnapshot, heartbeat, heartbeatAck
- **Presence**: presenceRegister, presenceDeregister, presenceList
- **Rendezvous**: rendezvousRequest, rendezvousCancel, rendezvousComplete
- **Signaling**: signalingOffer, signalingAnswer, signalingIceCandidate
- **Relay**: relayAllocate, relayForward, relayRelease
- **Audit**: auditEvent
- **Error**: errorResponse
- **Flow control**: flowControlAck

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
