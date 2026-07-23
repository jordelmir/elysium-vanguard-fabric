#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# Elysium Vanguard Fabric - Bootstrap Script
# Sets up the development environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Elysium Vanguard Fabric - Bootstrap ==="
echo "Root: $ROOT_DIR"

# Check prerequisites
echo ""
echo "--- Checking prerequisites ---"

if ! command -v swift &> /dev/null; then
    echo "ERROR: Swift not found"
    exit 1
fi
echo "Swift: $(swift --version 2>&1 | head -1)"

if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: Xcode not found"
    exit 1
fi
echo "Xcode: $(xcodebuild -version 2>&1 | head -1)"

# Resolve dependencies
echo ""
echo "--- Resolving dependencies ---"
cd "$ROOT_DIR"
swift package resolve

# Build all packages
echo ""
echo "--- Building packages ---"
swift build

echo ""
echo "=== Bootstrap complete ==="
