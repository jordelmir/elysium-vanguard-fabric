#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
DMG_NAME="ElysiumVanguard"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"
VOLUME_NAME="Elysium Vanguard"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "📀 Creating DMG: $DMG_NAME (${GIT_SHA})..."

# Verify apps exist
for app in VanguardNodeMac VanguardConsoleMac VanguardCoordinatorServer; do
    if [ ! -d "$BUILD_DIR/$app.app" ]; then
        echo "❌ $app.app not found. Run ./build.sh first."
        exit 1
    fi
done

# Clean staging
rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH"

# Create staging directory
mkdir -p "$STAGING_DIR"

# Copy apps
echo "📦 Copying apps to staging..."
cp -R "$BUILD_DIR/VanguardNodeMac.app" "$STAGING_DIR/"
cp -R "$BUILD_DIR/VanguardConsoleMac.app" "$STAGING_DIR/"
cp -R "$BUILD_DIR/VanguardCoordinatorServer.app" "$STAGING_DIR/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
echo "📀 Creating disk image..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean staging
rm -rf "$STAGING_DIR"

echo ""
echo "✅ DMG created: $DMG_PATH"
echo "   Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "To test:"
echo "   open $DMG_PATH"
echo ""
echo "To notarize (requires Apple Developer account):"
echo "   xcrun notarytool submit $DMG_PATH --keychain-profile \"notarytool-profile\" --wait"
echo "   xcrun stapler staple $DMG_PATH"
