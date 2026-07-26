# Protocol Test Vectors

## Hello Message

### Input
- Magic: 0x45564642
- Version: 1.0
- Type: 0x0001 (hello)
- Channel: 0 (control)
- Flags: 0x0000
- Reserved: 0x0000
- Sequence: 0
- Payload Length: 10

### Binary (hex)
```
45 56 46 42 00 01 00 00 00 01 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0A
```

## HelloAck Message

### Input
- Magic: 0x45564642
- Version: 1.0
- Type: 0x0002 (helloAck)
- Channel: 0 (control)
- Sequence: 1
- Payload: {"protocolVersion":{"major":1,"minor":0},"nodeID":"...","acceptedVersion":{"major":1,"minor":0}}

## VideoFrame Message

### Input
- Type: 0x0101 (videoFrame)
- Channel: 3 (video)
- Flags: 0x0010 (urgent)
- Sequence: 999
- Payload: 1024 bytes of 0xFF

### Binary (partial header)
```
45 56 46 42 00 01 00 00 01 01 00 10 00 00 03
00 00 00 00 00 00 03 E7 00 00 04 00
```

## FlowControlAck Message

### Input
- Type: 0x0600 (flowControlAck)
- Channel: 0 (control)
- Payload: {"channel":3,"bytesReceived":65536}

## Error Response

### Input
- Type: 0x0FFF (error)
- Channel: 0 (control)
- Flags: 0x0002 (isResponse)
- Payload: {"code":1,"message":"Invalid magic bytes"}
