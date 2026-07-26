# Physical Validation Checklist

## Prerequisites

- [ ] MacBook Pro 2016 running macOS 12.x (Monterey)
- [ ] Mac M1 running macOS 13+ (Ventura or later)
- [ ] Both devices on same LAN
- [ ] Network latency < 5ms
- [ ] Both devices have Elysium Vanguard Fabric built and installed

## Test 1: Discovery and Pairing

### Steps
1. Launch VanguardNodeMac on MacBook Pro 2016
2. Launch VanguardConsoleMac on Mac M1
3. Verify Console discovers Node via Bonjour
4. Initiate pairing from Console
5. Verify pairing code displayed on Node
6. Enter pairing code on Console
7. Verify pairing completes
8. Verify Node appears in Console node list

### Expected Results
- [ ] Node discovered within 5 seconds
- [ ] Pairing code matches on both devices
- [ ] Pairing completes without errors
- [ ] Node listed with correct architecture (x86_64)
- [ ] Capabilities granted correctly

## Test 2: Remote Desktop

### Steps
1. Connect to paired Node from Console
2. Verify screen capture starts
3. Verify video stream received
4. Verify Metal rendering works
5. Move mouse on Console, verify movement on Node
6. Click on Console, verify click on Node
7. Type on Console, verify input on Node
8. Resize Console window, verify resolution adaptation

### Expected Results
- [ ] First frame within 3 seconds
- [ ] Frame rate >= 30fps at 720p
- [ ] Input latency < 30ms (p95)
- [ ] No visual artifacts
- [ ] Resolution adapts to window size

## Test 3: 30-Minute Stability

### Steps
1. Maintain remote desktop session for 30 minutes
2. Perform regular interactions throughout
3. Monitor memory usage on both devices
4. Monitor CPU usage on both devices
5. Check for memory leaks
6. Check for CPU spikes

### Expected Results
- [ ] Session stable for 30 minutes
- [ ] No memory growth > 10%
- [ ] No CPU spikes > 80%
- [ ] No dropped frames > 1%
- [ ] No stuck keys
- [ ] No input lag increase

## Test 4: Network Recovery

### Steps
1. During active session, disable WiFi on Node
2. Wait 10 seconds
3. Re-enable WiFi on Node
4. Verify session recovers
5. Verify keyframe received after recovery
6. Verify input works after recovery

### Expected Results
- [ ] Session detects disconnection within 5 seconds
- [ ] Automatic reconnection attempted
- [ ] Session recovers within 3 seconds of reconnection
- [ ] Keyframe received and decoded
- [ ] Input works normally after recovery
- [ ] No stuck keys after recovery

## Test 5: Clipboard Sync

### Steps
1. Copy text on Console
2. Paste on Node
3. Copy text on Node
4. Paste on Console

### Expected Results
- [ ] Clipboard syncs both directions
- [ ] Text content matches
- [ ] No echo loops
- [ ] Sync completes within 1 second

## Test 6: Terminal

### Steps
1. Open terminal from Console
2. Execute commands on Node
3. Verify output received
4. Resize terminal window
5. Close terminal

### Expected Results
- [ ] Terminal opens successfully
- [ ] Commands execute correctly
- [ ] Output streams in real-time
- [ ] Resize works without artifacts
- [ ] Terminal closes cleanly
- [ ] Process terminated properly

## Test 7: File Transfer

### Steps
1. Drag file from Console to Node
2. Verify file received
3. Verify file integrity (SHA-256)
4. Transfer large file (>100MB)
5. Interrupt transfer mid-way
6. Resume transfer

### Expected Results
- [ ] Small file transfers successfully
- [ ] SHA-256 hash matches
- [ ] Large file transfers without corruption
- [ ] Transfer can be resumed after interruption
- [ ] Atomic rename on completion

## Test 8: Stress Test

### Steps
1. Open 3 simultaneous terminal sessions
2. Transfer file while using remote desktop
3. Run command on Node while streaming video
4. Monitor resource usage

### Expected Results
- [ ] All operations complete successfully
- [ ] No resource exhaustion
- [ ] Graceful degradation under load
- [ ] No crashes or hangs

## Performance Metrics

| Metric | Target | Measured |
|--------|--------|----------|
| Input latency p50 | < 15ms | |
| Input latency p95 | < 30ms | |
| Frame rate 720p | >= 30fps | |
| Frame rate 1080p | >= 60fps | |
| First frame | < 3s | |
| Reconnection | < 3s | |
| Memory growth (30min) | < 10% | |
| CPU usage (idle) | < 10% | |
| CPU usage (active) | < 50% | |

## Sign-off

- [ ] All tests passed
- [ ] Performance targets met
- [ ] No critical bugs found
- [ ] Ready for production use

**Tester**: ________________
**Date**: ________________
**Build**: ________________
