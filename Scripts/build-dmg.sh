#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.0}"
ARCH="${ARCH:-$(uname -m)}"
OUT="$ROOT/dist"
APP="$OUT/MacThermalMonitor.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT/stage"
BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"
cp "$BIN_DIR/MacThermalMonitor" "$APP/Contents/MacOS/MacThermalMonitor"
cat > "$OUT/$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleDisplayName</key><string>Mac Thermal Monitor</string><key>CFBundleExecutable</key><string>MacThermalMonitor</string><key>CFBundleIdentifier</key><string>com.example.MacThermalMonitor</string><key>CFBundleName</key><string>Mac Thermal Monitor</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>$VERSION</string><key>CFBundleVersion</key><string>$VERSION</string><key>LSMinimumSystemVersion</key><string>15.0</string><key>LSUIElement</key><true/></dict></plist>
PLIST
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi
ln -s /Applications "$OUT/stage/Applications"
cp -R "$APP" "$OUT/stage/"
DMG="$OUT/MacThermalMonitor-$VERSION-$ARCH.dmg"
hdiutil create -volname "Mac Thermal Monitor" -srcfolder "$OUT/stage" -ov -format UDZO "$DMG"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
  fi
fi
shasum -a 256 "$DMG" > "$DMG.sha256"
echo "$DMG"
