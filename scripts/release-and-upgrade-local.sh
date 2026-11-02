#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OWNER="${OWNER:-life2you}"
TAP_OWNER="${TAP_OWNER:-life2you}"
TAP_REPO="${TAP_REPO:-homebrew-tap}"
WAIT_INTERVAL_SECONDS="${WAIT_INTERVAL_SECONDS:-5}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
SKIP_PUSH=0
SKIP_BREW=0
VERSION=""

show_help() {
  cat <<EOF
Usage: ./scripts/release-and-upgrade-local.sh [options] [version]

Options:
  --skip-push   Assume branch and tag have already been pushed.
  --skip-brew   Only publish release and update tap; skip local brew refresh.
  --help        Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-push)
      SKIP_PUSH=1
      shift
      ;;
    --skip-brew)
      SKIP_BREW=1
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
TAG="v$VERSION"
CURRENT_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
RELEASE_NOTES_FILE="$(mktemp)"
TAP_TMP_DIR="$(mktemp -d)"
trap 'rm -f "$RELEASE_NOTES_FILE"; rm -rf "$TAP_TMP_DIR"' EXIT

cat > "$RELEASE_NOTES_FILE" <<'RELEASE_NOTES_EOF'
# GWorkbench __VERSION__

## English

- **Fix: strictly compare against canonical baseline branches**
  - Merge status is now strictly checked against authoritative baseline branches (`master`, `stage`, `test`, `uat`)
    via `origin/<target>` and local `<target>`, explicitly excluding individual integration/middle branches (e.g., `origin/**_meger`).
- **Feature: automatic silent git fetch before dashboard analysis**
  - The dashboard now automatically runs a background `git fetch origin` before analyzing merge statuses.
  - Ensures local `origin/*` tracking refs are immediately refreshed with GitLab/GitHub's latest commits, eliminating false "not merged" reports when a merge was recently completed remotely.

## 简体中文

- **修复：严格只比对真正的主干/环境基线分支**
  - 合入状态检测严格以权威基线分支（`master`、`stage`、`test`、`uat`）的 `origin/<target>` 与本地 `<target>` 为准，排除开发者个人中间集成分支（如 `origin/**_meger`）。
- **新增：看板分析前自动静默执行 git fetch origin**
  - 每次分析前在后台自动先同步远端最新分支引用，确保远端 GitLab/GitHub 刚完成的 MR 合并能被看板即刻识别，彻底解决因本地引用过旧导致的误判未合入问题。
RELEASE_NOTES_EOF

# Substitute version placeholder safely without shell expansion of note content
python3 - "$RELEASE_NOTES_FILE" "$VERSION" <<'PY_EOF'
import sys
path, version = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace('__VERSION__', version)
with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
PY_EOF

if [[ "$SKIP_PUSH" != "1" ]]; then
  git -C "$REPO_ROOT" push origin "$CURRENT_BRANCH"
  git -C "$REPO_ROOT" push origin "$TAG"
fi

"$SCRIPT_DIR/package-release-assets.sh"

gh release view "$TAG" --repo "$OWNER/gworkbench" >/dev/null 2>&1 && \
  gh release delete "$TAG" --repo "$OWNER/gworkbench" --yes || true

gh release create "$TAG" \
  "$REPO_ROOT/dist/release/GWorkbench-macos-arm64-v${VERSION}.zip" \
  "$REPO_ROOT/dist/release/GWorkbench-macos-x86_64-v${VERSION}.zip" \
  --repo "$OWNER/gworkbench" \
  --title "GWorkbench v$VERSION" \
  --notes-file "$RELEASE_NOTES_FILE"

git -C "/Users/life2you/vibeCodes/github/homebrew-tap" pull --ff-only
"$SCRIPT_DIR/update-homebrew-cask.sh" "$VERSION" --output "$TAP_TMP_DIR/gworkbench.rb"
mkdir -p "$REPO_ROOT/packaging/homebrew-tap/Casks"
cp "$TAP_TMP_DIR/gworkbench.rb" "$REPO_ROOT/packaging/homebrew-tap/Casks/gworkbench.rb"
mkdir -p "/Users/life2you/vibeCodes/github/homebrew-tap/Casks"
cp "$TAP_TMP_DIR/gworkbench.rb" "/Users/life2you/vibeCodes/github/homebrew-tap/Casks/gworkbench.rb"
git -C "/Users/life2you/vibeCodes/github/homebrew-tap" add Casks/gworkbench.rb
git -C "/Users/life2you/vibeCodes/github/homebrew-tap" commit -m "Add gworkbench $VERSION" || true
git -C "/Users/life2you/vibeCodes/github/homebrew-tap" push origin HEAD:main

deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
until gh release view "$TAG" --repo "$OWNER/gworkbench" >/dev/null 2>&1; do
  if (( $(date +%s) >= deadline )); then
    echo "Timed out waiting for release $TAG" >&2
    exit 1
  fi
  sleep "$WAIT_INTERVAL_SECONDS"
done

if [[ "$SKIP_BREW" == "1" ]]; then
  exit 0
fi

brew update
brew upgrade --cask "life2you/tap/gworkbench" || brew install --cask "life2you/tap/gworkbench"
