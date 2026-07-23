# Elysium Vanguard Fabric — Permissions

## Required Permissions

### Screen Recording (Node)
- **Purpose**: Capture screen for remote viewing
- **API**: `CGPreflightScreenCaptureAccess()`, `CGRequestScreenCaptureAccess()`
- **When**: Required before starting capture
- **Grant**: System Settings → Privacy & Security → Screen Recording

### Accessibility (Node)
- **Purpose**: Dispatch mouse and keyboard input remotely
- **API**: `AXIsProcessTrustedWithOptions()`
- **When**: Required before input control
- **Grant**: System Settings → Privacy & Security → Accessibility

### Local Network (Both)
- **Purpose**: Discover and connect to Vanguard devices on LAN
- **When**: Required for Bonjour discovery and transport
- **Grant**: System Settings → Privacy & Security → Local Network

### Login Item (Node)
- **Purpose**: Start node automatically at login
- **API**: `SMAppService` (macOS 13+) or LaunchAgent (Monterey)
- **When**: Optional, enabled by user
- **Grant**: System Settings → General → Login Items

## Permission Flow

```
Node starts
→ Check all permissions
→ Show onboarding if any denied
→ Request permissions
→ Verify granted
→ Ready for pairing
```

## Permission States

- `unknown`: Not checked yet
- `notDetermined`: First time, will prompt
- `denied`: User denied, requires manual grant
- `granted`: Permission active
- `requiresRestart`: Permission granted but needs restart
- `unsupported`: Platform doesn't support this permission
