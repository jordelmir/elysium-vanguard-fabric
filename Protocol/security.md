# Protocol Security

## Transport Security

- TLS 1.3 mandatory
- EC P-256 key pairs
- Certificate pinning via SHA-256 fingerprint
- No self-signed certificates accepted after pairing

## Identity Model

- Each device has a unique signing key pair
- Each device has a unique agreement key pair (ECDH)
- Certificate fingerprint is the device identity anchor
- No hostname/IP-based identity

## Pairing

1. Console generates pairing code
2. Node displays code for user verification
3. Both exchange public keys and transcript hash
4. Transcript hash = SHA-256(paired public keys)
5. Capabilities granted on pairing completion

## Capability Tokens

- Signed CapabilityGrant with expiration
- Contains: grantID, sessionID, subjectDeviceID, issuerDeviceID
- Validated: signature, expiry, issuer, revocation
- Replay protection via nonce

## Threats Mitigated

- Man-in-the-middle: TLS + certificate pinning
- Replay attacks: sequence numbers + nonces
- Unauthorized access: capability tokens
- Identity spoofing: cryptographic identity only
