# Elysium Vanguard Fabric Protocol Specification

## Overview

The Elysium Vanguard Fabric Protocol (EVFP) is a binary protocol for communication between Nodes and Consoles in the Fabric.

## Protocol Identity

- **Magic**: `0x45 0x56 0x46 0x42` ("EVFB")
- **Byte Order**: Big-endian for all multi-byte fields
- **Default Port**: 49494
- **Transport**: TCP with TLS 1.3
- **Service Type**: `_elysium-vanguard._tcp` (Bonjour)

## Versioning

- **Major version**: Incompatible changes
- **Minor version**: Backward-compatible extensions
- **Current**: 1.0

## Connection Flow

```
Console                          Node
  |--- Hello (1.0) ------------->|
  |<-- HelloAck (1.0) ----------|
  |--- PairingRequest ---------->|
  |<-- PairingChallenge ---------|
  |--- PairingResponse ----------|
  |<-- PairingComplete ----------|
  |                              |
  |--- VideoConfig ------------->|
  |<-- VideoFrame ---------------|
  |   ...                        |
  |--- InputEvent -------------->|
  |                              |
  |--- TerminalOpen ------------>|
  |<-- TerminalOutput -----------|
  |                              |
  |--- FlowControlAck --------->|
  |<-- FlowControlAck ----------|
  |                              |
  |--- Heartbeat --------------->|
  |<-- HeartbeatAck -------------|
```

## Message Types

| ID    | Name                | Channel     | Description |
|-------|---------------------|-------------|-------------|
| 0x0001| hello               | control     | Initial handshake |
| 0x0002| helloAck            | control     | Handshake response |
| 0x0010| pairingRequest      | control     | Start pairing |
| 0x0011| pairingChallenge    | control     | Challenge code |
| 0x0012| pairingResponse     | control     | Pairing response |
| 0x0013| pairingComplete     | control     | Pairing done |
| 0x0020| authenticate        | control     | Session auth |
| 0x0021| authenticated       | control     | Auth success |
| 0x0030| capabilityRequest   | control     | Request capabilities |
| 0x0031| capabilityGranted   | control     | Capabilities granted |
| 0x0032| capabilityDenied    | control     | Capabilities denied |
| 0x0040| sessionOpen         | control     | Open session |
| 0x0041| sessionClose        | control     | Close session |
| 0x0050| heartbeat           | heartbeat   | Keepalive ping |
| 0x0051| heartbeatAck        | heartbeat   | Keepalive pong |
| 0x0060| emergencyStop       | control     | Emergency stop — release all keys, stop capture |
| 0x0100| videoConfiguration  | video       | Codec config |
| 0x0101| videoFrame          | video       | Video frame |
| 0x0102| videoKeyframeRequest| video       | Request keyframe |
| 0x0103| videoAccessUnit     | video       | H.264 access unit |
| 0x0200| inputEvent          | inputReliable| Input event |
| 0x0300| terminalOpen        | terminal    | Open terminal |
| 0x0301| terminalOpened      | terminal    | Terminal opened |
| 0x0302| terminalInput       | terminal    | Terminal input |
| 0x0303| terminalOutput      | terminal    | Terminal output |
| 0x0304| terminalResize      | terminal    | Resize terminal |
| 0x0305| terminalClose       | terminal    | Close terminal |
| 0x0400| telemetrySnapshot   | telemetry   | System telemetry |
| 0x0500| auditEvent          | audit       | Audit event |
| 0x0600| flowControlAck      | control     | Flow control ACK |
| 0x0700| artifactManifest    | control     | Artifact manifest |
| 0x0701| artifactChunk       | files       | Artifact chunk |
| 0x0702| artifactRequest     | control     | Request artifact |
| 0x0800| jobSubmit           | control     | Submit job |
| 0x0801| jobAssigned         | control     | Job assigned |
| 0x0802| jobProgress         | control     | Job progress |
| 0x0803| jobCompleted        | control     | Job completed |
| 0x0804| jobFailed           | control     | Job failed |
| 0x0805| jobCancelled        | control     | Job cancelled |
| 0x0900| resourceDescriptor  | control     | Node resources |
| 0x0A00| workspaceSync       | control     | Workspace sync |
| 0x0A01| workspaceChangeSet  | control     | Workspace changes |
| 0x0A02| workspaceRequest    | control     | Workspace request |
| 0x0A03| workspaceResponse   | control     | Workspace response |
| 0x0B00| presenceRegister    | control     | Register node with coordinator |
| 0x0B01| presenceDeregister  | control     | Deregister node |
| 0x0B02| presenceHeartbeat   | control     | Presence heartbeat |
| 0x0B03| presenceList        | control     | Request node list |
| 0x0B04| presenceListResponse| control     | Node list response |
| 0x0B10| rendezvousRequest   | control     | Request rendezvous |
| 0x0B11| rendezvousOffer     | control     | Rendezvous offer |
| 0x0B12| rendezvousAnswer    | control     | Rendezvous answer |
| 0x0B13| rendezvousComplete  | control     | Rendezvous complete |
| 0x0B14| rendezvousCancel    | control     | Rendezvous cancel |
| 0x0B20| signalingOffer      | control     | SDP offer |
| 0x0B21| signalingAnswer     | control     | SDP answer |
| 0x0B22| signalingIceCandidate| control    | ICE candidate |
| 0x0B23| signalingError      | control     | Signaling error |
| 0x0B30| relayAllocate       | control     | Allocate relay channel |
| 0x0B31| relayAllocateResponse| control    | Relay allocation response |
| 0x0B32| relayForward        | control     | Forward packet via relay |
| 0x0B33| relayForwardAck     | control     | Relay forward ACK |
| 0x0B34| relayRelease        | control     | Release relay channel |
| 0x0C00| clipboardData       | control     | Clipboard data sync |
| 0x0D00| agentSubmit         | control     | Submit agent plan |
| 0x0D01| agentProgress       | control     | Agent plan progress |
| 0x0D02| agentCompleted      | control     | Agent plan completed |
| 0x0D03| agentFailed         | control     | Agent plan failed |
| 0x0FFF| error               | control     | Error response |

## Channels

| ID | Name          | Max Payload | Delivery |
|----|---------------|-------------|----------|
| 0  | control       | 1 MiB       | reliable |
| 1  | inputReliable | 256 B       | reliable |
| 2  | inputEphemeral| 256 B       | best-effort |
| 3  | video         | 8 MiB       | best-effort |
| 4  | terminal      | 64 KiB      | reliable |
| 5  | telemetry     | 256 KiB     | reliable |
| 6  | files         | 4 MiB       | reliable |
| 7  | audit         | 256 KiB     | reliable |
| 8  | heartbeat     | 64 B        | reliable |

## Flow Control

- Video frames: auto-ack after processing
- Non-video messages: explicit FlowControlAck
- Sender pauses when window is full
- Receiver sends ACK with bytes received count
