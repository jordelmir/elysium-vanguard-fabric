# Security Model

## Threat Model

### Assets Protected

- Screen content (real-time video stream)
- Keyboard and mouse input (keystrokes, pointer coordinates)
- Terminal sessions (shell output, commands)
- File system access (read/write/delete)
- CPU/GPU/memory resources (compute jobs)
- Cryptographic keys (Ed25519, X25519, TLS certificates)
- Session state (pairing, capabilities, audit logs)

### Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Node (screen owner) | MacBook Pro 2016 — captures screen, executes input, runs jobs |
| Console (remote viewer) | Mac M1 — displays remote screen, sends input, manages jobs |
| LAN network | TCP transport between Node and Console |
| Coordinator server | Optional relay for NAT traversal |

### Adversary Model

| Adversary | Capability | Mitigation |
|-----------|-----------|------------|
| Network eavesdropper | Passive listener on LAN | TLS 1.3 mandatory, no plaintext fallback |
| Rogue console | Impersonate a legitimate console | mTLS with certificate pinning, challenge-response pairing |
| Replay attacker | Re-record and replay protocol messages | Timestamped challenges, nonce replay protection |
| Input injection | Inject malicious CGEvents | Accessibility permission gate, rate limiting, coordinate validation |
| Privilege escalation | Request unauthorized capabilities | Capability-based authorization, Node is final authority |
| Tampered logs | Modify audit trail for undetectability | SHA-256 hash chaining, chain integrity verification |

---

## Authentication

### Identity Model

Each device generates an Ed25519 key pair on first launch. The public key becomes the device identity (`NodeID`). Private keys are stored in macOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

### Pairing Protocol

1. Console sends `Hello` with its NodeID and public key
2. Node responds with `HelloAck` and a 6-digit numeric challenge code
3. Console sends `PairingResponse` with the code (SHA-256 hash for verification)
4. Node verifies the code and sends `PairingComplete`
5. Both devices compute a shared secret via X25519 key agreement
6. Transcript hash of all pairing messages is computed and pinned

### Session Authentication

After pairing, all messages are signed with Ed25519. Each message includes:
- Sender NodeID
- Sequence number
- HMAC of the payload

---

## Authorization

### Capability-Based Access Control

No single "full control" capability exists. Each sensitive action requires a specific capability:

| Capability | Grants |
|------------|--------|
| `.screenView` | View screen frames |
| `.screenControl` | Send mouse/keyboard input |
| `.clipboardRead` | Read clipboard contents |
| `.clipboardWrite` | Write to clipboard |
| `.terminalOpen` | Open terminal sessions |
| `.terminalInput` | Send input to terminals |
| `.fileRead` | Read files |
| `.fileWrite` | Write/create files |
| `.fileDelete` | Delete files |
| `.processExecute` | Run jobs |
| `.nodeRestart` | Restart the node |
| `.systemQuery` | Query system metrics |
| `.audioCapture` | Capture system audio |
| `.updateInstall` | Install updates |

### Capability Grant Structure

```swift
struct CapabilityGrant {
    let grantedTo: NodeID       // Console receiving the grant
    let grantedBy: NodeID       // Node issuing the grant
    let capability: FabricCapability
    let expiresAt: Date         // Time-limited grants
    let nonce: UUID             // Single-use nonce
    let signature: Data         // Ed25519 signature
}
```

### Node Authority

The Node is the final authority on all capability decisions. Even if a Console holds a valid capability grant, the Node can:
- Revoke grants at any time
- Deny specific actions based on policy
- Require re-authorization for sensitive operations

---

## Transport Security

### TLS Configuration

- **Protocol:** TLS 1.3 mandatory
- **Cipher suites:** AES-256-GCM, ChaCha20-Poly1305
- **Certificate type:** EC P-256 (NIST P-256)
- **Certificate pinning:** SHA-256 fingerprint of peer's public key

### Fallback Protection

No plaintext TCP fallback. If TLS handshake fails, the connection is rejected. This prevents downgrade attacks.

### Protocol Versioning

The protocol uses a major.minor version scheme:
- **Major mismatch:** Connection refused immediately
- **Minor mismatch:** Highest mutually supported minor version is negotiated

---

## Input Security

### Accessibility Gate

All input dispatch (mouse, keyboard, scroll) requires macOS Accessibility permission. Without it, `CGEvent.post()` calls are silently ignored by the system.

### Rate Limiting

Input events are rate-limited via a token bucket algorithm:
- Mouse moves: 1000 events/second burst, sustained 500/second
- Keyboard: 200 events/second burst
- Scroll: 100 events/second burst

### Coordinate Validation

Mouse coordinates are validated against the captured display bounds. Out-of-bounds coordinates are clamped.

### Key State Tracking

All pressed keys and mouse buttons are tracked locally. On disconnect or emergency stop, a `releaseAll` event sends key-up and mouse-up for all tracked keys.

### Emergency Stop

`⌘⌥Ctrl+Esc` immediately:
- Disconnects the session
- Releases all held keys and mouse buttons
- Clears input state

---

## Data Protection

### Keychain Storage

Private keys are stored in the macOS Keychain with:
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — keys are not迁移到其他设备
- `kSecAttrSynchronizable = false` — no iCloud sync
- `kSecAttrIsPermanent = true` — not迁移到备份

### Log Sanitization

`SanitizedLogger` redacts:
- Base64-encoded strings (potential tokens/keys)
- JWTs (`eyJ...`)
- API keys (patterns: `sk-*`, `key-*`)
- Passwords in key-value pairs
- Private key headers (`-----BEGIN`)

### Audit Trail

All critical actions are logged to `FabricEventLog`:
- Pairing requests/completions
- Capability grants/revocations
- Input dispatches
- File operations
- Job submissions/completions

Logs use SHA-256 hash chaining for tamper evidence. Chain integrity is verifiable at any time.

---

## Audit

### Hash Chain

Each audit entry includes:
- Entry data (action, actor, target, timestamp)
- Previous entry hash
- Current entry hash = SHA-256(previousHash + data)

### Integrity Verification

`AuditLogService.verifyChainIntegrity()` walks the entire chain and verifies each hash link. Any tampering is detected.

### Export

Audit logs are exportable as JSON for external analysis. No sensitive data (keys, tokens) is included in the export.

---

## Incident Response

### Emergency Stop

1. Press `⌘⌥Ctrl+Esc` on either machine
2. All sessions are terminated
3. All held keys/buttons are released
4. Audit log is flushed

### Revoke a Console

1. Open TrustedPeers panel
2. Select the Console to revoke
3. Click "Remove" — all capability grants are invalidated

### Key Rotation

1. Delete identity from Keychain
2. Restart the application — new key pair is generated
3. Re-pair all devices
