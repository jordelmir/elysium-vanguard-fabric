#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Elysium Vanguard Fabric - Build All

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Elysium Vanguard Fabric - Build All ==="
cd "$ROOT_DIR"

echo ""
echo "--- Building Swift packages ---"
swift build 2>&1

echo ""
echo "=== Build complete ==="
