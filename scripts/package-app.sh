#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT/dist}"
BIN_PATH="${BIN_PATH:-$ROOT/.build/release/seldon}"
ARCH="${ARCH:-$(uname -m)}"
APP_NAME="${APP_NAME:-Seldon}"
BUNDLE_NAME="${BUNDLE_NAME:-${APP_NAME}.app}"
ZIP_NAME="${ZIP_NAME:-${APP_NAME}-macos-${ARCH}.app.zip}"

APP_DIR="$DIST_DIR/$BUNDLE_NAME"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources/tools"

cp "$BIN_PATH" "$APP_DIR/Contents/Resources/seldon"
chmod +x "$APP_DIR/Contents/Resources/seldon"
cp "$ROOT/tools.example.yaml" "$APP_DIR/Contents/Resources/tools.example.yaml"
cp -R "$ROOT/tools/." "$APP_DIR/Contents/Resources/tools/"
find "$APP_DIR/Contents/Resources/tools" -name '*.py' -type f -exec chmod +x {} +

cat > "$APP_DIR/Contents/MacOS/Seldon" <<'LAUNCH'
#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/Resources"
exec "$ROOT/Resources/seldon" --tools "$ROOT/Resources/tools.example.yaml"
LAUNCH
chmod +x "$APP_DIR/Contents/MacOS/Seldon"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Seldon</string>
  <key>CFBundleDisplayName</key><string>Seldon Chat</string>
  <key>CFBundleIdentifier</key><string>com.singe.seldon</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>Seldon</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
</dict>
</plist>
PLIST

rm -f "$DIST_DIR/$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$DIST_DIR/$ZIP_NAME"

echo "$DIST_DIR/$ZIP_NAME"
