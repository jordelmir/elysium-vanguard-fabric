# Elysium Vanguard Fabric — Language-Agnostic Protocol Schema

This document defines the wire format in a language-independent way so that implementations in Swift, Rust, Go, Kotlin, or any other language can interoperate.

## Type System

| Type | Size | Description |
|------|------|-------------|
| u8 | 1 byte | Unsigned 8-bit integer |
| u16 | 2 bytes | Unsigned 16-bit integer, big-endian |
| u32 | 4 bytes | Unsigned 32-bit integer, big-endian |
| u64 | 8 bytes | Unsigned 64-bit integer, big-endian |
| i32 | 4 bytes | Signed 32-bit integer, big-endian |
| f64 | 8 bytes | IEEE 754 double, big-endian |
| bool | 1 byte | 0x00 = false, 0x01 = true |
| uuid | 16 bytes | RFC 4122 v4, network byte order |
| bytes | variable | Length-prefixed: u32 length + raw data |
| string | variable | Length-prefixed: u32 length + UTF-8 data |
| enum | 1-4 bytes | Tag value, size depends on enum definition |

## Envelope (48 bytes fixed)

```
Offset  Size  Field
0       4     magic           0x45564642 ("EVFB")
4       2     protocolMajor   e.g. 1
6       2     protocolMinor   e.g. 0
8       2     messageType     Message type ID
10      2     channel         Stream channel ID
12      2     flags           Bit 0: hasMore, Bit 1: isFragment, Bit 2-15: reserved
14      2     reserved        Must be 0
16      16    sessionID       UUID (16 bytes)
32      8     sequence        Monotonic sequence number per channel
40      8     payloadLength   Total payload size in bytes
```

Total envelope: 48 bytes.

## Message Payloads

### hello (0x0001)

```
protocolMajor   u16
protocolMinor   u16
deviceID        uuid
displayName     string
capabilities    bytes    (Bitfield: 32 bits)
```

### helloAck (0x0002)

```
protocolMajor   u16
protocolMinor   u16
deviceID        uuid
displayName     string
capabilities    bytes    (Bitfield: 32 bits)
```

### pairingRequest (0x0010)

```
deviceID        uuid
publicKey       bytes    (EC P-256 public key, 64 bytes)
```

### pairingChallenge (0x0011)

```
challengeCode   string   (6-digit numeric code)
```

### pairingResponse (0x0012)

```
deviceID        uuid
publicKey       bytes    (EC P-256 public key, 64 bytes)
signature       bytes    (SHA-256 signature of challenge)
```

### pairingComplete (0x0013)

```
deviceID        uuid
trustStatus     u8       (0=trusted, 1=suspended, 2=revoked)
```

### authenticate (0x0020)

```
sessionID       uuid
deviceID        uuid
signature       bytes    (EC P-256 signature of session)
```

### authenticated (0x0021)

```
sessionID       uuid
success         bool
```

### capabilityRequest (0x0030)

```
requestedCaps   bytes    (Bitfield)
```

### capabilityGranted (0x0031)

```
grantedCaps     bytes    (Bitfield)
```

### capabilityDenied (0x0032)

```
deniedCaps      bytes    (Bitfield)
reason          string
```

### videoConfiguration (0x0100)

```
codec           u8       (0=H264)
revision        u32
width           u32
height          u32
nalLengthSize   u8       (4 for AVCC)
sps             bytes
pps             bytes
```

### videoFrame (0x0101)

```
frameID         u64
presentationTimestampNanos  u64
durationNanos   u64
isKeyframe      bool
configurationRevision  u32
payload         bytes    (H.264 AVCC data)
```

### inputEvent (0x0200)

```
eventType       u8       (0=mouseMove, 1=mouseButton, 2=scroll, 3=key, 4=releaseAll)
```

For mouseMove:
```
normalizedX     f64
normalizedY     f64
sequence        u64
```

For mouseButton:
```
button          u8       (0=left, 1=right, 2=middle)
phase           u8       (0=down, 1=up)
normalizedX     f64
normalizedY     f64
```

For scroll:
```
deltaX          f64
deltaY          f64
phase           u8       (0=began, 1=changed, 2=ended, 3=cancelled)
precise         bool
```

For key:
```
keyCode         u16
phase           u8       (0=down, 1=up)
modifiers       u32      (Bitfield: shift=1, control=2, option=4, command=8, capsLock=16, function=32)
isRepeat        bool
```

### terminalOpen (0x0300)

```
sessionID       uuid
shellPath       string
workingDirectory  string
columns         u16
rows            u16
```

### terminalOutput (0x0303)

```
sessionID       uuid
data            bytes
```

### artifactManifest (0x0700)

```
artifactID      uuid
logicalName     string
totalBytes      u64
chunkSize       u32
chunkCount      u32
sha256          bytes    (32 bytes)
contentType     string
```

### artifactChunk (0x0701)

```
artifactID      uuid
index           u32
offset          u64
payload         bytes
sha256          bytes    (32 bytes)
```

### jobSubmit (0x0800)

```
jobID           uuid
submittedBy     uuid
name            string
executor        u8       (0=nativeProcess, 1=swiftBuild, 2=xcodeBuild, ...)
command         struct {
    executable      string
    arguments       [string]
}
requirements    struct {
    allowedArchitectures  [u8]  (0=arm64, 1=x86_64, ...)
    minimumLogicalCPUs    u32
    minimumMemoryBytes    u64
}
timeoutSeconds  u64
priority        u8       (0=background, 1=normal, 10=critical)
```

### resourceDescriptor (0x0900)

```
nodeID          uuid
architecture    u8       (0=arm64, 1=x86_64, ...)
logicalCPUCount u32
totalMemoryBytes  u64
availableMemoryBytes  u64
totalStorageBytes  u64
availableStorageBytes  u64
batteryState    u8       (0=unknown, 1=charging, 2=discharging, 3=full, 4=notPresent)
thermalState    u8       (0=nominal, 1=fair, 2=serious, 3=critical)
currentCPULoad  f64
currentMemoryPressure  f64
```

## Capability Bitfield

```
Bit 0:  screenView
Bit 1:  screenControl
Bit 2:  audioReceive
Bit 3:  audioSend
Bit 4:  clipboardRead
Bit 5:  clipboardWrite
Bit 6:  terminalOpen
Bit 7:  terminalWrite
Bit 8:  fileRead
Bit 9:  fileWrite
Bit 10: processInspect
Bit 11: processExecute
Bit 12: jobSubmit
Bit 13: jobExecute
Bit 14: jobCancel
Bit 15: artifactRead
Bit 16: artifactWrite
Bit 17: workspaceRead
Bit 18: workspaceWrite
Bit 19: powerControl
Bit 20: softwareUpdate
Bit 21: agentPlan
Bit 22: agentExecute
Bit 23: policyAdmin
```

## Channel IDs

```
0: control       (reliable, 1 MiB max)
1: inputReliable (reliable, 256 B max)
2: inputEphemeral(best-effort, 256 B max)
3: video         (best-effort, 8 MiB max)
4: terminal      (reliable, 64 KiB max)
5: telemetry     (reliable, 256 KiB max)
6: files         (reliable, 4 MiB max)
7: audit         (reliable, 256 KiB max)
8: heartbeat     (reliable, 64 B max)
```

## Error Codes

```
0x0001: protocolIncompatible
0x0002: invalidMessage
0x0003: authenticationFailed
0x0004: capabilityDenied
0x0005: sessionNotFound
0x0006: resourceExhausted
0x0007: timeout
0x0008: internalError
```
