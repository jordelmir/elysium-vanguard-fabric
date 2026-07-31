# Protocol Framing

## Two Framing Formats

The protocol defines two framing formats:

1. **ProtocolHeader (25 bytes)** — The canonical wire format used by `NetworkTransport`. This is what goes on the TCP/TLS socket. It does NOT include a session ID; session routing is handled at the transport layer.

2. **FabricMessageEnvelope (48 bytes)** — A higher-level envelope used by cross-platform SDK test vectors and documentation. It includes a 16-byte session ID field for routing context. This format is NOT used on the wire by the native transport.

**The canonical wire format is ProtocolHeader (25 bytes).** Cross-platform SDKs should implement ProtocolHeader for wire compatibility. FabricMessageEnvelope is provided for reference and test vector generation only.

## Header Structure (25 bytes) — Canonical Wire Format

```
Offset  Size  Field
0       4     Magic (0x45564642)
4       2     Protocol Version (major)
6       2     Protocol Version (minor)
8       2     Message Type
10      2     Flags
12      2     Reserved
14      1     Stream Channel
15      8     Sequence Number
23      4     Payload Length
```

## Total Frame

```
[Header 25 bytes][Payload N bytes]
```

## Envelope Structure (32 bytes)

Used for extended routing:

```
Offset  Size  Field
0       4     Magic
4       2     Protocol Major
6       2     Protocol Minor
8       2     Message Type
10      2     Channel
12      2     Flags
14      2     Reserved
16      16    Session ID (UUID)
32      8     Sequence Number
40      8     Payload Length
```

## Flags

| Bit | Name           | Description |
|-----|----------------|-------------|
| 0   | requiresResponse | Message expects a response |
| 1   | isResponse     | This is a response message |
| 2   | isFragment     | Fragmented message |
| 3   | isLastFragment | Last fragment |
| 4   | urgent         | Priority message |

## Constraints

- Max control payload: 1 MiB
- Max video access unit: 8 MiB
- Max terminal chunk: 64 KiB
- Max file chunk: 4 MiB
- Max telemetry payload: 256 KiB
