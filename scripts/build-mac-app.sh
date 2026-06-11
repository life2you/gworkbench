#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="GWorkbench"
EXECUTABLE_NAME="GWorkbenchApp"
VERSION_FILE="$ROOT_DIR/VERSION"
TARGET_TRIPLE="${TARGET_TRIPLE:-arm64-apple-macosx}"
SCRATCH_PATH="${SCRATCH_PATH:-$ROOT_DIR/.build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
ICON_SCRIPT="$ROOT_DIR/scripts/generate-app-icon.py"
ICON_FILE="$ROOT_DIR/assets/appicon/AppIcon.icns"
BUILD_DIR="$SCRATCH_PATH/$TARGET_TRIPLE/release"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

mkdir -p "$DIST_DIR"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT_DIR" --triple "$TARGET_TRIPLE" --scratch-path "$SCRATCH_PATH"

if [[ ! -x "$BUILD_DIR/$EXECUTABLE_NAME" ]]; then
  echo "Release executable not found: $BUILD_DIR/$EXECUTABLE_NAME" >&2
  exit 1
fi

echo "==> Creating app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

if [[ -f "$ICON_SCRIPT" ]]; then
  echo "==> Generating app icon"
  python3 "$ICON_SCRIPT"
fi

if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>GWorkbench</string>
  <key>CFBundleExecutable</key>
  <string>GWorkbenchApp</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.life2you.gworkbench</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>GWorkbench</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_VERSION}</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  echo "==> Applying ad-hoc code signature"
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo
echo "App bundle created:"
echo "  $APP_DIR"
