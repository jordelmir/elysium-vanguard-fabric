# Cross-Platform Test Vectors

These test vectors are designed to be consumed by any implementation (Swift, Rust, Go, Kotlin) to validate protocol correctness.

## How to Use

1. Parse the hex string into bytes
2. Decode using your protocol implementation
3. Validate all fields match the expected values
4. Re-encode and compare with the original hex

---

## Test Vector 1: Hello Message Envelope

**Description**: Valid hello message envelope with zero payload.

**Hex**:
```
45564642 0001 0000 0001 0000 0000 0000
00000000000000000000000000000000
0000000000000000
0000000000000000
```

**Fields**:
- magic: 0x45564642
- protocolMajor: 1
- protocolMinor: 0
- messageType: 0x0001 (hello)
- channel: 0 (control)
- flags: 0
- reserved: 0
- sessionID: 00000000-0000-0000-0000-000000000000
- sequence: 0
- payloadLength: 0

---

## Test Vector 2: Binding Request (STUN)

**Description**: STUN binding request with random transaction ID.

**Hex (example)**:
```
0001 0000 2112A442
0102030405060708090A0B0C
```

**Fields**:
- type: 0x0001 (binding request)
- length: 0
- magicCookie: 0x2112A442
- transactionID: 0102030405060708090A0B0C

---

## Test Vector 3: Video Configuration Payload

**Description**: H.264 video configuration with SPS/PPS.

**JSON**:
```json
{
    "codec": 0,
    "revision": 1,
    "width": 1920,
    "height": 1080,
    "nalLengthSize": 4,
    "sps": "Z0IAHuUBQEgb",
    "pps": "aM4G4g=="
}
```

**Base64 SPS**: `Z0IAHuUBQEgb`
**Base64 PPS**: `aM4G4g==`

---

## Test Vector 4: Input Event — Mouse Move

**Description**: Normalized mouse move at center of screen.

**JSON**:
```json
{
    "eventType": 0,
    "normalizedX": 0.5,
    "normalizedY": 0.5,
    "sequence": 42
}
```

---

## Test Vector 5: Input Event — Key Press

**Description**: Key down for 'A' key (keyCode 0x00) with shift modifier.

**JSON**:
```json
{
    "eventType": 3,
    "keyCode": 0,
    "phase": 0,
    "modifiers": 1,
    "isRepeat": false
}
```

---

## Test Vector 6: Artifact Manifest

**Description**: 1 MB file with SHA-256 integrity.

**JSON**:
```json
{
    "artifactID": "550e8400-e29b-41d4-a716-446655440000",
    "logicalName": "Vanguard-arm64",
    "totalBytes": 1048576,
    "chunkSize": 65536,
    "chunkCount": 16,
    "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "contentType": "application/octet-stream"
}
```

---

## Test Vector 7: Resource Descriptor

**Description**: Apple Silicon node with 16 CPU cores, 16 GB RAM.

**JSON**:
```json
{
    "nodeID": "6BA7B810-9DAD-11D1-80B4-00C04FD430C8",
    "architecture": 0,
    "logicalCPUCount": 16,
    "totalMemoryBytes": 17179869184,
    "availableMemoryBytes": 8589934592,
    "totalStorageBytes": 500000000000,
    "availableStorageBytes": 250000000000,
    "batteryState": 4,
    "thermalState": 0,
    "currentCPULoad": 0.25,
    "currentMemoryPressure": 0.5
}
```

---

## Test Vector 8: Capability Bitfield

**Description**: Console capabilities (screen view + control + clipboard + terminal + file + job + agent).

**Hex**: `000000DF`
**Binary**: `11011111`
**Capabilities**:
- screenView (bit 0): ✓
- screenControl (bit 1): ✓
- clipboardRead (bit 4): ✓
- clipboardWrite (bit 5): ✓
- terminalOpen (bit 6): ✓
- fileRead (bit 8): ✓
- fileWrite (bit 9): ✓
- jobSubmit (bit 12): ✓
- jobExecute (bit 13): ✓
- agentPlan (bit 21): ✓

---

## Test Vector 9: Connection Route Negotiation

**Description**: Both sides behind cone NAT, relay available.

**Input**:
```json
{
    "localNATType": "coneNAT",
    "targetNATType": "coneNAT",
    "targetExternalAddress": {"ip": "203.0.113.1", "port": 5000},
    "relayAvailable": true
}
```

**Expected Route**: `direct` to `203.0.113.1:5000`

---

## Test Vector 10: Connection Route Negotiation — Relay Required

**Description**: Local node behind symmetric NAT.

**Input**:
```json
{
    "localNATType": "symmetricNAT",
    "targetNATType": "coneNAT",
    "targetExternalAddress": {"ip": "203.0.113.1", "port": 5000},
    "relayAvailable": true,
    "relayHost": "relay.example.com",
    "relayPort": 443
}
```

**Expected Route**: `relay` to `relay.example.com:443`
