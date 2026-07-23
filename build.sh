#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"

echo "🔨 Building Elysium Vanguard Fabric..."

# Build both targets
swift build --product VanguardNodeMac --configuration release 2>&1 | tail -5
swift build --product VanguardConsoleMac --configuration release 2>&1 | tail -5

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
    cp "$BUILD_DIR/release/$product_name" "$macos_dir/$product_name"
    
    # Copy Info.plist
    cp "$plist_source" "$contents_dir/Info.plist"
    
    # Copy entitlements (for code signing reference)
    cp "$entitlements" "$bundle_dir/$product_name.entitlements"
    
    # Copy assets
    local assets_source="$PROJECT_DIR/Apps/$product_name/Sources/$product_name/Assets.xcassets"
    if [ -d "$assets_source" ]; then
        cp -R "$assets_source" "$resources_dir/Assets.xcassets"
    fi
    
    # Create PkgInfo
    echo -n "APPL????" > "$contents_dir/PkgInfo"
    
    echo "✅ Created $bundle_dir"
}

create_app_bundle "VanguardNodeMac" "VanguardNodeMac" \
    "$PROJECT_DIR/Apps/VanguardNodeMac/Info.plist" \
    "$PROJECT_DIR/Apps/VanguardNodeMac/VanguardNodeMac.entitlements"

create_app_bundle "VanguardConsoleMac" "VanguardConsoleMac" \
    "$PROJECT_DIR/Apps/VanguardConsoleMac/Info.plist" \
    "$PROJECT_DIR/Apps/VanguardConsoleMac/VanguardConsoleMac.entitlements"

echo ""
echo "🚀 Build complete! Apps created in:"
echo "   $BUILD_DIR/VanguardNodeMac.app"
echo "   $BUILD_DIR/VanguardConsoleMac.app"
echo ""
echo "To launch:"
echo "   open $BUILD_DIR/VanguardNodeMac.app"
echo "   open $BUILD_DIR/VanguardConsoleMac.app"
