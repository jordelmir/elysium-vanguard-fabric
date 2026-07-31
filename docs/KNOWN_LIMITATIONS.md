# Elysium Vanguard Fabric — Known Limitations

## v0.1 Limitations

### Cannot Control
- EFI / firmware
- Recovery mode
- FileVault before login
- Secure Enclave
- Touch ID
- macOS protected dialogs (e.g., password prompts)
- Powered-off Mac without external boot support
- Frozen kernel state
- Pre-login session
- TCC permissions not yet granted by user

### Requires
- macOS 12.3+ (ScreenCaptureKit minimum)
- Both Macs on same LAN, Thunderbolt Bridge, or direct Ethernet
- User login session on the node Mac
- Screen Recording permission on the node
- Accessibility permission on the node for input control
- Local Network permission on both devices

### Not Implemented in v0.1
- Cloud relay / Internet access (STUN client implemented, full TURN relay planned)
- Online login
- Billing
- Team/RBAC
- Windows/Linux/Android nodes
- Virtualization
- Marketplace/plugins
- Autonomous agents (DAG pipeline implemented, full autonomy planned)
- Distributed scheduler (single-node scheduler implemented, multi-node planned)

### Implemented in v0.1 (contracts + functional)
- File transfer — chunked transfer with SHA-256 verification and resume (VanguardFiles)
- Clipboard sync — NSPasteboard polling, change detection, bidirectional (VanguardClipboard)
- Audio streaming — ScreenCaptureKit audio capture (VanguardAudio)
- NAT traversal — STUN client (RFC 5389), NATType detection, ConnectionRouteNegotiator
- Relay transport — RelayConfiguration, RelaySession, connectViaRelay()

### Hardware Constraints
- MacBook Pro 2016: Maximum macOS Monterey (12.x)
- ScreenCaptureKit requires macOS 12.3 minimum
- H.264 hardware encoding available on Intel 2016
- Metal rendering requires compatible GPU

### Network Constraints
- LAN only in v0.1 (STUN/NAT traversal available for direct connection)
- No TURN relay server deployed (code exists, server infrastructure planned)
- No port forwarding automation

### Security Constraints
- No custom cryptography
- No private APIs
- No root daemons
- No 0.0.0.0 listening by default
- No persistent install without consent
