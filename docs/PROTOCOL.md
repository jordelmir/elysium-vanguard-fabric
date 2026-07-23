# Elysium Vanguard Fabric — Protocol

## Wire Format

All messages use binary framing:

```
Offset  Size  Field
0       4     Magic (0x45 0x56 0x46 0x42 = "EVFB")
4       2     Protocol Version (big-endian uint16)
6       2     Message Type (big-endian uint16)
8       2     Flags (big-endian uint16)
10      2     Reserved (uint16)
12      1     Stream Channel (uint8)
13      8     Sequence Number (big-endian uint64)
21      4     Payload Length (big-endian uint32)
25      N     Payload
```

Total header: 25 bytes.

## Message Types

| Type | Value | Channel | Description |
|------|-------|---------|-------------|
| HELLO | 0x0001 | Control | Initial handshake |
| HELLO_ACK | 0x0002 | Control | Handshake acknowledgment |
| PAIRING_REQUEST | 0x0010 | Control | Initiate pairing |
| PAIRING_CHALLENGE | 0x0011 | Control | 6-digit code challenge |
| PAIRING_RESPONSE | 0x0012 | Control | Code + key exchange |
| PAIRING_COMPLETE | 0x0013 | Control | Pairing finalized |
| AUTHENTICATE | 0x0020 | Control | Session authentication |
| AUTHENTICATED | 0x0021 | Control | Auth success |
| CAPABILITY_REQUEST | 0x0030 | Control | Request capabilities |
| CAPABILITY_GRANTED | 0x0031 | Control | Capabilities approved |
| CAPABILITY_DENIED | 0x0032 | Control | Capabilities rejected |
| SESSION_OPEN | 0x0040 | Control | Open session |
| SESSION_CLOSE | 0x0041 | Control | Close session |
| HEARTBEAT | 0x0050 | Heartbeat | Keepalive |
| HEARTBEAT_ACK | 0x0051 | Heartbeat | Keepalive response |
| VIDEO_CONFIGURATION | 0x0100 | Video | Encoder config |
| VIDEO_FRAME | 0x0101 | Video | Encoded frame |
| VIDEO_KEYFRAME_REQUEST | 0x0102 | Video | Request keyframe |
| INPUT_EVENT | 0x0200 | Input | Mouse/keyboard |
| TERMINAL_OPEN | 0x0300 | Terminal | Open terminal |
| TERMINAL_OPENED | 0x0301 | Terminal | Terminal ready |
| TERMINAL_INPUT | 0x0302 | Terminal | Terminal input |
| TERMINAL_OUTPUT | 0x0303 | Terminal | Terminal output |
| TERMINAL_RESIZE | 0x0304 | Terminal | Resize terminal |
| TERMINAL_CLOSE | 0x0305 | Terminal | Close terminal |
| TELEMETRY_SNAPSHOT | 0x0400 | Telemetry | Metrics |
| AUDIT_EVENT | 0x0500 | Audit | Audit entry |
| ERROR | 0x0FFF | Control | Error response |

## Stream Channels

| Channel | Value | Reliability | Max Payload |
|---------|-------|-------------|-------------|
| Control | 0 | Reliable, ordered | 1 MiB |
| Input Reliable | 1 | Reliable, ordered | 256 bytes |
| Input Ephemeral | 2 | Last-value-wins | 256 bytes |
| Video | 3 | Expirable | 8 MiB |
| Terminal | 4 | Reliable, ordered | 64 KiB |
| Telemetry | 5 | Last-value-wins | 256 KiB |
| Files | 6 | Reliable, ordered | 4 MiB |
| Audit | 7 | Reliable, ordered | 256 KiB |
| Heartbeat | 8 | Reliable, ordered | 64 bytes |

## Limits

- Network byte order (big-endian) for all multi-byte fields
- Magic constant must match exactly
- Payload length validated before memory allocation
- Unknown message types rejected without crash
- Sequence numbers per channel for deduplication
- Operation IDs for idempotent commands
