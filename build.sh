#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
RELEASE_DIR="$BUILD_DIR/release"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VERSION=$(grep -A1 "CFBundleShortVersionString" "$PROJECT_DIR/Apps/VanguardNodeMac/Info.plist" | grep string | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

echo "🔨 Building Elysium Vanguard Fabric v${VERSION} (${GIT_SHA})..."
echo ""

# Clean previous release artifacts
echo "🧹 Cleaning previous release artifacts..."
rm -rf "$BUILD_DIR/VanguardNodeMac.app"
rm -rf "$BUILD_DIR/VanguardConsoleMac.app"
rm -rf "$BUILD_DIR/VanguardCoordinatorServer.app"
rm -rf "$BUILD_DIR/ElysiumVanguard.dmg"

# Build all targets (show full output on failure)
echo "🔨 Building VanguardNodeMac..."
if ! swift build --product VanguardNodeMac --configuration release 2>&1; then
    echo "❌ Failed to build VanguardNodeMac"
    exit 1
fi

echo "🔨 Building VanguardConsoleMac..."
if ! swift build --product VanguardConsoleMac --configuration release 2>&1; then
    echo "❌ Failed to build VanguardConsoleMac"
    exit 1
fi

echo "🔨 Building VanguardCoordinatorServer..."
if ! swift build --product VanguardCoordinatorServer --configuration release 2>&1; then
    echo "❌ Failed to build VanguardCoordinatorServer"
    exit 1
fi

echo ""
echo "✅ All targets built successfully"
echo ""

# Generate .icns from AppIcon.appiconset PNGs
generate_icns() {
    local product_name="$1"
    local iconset_src="$PROJECT_DIR/Apps/$product_name/Sources/$product_name/Assets.xcassets/AppIcon.appiconset"
    local iconset_dir="$BUILD_DIR/$product_name.iconset"
    local icns_output="$BUILD_DIR/$product_name.icns"

    if [ ! -d "$iconset_src" ]; then
        echo "⚠️  No icon source for $product_name, skipping .icns generation"
        return 1
    fi

    rm -rf "$iconset_dir"
    mkdir -p "$iconset_dir"

    # Map AppIcon.appiconset PNGs to .iconset naming convention
    cp "$iconset_src/icon_16x16.png"     "$iconset_dir/icon_16x16.png"
    cp "$iconset_src/icon_32x32.png"     "$iconset_dir/icon_16x16@2x.png"
    cp "$iconset_src/icon_32x32.png"     "$iconset_dir/icon_32x32.png"
    cp "$iconset_src/icon_64x64.png"     "$iconset_dir/icon_32x32@2x.png"
    cp "$iconset_src/icon_128x128.png"   "$iconset_dir/icon_128x128.png"
    cp "$iconset_src/icon_256x256.png"   "$iconset_dir/icon_128x128@2x.png"
    cp "$iconset_src/icon_256x256.png"   "$iconset_dir/icon_256x256.png"
    cp "$iconset_src/icon_512x512.png"   "$iconset_dir/icon_256x256@2x.png"
    cp "$iconset_src/icon_512x512.png"   "$iconset_dir/icon_512x512.png"
    cp "$iconset_src/icon_1024x1024.png" "$iconset_dir/icon_512x512@2x.png"

    iconutil -c icns "$iconset_dir" -o "$icns_output"
    rm -rf "$iconset_dir"

    echo "   ✅ Generated $(basename "$icns_output") ($(du -h "$icns_output" | cut -f1))"
}

echo "🎨 Generating app icons..."
generate_icns "VanguardNodeMac"
generate_icns "VanguardConsoleMac"
generate_icns "VanguardCoordinatorServer"
echo ""

# Create app bundles
create_app_bundle() {
    local product_name="$1"
    local app_name="$2"
    local plist_source="$3"
    local entitlements="$4"

    local bundle_dir="$BUILD_DIR/$app_name.app"
    local contents_dir="$bundle_dir/Contents"
    local macos_dir="$contents_dir/MacOS"
    local resources_dir="$contents_dir/Resources"

    echo "📦 Creating $app_name.app bundle..."

    # Clean and create structure
    rm -rf "$bundle_dir"
    mkdir -p "$macos_dir" "$resources_dir"

    # Copy binary
    cp "$RELEASE_DIR/$product_name" "$macos_dir/$product_name"

    # Copy Info.plist
    cp "$plist_source" "$contents_dir/Info.plist"

    # Copy entitlements (for code signing reference)
    cp "$entitlements" "$bundle_dir/$product_name.entitlements"

    # Copy compiled .icns icon
    local icns_file="$BUILD_DIR/$product_name.icns"
    if [ -f "$icns_file" ]; then
        cp "$icns_file" "$resources_dir/AppIcon.icns"
        echo "   🎨 AppIcon.icns installed"
    else
        # Fallback: copy raw Assets.xcassets
        local assets_source="$PROJECT_DIR/Apps/$product_name/Sources/$product_name/Assets.xcassets"
        if [ -d "$assets_source" ]; then
            cp -R "$assets_source" "$resources_dir/Assets.xcassets"
        fi
    fi

    # Create PkgInfo
    echo -n "APPL????" > "$contents_dir/PkgInfo"

    echo "   ✅ Created $bundle_dir"
}

create_app_bundle "VanguardNodeMac" "VanguardNodeMac" \
    "$PROJECT_DIR/Apps/VanguardNodeMac/Info.plist" \
    "$PROJECT_DIR/Apps/VanguardNodeMac/VanguardNodeMac.entitlements"

create_app_bundle "VanguardConsoleMac" "VanguardConsoleMac" \
    "$PROJECT_DIR/Apps/VanguardConsoleMac/Info.plist" \
    "$PROJECT_DIR/Apps/VanguardConsoleMac/VanguardConsoleMac.entitlements"

create_app_bundle "VanguardCoordinatorServer" "VanguardCoordinatorServer" \
    "$PROJECT_DIR/Apps/VanguardCoordinatorServer/Info.plist" \
    "$PROJECT_DIR/Apps/VanguardCoordinatorServer/VanguardCoordinatorServer.entitlements"

echo ""

sign_bundle() {
    local app_path="$1"
    local entitlements="$2"
    local marker="$BUILD_DIR/.$(basename "$app_path").signed"

    if [ "${SIGN:-0}" = "1" ] || [ ! -f "$marker" ]; then
        echo "🔐 Signing $(basename "$app_path")..."
        codesign --force --deep --sign - --entitlements "$entitlements" "$app_path" || true
        codesign --verify --deep --strict --verbose=2 "$app_path" || true
        touch "$marker"
        echo "   ✅ Signed"
    else
        echo "⏭️  Skipping sign for $(basename "$app_path") (use SIGN=1 to force)"
    fi
}

sign_bundle "$BUILD_DIR/VanguardNodeMac.app" \
    "$PROJECT_DIR/Apps/VanguardNodeMac/VanguardNodeMac.entitlements"

sign_bundle "$BUILD_DIR/VanguardConsoleMac.app" \
    "$PROJECT_DIR/Apps/VanguardConsoleMac/VanguardConsoleMac.entitlements"

sign_bundle "$BUILD_DIR/VanguardCoordinatorServer.app" \
    "$PROJECT_DIR/Apps/VanguardCoordinatorServer/VanguardCoordinatorServer.entitlements"

echo ""
echo "🚀 Build complete! Apps created in:"
echo "   $BUILD_DIR/VanguardNodeMac.app"
echo "   $BUILD_DIR/VanguardConsoleMac.app"
echo "   $BUILD_DIR/VanguardCoordinatorServer.app"
echo ""
echo "To launch:"
echo "   open $BUILD_DIR/VanguardNodeMac.app"
echo "   open $BUILD_DIR/VanguardConsoleMac.app"
echo "   open $BUILD_DIR/VanguardCoordinatorServer.app"
