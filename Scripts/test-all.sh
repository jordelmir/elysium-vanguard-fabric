#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Elysium Vanguard Fabric - Test All

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Elysium Vanguard Fabric - Test All ==="
cd "$ROOT_DIR"

echo ""
echo "--- Running unit tests ---"
swift test --parallel 2>&1

TEST_EXIT=$?

echo ""
echo "=== Tests complete (exit: $TEST_EXIT) ==="
exit $TEST_EXIT
