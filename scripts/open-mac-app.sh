#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/GWorkbench.app"

"$ROOT_DIR/scripts/build-mac-app.sh"
open "$APP_PATH"
