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

- **Critical Fix: app could hang with blank data and refuse to quit**
  - Root cause: several scan pipelines used `withTaskGroup` while every task performed
    blocking `Process` calls (git worktree list / log / status / rev-parse). TaskGroup tasks
    run on the Swift cooperative thread pool, so blocking them starves the pool and the
    task group can never complete. The window stayed empty forever and the app became
    unresponsive and impossible to quit.
  - Secondary cause: `ProjectScanCache` implemented single-flight with `NSCondition`, but
    callers run inside `Task.detached`, so blocking waits also starved the cooperative pool.
  - Tertiary cause: a single-permit `ScanGate` made the three concurrent bootstrap callers
    (worktrees / branch sync / merge requests) starve each other and surface empty lists.
- **Fixes**
  - Replaced every blocking `withTaskGroup` / `withThrowingTaskGroup` with
    `DispatchQueue.concurrentPerform` plus lock-protected collectors (GCD tolerates blocking
    work; the cooperative pool is no longer involved). Applied to worktree parsing, branch
    sync project scan, GitLab project scan, worktree sweeper analysis, and background
    disk-usage measurement.
  - Removed the `NSCondition` single-flight and the single-permit `ScanGate`. The project
    cache is now a pure non-blocking TTL cache (2s): no waits, no deadlocks.
  - Kept the genuinely asynchronous task group in merge-request enrichment, since it only
    awaits URLSession network calls and never blocks a thread.
- **Verification**
  - 28 repositories and 38 worktrees load in ~1.6s
  - Branch sync populates all GitLab projects correctly
  - Switching between sections no longer hangs
  - App quits cleanly

## 简体中文

- **重要修复：应用可能卡死、数据刷不出来、且无法退出**
  - 根因一：多个扫描链路使用 `withTaskGroup`，而任务体内全是阻塞式 `Process` 调用
    （git worktree list / log / status / rev-parse）。TaskGroup 的任务运行在 Swift 协作线程池上，
    阻塞它们会耗尽线程池，任务组永远无法完成，界面因此一直空白，应用也无法响应或退出。
  - 根因二：`ProjectScanCache` 使用 `NSCondition` 实现单飞，而调用方位于 `Task.detached` 中，
    阻塞等待同样会耗尽协作线程池。
  - 根因三：单许可的 `ScanGate` 让启动时并发的工作树 / 分支同步 / 合并请求三个调用方互相饿死，
    最终返回空列表。
- **修复内容**
  - 将所有阻塞式 `withTaskGroup` / `withThrowingTaskGroup` 替换为
    `DispatchQueue.concurrentPerform` + 加锁收集器（GCD 容忍阻塞工作，不再占用协作线程池）。
    覆盖工作树解析、分支同步项目扫描、GitLab 项目扫描、工作树回收站分析、后台磁盘占用统计。
  - 移除 `NSCondition` 单飞与单许可 `ScanGate`。项目扫描缓存改为纯非阻塞 TTL 缓存（2 秒），
    不再有任何等待与死锁风险。
  - 保留合并请求补全中真正异步的任务组，因为它只 await URLSession 网络请求，不会阻塞线程。
- **验证结果**
  - 28 个仓库、38 个工作树约 1.6 秒完成加载
  - 分支同步可正确加载全部 GitLab 项目
  - 各页面切换不再卡死
  - 应用可正常退出
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
