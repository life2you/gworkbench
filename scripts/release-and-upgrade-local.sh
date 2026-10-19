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

- **Worktree Sweeper: 4-Baseline Merge Analysis with Lamp Indicators**
  - Merge analysis now focuses on a fixed ordered baseline set: master, stage, test, uat
  - New 4-lamp indicator column shows one green lamp per merged baseline; an "all lit" badge appears when merged into all four
  - New statuses: fully merged (4/4), partially merged (n/4), remote-deleted, stale (>30d), active, protected
  - Results sorted by merge completeness: fully merged > partially merged > remote deleted > stale > active > protected
  - Summary banner now reports fully-merged and partially-merged counts separately
  - Category filters updated to: All / Fully Merged / Partially Merged / Stale (>30d) / Protected
  - Workspace cleanliness column moved next to branch identity for faster scanning
- **Critical Fix: Compare Against Remote origin/* Baselines**
  - Merge checks now prioritize the authoritative remote refs `origin/<base>` instead of stale local branches
  - Falls back to the local branch only when the remote ref is unavailable
  - Fixes false negatives where outdated local stage/test/uat branches made fully-merged worktrees appear unmerged
  - Measured impact on a real repository: fully-merged count 6 -> 7, recommended cleanup 7 -> 8

## 简体中文

- **工作树回收站：以 4 条基线为核心的合入分析与亮点指示灯**
  - 合入分析聚焦固定有序的 4 条基线：master、stage、test、uat
  - 新增 4 亮点指示灯列，每条基线合入后点亮一个绿灯；4 条全部合入时额外显示“全亮”徽标
  - 新增状态：全部合入 (4/4)、部分合入 (n/4)、远端已删除、休眠 (>30天)、活跃开发、受保护
  - 结果按合入完整度排序：全部合入 > 部分合入 > 远端删除 > 休眠 > 活跃 > 受保护
  - 顶部横幅分别统计“全部合入”与“部分合入”数量
  - 筛选分类更新为：全部 / 全部合入 / 部分合入 / 休眠 >30天 / 受保护
  - “工作区”干净/脏状态列前移至分支名右侧，横向扫读更高效
- **关键修复：改为与远端 origin/* 基线比对**
  - 合入判定优先使用远端权威引用 `origin/<base>`，而非可能落后的本地分支
  - 仅在远端引用不存在时才回退到本地分支
  - 修复了本地 stage/test/uat 落后导致已完全合入的工作树被误判为“未合入”的问题
  - 真实仓库实测：全部合入数量由 6 提升至 7，建议清理项由 7 提升至 8
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
