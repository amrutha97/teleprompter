#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

APP="Teleprompter.app"
BINARY="Teleprompter"
ICONSET_DIR="AppIcon.iconset"

echo "==> Compiling teleprompter.swift..."
swiftc -O -framework Cocoa -o "$BINARY" teleprompter.swift

echo "==> Generating app icon..."
mkdir -p "$ICONSET_DIR"
sips -z 16 16     icon.png --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32     icon.png --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
sips -z 32 32     icon.png --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64     icon.png --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
sips -z 128 128   icon.png --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256   icon.png --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   icon.png --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512   icon.png --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   icon.png --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024 icon.png --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null
iconutil -c icns "$ICONSET_DIR" -o AppIcon.icns
rm -rf "$ICONSET_DIR"

echo "==> Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$BINARY"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

rm -f "$BINARY" AppIcon.icns

echo "==> Signing (ad-hoc)..."
codesign --force --deep -s - "$APP"

echo ""
echo "Done! $APP is ready."
echo ""
echo "  To run:    open $APP"
echo "  To install: cp -r $APP /Applications/"
echo ""
