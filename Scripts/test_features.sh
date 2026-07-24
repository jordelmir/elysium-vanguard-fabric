#!/bin/bash

echo "=== Elysium Vanguard Fabric - Feature Test ==="
echo "Testing all components..."
echo ""

# Build the apps
cd "/Users/jordelmirsdevhome/Downloads/Elysium Vanguard Macs control/ElysiumVanguardFabric"
swift build 2>&1 | tail -5

echo ""
echo "Building apps..."

# Test 1: Verify Node app can start
echo ""
echo "1. Testing Node app startup..."
.build/debug/VanguardNodeMac &
NODE_PID=$!
sleep 3

if ps -p $NODE_PID > /dev/null 2>&1; then
    echo "   ✓ Node app started successfully (PID: $NODE_PID)"
    kill $NODE_PID 2>/dev/null
    wait $NODE_PID 2>/dev/null
else
    echo "   ✗ Node app failed to start"
fi

# Test 2: Verify Console app can start
echo ""
echo "2. Testing Console app startup..."
.build/debug/VanguardConsoleMac &
CONSOLE_PID=$!
sleep 3

if ps -p $CONSOLE_PID > /dev/null 2>&1; then
    echo "   ✓ Console app started successfully (PID: $CONSOLE_PID)"
    kill $CONSOLE_PID 2>/dev/null
    wait $CONSOLE_PID 2>/dev/null
else
    echo "   ✗ Console app failed to start"
fi

# Test 3: Run unit tests
echo ""
echo "3. Running unit tests..."
swift test 2>&1 | grep -E "passed|failed" | tail -5

echo ""
echo "=== Feature Test Complete ==="
