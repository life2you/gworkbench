#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_CASK_PATH="$REPO_ROOT/packaging/homebrew-tap/Casks/gworkbench.rb"

OWNER="${OWNER:-life2you}"
REPO="${REPO:-gworkbench}"
HOMEPAGE="${HOMEPAGE:-https://github.com/$OWNER/$REPO}"
CASK_TOKEN="${CASK_TOKEN:-gworkbench}"
APP_NAME="${APP_NAME:-GWorkbench}"
DESCRIPTION="${DESCRIPTION:-Native macOS desktop app for Git worktrees and GitLab merge workflows}"
VERSION=""
CASK_PATH="$DEFAULT_CASK_PATH"
DRY_RUN=0

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

require_command git
require_command curl
require_command shasum

show_help() {
  cat <<EOF
Usage: ./scripts/update-homebrew-cask.sh [options] [version]

Options:
  --output PATH   Write the generated cask to PATH.
  --dry-run       Print the generated cask to stdout instead of writing it.
  --help          Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      CASK_PATH="$2"
      shift 2
      ;;
    --output=*)
      CASK_PATH="${1#*=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      show_help
      exit 0
      ;;
    --)
      shift
      if [[ $# -gt 0 ]]; then
        VERSION="$1"
        shift
      fi
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      VERSION="$1"
      shift
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "Unexpected extra arguments: $*" >&2
  exit 1
fi

VERSION="${VERSION:-$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")}"
if [[ -z "$VERSION" ]]; then
  echo "Failed to detect version from VERSION" >&2
  exit 1
fi

TAG="v$VERSION"
LOCAL_TAG_COMMIT="$(git -C "$REPO_ROOT" rev-parse "$TAG^{}" 2>/dev/null || true)"
if [[ -z "$LOCAL_TAG_COMMIT" ]]; then
  echo "Local tag $TAG does not exist. Create and push the release tag first." >&2
  exit 1
fi

REMOTE_TAG_COMMIT="$(git -C "$REPO_ROOT" ls-remote --tags origin "refs/tags/$TAG^{}" | awk 'NR==1 {print $1}')"
if [[ -z "$REMOTE_TAG_COMMIT" ]]; then
  REMOTE_TAG_COMMIT="$(git -C "$REPO_ROOT" ls-remote --tags origin "refs/tags/$TAG" | awk 'NR==1 {print $1}')"
fi
if [[ -z "$REMOTE_TAG_COMMIT" ]]; then
  echo "Remote tag $TAG not found on origin. Push the tag before updating the cask." >&2
  exit 1
fi

if [[ "$REMOTE_TAG_COMMIT" != "$LOCAL_TAG_COMMIT" ]]; then
  echo "Remote tag $TAG points to $REMOTE_TAG_COMMIT, but local tag points to $LOCAL_TAG_COMMIT." >&2
  exit 1
fi

ARM_URL="https://github.com/$OWNER/$REPO/releases/download/$TAG/GWorkbench-macos-arm64-v${VERSION}.zip"
INTEL_URL="https://github.com/$OWNER/$REPO/releases/download/$TAG/GWorkbench-macos-x86_64-v${VERSION}.zip"

ARM_SHA256="$(
  curl --fail --silent --show-error --location --retry 3 "$ARM_URL" |
    shasum -a 256 |
    awk '{print $1}'
)"

INTEL_SHA256="$(
  curl --fail --silent --show-error --location --retry 3 "$INTEL_URL" |
    shasum -a 256 |
    awk '{print $1}'
)"

CASK_CONTENT="$(cat <<EOF
cask "$CASK_TOKEN" do
  version "$VERSION"

  on_arm do
    sha256 "$ARM_SHA256"
    url "$ARM_URL"
  end

  on_intel do
    sha256 "$INTEL_SHA256"
    url "$INTEL_URL"
  end

  name "$APP_NAME"
  desc "$DESCRIPTION"
  homepage "$HOMEPAGE"

  depends_on macos: ">= :sequoia"

  app "$APP_NAME.app"

  zap trash: [
    "~/.config/gworkbench",
  ]
end
EOF
)"

if [[ "$DRY_RUN" == "1" ]]; then
  printf '%s\n' "$CASK_CONTENT"
  exit 0
fi

mkdir -p "$(dirname "$CASK_PATH")"
printf '%s\n' "$CASK_CONTENT" > "$CASK_PATH"

echo "Updated $CASK_PATH"
echo "Version:      $VERSION"
echo "ARM SHA256:   $ARM_SHA256"
echo "Intel SHA256: $INTEL_SHA256"
