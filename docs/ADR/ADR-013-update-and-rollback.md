# ADR-013: Update and Rollback

## Status

Accepted

## Context

The platform needs secure, reliable update mechanisms with rollback capability to prevent bricking devices.

## Decision

Implement signed updates with staged rollout and automatic rollback:

### Update Flow

```
Download → Verify Signature → Verify Hash → Install to Staging → Health Check → Activate → Rollback if Failed
```

### Security Requirements
- All updates must be cryptographically signed
- SHA-256 hash verification required
- Signature verification against trusted public key
- No unsigned updates accepted

### Staged Installation
1. Download to staging directory
2. Verify integrity
3. Run health check
4. Activate (atomic rename)
5. If health check fails, rollback

### Rollback Strategy
- Keep previous version available
- Automatic rollback on health check failure
- Manual rollback capability
- No update replaces running agent without recovery mechanism

### Update Manifest

```swift
struct UpdateManifest: Codable, Sendable {
    let version: String
    let build: UInt64
    let targetOS: String
    let targetArchitecture: CPUArchitecture
    let minimumOSVersion: String
    let artifactURL: String
    let sha256: Data
    let signature: Data
    let releaseNotes: String
}
```

## Alternatives Considered

1. In-place updates - rejected, no recovery
2. Auto-updates without verification - rejected, security risk
3. Manual updates only - rejected, poor UX

## Consequences

- Updates are cryptographically verified
- Failed updates automatically rollback
- Users can inspect release notes before updating
- Platform remains stable through updates

## Risks

- Signing key compromise affects all updates
- Rollback may lose user data if not designed carefully
- Health check may not catch all issues
