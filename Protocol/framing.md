# Protocol Framing

## Header Structure (25 bytes)

```
Offset  Size  Field
0       4     Magic (0x45564642)
4       2     Protocol Version (major)
6       2     Protocol Version (minor)
8       2     Message Type
10      2     Flags
12      2     Reserved
14      1     Stream Channel
15      8     Sequence Number
23      4     Payload Length
```

## Total Frame

```
[Header 25 bytes][Payload N bytes]
```

## Envelope Structure (32 bytes)

Used for extended routing:

```
Offset  Size  Field
0       4     Magic
4       2     Protocol Major
6       2     Protocol Minor
8       2     Message Type
10      2     Channel
12      2     Flags
14      2     Reserved
16      16    Session ID (UUID)
32      8     Sequence Number
40      8     Payload Length
```

## Flags

| Bit | Name           | Description |
|-----|----------------|-------------|
| 0   | requiresResponse | Message expects a response |
| 1   | isResponse     | This is a response message |
| 2   | isFragment     | Fragmented message |
| 3   | isLastFragment | Last fragment |
| 4   | urgent         | Priority message |

## Constraints

- Max control payload: 1 MiB
- Max video access unit: 8 MiB
- Max terminal chunk: 64 KiB
- Max file chunk: 4 MiB
- Max telemetry payload: 256 KiB
