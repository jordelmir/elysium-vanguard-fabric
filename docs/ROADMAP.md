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
- [x] WorkspaceSyncService tests (delta computation, conflict resolution, state management)
- [x] TLSCertificateManager tests (ephemeral keys, fingerprint validation)
- [x] MultiDisplayTests (coordinate mapping, display descriptors, window geometry)

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
- [x] All 250 tests pass (76 XCTest + 174 Swift Testing)

---

## Statistics

| Metric | Value |
|--------|-------|
| Swift packages | 37 |
| Swift source files | 112+ |
| Unit test files | 44+ |
| Unit tests | 250 (76 XCTest + 174 Swift Testing) |
| Console panels | 11 |
| Executable targets | 3 (ConsoleMac, NodeMac, CoordinatorServer) |
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

## v0.2 — Secure Transport & Workspace Sync

### Phase 13: TLS & Certificate Pinning ✅
- [x] mTLS with certificate pinning
- [x] Ephemeral key exchange (createEphemeralKeyPair, computeFingerprint)
- [x] Peer fingerprint validation
- [x] Keychain-based persistent key storage
- [x] TLS verify blocks on proper QoS (not .main)
- [x] Server validates all client certs in chain

### Phase 14: Bidirectional Workspace Sync ✅
- [x] WorkspaceSyncService actor with state management
- [x] FileVersion tracking (path, sha256, size, modifiedBy, version)
- [x] SyncDelta computation (added, modified, deleted, conflicts)
- [x] Conflict resolution (newestWins, consoleWins, nodeWins, manual)
- [x] Delta merge and state persistence
- [x] 6 tests passing

### Phase 15: Remote Applications & Multi-Display ✅
- [x] Window capture via SCContentFilter(desktopIndependentWindow:)
- [x] RemoteWindowDescriptor, WindowBounds, WindowStreamSession
- [x] DisplayDescriptor with multi-display tracking
- [x] RemotePointerContext for per-display input routing
- [x] WindowGeometryMapper for coordinate space conversion
- [x] WindowCaptureMode (display/window/application)
- [x] ScreenCaptureService protocol: availableWindows(), availableDisplays(), startWindowCapture(), switchDisplay()
- [x] NodeSessionCoordinator: switchToWindow(), switchToDisplay(), getAvailableWindows(), getAvailableDisplays()
- [x] CGEventInputDispatchService: setPointerContext(), setWindowGeometryMapper()
- [x] ConsoleAppState: availableDisplays, availableWindows, selectedDisplayID, selectedWindowID, captureMode
- [x] 14 tests passing (MultiDisplayTests)

### Phase 15B: Global Access — NAT Traversal & Relay ✅
- [x] NATType enum (directOpen, coneNAT, restrictedConeNAT, portRestrictedConeNAT, symmetricNAT, symmetricFirewall)
- [x] STUNAddress, NATMapping, RelayConfiguration, ConnectionRoute, RelaySession, NetworkPath domain types
- [x] STUNMessage parser (RFC 5389): binding request/response, attributes (mappedAddress, xorMappedAddress, username, software, errorCode, fingerprint)
- [x] STUNClient actor: UDP NAT discovery via binding request
- [x] ConnectionRouteNegotiator actor: direct/relay/vpn route selection, TCP reachability probing
- [x] NetworkTransport.connectViaRelay(): relay connection support
- [x] 15 tests passing (STUNTests: STUNMessage, NATType, ConnectionRoute, RouteNegotiator)

### Phase 16: Multi-OS Protocol SDK ✅
- [x] Language-agnostic protocol schema (Protocol/schema.md) — type system, envelope, all message payloads, capability bitfield, channel IDs, error codes
- [x] Cross-platform test vectors (Protocol/test-vectors/cross-platform-vectors.md) — envelope, STUN, video config, input events, artifacts, resources, capability bitfield, route negotiation
- [x] SDK structure docs (Protocol/sdk-structure.md) — per-platform requirements (macOS/Linux/Windows/Android), protocol compliance checklist, interoperability tests
- [x] Cross-platform compatibility tests (CrossPlatformTests.swift) — envelope round-trip, STUN RFC 5389, capability bitfield, big-endian encoding, UUID format, NAT types, route descriptions, message type IDs, channel IDs
- [x] Fixed STUN class encoding bug (class shifted 4 bits → 14 bits per RFC 5389)
- [x] Added UInt64.bigEndianBytes extension
- [x] 11 tests passing (CrossPlatformTests)

### Phase 17: Signed Update Packages ✅
- [x] P256 ECDSA signature verification (CryptoKit)
- [x] Trusted signing key management (addTrustedKey/removeTrustedKey)
- [x] Manifest signature field integration
- [x] Staged installation with backup
- [x] Atomic activation (move staging → active, backup previous)
- [x] Health check (file existence + content validation)
- [x] Automatic rollback on activation failure
- [x] Manual rollback with backup restoration
- [x] Error state transitions (.failed on all failure paths)
- [x] 20 tests passing (UpdateServiceTests)

### Phase 18: Multi-Node Coordination ✅
- [x] DistributedJobCoordinator actor (submit, dispatch, monitor, collect, cancel)
- [x] FabricScheduler locality scoring (artifact proximity influences node selection)
- [x] RemoteJobExecutorClient (network-based job dispatch via VanguardTransport)
- [x] Job lifecycle tracking (pending → scheduling → dispatched → running → succeeded/failed)
- [x] Automatic rollback on dispatch failure
- [x] 7 tests passing (DistributedJobCoordinatorTests: submit, no nodes, no executor, cancel, executor management, lifecycle, locality)

### Phase 19: Coordinator Server ✅
- [x] CoordinatorService actor (presence directory, node registry, heartbeat, cleanup)
- [x] RendezvousService (connection brokering, request/accept/cancel lifecycle)
- [x] SignalingService (SDP offer/answer, ICE candidate exchange, session management)
- [x] RelayService (channel allocation, packet forwarding, bandwidth tracking, cleanup)
- [x] 16 new message types added to protocol (presence, rendezvous, signaling, relay)
- [x] 22 tests passing (CoordinatorServiceTests: 7, RendezvousServiceTests: 4, SignalingServiceTests: 5, RelayServiceTests: 6)
  - [x] 15 coordinator edge-case tests (CoordinatorEdgeCases: 5, RendezvousEdgeCases: 3, SignalingEdgeCases: 4, RelayEdgeCases: 4)

### Phase 20: Universal Binary Builds ✅
- [x] BuildManifest type (track per-arch artifacts, status, SHA-256)
- [x] LipoService actor (combine binaries via /usr/bin/lipo, extract architectures, verify fat binaries)
- [x] UniversalBuildService actor (multi-arch build orchestration, xcodebuild per architecture, lipo combine)
- [x] BuildTarget, UniversalBuildRequest types (configuration, signing, entitlements)
- [x] 12 tests passing (BuildManifestTests: 3, LipoServiceTests: 3, UniversalBuildServiceTests: 6)
  - [x] 8 build edge-case tests (BuildEdgeCases: 8)

### Phase 21: Hardening & Documentation
- [x] Threat model and security architecture (docs/SECURITY.md)
- [x] Public API reference for all packages (docs/API.md)
- [x] Coordinator edge-case tests (15 tests)
- [x] Build edge-case tests (8 tests)
- [x] All 250 tests pass

### Phase 22: Coordinator Server & CI/CD
- [x] Standalone VanguardCoordinatorServer app (MenuBarExtra, status display)
- [x] CoordinatorServerState: CoordinatorService, RendezvousService, SignalingService, RelayService wired
- [x] NetworkTransport listener for incoming connections
- [x] Message routing: presence, heartbeat, rendezvous, signaling, relay
- [x] Automatic cleanup (expired nodes, stale sessions, inactive channels)
- [x] Info.plist and entitlements for code signing
- [x] build.sh updated with coordinator server bundle creation and signing
- [x] CI/CD workflows (pr.yml, nightly.yml) verify coordinator server artifact
- [x] 3 executable targets: VanguardConsoleMac, VanguardNodeMac, VanguardCoordinatorServer

### Phase 23: Network Integration
- [x] Emergency stop propagation to remote node
- [x] Bidirectional clipboard sync over network
- [x] Job dispatch over network with progress/completion events
- [x] Agent plan dispatch over network
- [x] Workspace request/response over network
- [x] Terminal output streaming over network
- [x] Node telemetry snapshots to Console
