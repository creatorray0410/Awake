#!/bin/bash
# Awake - Build Script
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/Awake"

echo "🔨 Building Awake..."

# Create app bundle structure
mkdir -p Awake.app/Contents/MacOS
mkdir -p Awake.app/Contents/Resources

# Copy Info.plist
cp Resources/Info.plist Awake.app/Contents/Info.plist

# Generate .icns icon
if [ -d "Resources/AppIcon.iconset" ]; then
    echo "🎨 Generating app icon..."
    iconutil -c icns Resources/AppIcon.iconset -o Awake.app/Contents/Resources/AppIcon.icns
fi

# Compile Swift source
echo "⚙️  Compiling..."
swiftc Sources/main.swift \
    -o Awake.app/Contents/MacOS/Awake \
    -framework AppKit \
    -framework IOKit \
    -target arm64-apple-macosx13.0

echo "✅ Build successful!"
echo "📦 App: $SCRIPT_DIR/Awake/Awake.app"
echo ""
echo "Run:     open Awake/Awake.app"
echo "Install: cp -r Awake/Awake.app /Applications/"
