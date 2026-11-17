#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="KazeRun"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

echo "Building Swift release binary..."
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$ROOT_DIR/.build/release/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ -d "$APP_BUNDLE" ]; then
    if [ -x "$LSREGISTER" ]; then
        "$LSREGISTER" -u "$APP_BUNDLE" 2>/dev/null || true
    fi
    rm -rf "$APP_BUNDLE"
fi
mkdir -p "$MACOS_DIR" "$RES_DIR/sidecar"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/bridge/kaze_bridge.py" "$RES_DIR/sidecar/kaze_bridge.py"
cp "$ROOT_DIR/bridge/requirements.txt" "$RES_DIR/sidecar/requirements.txt"

if [ -f "$ROOT_DIR/AppIcon.icns" ]; then
    cp "$ROOT_DIR/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>KazeRun</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>dev.kazerun.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KazeRun</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$APP_BUNDLE" 2>/dev/null || true
fi
mdimport "$APP_BUNDLE" 2>/dev/null || true

echo "Created app bundle: $APP_BUNDLE"
