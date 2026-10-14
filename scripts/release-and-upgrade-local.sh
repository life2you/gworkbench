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

cat > "$RELEASE_NOTES_FILE" <<EOF
# GWorkbench $VERSION

## English

- **AI-Powered Branch Name Generator**:
  - Automatically derives concise, standard Git branch names from natural language feature/bug descriptions with 2 candidate alternative pills.
  - Multi-provider compatibility supporting DeepSeek, OpenAI, Kimi, Qwen, Ollama (local offline), and custom OpenAI-compatible proxies.
  - Fully customizable System Prompt in Settings without domain-specific hardcoding.
  - Intelligently isolated: only shown in "新建分支" mode, cleanly hidden in "已有分支" mode.
- **Intelligent Worktree Sweeper & Space Reclaim Wizard**:
  - Automatically identifies merged upstream branches (\`git merge-base --is-ancestor\`), deleted remote tracking branches, and stale branches (>30 days).
  - Triple safety guard: strictly protects main repository base and uncommitted dirty worktrees from accidental deletion.
  - Real-time disk space calculation with one-click bulk physical cleanup and automatic \`git worktree prune\`.
- **Window Activation Foreground Auto-Refresh (\`scenePhase == .active\`)**:
  - Automatically detects when switching back to GWorkbench from Zed, Otty, or browser with 3-second smart debouncing.
  - Silently synchronizes modified files, ahead/behind commit telemetry, and branch states without interrupting the user.
- **Modal Sheets Overhaul**:
  - Completely redesigned "新建工作树 (New Worktree)", "新建 MR (New MR)", and "批量创建 MR (Batch Create MR)" sheets with modern macOS cards and clean visual hierarchy.
  - Quick-mapping shortcut pills for one-click source/target branch population.
- **Enhanced Tooling Support**:
  - Native auto-detection and instant launching for **Zed** editor and **Otty** terminal.

## 简体中文

- **AI 智能分支名推导（多厂商兼容）**：
  - 支持根据中文功能描述/Bug背景一键自动推导规范英文分支名，并附带 2 个候选分支小胶囊。
  - 基于标准 OpenAI-Compatible 协议，原生支持 DeepSeek、OpenAI、Kimi、通义千问、Ollama（本地离线）及自定义代理。
  - 设置中开放「自定义 System Prompt / 命名偏好约束」，无任何业务词库硬编码。
  - 工作流隔离：仅在「新建分支」展示 AI 推导，在「已有分支」模式下保持纯净。
- **陈旧工作树空间智能回收站 (Worktree Sweeper)**：
  - 自动识别已并入上游基准（\`git merge-base --is-ancestor\`）、远端已删及长期休眠分支。
  - 三道绝对安全防线：强制保护生产主干基准，强制保护含有未提交修改的脏工作区，绝不误伤代码。
  - 实时精确换算可释放磁盘空间，支持批量安全物理释放并自动执行 \`git worktree prune\`。
- **窗口切回前台静默感知与自动刷新 (\`scenePhase == .active\`)**：
  - 从 Zed、Otty 或浏览器点回 GWorkbench 的瞬间，智能静默同步当前工作树改动、Ahead/Behind 提交数与最新分支状态（附带 3 秒防抖）。
- **新建工作树与 MR 弹窗现代化重构**：
  - 全面升级「新建工作树」、「新建 MR」、「按环境映射批量创建 MR」弹窗，去除突兀 iOS 表单气泡，采用原生精细卡片。
  - 新建 MR 提供常用环境映射快捷胶囊，点击即可秒级同时填入来源分支与目标分支。
- **工具链深度集成**：
  - 原生深度适配 **Zed** 代码编辑器与 **Otty** 现代终端的自动探测与唤起联动。
EOF

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
