# Elysium Vanguard Fabric — Cross-Platform SDK Structure

This document defines the structure for implementing Elysium Vanguard Fabric nodes in different languages.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Console (macOS, Swift)                    │
│  SwiftUI + AppKit + ScreenCaptureKit + VideoToolbox + Metal │
└───────────────────────┬─────────────────────────────────────┘
                        │ EVFP (TCP/TLS)
┌───────────────────────┴─────────────────────────────────────┐
│                    Node SDK (per-platform)                   │
│  Protocol codec + Transport + Capture + Executor + Agent    │
└─────────────────────────────────────────────────────────────┘
```

## Required Components Per Platform

### 1. Protocol Codec

Encode/decode the binary envelope and message payloads.

**Required**:
- Envelope parser (48-byte fixed header)
- Message type registry
- Payload serialization/deserialization
- Capability bitfield encoding
- UUID handling (RFC 4122 v4)

**Files**:
```
codec/
├── envelope.rs         (or .go, .kt)
├── message.rs
├── types.rs
├── capability.rs
└── error.rs
```

### 2. Transport

TCP connection with TLS 1.3.

**Required**:
- TCP client connect
- TLS 1.3 with certificate pinning
- Send/receive with framing
- Flow control (window-based backpressure)
- Heartbeat (ping/pong)
- Reconnection with exponential backoff

**Files**:
```
transport/
├── connection.rs
├── tls.rs
├── flow_control.rs
├── heartbeat.rs
└── reconnect.rs
```

### 3. Capture (Node-Side)

Capture screen, windows, or applications.

**Platform-specific**:
- macOS: ScreenCaptureKit (Swift only)
- Linux: PipeWire, X11, or Wayland capture
- Windows: DXGI Desktop Duplication API
- Android: MediaProjection API

**Files**:
```
capture/
├── screen_capture.rs
├── window_capture.rs
└── display_info.rs
```

### 4. Executor

Run jobs on the node.

**Required**:
- Process execution with sandboxing
- stdout/stderr streaming
- Timeout enforcement
- Cancellation (SIGTERM → SIGKILL)
- Output collection
- Artifact generation

**Files**:
```
executor/
├── native_process.rs
├── sandbox.rs
├── timeout.rs
└── artifact.rs
```

### 5. Agent (Optional)

AI agent integration.

**Required**:
- Plan reception
- Policy evaluation
- Execution orchestration
- Result reporting

**Files**:
```
agent/
├── plan_executor.rs
├── policy.rs
└── reporter.rs
```

## Platform-Specific Requirements

### macOS Node (Swift)

**Frameworks**:
- ScreenCaptureKit (capture)
- VideoToolbox (encode/decode)
- Metal (render)
- Network.framework (transport)
- Security.framework (TLS, keychain)
- CryptoKit (identity, signing)

**Deployment**: macOS 12.0+

### Linux Node (Rust)

**Libraries**:
- `tokio` (async runtime)
- `rustls` (TLS)
- `x264` or `openh264` (video encode/decode)
- `pipewire` or `xcb` (screen capture)
- `nix` (process management)

**Deployment**: Ubuntu 22.04+, Fedora 38+

### Windows Node (Rust or C#)

**APIs**:
- DXGI Desktop Duplication (capture)
- Media Foundation (encode/decode)
- SChannel (TLS)
- Win32 Process API (execution)

**Deployment**: Windows 10+

### Android Node (Kotlin)

**APIs**:
- MediaProjection (capture)
- MediaCodec (encode/decode)
- OkHttp (TLS transport)
- ProcessBuilder (execution)

**Deployment**: Android 10+

## Protocol Compliance Checklist

Each platform SDK must pass these tests:

- [ ] Envelope round-trip (serialize → parse → compare)
- [ ] All message types encode/decode correctly
- [ ] Capability bitfield encoding matches spec
- [ ] UUID handling matches RFC 4122
- [ ] Big-endian byte order for all multi-byte fields
- [ ] TLS 1.3 with certificate pinning
- [ ] Flow control window management
- [ ] Heartbeat ping/pong
- [ ] Reconnection with backoff
- [ ] Input event dispatch (mouse, keyboard, scroll)
- [ ] Video frame encode/decode (H.264 AVCC)
- [ ] Artifact chunk transfer with SHA-256 verification
- [ ] Job submission and execution
- [ ] Resource descriptor reporting
- [ ] Emergency stop handling

## Test Vector Consumption

Each SDK must implement a test vector runner:

```rust
// Rust example
fn run_test_vector(hex: &str, expected: &ParsedMessage) {
    let bytes = hex::decode(hex).unwrap();
    let parsed = parse_envelope(&bytes).unwrap();
    assert_eq!(parsed, *expected);
    
    let reencoded = parsed.serialize();
    assert_eq!(reencoded, bytes);
}
```

```go
// Go example
func TestVector(t *testing.T) {
    bytes, _ := hex.DecodeString(hexString)
    parsed, _ := ParseEnvelope(bytes)
    assert.Equal(t, expected, parsed)
    
    reencoded := parsed.Serialize()
    assert.Equal(t, bytes, reencoded)
}
```

## Interoperability Tests

Run between Swift (macOS) and Rust (Linux) nodes:

1. **Connect**: Swift console connects to Rust node
2. **Pairing**: Full pairing flow
3. **Capture**: Rust node captures screen, sends to Swift
4. **Input**: Swift sends input, Rust dispatches
5. **Transfer**: File transfer with integrity check
6. **Job**: Submit job to Rust node, collect artifact
7. **Disconnect**: Clean disconnect and reconnect

## Future: Coordinator Server

The coordinator server (Oracle Free) should be implemented in a cross-platform language:

**Recommendation**: Rust or Go

**Responsibilities**:
- Presence directory (node registration)
- Rendezvous (connection brokering)
- Signaling (NAT traversal coordination)
- Relay (packet forwarding when P2P fails)
- Job queue (optional, for distributed builds)
- Artifact cache (optional, for build caching)

**Files**:
```
coordinator/
├── presence.rs
├── rendezvous.rs
├── signaling.rs
├── relay.rs
├── job_queue.rs
├── artifact_cache.rs
└── main.rs
```
