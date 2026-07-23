# ADR-004: Screen Capture

## Status

Accepted

## Context

The node must capture its screen for remote viewing.

## Decision

Use ScreenCaptureKit (introduced macOS 12.3) for screen capture. Fallback to CGWindowListCreateImage for macOS versions before 12.3 is not planned; the node requires macOS 12.3+ minimum.

## Consequences

- Modern, performant capture API
- Hardware-accelerated when available
- Requires Screen Recording permission
- Can select specific displays, windows, or applications
- Delivers frames as CMSampleBuffer

## Verification

- Capture starts after permission granted
- Capture fails gracefully when permission denied
- Frame rate matches configuration
- Memory bounded during capture
