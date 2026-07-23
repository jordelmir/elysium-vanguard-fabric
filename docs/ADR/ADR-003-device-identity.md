# ADR-003: Device Identity

## Status

Accepted

## Context

Each device needs a persistent, verifiable identity for pairing and authentication.

## Decision

- Generate Ed25519 signing key pair
- Generate X25519 key agreement pair
- Store private keys in Keychain with item classes that require biometric or password
- Assign random `NodeID` (UUID)
- Compute certificate fingerprint from public key material
- Never export private keys
- Never reuse keys between installations

## Consequences

- Strong identity verification
- Keychain provides OS-level protection
- Revocation is possible by removing peer record
- Key rotation supported in future versions

## Verification

- Identity survives app restart
- Identity survives system reboot
- Private keys not accessible outside Keychain
- Pairing with wrong key fails verification
