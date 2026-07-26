# Protocol Versioning

## Version Format

```
<major>.<minor>
```

- **Major**: Incompatible wire format changes
- **Minor**: Backward-compatible extensions

## Negotiation

```
Console supports: 1.0–1.4
Node supports:    1.0–1.2
Result:           1.2
```

## Rules

1. Major version mismatch = connection refused
2. Minor version: use highest mutually supported
3. Unknown message types on minor extensions: ignore
4. Unknown message types on major mismatch: disconnect

## Current Version

- **1.0**: Initial release
