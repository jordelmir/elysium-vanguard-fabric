# ADR-005: Video Codec

## Status

Accepted

## Context

Screen frames must be encoded efficiently for network transmission.

## Decision

Use H.264 via VideoToolbox with hardware acceleration preferred. Configure for low latency: no B-frame reordering, real-time rate control, keyframe interval 1-2 seconds.

## Consequences

- Hardware encoding on both Intel and Apple Silicon
- Low latency profile
- Wide decoder support
- Configurable bitrate (6-12 Mbps initial)
- SPS/PPS sent with keyframes and on reconnect

## Verification

- H.264 encoding succeeds on both architectures
- Decode works on M1 from Intel-encoded frames
- Memory bounded during encode/decode
- Keyframe recovery after desync
