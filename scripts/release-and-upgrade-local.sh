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

- **Massive Performance Boost: Initial Launch & Refresh from 15s to ~0.3s**
  - Parallelized candidate repository inspection using concurrent workers (33 local repos: 3.8s -> 0.06s)
  - Parallelized worktree, commit log, and dirty-state parsing via Swift TaskGroup (44 worktrees: 1.84s -> 0.34s)
  - Introduced a DiskUsageStore cache and moved heavy disk-usage traversal to background async tasks (9.31s blocking -> 0s main-thread)
  - bootstrap() no longer blocks the window on remote GitLab requests; the worktree workspace renders immediately at launch
  - Branch Sync & Merge Requests now load silently in the background, with automatic on-demand recovery when switching sections
- **Copy Merge Request Link Everywhere**
  - New Copy Link action in the MR toolbar operating on the selected MR
  - New operations column in the MR table with 1-click copy link and open-in-browser buttons
  - Copy-link button beside the MR title, plus a dedicated GitLab web link card with copy & open actions
  - 2-second green Copied visual feedback across all copy entry points
  - Removed the redundant raw URL entry from the activity list

## 简体中文

- **首次启动与刷新性能大幅提速：从 15 秒降至约 0.3 秒**
  - 使用多核并发并行扫描本地仓库（33 个仓库：3.8 秒 -> 0.06 秒）
  - 通过 Swift TaskGroup 并行解析工作树、提交记录与脏状态（44 个工作树：1.84 秒 -> 0.34 秒）
  - 引入磁盘占用缓存 DiskUsageStore，将耗时的磁盘遍历彻底移至后台异步任务（9.31 秒阻塞 -> 主线程零耗时）
  - 启动流程不再因远程 GitLab 网络请求阻塞窗口，启动瞬间即可渲染工作树工作区
  - 分支同步与合并请求改为后台静默加载，切换到对应页面时自动按需补全
- **全场景“复制 MR 链接”能力**
  - 合并请求顶栏新增「复制链接」按钮，作用于当前选中的 MR
  - MR 表格新增「操作」列，提供一键复制链接与在浏览器打开按钮
  - MR 标题旁新增复制链接按钮，并在检查器中新增独立的 GitLab 网页链接卡片
  - 所有复制入口均提供 2 秒绿色“已复制链接”视觉反馈
  - 清理了活动列表中冗余的原始 URL 条目
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
