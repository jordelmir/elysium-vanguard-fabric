# Elysium Vanguard Fabric — Roadmap

## v0.1 — Local Control Core

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
- [ ] Trusted peers persistence UI
- [ ] Revocation

### Phase 3: Authenticated Transport
- [x] Network.framework transport
- [ ] TLS certificate pinning
- [x] Handshake protocol (hello → helloAck → pairingRequest → pairingResponse → pairingComplete)
- [ ] Capability negotiation
- [x] Heartbeat
- [ ] Reconnection logic
- [ ] Idempotency cache

### Phase 4: Capture & Encoding
- [x] Permission service (macOS)
- [x] Screen source enumeration
- [x] SCStream capture
- [x] VideoToolbox encoder (H.264)
- [x] Encoded frame protocol

### Phase 5: Decoder & Display
- [x] VideoToolbox decoder
- [x] Metal renderer (runtime shader compilation)
- [ ] Aspect correction
- [ ] Latency measurement

### Phase 6: Input
- [x] Local input capture
- [x] Canonical event model
- [x] CGEvent adapter
- [x] Stuck-key prevention
- [ ] Panic shortcut

### Phase 7: Terminal PTY
- [x] PTY allocation (openpty)
- [x] Process supervisor (posix_spawn)
- [x] Terminal transport
- [x] Terminal UI
- [x] Resize (TIOCSWINSZ)
- [ ] Scrollback

### Phase 8: Session Orchestration
- [x] NodeSessionCoordinator
- [x] ConsoleSessionCoordinator
- [x] SwiftUI Node App (menu bar + window)
- [x] SwiftUI Console App (sidebar + main)
- [x] Package integration (VanguardSession)
- [x] Terminal output streaming
- [x] Pairing view integration

### Phase 9: Telemetry, Audit & Hardening
- [ ] Metrics collector
- [ ] Observatory UI
- [ ] Audit chain
- [ ] Sanitized logging
- [ ] Security tests

---

## Statistics

| Metric | Value |
|--------|-------|
| Swift packages | 17 |
| Swift source files | 54 |
| Unit test files | 19 |
| Unit tests | 94 |
| Build status | ✅ Passing |
| Test status | ✅ All pass |
| App launch | ✅ Both apps build and run |
| Transport | ✅ Node listens, Console connects |
| Handshake | ✅ Full hello → pairing flow wired |
