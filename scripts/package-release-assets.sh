#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_NAME="GWorkbench.app"

build_asset() {
  local triple="$1"
  local scratch_path="$2"
  local archive_name="$3"
  local temp_dir

  temp_dir="$(mktemp -d "$RELEASE_DIR/tmp.XXXXXX")"
  TARGET_TRIPLE="$triple" SCRATCH_PATH="$scratch_path" DIST_DIR="$temp_dir" "$SCRIPT_DIR/build-mac-app.sh"

  ditto -c -k --keepParent "$temp_dir/$APP_NAME" "$RELEASE_DIR/$archive_name"
  rm -rf "$temp_dir"
}

mkdir -p "$RELEASE_DIR"
rm -f "$RELEASE_DIR"/GWorkbench-macos-*.zip

build_asset "arm64-apple-macosx" "$ROOT_DIR/.build" "GWorkbench-macos-arm64-v${VERSION}.zip"
build_asset "x86_64-apple-macosx" "$ROOT_DIR/.build-x86" "GWorkbench-macos-x86_64-v${VERSION}.zip"

echo "Packaged release assets:"
ls -lh "$RELEASE_DIR"/GWorkbench-macos-*.zip
