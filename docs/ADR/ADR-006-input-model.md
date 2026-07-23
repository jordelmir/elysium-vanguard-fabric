# ADR-006: Input Model

## Status

Accepted

## Context

Remote input must be captured on the console and dispatched on the node.

## Decision

- Use canonical `RemoteInputEvent` enum for all input types
- Mouse coordinates normalized to 0.0-1.0 range
- Reliable channel for key/button down/up events
- Ephemeral channel for mouse move (last-value-wins)
- CGEvent for dispatch on node
- Accessibility permission required
- Panic shortcut (Ctrl+Opt+Cmd+Esc) locally to release control

## Consequences

- Coordinate system independent of screen resolution
- Reliable delivery for critical events
- Low latency for mouse movement
- Safety mechanism for lost control
- Requires Accessibility permission on node

## Verification

- Mouse movement smooth
- Click, right-click, scroll work
- Keyboard input including modifiers
- Panic shortcut releases control
- Disconnect releases all keys
