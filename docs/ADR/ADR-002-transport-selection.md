# ADR-002: Transport Selection

## Status

Accepted (Initial)

## Context

The transport layer must provide authenticated, encrypted, low-latency communication between Console and Node over LAN.

## Options Considered

1. **Network.framework + QUIC**: Native macOS, built-in TLS, multiplexing
2. **Network.framework + TCP + TLS**: Widely compatible, proven
3. **WebSockets**: Cross-platform but higher overhead
4. **gRPC**: Feature-rich but heavy dependency
5. **Custom UDP**: Maximum control but requires crypto implementation

## Decision

Start with Network.framework + QUIC as primary transport. If QUIC presents practical incompatibilities on macOS 12 (Monterey), fall back to TLS over TCP under the same `VanguardTransport` protocol abstraction.

## Consequences

- Native performance on macOS
- Built-in TLS without custom crypto
- QUIC provides multiplexing and 0-RTT
- Fallback to TCP if needed without domain changes
- Transport protocol abstraction enables future alternatives

## Verification

- QUIC spike between M1 and MacBook 2016
- TLS fallback test
- Latency measurement
