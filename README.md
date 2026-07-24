# Elysium Vanguard Fabric

Sovereign local-first platform for controlling multiple computers from a central console.

## Overview

Elysium Vanguard Fabric turns multiple Macs into a single coherent, low-latency remote work environment. View screens, control input, open terminals, share clipboards, and monitor system health — all over a secure TLS 1.3 local connection with zero cloud dependency.

## First Use Case

```
Mac M1 (Console)
    ↓ secure TLS 1.3 connection
MacBook Pro Intel 2016 (Node)
```

Control your MacBook with a damaged screen from your M1 Mac — full remote desktop, terminal, and clipboard sync.

## Features

### P0 — Core Remote Control
- **Screen Capture** — ScreenCaptureKit hardware-accelerated capture at 1080p60
- **H.264 Encode/Decode** — VideoToolbox hardware pipeline with adaptive bitrate
- **Metal Rendering** — Zero-copy GPU rendering via MTKView with aspect-correct scaling
- **Input Dispatch** — Mouse, keyboard, scroll, drag, modifiers, key repeat, emergency stop
- **TLS 1.3** — ECDH P256 key exchange, mutual authentication, identity pinning

### P1 — Platform Services
- **Bonjour Discovery** — Automatic LAN discovery via `_elysium-vanguard._tcp`
- **Pairing Flow** — 6-digit challenge code with transcript hash verification
- **Terminal** — Full PTY terminal with word wrap, command history, resize
- **Clipboard Sync** — Bidirectional NSPasteboard sync (10MB limit, 500ms polling)
- **File Transfer** — Drag-and-drop file exchange between Console and Node
- **Audio Capture** — ScreenCaptureKit system audio forwarding
- **Workspace Management** — Multi-display workspace orchestration
- **LaunchAgent** — Node auto-start on boot

### P2 — Enterprise & Polish
- **Audit Log** — Append-only hash chain with SHA-256 integrity verification
- **Telemetry** — CPU, memory, GPU, battery, disk, network, thermal monitoring
- **Keyboard Shortcuts** — Emergency Stop (⌘⇧.), Fullscreen, New Tab, Disconnect
- **Theme Profiles** — Minimal, Balanced, Ultra presets with glass morphism
- **Observability** — 21-category os.Logger with structured diagnostics
- **CI/CD** — GitHub Actions PR gate + Nightly builds

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Console (Mac M1)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ UI Layer │  │ Decoder  │  │ Input Dispatch   │  │
│  │ Metal    │  │ H.264    │  │ CGEvent          │  │
│  └────┬─────┘  └────┬─────┘  └────────┬─────────┘  │
│       └──────────────┼─────────────────┘            │
│              ┌───────┴────────┐                     │
│              │ Session Coord  │                     │
│              │ (Actor)        │                     │
│              └───────┬────────┘                     │
│              ┌───────┴────────┐                     │
│              │ TLS Transport  │                     │
│              │ NWConnection   │                     │
│              └───────┬────────┘                     │
└──────────────────────┼──────────────────────────────┘
                       │ LAN / Thunderbolt / Ethernet
┌──────────────────────┼──────────────────────────────┐
│              ┌───────┴────────┐                     │
│              │ TLS Transport  │                     │
│              │ NWConnection   │                     │
│              └───────┬────────┘                     │
│              ┌───────┴────────┐                     │
│              │ Session Coord  │                     │
│              │ (Actor)        │                     │
│              └───────┬────────┘                     │
│  ┌──────────┐  ┌─────┴──────┐  ┌────────────────┐  │
│  │ Capture  │  │ Encoder    │  │ Terminal (PTY) │  │
│  │ SCKit    │  │ H.264 VT   │  │ POSIX          │  │
│  └──────────┘  └────────────┘  └────────────────┘  │
│                  Node (Intel)                       │
└─────────────────────────────────────────────────────┘
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

# Build release
./build.sh

# Run Node
open Apps/VanguardNodeMac/.build/release/VanguardNodeMac.app

# Run Console
open Apps/VanguardConsoleMac/.build/release/VanguardConsoleMac.app
```

## Packages (23)

| Package | Purpose |
|---------|---------|
| VanguardDomain | Pure domain models, zero Apple imports |
| VanguardProtocol | Binary wire protocol with 10 logical channels |
| VanguardTransport | NWConnection TLS transport with multiplexer |
| VanguardDiscovery | Bonjour `_elysium-vanguard._tcp` discovery |
| VanguardIdentity | Ed25519 + X25519 device identity |
| VanguardSecurity | TLS 1.3, ECDH P256, capability-based auth |
| VanguardPermissions | Screen Recording, Accessibility, Microphone |
| VanguardCapture | ScreenCaptureKit capture with presets |
| VanguardVideo | VideoToolbox H.264 encode/decode |
| VanguardRender | Metal zero-copy GPU renderer |
| VanguardInput | CGEvent dispatch with coalescing |
| VanguardTerminal | POSIX PTY terminal service |
| VanguardClipboard | NSPasteboard bidirectional sync |
| VanguardAudio | ScreenCaptureKit audio capture |
| VanguardFiles | File transfer service |
| VanguardProcesses | Process supervision |
| VanguardTelemetry | System metrics collector |
| VanguardAudit | Append-only hash chain audit log |
| VanguardUI | Design system, glass morphism, themes |
| VanguardPersistence | Data storage |
| VanguardWorkspace | Multi-display workspace |

## Video Pipeline

The end-to-end video pipeline operates at 1080p30 with H.264 hardware encoding:

```
ScreenCaptureKit → CVPixelBuffer → VideoToolbox Encoder → H.264 NAL
    → Binary Protocol Framing → TLS 1.3 Transport
    → VideoToolbox Decoder → CVPixelBuffer → Metal Renderer
```

- **Latency**: <50ms encode+decode on Apple Silicon
- **Bitrate**: 8 Mbps default, adaptive
- **Keyframes**: On-demand via Console request

## License

Copyright © 2026 Jorge David Del Valle Miranda. All rights reserved.
Proprietary software. Unauthorized distribution is prohibited.
