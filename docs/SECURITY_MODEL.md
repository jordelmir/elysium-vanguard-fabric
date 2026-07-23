# Elysium Vanguard Fabric — Security Model

## Authentication

- Ed25519 signing for identity verification
- X25519 for key agreement
- Challenge-response pairing with 6-digit code
- Certificate fingerprint verification

## Authorization

- Capability-based access control
- No monolithic "full control" capability
- Each action checked against granted capabilities
- Node is the final authority

## Transport Security

- TLS encryption on all channels
- Certificate pinning for known peers
- No plaintext fallback
- Protocol version negotiation

## Input Security

- Accessibility permission required
- Rate limiting on input events
- Coordinate validation
- Key state tracking
- Panic shortcut for emergency release

## Data Protection

- Private keys in Keychain only
- No secrets in logs
- No secrets in SQLite
- Audit log without sensitive content

## Audit

- Hash chain for tamper evidence
- All critical actions logged
- Chain integrity verifiable
- Exportable for analysis
