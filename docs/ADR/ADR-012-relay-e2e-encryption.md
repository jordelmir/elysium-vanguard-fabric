# ADR-012: Relay E2E Encryption

## Status

Accepted

## Context

When direct P2P connection is not possible (NAT, firewall), traffic must route through a relay server. The relay must never have access to plaintext data.

## Decision

Implement end-to-end encryption through relay:

```
Mac M1 ←──E2E──→ Oracle Relay ←──E2E──→ Mac 2016
```

### Architecture

1. **Direct connection preferred**: Nodes attempt direct TCP/TLS connection first
2. **Relay fallback**: When direct fails, route through relay
3. **E2E encryption**: All traffic encrypted between endpoints, relay sees only ciphertext
4. **Relay role**: Pure packet forwarding, no decryption

### Relay Responsibilities
- Presence directory
- Signaling for connection setup
- Encrypted packet relay
- Connection health monitoring

### Relay Prohibitions
- Decrypt video streams
- Decrypt input events
- Read terminal content
- Read clipboard content
- Read file contents
- Store device private keys
- Self-authorize

## Alternatives Considered

1. Relay with TLS termination - rejected, relay sees plaintext
2. VPN-only approach - rejected, requires infrastructure
3. No relay, direct only - rejected, fails behind NAT

## Consequences

- Relay operator cannot inspect traffic
- Relay has minimal attack surface
- Latency increases through relay
- Relay can be self-hosted for full control

## Risks

- Relay availability affects connectivity
- Relay performance impacts user experience
- Relay storage must be encrypted at rest
