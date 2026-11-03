#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.1.0}"
ARCH="${ARCH:-$(uname -m)}"
OUT="$ROOT/dist"
APP="$OUT/MacThermalMonitor.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OUT/stage"
swift build -c release --arch "$ARCH"
BIN="$(find "$ROOT/.build" -path '*/release/MacThermalMonitor' -type f -perm -111 -print -quit)"
if [[ -z "$BIN" ]]; then
  echo "Release executable not found under $ROOT/.build" >&2
  find "$ROOT/.build" -maxdepth 5 -type f -name MacThermalMonitor -print >&2 || true
  exit 1
fi
cp "$BIN" "$APP/Contents/MacOS/MacThermalMonitor"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleDisplayName</key><string>Mac Thermal Monitor</string><key>CFBundleExecutable</key><string>MacThermalMonitor</string><key>CFBundleIdentifier</key><string>com.averery.MacThermalMonitor</string><key>CFBundleName</key><string>Mac Thermal Monitor</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>$VERSION</string><key>CFBundleVersion</key><string>$VERSION</string><key>LSMinimumSystemVersion</key><string>15.0</string><key>LSUIElement</key><true/></dict></plist>
PLIST
if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
  # Ad-hoc signing does not provide Apple trust or notarization, but keeps the
  # app bundle internally consistent for personal testing.
  codesign --force --deep --sign - "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi
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
