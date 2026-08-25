#!/bin/bash
# Builds TranslateHotkey.app into ./build
# Requires: Xcode Command Line Tools (xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build -c release"
swift build -c release

APP="build/TranslateHotkey.app"
BIN=".build/release/TranslateHotkey"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TranslateHotkey"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> codesign (ad-hoc)"
codesign --force --sign - "$APP"

echo ""
echo "Built: $APP"
echo ""
echo "Next steps:"
echo "  1. mv \"$APP\" /Applications/   (recommended, keeps permissions stable)"
echo "  2. open /Applications/TranslateHotkey.app"
echo "  3. Grant Accessibility permission when prompted"
echo "     (System Settings → Privacy & Security → Accessibility)"
echo ""
echo "Note: after every rebuild the ad-hoc signature changes. If the hotkey"
echo "stops working after a rebuild, remove TranslateHotkey from the"
echo "Accessibility list and add it again."
