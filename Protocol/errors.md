# Protocol Errors

## Error Codes

| Code  | Name               | Description |
|-------|--------------------|-------------|
| 0x0001| invalidMagic       | Invalid magic bytes |
| 0x0002| unsupportedVersion | Unsupported protocol version |
| 0x0003| unknownMessageType | Unknown message type |
| 0x0004| invalidPayload     | Invalid payload |
| 0x0005| payloadTooLarge    | Payload too large |
| 0x0006| invalidState       | Invalid state for operation |
| 0x0010| authenticationFailed | Authentication failed |
| 0x0011| authorizationDenied | Authorization denied |
| 0x0012| capabilityRequired | Required capability not granted |
| 0x0013| sessionExpired     | Session expired |
| 0x0014| replayDetected     | Replay attack detected |
| 0x0015| rateLimited        | Rate limited |
| 0x0020| codecNotSupported  | Codec not supported |
| 0x0021| videoConfigRequired | Video configuration required |
| 0x0022| keyframeRequired   | Keyframe required |
| 0x0023| decoderFailed      | Decoder error |
| 0x0030| terminalFailed     | Terminal operation failed |
| 0x0031| terminalNotFound   | Terminal session not found |
| 0x0040| fileTransferFailed | File transfer failed |
| 0x0041| pathTraversal      | Path traversal detected |
| 0x0042| diskFull           | Disk full |
| 0x0050| jobFailed          | Job execution failed |
| 0x0051| jobNotFound        | Job not found |
| 0x0052| schedulerFailed    | Scheduler error |
| 0x0053| nodeUnavailable    | Node unavailable |
| 0x0060| timeout            | Operation timed out |
| 0x0FFF| internal           | Internal error |

## Handling

- Unknown error codes: disconnect
- Transport errors: attempt reconnect
- Auth errors: require re-authentication
- Capability errors: request elevation
