#!/bin/bash
# Builds Feather.app and (optionally) installs it to /Applications.
# Usage: ./build-app.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="Feather.app"
BIN=".build/release/Feather"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Feather"
cp art/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Feather</string>
    <key>CFBundleDisplayName</key>     <string>Feather</string>
    <key>CFBundleIdentifier</key>      <string>com.amol.feather</string>
    <key>CFBundleExecutable</key>      <string>Feather</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>
</dict>
</plist>
PLIST

# Sign with a real identity when available — gives the app a stable identity
# so the Accessibility grant survives rebuilds. Ad-hoc otherwise.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Signed as: ${IDENTITY:-ad-hoc}"

echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Feather.app"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/Feather.app"
fi
