# AI Agent Guide — Elysium Vanguard Fabric

This guide explains how two AI agents can clone, build, test, and operate Elysium Vanguard Fabric across two Macs.

## Architecture Overview

```
┌─────────────────────┐         TCP + TLS 1.3         ┌─────────────────────┐
│   Mac M1 (Console)  │◄──────────────────────────────►│  MacBook Pro 2016   │
│   VanguardConsoleMac│   Bonjour: _elysium-vanguard   │  VanguardNodeMac    │
│                     │         port 49494             │                     │
│  - RemoteDesktopView│   Encodes → H.264 → Transmits │  ScreenCaptureKit   │
│  - Metal rendering  │   Sends ← Input ← Controls    │  VideoToolbox encode│
│  - Input dispatch   │                                │  CGEvent dispatch   │
│  - 11 UI panels     │                                │  PTY terminal       │
└─────────────────────┘                                └─────────────────────┘
```

**Console** = the machine controlling (M1)
**Node** = the machine being controlled (MacBook Pro 2016)

## Prerequisites

- macOS 12.0+ (Monterey or later)
- Xcode 16.x with Swift 6.0
- Both machines on the same LAN
- Screen Recording permission on the Node
- Accessibility permission on the Node (for input control)

## Clone & Build

```bash
# On BOTH machines:
git clone git@github.com:jordelmir/elysium-vanguard-fabric.git
cd elysium-vanguard-fabric

# Build everything
swift build

# Run all tests (250 tests)
swift test --parallel

# Build the Console app
swift build --target VanguardConsoleMac

# Build the Node app
swift build --target VanguardNodeMac
```

## Run

### On the Node (MacBook Pro 2016):

```bash
open .build/arm64-apple-macosx/debug/VanguardNodeMac.app
# OR in Xcode: select VanguardNodeMac scheme, press Cmd+R
```

1. Grant Screen Recording permission when prompted
2. Grant Accessibility permission when prompted
3. The Node will show "Advertising on LAN..."
4. A pairing code will appear when a Console connects

### On the Console (Mac M1):

```bash
open .build/arm64-apple-macosx/debug/VanguardConsoleMac.app
# OR in Xcode: select VanguardConsoleMac scheme, press Cmd+R
```

1. The Console will scan for Nodes on the LAN
2. Click on the discovered Node to connect
3. Enter the pairing code shown on the Node
4. The Node's screen will appear in the Remote Desktop view

## How It Works

### Session Lifecycle

```
1. Discovery    → Console finds Node via Bonjour (_elysium-vanguard._tcp)
2. Connect      → Console opens TCP connection to Node on port 49494
3. Handshake    → Hello/HelloAck exchange (protocol version negotiation)
4. Pairing      → Challenge-response with 6-digit code
5. Capture      → Node starts ScreenCaptureKit → SCStream
6. Encode       → VideoToolbox H.264 encodes each frame
7. Transmit     → Encoded frames sent over TCP (channel 3, best-effort)
8. Decode       → Console decodes H.264 via VTDecompressionSession
9. Render       → Metal renders CVPixelBuffer to MTKView
10. Input        → Console captures NSEvents → sends over network → Node posts CGEvents
```

### Protocol

- **Magic**: `0x45564642` ("EVFB")
- **Envelope**: 48 bytes, big-endian
- **Version**: 1.0
- **Channels**: 9 (control, input, video, terminal, telemetry, files, audit, heartbeat)

Full message reference: `Protocol/messages.md`

### Security

- **Identity**: Ed25519 key pairs, stored in macOS Keychain
- **Transport**: TLS 1.3 mandatory, certificate pinning
- **Authorization**: Capability-based (25 capabilities, no "full control")
- **Audit**: SHA-256 hash chaining, tamper-evident logs

Full security model: `docs/SECURITY.md`

## Repository Structure

```
Apps/
├── VanguardConsoleMac/          ← Console app (M1 controller)
├── VanguardNodeMac/             ← Node app (MacBook Pro 2016)
└── VanguardCoordinatorServer/   ← Standalone coordinator server

Packages/
├── VanguardDomain/        ← Platform types (zero Apple imports)
├── VanguardProtocol/      ← Wire protocol, message types
├── VanguardTransport/     ← TCP+TLS, STUN, NAT traversal
├── VanguardSession/       ← Session lifecycle (hello→capture→input)
├── VanguardCapture/       ← ScreenCaptureKit capture
├── VanguardVideo/         ← VideoToolbox H.264 encode/decode
├── VanguardRender/        ← Metal rendering
├── VanguardInput/         ← CGEvent input dispatch
├── VanguardSecurity/      ← Authorization, capabilities
├── VanguardIdentity/      ← CryptoKit, TLS certificates
├── VanguardScheduler/     ← Job scheduling (8-dimension scoring)
├── VanguardCompute/       ← Job types, native process executor
├── VanguardExecutors/     ← Distributed job coordinator
├── VanguardCoordinator/   ← Presence, rendezvous, signaling, relay
├── VanguardBuild/         ← Universal builds (lipo)
├── VanguardAgents/        ← AI agent pipeline
├── VanguardObservability/ ← Events, metrics, audit
├── VanguardUpdates/       ← Signed update packages
├── VanguardWorkspace/     ← Bidirectional file sync
├── VanguardClipboard/     ← Clipboard sync
├── VanguardTerminal/      ← POSIX PTY terminal
├── VanguardArtifacts/     ← Chunked file transfer
├── VanguardFiles/         ← File transfer with SHA-256
├── VanguardAudit/         ← Hash chain audit log
├── VanguardPermissions/   ← macOS permission checks
├── VanguardPersistence/   ← File persistence
├── VanguardProcesses/     ← Process supervision
├── VanguardTelemetry/     ← System metrics (mach APIs)
├── VanguardUI/            ← Design system
├── VanguardAudio/         ← Audio capture
├── CSystemMetrics/        ← C bridge to mach APIs
└── SystemMetrics/         ← Swift wrapper

Protocol/
├── specification.md       ← Full protocol spec
├── messages.md            ← All 69 message types
├── versioning.md          ← Version negotiation
├── framing.md             ← Binary header structures
├── security.md            ← TLS, identity, pairing
├── errors.md              ← 27 error codes
├── schema.md              ← Language-agnostic wire format
├── sdk-structure.md       ← Cross-platform SDK architecture
└── test-vectors/          ← Binary test vectors

docs/
├── ARCHITECTURE.md        ← 8-plane architecture
├── SECURITY.md            ← Threat model, auth, audit
├── ROADMAP.md             ← Phases and milestones
├── API.md                 ← Public API reference
├── KNOWN_LIMITATIONS.md   ← Current constraints
├── ADR/                   ← 13 architecture decisions
└── physical-validation/   ← 8 test categories with checklist
```

## Key Files for AI Agents

| File | Purpose |
|------|---------|
| `AGENTS.md` | Master guide — start here |
| `Protocol/messages.md` | All 69 message types with field definitions |
| `Protocol/specification.md` | Protocol overview and connection flow |
| `Protocol/schema.md` | Language-agnostic wire format |
| `docs/API.md` | Public API for all packages |
| `docs/SECURITY.md` | Threat model and security architecture |
| `docs/ARCHITECTURE.md` | 8-plane architecture |
| `docs/ROADMAP.md` | Phases and completion status |
| `docs/physical-validation/` | Physical test checklist |
| `build.sh` | Build script (all 3 targets) |
| `.github/workflows/pr.yml` | CI pipeline |

## Testing

```bash
swift test --parallel                    # All 250 tests
swift test --filter SecurityTests        # Security tests
swift test --filter ChaosTests           # Disconnect/reconnect tests
swift test --filter STUNTests            # NAT traversal tests
swift test --filter DistributedJobCoordinatorTests  # Job tests
swift test --filter CoordinatorServiceTests  # Coordinator tests
```

### Test Counts
- **76 XCTest** — Unit tests across all packages
- **174 Swift Testing** — Modern async/concurrent tests
- **250 total** — 250 passing (2 known pre-existing failures in testVideoFrameDeduplication)

## Multi-Machine Setup

### For Physical Testing

1. **Node machine** (MacBook Pro 2016):
   - Run `VanguardNodeMac`
   - Grant Screen Recording + Accessibility permissions
   - Note the IP address (shown in app or `ifconfig`)

2. **Console machine** (Mac M1):
   - Run `VanguardConsoleMac`
   - Node will appear automatically via Bonjour
   - If Bonjour doesn't work, connect by IP directly

3. **Testing checklist**: `docs/physical-validation/checklist.md`

### For CI/CD

- **PR builds**: `.github/workflows/pr.yml` — builds all 3 targets, runs tests, checks for stubs
- **Nightly builds**: `.github/workflows/nightly.yml` — TSan/ASan/UBSan, secret scan, build report
- **Release builds**: `build.sh` — creates signed .app bundles for all 3 targets

## Coordinator Server

The Coordinator Server is a standalone app that acts as a relay for NAT traversal:

```bash
swift build --target VanguardCoordinatorServer
open .build/arm64-apple-macosx/debug/VanguardCoordinatorServer.app
```

It handles:
- Presence directory (node registration)
- Rendezvous brokering (connection setup)
- Signaling relay (SDP exchange)
- Media relay (TURN-like forwarding)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Node not discovered | Check both machines are on same LAN, check firewall |
| Pairing fails | Ensure Screen Recording permission is granted on Node |
| No video | Check Screen Recording permission, try restarting the app |
| Input not working | Ensure Accessibility permission is granted on Node |
| Build fails | Run `swift package resolve` first, check Xcode 16.x |
| Tests fail | Run `swift test --parallel`, check for pre-existing SIGTRAP (signal 5) |

## Code Style

- **Swift 6 strict concurrency** — actors for mutable state, `Sendable` everywhere
- **No comments** in code unless explicitly requested
- **No force unwraps** in production code (except Metal init)
- **Typed errors** per subsystem (every error is an enum)
- **Protocols at boundaries** — test with mocks
- **Value types by default** — structs, not classes
- **Domain package has zero Apple framework imports**

## Contributing

See `CONTRIBUTING.md` for commit conventions, branch strategy, and PR requirements.
