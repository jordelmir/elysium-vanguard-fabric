# Elysium Vanguard Fabric

Sovereign local-first platform for controlling multiple computers from a central console.

## Overview

Elysium Vanguard Fabric turns multiple Macs into a single coherent, low-latency remote work environment. View screens, control input, open terminals, share clipboards, and monitor system health — all over a secure TLS 1.3 local connection with zero cloud dependency.

## First Use Case

```
Mac M1 (Console)
    ↓ secure TLS 1.3 connection
MacBook Pro Intel 2016 (Node)
```

Control your MacBook with a damaged screen from your M1 Mac — full remote desktop, terminal, and clipboard sync.

## Features

### Core Remote Control
- **Screen Capture** — ScreenCaptureKit hardware-accelerated capture at 1080p60
- **H.264 Encode/Decode** — VideoToolbox hardware pipeline with adaptive bitrate
- **Metal Rendering** — Zero-copy GPU rendering via MTKView with aspect-correct scaling
- **Input Dispatch** — Mouse, keyboard, scroll, drag, modifiers, key repeat, emergency stop

### Platform Services
- **Bonjour Discovery** — Automatic LAN discovery via `_elysium-vanguard._tcp`
- **Pairing Flow** — 6-digit challenge code with transcript hash verification
- **Terminal** — Full PTY terminal with scrollback, command history, resize
- **Clipboard Sync** — Bidirectional NSPasteboard sync with change detection
- **File Transfer** — Chunked transfer with SHA-256 integrity verification
- **Reconnection** — Exponential backoff (0.5s → 30s, 10 attempts)
- **Emergency Stop** — ⌘⌥Esc disconnects everything instantly

### Security
- **Zero Trust** — Every action requires identity + capability
- **Capability Negotiation** — Console and node negotiate allowed operations
- **Audit Chain** — SHA-256 hash chain with integrity verification
- **Sanitized Logging** — Secrets redacted from all log output
- **Trusted Peers** — Persisted paired nodes list

### Observability
- **Pipeline Metrics** — Frames, bytes, encode/decode times, RTT, jitter, FPS
- **Observatory Dashboard** — Real-time system, network, media, and performance metrics
- **Audit Log** — Append-only security event history

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Console (Mac M1)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ UI Layer │  │ Decoder  │  │ Input Dispatch   │  │
│  │ Metal    │  │ H.264    │  │ CGEvent          │  │
│  └────┬─────┘  └────┬─────┘  └────────┬─────────┘  │
│       └──────────────┼─────────────────┘            │
│              ┌───────┴────────┐                     │
│              │ Session Coord  │                     │
│              │ (Actor)        │                     │
│              └───────┬────────┘                     │
│              ┌───────┴────────┐                     │
│              │ TLS Transport  │                     │
│              │ NWConnection   │                     │
│              └───────┬────────┘                     │
└──────────────────────┼──────────────────────────────┘
                       │ LAN / Thunderbolt / Ethernet
┌──────────────────────┼──────────────────────────────┐
│              ┌───────┴────────┐                     │
│              │ TLS Transport  │                     │
│              │ NWConnection   │                     │
│              └───────┬────────┘                     │
│              ┌───────┴────────┐                     │
│              │ Session Coord  │                     │
│              │ (Actor)        │                     │
│              └───────┬────────┘                     │
│  ┌──────────┐  ┌─────┴──────┐  ┌────────────────┐  │
│  │ Capture  │  │ Encoder    │  │ Terminal (PTY) │  │
│  │ SCKit    │  │ H.264 VT   │  │ POSIX          │  │
│  └──────────┘  └────────────┘  └────────────────┘  │
│                  Node (Intel)                       │
└─────────────────────────────────────────────────────┘
```

## Requirements

- macOS 12.0+ (Monterey — both devices)
- Same LAN, Thunderbolt Bridge, or direct Ethernet
- Screen Recording permission (Node)
- Accessibility permission (Node, for input control)

## Quick Start

```bash
# Clone
git clone git@github.com:jordelmir/elysium-vanguard-fabric.git
cd elysium-vanguard-fabric

# Build
swift build --target VanguardConsoleMac       # Console (M1)
swift build --target VanguardNodeMac          # Node (Intel)
swift build --target VanguardCoordinatorServer # Coordinator Server

# Run
open .build/arm64-apple-macosx/debug/VanguardConsoleMac.app
open .build/arm64-apple-macosx/debug/VanguardNodeMac.app
open .build/arm64-apple-macosx/debug/VanguardCoordinatorServer.app
```

## Packages (35)

| Package | Purpose |
|---------|---------|
| VanguardDomain | Pure domain models, 5 identity types, zero Apple imports |
| VanguardProtocol | Binary wire protocol with 10 logical channels |
| VanguardTransport | NWConnection TLS transport with multiplexer |
| VanguardDiscovery | Bonjour `_elysium-vanguard._tcp` discovery |
| VanguardIdentity | Ed25519 + X25519 device identity |
| VanguardSecurity | Capability negotiation, authorization guard |
| VanguardPermissions | Screen Recording, Accessibility, Microphone |
| VanguardCapture | ScreenCaptureKit capture with presets |
| VanguardVideo | VideoToolbox H.264 encode/decode |
| VanguardRender | Metal zero-copy GPU renderer |
| VanguardInput | CGEvent dispatch with coalescing |
| VanguardTerminal | POSIX PTY terminal service |
| VanguardClipboard | NSPasteboard bidirectional sync |
| VanguardAudio | ScreenCaptureKit audio capture |
| VanguardFiles | Chunked file transfer with SHA-256 |
| VanguardProcesses | Process supervision |
| VanguardTelemetry | System metrics collector |
| VanguardAudit | SHA-256 hash chain audit log + sanitized logging |
| VanguardUI | Design system, glass morphism, themes |
| VanguardPersistence | Data storage |
| VanguardWorkspace | Workspace snapshots |
| VanguardCompute | JobSpec, NativeProcessExecutor, 13-state lifecycle |
| VanguardScheduler | 8-dimension weighted scoring model |
| VanguardAgents | AgentPipeline with DAG validation |
| VanguardPolicy | SecurityPolicyAction capability mapping |
| VanguardObservability | FabricEventLog, PipelineMetricsCollector |
| VanguardUpdates | Update service with rollback |
| VanguardExecutors | Remote job executor protocol |
| VanguardTestSupport | Mocks for testing |
| CSystemMetrics | Real mach APIs for CPU/RAM/battery |
| SystemMetrics | Swift wrapper for CSystemMetrics |
| VanguardArtifacts | Artifact chunking and transfer |

## Console App — 11 Panels

| Panel | Description |
|-------|-------------|
| Remote Desktop | Metal-rendered remote screen with mouse/keyboard control |
| Nodes | Discovered nodes with resource bars |
| Jobs | 13-state job lifecycle with real execution |
| Resources | Live CPU, RAM, storage, battery metrics |
| Workspace | File scanning with SHA-256 verification |
| Terminal | Remote/local PTY with configurable scrollback |
| Agents | AI agent pipeline execution |
| Security | Capabilities, events, audit, chain integrity tabs |
| Observatory | Real-time metrics dashboard (frames, RTT, FPS, memory) |
| Trusted Peers | View/remove paired nodes |
| Settings | Scheduler weights, persistence, display options |

## Video Pipeline

```
ScreenCaptureKit → CVPixelBuffer → VideoToolbox Encoder → H.264 NAL
    → Binary Protocol Framing → TLS 1.3 Transport
    → VideoToolbox Decoder → CVPixelBuffer → Metal Renderer
```

- **Latency**: <50ms encode+decode on Apple Silicon
- **Bitrate**: 8 Mbps default, adaptive
- **Keyframes**: On-demand via Console request

## Testing

```bash
swift test                        # 378 tests (204 XCTest + 174 Swift Testing)
swift test --filter SecurityTests # Security tests
swift test --filter ChaosTests    # Chaos/disconnect tests
```

## License

Copyright © 2026 Jorge David Del Valle Miranda. All rights reserved.
Proprietary software. Unauthorized distribution is prohibited.
