# Elysium Vanguard Fabric — Threat Model

## Assets

| Asset | Description | Sensitivity |
|-------|-------------|-------------|
| Screen content | Real-time video of remote display | High |
| Input events | Mouse, keyboard, scroll from controller | High |
| File system | Artifacts, workspace files, build outputs | High |
| Terminal | Shell sessions, command output | High |
| Cryptographic keys | Ed25519, P256, TLS certificates | Critical |
| Node resources | CPU, memory, GPU, storage | Medium |
| Session state | Connection metadata, capabilities | Medium |
| Audit logs | Activity trail, hash chain | Low |

## Threat Actors

| Actor | Capability | Motivation |
|-------|-----------|------------|
| Network attacker (MITM) | Intercept/modify LAN traffic | Eavesdrop, inject commands |
| Rogue node | Impersonate a trusted node | Execute unauthorized actions |
| Malicious console | Compromised controller app | Exfiltrate data from nodes |
| Rogue coordinator | Compromised server | Redirect connections, track users |
| Insider threat | Physical access to device | Data theft, sabotage |

## Security Architecture

### 1. Identity & Authentication

```
┌─────────────┐    Ed25519     ┌─────────────┐
│   Console   │◄──────────────►│    Node     │
│  (signer)   │  challenge     │  (verifier) │
│             │  response      │             │
└─────────────┘                └─────────────┘
```

- **Key generation**: Ed25519 for signing, P256 for ECDH key agreement
- **Pairing**: 6-digit challenge-response, device displays code for human verification
- **Identity persistence**: Keys stored in macOS Keychain, never on disk
- **Fingerprint pinning**: SHA-256 hash of peer's public key, verified on every connection
- **No password auth**: All authentication is cryptographic

### 2. Transport Security

```
┌──────────┐   TLS 1.3    ┌──────────┐
│ Console  │◄─────────────►│   Node   │
│          │  certificate  │          │
│          │    pinning    │          │
└──────────┘               └──────────┘
```

- **TLS 1.3 mandatory**: No plaintext fallback, no downgrade
- **Certificate pinning**: Public key hash verified against known peers
- **mTLS**: Both sides present certificates
- **Session binding**: TLS session tied to device identity

### 3. Capability-Based Authorization

```
Console requests: [screenView, inputControl]
Node grants:      [screenView]  ← partial grant
Action:           inputControl → DENIED
```

- **No monolithic "admin"**: Every action requires explicit capability
- **CapabilityGrant tokens**: Signed, time-limited, nonce-bound
- **Node is authority**: Node decides what to grant, console cannot escalate
- **Granular permissions**: 25 capability types (screen, audio, clipboard, terminal, file, job, agent, etc.)

### 4. Data Protection

| Data | At Rest | In Transit | In Log |
|------|---------|-----------|--------|
| Private keys | Keychain (encrypted) | N/A | Never logged |
| Session keys | Memory only | TLS encrypted | Never logged |
| Video frames | Memory only | TLS encrypted | Never logged |
| Input events | Memory only | TLS encrypted | Never logged |
| File chunks | Disk (sandboxed) | TLS encrypted | SHA-256 only |
| Audit events | Disk (hash chain) | N/A | Sanitized |

### 5. Input Security

- **Accessibility permission required**: macOS prompts user
- **Rate limiting**: Max events per second enforced
- **Coordinate validation**: Normalized [0,1] range checked
- **Key state tracking**: All keys released on disconnect
- **Emergency stop**: ⌘⌥Esc disconnects everything immediately
- **No clipboard auto-sync**: Requires explicit user action

### 6. Job Execution Security

- **Sandboxed execution**: Jobs run in isolated directories
- **Timeout enforcement**: Jobs killed after deadline
- **Signature verification**: Job specs signed by submitter
- **Capability gating**: Each job action requires capability
- **Path traversal prevention**: All paths resolved and validated
- **No shell injection**: Arguments passed as array, not concatenated

### 7. Update Security

- **P256 ECDSA signatures**: All updates cryptographically signed
- **Trusted key store**: Only known signing keys accepted
- **SHA-256 integrity**: Hash verified before installation
- **Staged installation**: Install to temp, verify, then activate
- **Automatic rollback**: Previous version restored on health check failure
- **No unsigned updates**: Rejected at signature verification

### 8. Coordinator Security

- **Presence directory**: Only registered nodes visible
- **Rendezvous brokering**: Coordinator sees endpoints but not content
- **Signaling relay**: SDP/ICE exchanged, but media flows peer-to-peer
- **Relay encryption**: End-to-end encrypted even through relay
- **No single point of failure**: P2P preferred, coordinator optional

## Attack Scenarios & Mitigations

### Scenario 1: MITM on LAN

**Attack**: Attacker intercepts TCP connection between console and node.

**Mitigation**: TLS 1.3 with certificate pinning. Attacker cannot forge certificate for pinned public key. Connection fails immediately.

### Scenario 2: Rogue Node Impersonation

**Attack**: Attacker starts a service on `_elysium-vanguard._tcp` pretending to be a known node.

**Mitigation**: Console verifies node's certificate fingerprint against trusted peers. Rogue node's fingerprint won't match. Pairing required for new nodes.

### Scenario 3: Compromised Console

**Attack**: Console app is compromised, tries to escalate privileges.

**Mitigation**: Node is final authority. Console can only use capabilities explicitly granted. Node can revoke capabilities at any time.

### Scenario 4: Key Extraction

**Attack**: Attacker extracts private keys from device.

**Mitigation**: Keys stored in Keychain (hardware-backed on Apple Silicon). Even if extracted, keys are per-device and can be revoked by re-pairing.

### Scenario 5: Replay Attack

**Attack**: Attacker captures and replays capability grant tokens.

**Mitigation**: CapabilityGrant includes nonce and expiration. Replayed tokens rejected.

### Scenario 6: Relay Eavesdropping

**Attack**: Compromised relay server reads forwarded packets.

**Mitigation**: End-to-end encryption. Relay sees only encrypted bytes. ADR-012 specifies relay never sees plaintext.

## Security Properties

| Property | Guarantee |
|----------|-----------|
| Confidentiality | All data encrypted in transit (TLS 1.3) and at rest (Keychain) |
| Integrity | SHA-256 hash chain for audit, signature verification for updates/jobs |
| Authentication | Ed25519 cryptographic identity, challenge-response pairing |
| Authorization | Capability-based, 25 granular permissions, node is authority |
| Availability | Emergency stop, automatic rollback, reconnection with backoff |
| Non-repudiation | Audit log with hash chain, all actions attributed to device |
| Forward secrecy | Ephemeral keys for TLS, session keys not persisted |

## Known Limitations

1. **Physical access**: Device with unlocked screen can use the app. No additional authentication beyond macOS login.
2. **LAN only (v0.1)**: No encryption beyond LAN boundary. Coordinator/relay needed for WAN.
3. **No key revocation protocol**: Revoked peers must re-pair manually.
4. **Single-user model**: No multi-user permission delegation.
5. **No hardware attestation**: Cannot verify device integrity beyond Keychain.
