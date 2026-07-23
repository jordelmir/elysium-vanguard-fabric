# Elysium Vanguard Fabric — Threat Model

## Assets

- User's Mac computers
- Screen content (potentially sensitive)
- Keyboard input (potentially credentials)
- File system access
- Terminal sessions and command history
- Pairing keys and trust relationships
- Audit logs

## Threat Actors

1. **LAN attacker**: Same network segment, passive or active
2. **MITM**: Intercepting or modifying traffic
3. **Compromised peer**: Previously trusted device now malicious
4. **Stolen device**: Physical theft of M1 or MacBook
5. **Malicious update**: Tampered application binary

## Threats and Mitigations

### 1. LAN Sniffing
- **Asset**: Screen content, input, files
- **Attack**: Passive packet capture on LAN
- **Precondition**: Attacker on same network segment
- **Mitigation**: TLS encryption on all transport
- **Residual**: Metadata leakage (IP addresses, timing)
- **Verification**: Protocol inspection tests

### 2. MITM Attack
- **Asset**: Authentication credentials, pairing keys
- **Attack**: Intercept and modify pairing/handshake
- **Precondition**: ARP spoofing or DNS hijack on LAN
- **Mitigation**: Certificate pinning, Ed25519 signatures
- **Residual**: First pairing vulnerable if user tricked
- **Verification**: MITM simulation tests

### 3. Replay Attack
- **Asset**: Commands, input events
- **Attack**: Re-record and replay valid messages
- **Precondition**: Capture of valid traffic
- **Mitigation**: Sequence numbers, operation IDs, idempotency cache
- **Residual**: None if sequence tracking is correct
- **Verification**: Replay detection tests

### 4. Compromised Peer
- **Asset**: All resources accessible via granted capabilities
- **Attack**: Previously trusted device behaves maliciously
- **Precondition**: Device compromise after pairing
- **Mitigation**: Capability scoping, revocation, audit
- **Residual**: Window between compromise and detection
- **Verification**: Revocation tests, audit verification

### 5. Brute Force Pairing
- **Asset**: Pairing code (6 digits)
- **Attack**: Try all 1,000,000 combinations
- **Precondition**: Access to pairing protocol
- **Mitigation**: Rate limiting, challenge expiry (120s), max attempts
- **Residual**: 3 attempts in 120s = very limited
- **Verification**: Rate limiting tests

### 6. Malicious Payload Deserialization
- **Asset**: Node process memory
- **Attack**: Craft invalid message payload
- **Precondition**: Network access to node
- **Mitigation**: Strict validation, size limits, typed decoders
- **Residual**: Parser bugs in JSON/Codable
- **Verification**: Fuzzing tests

### 7. Payload Length Bomb
- **Asset**: Node memory
- **Attack**: Send message claiming huge payload
- **Precondition**: Network access
- **Mitigation**: Per-channel max payload limits, validate before allocation
- **Residual**: None if limits enforced
- **Verification**: Oversized payload rejection tests

### 8. Frame Bomb
- **Asset**: Network bandwidth, decoder resources
- **Attack**: Flood with video frames
- **Precondition**: Active session
- **Mitigation**: Frame dropping, backpressure, rate limiting
- **Residual**: Temporary degradation
- **Verification**: Stress tests

### 9. Terminal Injection
- **Asset**: Terminal session, underlying system
- **Attack**: Inject escape sequences or commands
- **Precondition**: Active terminal session
- **Mitigation**: Input validation, PTY isolation, process group
- **Residual**: Shell-specific injection vectors
- **Verification**: Terminal injection tests

### 10. Command Injection
- **Asset**: Node system
- **Attack**: Execute arbitrary commands via task descriptors
- **Precondition**: Active session with processExecute capability
- **Mitigation**: Typed task descriptors, no raw shell execution
- **Residual**: Task descriptor parsing bugs
- **Verification**: Task validation tests

### 11. Path Traversal
- **Asset**: File system
- **Attack**: Access files outside authorized directories
- **Precondition**: Active session with fileRead/fileWrite
- **Mitigation**: Path canonicalization, directory confinement
- **Residual**: Symlink escape
- **Verification**: Path traversal tests

### 12. Stuck Input
- **Asset**: Remote system usability
- **Attack**: Send keyDown without keyUp
- **Precondition**: Active control session
- **Mitigation**: releaseAll on disconnect, key state tracking, panic shortcut
- **Residual**: Edge cases in modifier keys
- **Verification**: Stuck key recovery tests

### 13. Denial of Service
- **Asset**: Availability
- **Attack**: Exhaust resources or crash node
- **Precondition**: Network access
- **Mitigation**: Resource limits, timeouts, graceful degradation
- **Residual**: Undiscovered resource leaks
- **Verification**: 8-hour session tests, memory tests

### 14. Log Secret Leakage
- **Asset**: Credentials, keys
- **Attack**: Read log files for secrets
- **Precondition**: Access to log storage
- **Mitigation**: Log sanitizer, private markers, audit
- **Residual**: Undiscovered logging points
- **Verification**: Secret scan in logs

### 15. Stolen Device
- **Asset**: All data on device
- **Attack**: Physical access to stolen Mac
- **Precondition**: Device theft
- **Mitigation**: FileVault, keychain protection, revocation from other device
- **Residual**: If FileVault not enabled
- **Verification**: Revocation workflow tests
