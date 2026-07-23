# Elysium Vanguard Fabric

Sovereign local-first platform for controlling multiple computers from a central console.

## Overview

Elysium Vanguard Fabric enables you to control multiple Macs as a single logical infrastructure. View screens, control input, open terminals, and monitor system health — all over a secure local connection.

## First Use Case

```
Mac M1 (Console)
    ↓ secure local connection
MacBook Pro Intel 2016 (Node)
```

Control your MacBook with a damaged screen from your M1 Mac.

## Architecture

```
Vanguard Console ←→ Vanguard Link ←→ Vanguard Node
     UI                  TLS            Capture/Input/Terminal
```

## Requirements

- macOS 12.3+ (both devices)
- Same LAN, Thunderbolt Bridge, or direct Ethernet
- Screen Recording permission (Node)
- Accessibility permission (Node, for input control)

## Quick Start

```bash
# Bootstrap
./Scripts/bootstrap.sh

# Build
./Scripts/build-all.sh

# Test
./Scripts/test-all.sh
```

## Packages

| Package | Purpose |
|---------|---------|
| VanguardDomain | Pure domain models |
| VanguardProtocol | Wire protocol |
| VanguardTransport | Network abstraction |
| VanguardDiscovery | Bonjour discovery |
| VanguardIdentity | Device identity |
| VanguardSecurity | Authorization |
| VanguardPermissions | macOS permissions |
| VanguardCapture | Screen capture |
| VanguardVideo | Video encode/decode |
| VanguardInput | Input control |
| VanguardTerminal | PTY terminals |
| VanguardProcesses | Process supervision |
| VanguardTelemetry | System metrics |
| VanguardAudit | Audit logging |
| VanguardPersistence | Data storage |

## License

Copyright © 2026 Jorge David Del Valle Miranda. All rights reserved.
