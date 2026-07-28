# Elysium Vanguard Fabric — Roadmap

## v0.1 — Local Control Core ✅ COMPLETE

### Phase 0: Archeology & Baseline
- [x] Repository structure
- [x] Xcode workspace
- [x] Two compilable targets
- [x] Packages with domain models
- [x] Protocol framing
- [x] In-memory transport
- [x] Test support
- [x] Initial documentation

### Phase 1: Skeleton & Domain
- [x] Typed identifiers
- [x] Node model
- [x] Capability model
- [x] Session model
- [x] Error taxonomy
- [x] State machines
- [x] Protocol header and framing
- [x] In-memory transport
- [x] Test support

### Phase 2: Discovery & Pairing
- [x] Bonjour service type definition
- [x] Bonjour browser implementation
- [x] Bonjour publisher implementation
- [x] Pairing UI (ContentView + PairingView)
- [x] Identity generation (CryptoKit)
- [x] Keychain integration
- [x] Trusted peers persistence UI
- [ ] Revocation (v0.2)

### Phase 3: Authenticated Transport
- [x] Network.framework transport
- [ ] TLS certificate pinning (v0.2)
- [x] Handshake protocol (hello → helloAck → pairingRequest → pairingResponse → pairingComplete)
- [x] Capability negotiation
- [x] Heartbeat
- [x] Reconnection logic (exponential backoff, 10 attempts)
- [x] Idempotency cache

### Phase 4: Capture & Encoding
- [x] Permission service (macOS)
- [x] Screen source enumeration
- [x] SCStream capture
- [x] VideoToolbox encoder (H.264)
- [x] Encoded frame protocol

### Phase 5: Decoder & Display
- [x] VideoToolbox decoder
- [x] Metal renderer (runtime shader compilation)
- [x] Aspect correction (aspect-fit in VideoMetalRenderer)
- [x] Latency measurement (HeartbeatController RTT)

### Phase 6: Input
- [x] Local input capture
- [x] Canonical event model
- [x] CGEvent adapter
- [x] Stuck-key prevention
- [x] Emergency stop (Cmd+Option+Escape)

### Phase 7: Terminal PTY
- [x] PTY allocation (openpty)
- [x] Process supervisor (posix_spawn)
- [x] Terminal transport
- [x] Terminal UI
- [x] Resize (TIOCSWINSZ)
- [x] Scrollback (configurable limit)

### Phase 8: Session Orchestration
- [x] NodeSessionCoordinator
- [x] ConsoleSessionCoordinator
- [x] SwiftUI Node App (menu bar + window)
- [x] SwiftUI Console App (sidebar + main)
- [x] Package integration (VanguardSession)
- [x] Terminal output streaming
- [x] Pairing view integration

### Phase 9: Telemetry, Audit & Hardening
- [x] PipelineMetricsCollector (frames, bytes, encode/decode, RTT, memory)
- [x] Observatory UI (real-time dashboard with live toggle)
- [x] Audit chain (SHA-256 hash chaining with integrity verification)
- [x] Sanitized logging (redacts secrets from logs)
- [x] Security tests (SanitizedLogger, IdempotencyCache, CapabilityNegotiator)
- [x] Heartbeat/Reconnection tests
- [x] FileTransfer tests
- [x] KeyboardShortcutService tests
- [x] PipelineMetricsCollector tests

### Phase 10: Per-Context Identity Types
- [x] SessionIdentity (per-session cryptographic identity)
- [x] JobIdentity (per-job signed identity)
- [x] ArtifactIdentity (per-artifact producer identity)
- [x] AgentIdentity (per-agent signed identity)
- [x] ApplicationIdentity (per-app signed identity)

### Phase 11: Console App Panels (11 panels)
- [x] NodesPanel (real resource bars)
- [x] JobsPanel (13-state lifecycle, real execution)
- [x] ResourcesPanel (live metrics, 5s refresh)
- [x] WorkspacePanel (real file scanning, SHA-256)
- [x] TerminalPanel (remote/local indicator, scrollback)
- [x] AgentsPanel (real pipeline execution)
- [x] SecurityPanel (capabilities/events/audit/chain tabs)
- [x] SettingsPanel (7 weight sliders, persistence, scrollback slider)
- [x] ObservatoryPanel (real-time metrics from PipelineMetricsCollector)
- [x] TrustedPeersPanel (view/remove paired nodes)
- [x] RemoteDesktopView (Metal renderer, mouse/click forwarding)

### Phase 12: Polish & Verification
- [x] Emergency stop disconnects everything
- [x] Reconnection with exponential backoff
- [x] Clipboard sync with change detection
- [x] Settings persistence via @AppStorage
- [x] Both apps build and launch
- [x] All 82 tests pass (54 XCTest + 28 Swift Testing)

---

## Statistics

| Metric | Value |
|--------|-------|
| Swift packages | 32 |
| Swift source files | 108+ |
| Unit test files | 42+ |
| Unit tests | 82 (54 XCTest + 28 Swift Testing) |
| Console panels | 11 |
| Build status | ✅ Passing |
| Test status | ✅ All pass (0 failures) |
| App launch | ✅ Both apps build and run |
| Transport | ✅ Node listens, Console connects |
| Handshake | ✅ Full hello → pairing flow wired |
| Media Pipeline | ✅ Capture → H.264 → Metal render |
| Input | ✅ Mouse/keyboard → CGEvent dispatch |
| Terminal | ✅ PTY with scrollback |
| Reconnection | ✅ Exponential backoff |
| Emergency Stop | ✅ Cmd+Option+Escape |
| Audit | ✅ SHA-256 hash chain |
| Identity Types | ✅ 5 per-context types |

---

## v0.2 — Secure Transport & Multi-Node

### Phase 13: TLS & Certificate Pinning
- [ ] mTLS with certificate pinning
- [ ] Ephemeral key exchange
- [ ] Certificate rotation

### Phase 14: Multi-Node Coordination
- [ ] Coordinator server (Oracle Free)
- [ ] Multi-node job distribution
- [ ] Universal binary builds (ARM + Intel → lipo)

### Phase 15: Workspace Sync
- [ ] Bidirectional workspace sync
- [ ] Conflict resolution
- [ ] Delta transfers

### Phase 16: Distribution
- [ ] Update service (already scaffolded)
- [ ] Rollback mechanism
- [ ] Signed update packages
