# ADR-008: Node Autostart

## Status

Accepted

## Context

The node should start automatically at login for convenience.

## Decision

- macOS 13+: Use `SMAppService` for LoginItem registration
- macOS 12 (Monterey): Use LaunchAgent plist with user consent
- Both paths behind `NodeAutostartService` protocol

## Consequences

- Consistent API across OS versions
- Monterey gets LaunchAgent, Ventura+ gets SMAppService
- User consent required for both
- No root daemons

## Verification

- Node starts at login after enabling autostart
- Node does not start if autostart disabled
- Uninstall removes LaunchAgent/SMAppService registration
