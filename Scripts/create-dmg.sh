#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
RELEASE_DIR="$BUILD_DIR/release"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Apps/VanguardNodeMac/Info.plist" | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

echo "📀 Creating DMG installers v${VERSION} (${GIT_SHA})..."
echo ""

# Verify apps exist
for app in VanguardNodeMac VanguardConsoleMac VanguardCoordinatorServer; do
    if [ ! -d "$BUILD_DIR/$app.app" ]; then
        echo "❌ $app.app not found in .build/. Run ./build.sh first."
        exit 1
    fi
done

# Clean previous DMGs
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# ──────────────────────────────────────────────────────────────
# 1. Combined DMG (all 3 apps)
# ──────────────────────────────────────────────────────────────
echo "📀 [1/4] Creating combined DMG..."
COMBINED_STAGING="$BUILD_DIR/dmg-combined"
rm -rf "$COMBINED_STAGING"
mkdir -p "$COMBINED_STAGING"

cp -R "$BUILD_DIR/VanguardNodeMac.app" "$COMBINED_STAGING/"
cp -R "$BUILD_DIR/VanguardConsoleMac.app" "$COMBINED_STAGING/"
cp -R "$BUILD_DIR/VanguardCoordinatorServer.app" "$COMBINED_STAGING/"
ln -s /Applications "$COMBINED_STAGING/Applications"

COMBINED_DMG="$RELEASE_DIR/ElysiumVanguard-v${VERSION}-${GIT_SHA}.dmg"
hdiutil create \
    -volname "Elysium Vanguard" \
    -srcfolder "$COMBINED_STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$COMBINED_DMG"

rm -rf "$COMBINED_STAGING"
echo "   ✅ $(basename "$COMBINED_DMG") ($(du -h "$COMBINED_DMG" | cut -f1))"

# ──────────────────────────────────────────────────────────────
# 2. Individual DMG — Node
# ──────────────────────────────────────────────────────────────
echo "📀 [2/4] Creating VanguardNodeMac DMG..."
NODE_STAGING="$BUILD_DIR/dmg-node"
rm -rf "$NODE_STAGING"
mkdir -p "$NODE_STAGING"

cp -R "$BUILD_DIR/VanguardNodeMac.app" "$NODE_STAGING/"
ln -s /Applications "$NODE_STAGING/Applications"

NODE_DMG="$RELEASE_DIR/VanguardNodeMac-v${VERSION}-${GIT_SHA}.dmg"
hdiutil create \
    -volname "Elysium Node" \
    -srcfolder "$NODE_STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$NODE_DMG"

rm -rf "$NODE_STAGING"
echo "   ✅ $(basename "$NODE_DMG") ($(du -h "$NODE_DMG" | cut -f1))"

# ──────────────────────────────────────────────────────────────
# 3. Individual DMG — Console
# ──────────────────────────────────────────────────────────────
echo "📀 [3/4] Creating VanguardConsoleMac DMG..."
CONSOLE_STAGING="$BUILD_DIR/dmg-console"
rm -rf "$CONSOLE_STAGING"
mkdir -p "$CONSOLE_STAGING"

cp -R "$BUILD_DIR/VanguardConsoleMac.app" "$CONSOLE_STAGING/"
ln -s /Applications "$CONSOLE_STAGING/Applications"

CONSOLE_DMG="$RELEASE_DIR/VanguardConsoleMac-v${VERSION}-${GIT_SHA}.dmg"
hdiutil create \
    -volname "Elysium Console" \
    -srcfolder "$CONSOLE_STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$CONSOLE_DMG"

rm -rf "$CONSOLE_STAGING"
echo "   ✅ $(basename "$CONSOLE_DMG") ($(du -h "$CONSOLE_DMG" | cut -f1))"

# ──────────────────────────────────────────────────────────────
# 4. Individual DMG — Coordinator Server
# ──────────────────────────────────────────────────────────────
echo "📀 [4/4] Creating VanguardCoordinatorServer DMG..."
COORD_STAGING="$BUILD_DIR/dmg-coordinator"
rm -rf "$COORD_STAGING"
mkdir -p "$COORD_STAGING"

cp -R "$BUILD_DIR/VanguardCoordinatorServer.app" "$COORD_STAGING/"
ln -s /Applications "$COORD_STAGING/Applications"

COORD_DMG="$RELEASE_DIR/VanguardCoordinatorServer-v${VERSION}-${GIT_SHA}.dmg"
hdiutil create \
    -volname "Elysium Coordinator" \
    -srcfolder "$COORD_STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$COORD_DMG"

rm -rf "$COORD_STAGING"
echo "   ✅ $(basename "$COORD_DMG") ($(du -h "$COORD_DMG" | cut -f1))"

# ──────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  DMG INSTALLERS READY"
echo "════════════════════════════════════════════════════════════"
echo ""
ls -lh "$RELEASE_DIR"/*.dmg | awk '{print "  " $NF " (" $5 ")"}'
echo ""
echo "  Total: $(du -sh "$RELEASE_DIR" | cut -f1)"
echo ""
echo "  To test a DMG:"
echo "    open $RELEASE_DIR/ElysiumVanguard-v${VERSION}-${GIT_SHA}.dmg"
echo ""
echo "  To publish to GitHub:"
echo "    gh release create v${VERSION} \\"
echo "      $RELEASE_DIR/*.dmg \\"
echo "      --title \"Elysium Vanguard v${VERSION}\" \\"
echo "      --notes \"Release v${VERSION}\""
echo ""
echo "  To notarize (requires Apple Developer account):"
echo "    xcrun notarytool submit <dmg-path> --keychain-profile \"notarytool-profile\" --wait"
echo "    xcrun stapler staple <dmg-path>"
echo ""
