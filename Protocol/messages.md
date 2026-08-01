# Message Reference

All messages are sent inside a 48-byte envelope (see framing.md). The payload follows the envelope.

## Control Messages

### hello (0x0001)

Initial handshake from Console to Node.

| Field | Type | Description |
|-------|------|-------------|
| protocolMajor | u16 | Protocol major version |
| protocolMinor | u16 | Protocol minor version |
| deviceID | uuid | Sender's device identifier |
| displayName | string | Human-readable device name |
| capabilities | bytes | 32-bit capability bitfield |

### helloAck (0x0002)

Node response to hello.

| Field | Type | Description |
|-------|------|-------------|
| protocolMajor | u16 | Negotiated major version |
| protocolMinor | u16 | Negotiated minor version |
| deviceID | uuid | Node's device identifier |
| displayName | string | Human-readable device name |
| capabilities | bytes | 32-bit capability bitfield |

### pairingRequest (0x0010)

Console requests to pair with a Node.

| Field | Type | Description |
|-------|------|-------------|
| deviceID | uuid | Console's device identifier |
| publicKey | bytes | EC P-256 public key (64 bytes) |

### pairingChallenge (0x0011)

Node sends a challenge code to Console.

| Field | Type | Description |
|-------|------|-------------|
| challengeCode | string | 6-digit numeric code |

### pairingResponse (0x0012)

Console responds to the challenge.

| Field | Type | Description |
|-------|------|-------------|
| deviceID | uuid | Console's device identifier |
| publicKey | bytes | EC P-256 public key (64 bytes) |
| signature | bytes | SHA-256 signature of challenge code |

### pairingComplete (0x0013)

Pairing finalized.

| Field | Type | Description |
|-------|------|-------------|
| deviceID | uuid | Paired device identifier |
| trustStatus | u8 | 0=trusted, 1=suspended, 2=revoked |

### authenticate (0x0020)

Session authentication.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Session identifier |
| deviceID | uuid | Authenticating device |
| signature | bytes | EC P-256 signature of session |

### authenticated (0x0021)

Authentication result.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Session identifier |
| success | bool | Whether authentication succeeded |

### capabilityRequest (0x0030)

Console requests specific capabilities.

| Field | Type | Description |
|-------|------|-------------|
| requestedCaps | bytes | 32-bit capability bitfield |

### capabilityGranted (0x0031)

Node grants requested capabilities.

| Field | Type | Description |
|-------|------|-------------|
| grantedCaps | bytes | 32-bit granted capability bitfield |

### capabilityDenied (0x0032)

Node denies requested capabilities.

| Field | Type | Description |
|-------|------|-------------|
| deniedCaps | bytes | 32-bit denied capability bitfield |
| reason | string | Human-readable denial reason |

### sessionOpen (0x0040)

Open a new session.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | New session identifier |
| deviceID | uuid | Initiating device |

### sessionClose (0x0041)

Close an existing session.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Session to close |
| reason | string | Close reason |

### flowControlAck (0x0600)

Acknowledgment for flow-controlled messages.

| Field | Type | Description |
|-------|------|-------------|
| channel | u16 | Acknowledged channel |
| bytesReceived | u64 | Total bytes received on channel |
| lastSequence | u64 | Last sequence number received |

---

## Heartbeat Messages

### heartbeat (0x0050)

Keepalive ping.

| Field | Type | Description |
|-------|------|-------------|
| timestamp | u64 | Sender's timestamp (nanoseconds) |

### heartbeatAck (0x0051)

Keepalive pong.

| Field | Type | Description |
|-------|------|-------------|
| timestamp | u64 | Original ping timestamp |
| rttNanos | u64 | Round-trip time estimate |

---

## Video Messages

### videoConfiguration (0x0100)

Codec configuration (SPS/PPS).

| Field | Type | Description |
|-------|------|-------------|
| codec | u8 | 0=H264 |
| revision | u32 | Configuration revision |
| width | u32 | Frame width |
| height | u32 | Frame height |
| nalLengthSize | u8 | NAL length prefix size (4 for AVCC) |
| sps | bytes | Sequence Parameter Set |
| pps | bytes | Picture Parameter Set |

### videoFrame (0x0101)

Encoded video frame.

| Field | Type | Description |
|-------|------|-------------|
| frameID | u64 | Frame identifier |
| presentationTimestampNanos | u64 | Presentation timestamp |
| durationNanos | u64 | Frame duration |
| isKeyframe | bool | Whether this is a keyframe |
| configurationRevision | u32 | Codec config revision |
| payload | bytes | H.264 AVCC data |

### videoKeyframeRequest (0x0102)

Console requests a keyframe from Node.

| Field | Type | Description |
|-------|------|-------------|
| reason | string | Request reason |

### videoAccessUnit (0x0103)

H.264 access unit (alternative framing).

| Field | Type | Description |
|-------|------|-------------|
| frameID | u64 | Frame identifier |
| presentationTimestampNanos | u64 | Presentation timestamp |
| durationNanos | u64 | Frame duration |
| isKeyframe | bool | Whether this is a keyframe |
| configurationRevision | u32 | Codec config revision |
| avccData | bytes | H.264 AVCC data |

---

## Input Messages

### inputEvent (0x0200)

Remote input event.

| Field | Type | Description |
|-------|------|-------------|
| eventType | u8 | 0=mouseMove, 1=mouseButton, 2=scroll, 3=key, 4=releaseAll |

**mouseMove (eventType=0):**

| Field | Type | Description |
|-------|------|-------------|
| normalizedX | f64 | X coordinate [0.0, 1.0] |
| normalizedY | f64 | Y coordinate [0.0, 1.0] |
| sequence | u64 | Event sequence number |

**mouseButton (eventType=1):**

| Field | Type | Description |
|-------|------|-------------|
| button | u8 | 0=left, 1=right, 2=middle |
| phase | u8 | 0=down, 1=up |
| normalizedX | f64 | X coordinate [0.0, 1.0] |
| normalizedY | f64 | Y coordinate [0.0, 1.0] |

**scroll (eventType=2):**

| Field | Type | Description |
|-------|------|-------------|
| deltaX | f64 | Horizontal scroll delta |
| deltaY | f64 | Vertical scroll delta |
| phase | u8 | 0=began, 1=changed, 2=ended, 3=cancelled |
| precise | bool | Whether this is precise (trackpad) scrolling |

**key (eventType=3):**

| Field | Type | Description |
|-------|------|-------------|
| keyCode | u16 | Virtual key code |
| phase | u8 | 0=down, 1=up |
| modifiers | u32 | Bitfield: shift=1, control=2, option=4, command=8, capsLock=16, function=32 |
| isRepeat | bool | Whether this is a key repeat |

**releaseAll (eventType=4):**

No additional fields. Releases all held keys and buttons.

---

## Terminal Messages

### terminalOpen (0x0300)

Open a remote terminal session.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Terminal session identifier |
| shellPath | string | Path to shell binary |
| workingDirectory | string | Initial working directory |
| columns | u16 | Terminal columns |
| rows | u16 | Terminal rows |

### terminalOpened (0x0301)

Terminal session opened confirmation.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Terminal session identifier |
| pid | u32 | Process ID |

### terminalInput (0x0302)

Input to a terminal session.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Terminal session identifier |
| data | bytes | Input data (UTF-8) |

### terminalOutput (0x0303)

Output from a terminal session.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Terminal session identifier |
| data | bytes | Output data (UTF-8) |

### terminalResize (0x0304)

Resize a terminal session.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Terminal session identifier |
| columns | u16 | New columns |
| rows | u16 | New rows |

### terminalClose (0x0305)

Close a terminal session.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Terminal session identifier |

---

## Telemetry Messages

### telemetrySnapshot (0x0400)

System telemetry snapshot.

| Field | Type | Description |
|-------|------|-------------|
| nodeID | uuid | Node identifier |
| timestamp | u64 | Snapshot timestamp (nanoseconds) |
| cpuLoad | f64 | CPU load [0.0, 1.0] |
| memoryPressure | f64 | Memory pressure [0.0, 1.0] |
| availableMemoryBytes | u64 | Available memory |
| batteryState | u8 | 0=unknown, 1=charging, 2=discharging, 3=full, 4=notPresent |
| batteryLevel | f64 | Battery level [0.0, 1.0] |
| thermalState | u8 | 0=nominal, 1=fair, 2=serious, 3=critical |

---

## Audit Messages

### auditEvent (0x0500)

Audit log event.

| Field | Type | Description |
|-------|------|-------------|
| eventID | uuid | Event identifier |
| timestamp | u64 | Event timestamp (nanoseconds) |
| category | u8 | Event category |
| severity | u8 | 0=debug, 1=info, 2=notice, 3=warning, 4=error, 5=critical |
| actorID | uuid | Acting device |
| description | string | Human-readable description |
| previousHash | bytes | Hash of previous entry (32 bytes) |

---

## File Transfer Messages

### artifactManifest (0x0700)

Artifact metadata for transfer.

| Field | Type | Description |
|-------|------|-------------|
| artifactID | uuid | Artifact identifier |
| logicalName | string | Human-readable name |
| totalBytes | u64 | Total file size |
| chunkSize | u32 | Chunk size |
| chunkCount | u32 | Number of chunks |
| sha256 | bytes | SHA-256 hash (32 bytes) |
| contentType | string | MIME type |

### artifactChunk (0x0701)

File chunk.

| Field | Type | Description |
|-------|------|-------------|
| artifactID | uuid | Artifact identifier |
| index | u32 | Chunk index |
| offset | u64 | Byte offset in file |
| payload | bytes | Chunk data |
| sha256 | bytes | SHA-256 hash of chunk (32 bytes) |

### artifactRequest (0x0702)

Request an artifact transfer.

| Field | Type | Description |
|-------|------|-------------|
| artifactID | uuid | Artifact to request |
| resumeFrom | u32 | Resume from chunk index (0 = from start) |

---

## Job Messages

### jobSubmit (0x0800)

Submit a compute job.

| Field | Type | Description |
|-------|------|-------------|
| jobID | uuid | Job identifier |
| submittedBy | uuid | Submitting device |
| name | string | Human-readable job name |
| executor | u8 | 0=nativeProcess, 1=swiftBuild, 2=xcodeBuild |
| command | struct | `{ executable: string, arguments: [string] }` |
| requirements | struct | `{ allowedArchitectures: [u8], minimumLogicalCPUs: u32, minimumMemoryBytes: u64 }` |
| timeoutSeconds | u64 | Execution timeout |
| priority | u8 | 0=background, 1=normal, 10=critical |

### jobAssigned (0x0801)

Job assigned to a node.

| Field | Type | Description |
|-------|------|-------------|
| jobID | uuid | Job identifier |
| nodeID | uuid | Assigned node |

### jobProgress (0x0802)

Job progress update.

| Field | Type | Description |
|-------|------|-------------|
| jobID | uuid | Job identifier |
| progress | f64 | Progress [0.0, 1.0] |
| message | string | Status message |

### jobCompleted (0x0803)

Job completed successfully.

| Field | Type | Description |
|-------|------|-------------|
| jobID | uuid | Job identifier |
| exitCode | i32 | Process exit code |
| outputBytes | u64 | Output size |
| durationNanos | u64 | Execution duration |

### jobFailed (0x0804)

Job failed.

| Field | Type | Description |
|-------|------|-------------|
| jobID | uuid | Job identifier |
| error | string | Error message |
| exitCode | i32 | Process exit code |

### jobCancelled (0x0805)

Job cancelled.

| Field | Type | Description |
|-------|------|-------------|
| jobID | uuid | Job identifier |

---

## Resource Messages

### resourceDescriptor (0x0900)

Node resource description.

| Field | Type | Description |
|-------|------|-------------|
| nodeID | uuid | Node identifier |
| architecture | u8 | 0=arm64, 1=x86_64 |
| logicalCPUCount | u32 | Number of logical CPUs |
| totalMemoryBytes | u64 | Total physical memory |
| availableMemoryBytes | u64 | Available memory |
| totalStorageBytes | u64 | Total storage |
| availableStorageBytes | u64 | Available storage |
| batteryState | u8 | 0=unknown, 1=charging, 2=discharging, 3=full, 4=notPresent |
| thermalState | u8 | 0=nominal, 1=fair, 2=serious, 3=critical |
| currentCPULoad | f64 | Current CPU load [0.0, 1.0] |
| currentMemoryPressure | f64 | Current memory pressure [0.0, 1.0] |

---

## Workspace Messages

### workspaceSync (0x0A00)

Workspace synchronization request.

| Field | Type | Description |
|-------|------|-------------|
| workspaceID | uuid | Workspace identifier |
| stateHash | bytes | Current state hash (32 bytes) |
| operations | [WorkspaceOperation] | Pending operations |

### workspaceChangeSet (0x0A01)

Workspace change set.

| Field | Type | Description |
|-------|------|-------------|
| workspaceID | uuid | Workspace identifier |
| baseVersion | u64 | Base version number |
| changes | [WorkspaceChange] | List of changes |
| stateHash | bytes | New state hash (32 bytes) |

### workspaceRequest (0x0A02)

Console requests workspace snapshot from Node.

| Field | Type | Description |
|-------|------|-------------|
| workspaceID | uuid | Workspace identifier |

### workspaceResponse (0x0A03)

Node responds with workspace snapshot.

| Field | Type | Description |
|-------|------|-------------|
| workspaceID | uuid | Workspace identifier |
| files | map[string]string] | File paths to content hashes |
| stateHash | bytes | Current state hash (32 bytes) |

---

## Clipboard Messages

### clipboardData (0x0C00)

Bidirectional clipboard synchronization.

| Field | Type | Description |
|-------|------|-------------|
| content | string | Clipboard text content |
| contentType | string | MIME type (e.g. `public.utf8-plain-text`) |
| changeCount | i32 | Pasteboard change count for dedup |

---

## Agent Messages

### agentSubmit (0x0D00)

Submit an agent plan for remote execution.

| Field | Type | Description |
|-------|------|-------------|
| planID | string | Plan identifier |
| objective | string | Human-readable objective |
| steps | [string] | Shell commands to execute in order |

### agentProgress (0x0D01)

Agent step progress update.

| Field | Type | Description |
|-------|------|-------------|
| planID | string | Plan identifier |
| stepIndex | u32 | Current step index |
| output | string | Step output |

### agentCompleted (0x0D02)

Agent plan completed.

| Field | Type | Description |
|-------|------|-------------|
| planID | string | Plan identifier |
| outputs | [string] | Output from each step |

### agentFailed (0x0D03)

Agent plan failed.

| Field | Type | Description |
|-------|------|-------------|
| planID | string | Plan identifier |
| error | string | Error message |

---

## Emergency Stop

### emergencyStop (0x0060)

Emergency stop — releases all held keys and buttons on Node.

No payload.

---

## Multi-Display Messages

### switchDisplay (0x0070)

Console requests Node to switch to a specific display.

| Field | Type | Description |
|-------|------|-------------|
| displayID | u32 | Target display identifier |

### switchWindow (0x0071)

Console requests Node to switch to a specific window.

| Field | Type | Description |
|-------|------|-------------|
| windowID | u32 | Target window identifier |
| applicationName | string? | Optional application bundle ID |

### displayList (0x0072)

Node sends available display list to Console.

| Field | Type | Description |
|-------|------|-------------|
| displays | [DisplayDescriptor] | Array of display descriptors |

DisplayDescriptor:

| Field | Type | Description |
|-------|------|-------------|
| displayID | u32 | Display identifier |
| name | string | Display name |
| width | i32 | Width in pixels |
| height | i32 | Height in pixels |
| isMain | bool | Whether this is the main display |
| isBuiltIn | bool | Whether this is a built-in display |

### windowList (0x0073)

Node sends available window list to Console.

| Field | Type | Description |
|-------|------|-------------|
| windows | [WindowDescriptor] | Array of window descriptors |

WindowDescriptor:

| Field | Type | Description |
|-------|------|-------------|
| windowID | u32 | Window identifier |
| applicationName | string | Application bundle ID |
| title | string | Window title |
| x | i32 | X position |
| y | i32 | Y position |
| width | i32 | Width in pixels |
| height | i32 | Height in pixels |
| isOnScreen | bool | Whether window is visible |

---

## Presence Messages

### presenceRegister (0x0B00)

Node registers itself with the coordinator.

| Field | Type | Description |
|-------|------|-------------|
| nodeID | uuid | Node's unique identifier |
| displayName | string | Human-readable name |
| host | string | Node's IP or hostname |
| port | u16 | Node's listening port |
| architecture | u8 | CPU architecture (0=arm64, 1=x86_64) |
| capabilities | bytes | 32-bit capability bitfield |

### presenceDeregister (0x0B01)

Node deregisters from the coordinator.

| Field | Type | Description |
|-------|------|-------------|
| nodeID | uuid | Node's unique identifier |

### presenceHeartbeat (0x0B02)

Node sends heartbeat to coordinator to keep presence alive.

| Field | Type | Description |
|-------|------|-------------|
| nodeID | uuid | Node's unique identifier |

### presenceList (0x0B03)

Console requests list of registered nodes from coordinator.

No payload. Response contains node IDs.

### presenceListResponse (0x0B04)

Coordinator responds with list of registered node IDs.

| Field | Type | Description |
|-------|------|-------------|
| nodeIDs | uuid[] | Array of registered node identifiers |

---

## Rendezvous Messages

### rendezvousRequest (0x0B10)

Console requests rendezvous with a target node through the coordinator.

| Field | Type | Description |
|-------|------|-------------|
| consoleID | uuid | Console's node identifier |
| targetNodeID | uuid | Target node's identifier |

### rendezvousOffer (0x0B11)

Coordinator forwards rendezvous offer to the target node.

| Field | Type | Description |
|-------|------|-------------|
| requestID | uuid | Rendezvous request identifier |
| consoleID | uuid | Console's node identifier |
| route | u8 | Proposed route (0=direct, 1=relay, 2=vpn) |

### rendezvousAnswer (0x0B12)

Node responds to rendezvous offer.

| Field | Type | Description |
|-------|------|-------------|
| requestID | uuid | Rendezvous request identifier |
| accepted | bool | Whether node accepted the rendezvous |
| selectedRoute | u8 | Chosen route |

### rendezvousComplete (0x0B13)

Finalizes rendezvous after both parties accept.

| Field | Type | Description |
|-------|------|-------------|
| requestID | uuid | Rendezvous request identifier |

### rendezvousCancel (0x0B14)

Cancels an in-progress rendezvous.

| Field | Type | Description |
|-------|------|-------------|
| requestID | uuid | Rendezvous request identifier |

---

## Signaling Messages

### signalingOffer (0x0B20)

Console sends SDP offer to target node via coordinator.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Signaling session identifier |
| fromNodeID | uuid | Sender's node identifier |
| toNodeID | uuid | Recipient's node identifier |
| sdp | bytes | SDP offer data |

### signalingAnswer (0x0B21)

Node sends SDP answer back to console.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Signaling session identifier |
| fromNodeID | uuid | Sender's node identifier |
| toNodeID | uuid | Recipient's node identifier |
| sdp | bytes | SDP answer data |

### signalingIceCandidate (0x0B22)

ICE candidate exchange during signaling.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Signaling session identifier |
| candidate | string | ICE candidate string |
| sdpMLineIndex | i32 | SDP media line index |
| sdpMid | string? | SDP media ID (optional) |

### signalingError (0x0B23)

Signaling error notification.

| Field | Type | Description |
|-------|------|-------------|
| sessionID | uuid | Signaling session identifier |
| errorCode | u16 | Error code |
| reason | string | Human-readable error description |

---

## Relay Messages

### relayAllocate (0x0B30)

Request allocation of a relay channel between two nodes.

| Field | Type | Description |
|-------|------|-------------|
| sourceNodeID | uuid | Source node identifier |
| targetNodeID | uuid | Target node identifier |

### relayAllocateResponse (0x0B31)

Coordinator responds with allocated channel.

| Field | Type | Description |
|-------|------|-------------|
| channelID | uuid | Allocated channel identifier |
| sourceNodeID | uuid | Source node identifier |
| targetNodeID | uuid | Target node identifier |

### relayForward (0x0B32)

Forward a data packet through a relay channel.

| Field | Type | Description |
|-------|------|-------------|
| channelID | uuid | Relay channel identifier |
| fromNodeID | uuid | Sender's node identifier |
| data | bytes | Payload data |

### relayForwardAck (0x0B33)

Acknowledgment of relay packet delivery.

| Field | Type | Description |
|-------|------|-------------|
| channelID | uuid | Relay channel identifier |
| delivered | bool | Whether packet was delivered |
| latencyMs | f64 | Round-trip latency in milliseconds |

### relayRelease (0x0B34)

Release a relay channel.

| Field | Type | Description |
|-------|------|-------------|
| channelID | uuid | Relay channel identifier |

---

## Error Messages

### errorResponse (0x0FFF)

Generic error response.

| Field | Type | Description |
|-------|------|-------------|
| errorCode | u16 | Error code (see errors.md) |
| message | string | Human-readable error description |
| relatedMessageID | uuid? | ID of the message that caused the error (optional) |

---

## Channel Assignment Summary

| Channel | Messages | Delivery | Max Payload |
|---------|----------|----------|-------------|
| 0 (control) | hello, helloAck, pairing*, sessionOpen/Close, capability*, flowControlAck, artifactManifest, artifactRequest, job*, resourceDescriptor, workspaceSync, clipboardData, emergencyStop, agent*, workspaceRequest/Response | reliable | 1 MiB |
| 1 (inputReliable) | inputEvent | reliable | 256 B |
| 2 (inputEphemeral) | inputEvent (mouse moves) | best-effort | 256 B |
| 3 (video) | videoConfiguration, videoFrame, videoKeyframeRequest, videoAccessUnit | best-effort | 8 MiB |
| 4 (terminal) | terminalOpen/Opened/Input/Output/Resize/Close | reliable | 64 KiB |
| 5 (telemetry) | telemetrySnapshot | reliable | 256 KiB |
| 6 (files) | artifactChunk | reliable | 4 MiB |
| 7 (audit) | auditEvent | reliable | 256 KiB |
| 8 (heartbeat) | heartbeat, heartbeatAck | reliable | 64 B |
