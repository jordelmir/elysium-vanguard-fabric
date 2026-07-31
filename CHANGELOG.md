# Changelog

## [0.2.0] - 2026-07-31

### Added
- Network integration: bidirectional clipboard, job dispatch, agent plans, workspace sync, terminal streaming, telemetry
- Emergency stop propagation over network
- Coordinator server message handlers for all 69 message types
- 12 new payload types for coordinator messaging (Presence, Rendezvous, Signaling, Relay)
- DMG packaging script (`Scripts/create-dmg.sh`)
- CoordinatorServer app icon (Assets.xcassets)
- 22 new unit tests (ClipboardService, FabricPolicy)
- Protocol/messages.md: 69/69 message types documented with field definitions
- Protocol/framing.md: dual framing documentation (ProtocolHeader vs FabricMessageEnvelope)
- SECURITY_MODEL.md: coordinator security section

### Fixed
- 5 force unwraps in production code (FilePersistenceService, LocalArtifactStore, NativeProcessExecutor, VideoToolboxDecoder, STUNMessage)
- CI protocol compliance check now blocks on violations
- InMemoryAuditLogService audit chain integrity (placeholder hash fix)
- CoordinatorServerState: presenceDeregister now actually deregisters nodes
- CoordinatorServerState: all message handlers deserialize real payloads (no more placeholder NodeID())
- Info.plist: CoordinatorServer CFBundleIconFile, LSMinimumSystemVersion unified to 12.3
- ConsoleMac LSUIElement added (MenuBarExtra)
- build.sh: full error output, clean step, version stamping
- nightly.yml: sanitizer failures no longer silently ignored

### Changed
- Test count: 250 (76 XCTest + 174 Swift Testing)
- Package count: 34 (32 Swift + 2 C targets)
- Channel count: 9 logical channels
- Capability count: 25 FabricCapability cases
- Port constants extracted to VanguardProtocolConstants (defaultNodePort, defaultCoordinatorPort)

## [0.1.0] - 2026-07-20

### Added
- Initial repository structure
- Domain models (Node, Session, Capabilities, Errors)
- Protocol framing and message types (48-byte envelope, 69 message types)
- In-memory transport for testing
- Test helpers and mocks
- Documentation (Architecture, Threat Model, Known Limitations)
- CI workflows (PR Gate, Nightly)
- Build scripts
- Bonjour discovery type definitions
- Permission state model
- Audit entry model
- Telemetry snapshot model
- Terminal session model
- Input event model
