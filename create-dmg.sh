#!/bin/bash
# Awake - Create DMG installer
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Awake"
APP_PATH="$SCRIPT_DIR/Awake/Awake.app"
DMG_NAME="Awake-v${1:-1.0.0}.dmg"
DMG_DIR="$SCRIPT_DIR/build"
DMG_TEMP="$DMG_DIR/temp_dmg"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found. Run ./build.sh first."
    exit 1
fi

echo "📦 Creating DMG: $DMG_NAME"

# Clean up
rm -rf "$DMG_TEMP" "$DMG_DIR/$DMG_NAME"
mkdir -p "$DMG_TEMP" "$DMG_DIR"

# Copy app to temp directory
cp -r "$APP_PATH" "$DMG_TEMP/$APP_NAME.app"

# Create symbolic link to /Applications for drag-and-drop install
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_DIR/$DMG_NAME"

# Clean up
rm -rf "$DMG_TEMP"

echo "✅ DMG created: $DMG_DIR/$DMG_NAME"
