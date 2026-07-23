# Elysium Vanguard Fabric — Test Strategy

## Pyramid

### Unit Tests
- Protocol framing (encode/decode round trip)
- Message validation
- State machines (connection, capture, terminal)
- Pairing transcript verification
- Capability engine
- Input normalization
- Sequence deduplication
- Backoff calculation
- Audit hash chain
- Terminal ring buffer
- Telemetry aggregation
- Permission state mapping

### Property-Based Tests
- Encode/decode round trip for all message types
- Frame ordering and duplication detection
- Sequence number monotonicity
- Input coordinate bounds (0.0-1.0)
- Frame length validation
- Random protocol payloads
- Random disconnect points
- Idempotency of operations

### Fuzzing
- Frame decoder with random bytes
- Message header parsing
- Length field validation
- UTF-8 terminal output
- Pairing payload malformed data
- Terminal control messages
- Telemetry payload

### Integration Tests
- Bonjour discovery between two processes
- Pairing flow end-to-end
- TLS handshake
- Video loopback (capture → encode → decode)
- PTY creation and I/O
- Reconnect after disconnect
- Audit chain across sessions

### Physical Tests
- Mac M1 → MacBook Pro 2016
- Thunderbolt Bridge connection
- Wi-Fi connection
- Monitor disconnect/reconnect
- Network cable pull

## Concurrency Tests
1. Start/stop capture simultaneously
2. Two capture requests
3. Disconnect during encode
4. Reconnect during close
5. Terminal output during disconnect
6. Node shutdown during terminal
7. Console close during decode
8. Display change during capture
9. Permission revoked during capture
10. Peer revoked during session
11. Heartbeat timeout
12. Duplicate events
13. Out-of-order input
14. Lost key up
15. Thousands of mouse moves
16. Slow stream
17. Blocked network send
18. Multiple keyframe requests

## Memory Tests
- 1 hour of video
- 8 hours of session
- 100 reconnections
- 100 terminal open/close cycles
- Repeated resolution changes
- Verify: no linear growth, no retained CVPixelBuffers, no accumulated textures

## Performance Targets
- Resolution: 1920×1080
- FPS: 30 stable on LAN
- Glass-to-glass p50: < 80ms
- Glass-to-glass p95: < 150ms
- Input visible p95: < 100ms
- Node idle memory: < 150 MiB
- Node streaming memory: < 350 MiB
- Console memory: < 500 MiB
- Dropped frames: < 2% on stable network
- Reconnect: < 5s on LAN
- Duplicated operations: 0
- Secrets in logs: 0
