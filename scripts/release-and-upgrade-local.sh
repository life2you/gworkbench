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

- **Fix: merge detection now recognizes environment integration branches**
  - In branch-sync workflows, feature branches are merged into environment-specific
    integration branches (e.g., `stage_<middle>_meger`, `test_<middle>_meger`, `uat_<middle>_meger`).
  - Previously, merge detection strictly compared against bare `origin/<baseline>` refs,
    falsely reporting branches as not merged even though they were pushed to their integration branches.
  - Merge detection now resolves candidate bases using `merge_branch_middle` and `branch_map`
    configurations, accurately detecting merges into integration branches.
  - Hover tooltips and the detail panel now display the exact matched branch name (e.g.,
    `stage: merged into origin/stage_henry_meger`).
  - Space Cleanup Sweeper also adopts the same baseline candidate resolution.
- **Fix: eliminate violent flickering on dashboard refresh**
  - Previously, refreshing cleared all items and rendered a full-screen loading spinner,
    causing cards, tables, and the detail inspector to abruptly disappear and re-appear.
  - Implemented smooth in-place refresh (stale-while-revalidate): existing cards and tables stay
    rendered while a background refresh runs, with a subtle inline progress indicator in the toolbar.
  - Clicking the currently active project in the sidebar no longer clears or flashes the screen.

## 简体中文

- **修复：合入检测支持识别环境合并/集成分支**
  - 在分支同步工作流中，功能分支通常先合并推送到个人环境集成分支（如 `stage_<middle>_meger`、`test_<middle>_meger`、`uat_<middle>_meger`）。
  - 此前仅严格比对公共 `origin/<基线>` 分支，导致已完成环境同步的分支被误判为全部“未合入”。
  - 现已结合配置的 `merge_branch_middle` 与 `branch_map` 自动解析候选集成分支，准确识别环境合流状态。
  - 矩阵勾选悬浮提示与右侧详情面板现已明确展示具体合入的分支名（如 `stage: 已合入 origin/stage_henry_meger`）。
  - 空间清理（Sweeper）分析器同步采用该候选基线检测标准，保证清理判定与看板完全一致。
- **修复：彻底解决合入看板刷新时的剧烈闪烁跳动**
  - 之前每次手动刷新或切窗回前台时，会清空数据并显示整屏居中加载，导致卡片、表格和右侧详情瞬间消失又重新弹出。
  - 改为平滑的原地静默刷新（Stale-while-revalidate）：刷新过程中保留现有统计卡片与表格，只在工具栏展示轻量微型加载状态。
  - 侧边栏重复点击当前已选中项目时不再清空数据或重置界面。
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
