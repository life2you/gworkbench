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

- **100% Pure Native macOS Desktop App**: Completely removed legacy CLI (gwtm/gmux) and rust-core runtime dependencies; the app is now a self-contained, lightweight, high-performance SwiftUI/AppKit macOS desktop application (~5.5MB).
- **Comprehensive UI Overhaul**:
  - **Worktrees**: Upgraded to a high-density native Table with column sorting, live telemetry pills, and an integrated bottom console drawer.
  - **Branch Sync**: Redesigned pipeline topology flow, clean mode picker (sync environments, merge all, custom targets), and execution logs.
  - **Merge Requests**: High-density Table with approval pills, CI status, sticky batch approve-and-merge bar, and detailed inspector.
  - **Settings**: Streamlined 3-tab architecture (Local & Worktrees, Connection Pool, Presets) with runtime health radar diagnostics.
- **Multi-Platform Classification & Auto-Routing**: Automatic detection of GitHub vs private GitLab repositories based on Git Remote URL with clean collapsible sidebar grouping.
- **Terminal & IDE Integration**:
  - Auto-detection for installed terminals (Otty, Ghostty, Terminal, iTerm2) with customizable startup hook commands.
  - Auto-detection for installed IDEs (Zed, IntelliJ IDEA, Sublime Text, VS Code, Cursor) with instant test-launching.
- **Customizable Path Templates**: Wildcard template engine (\`\${rootDir}/\${project}/\${branch}\`) with real-time physical path preview.
- **Branch Mappings Sync**: Two-way integration between environment branches and branch mappings table with one-click auto-generation.

## 简体中文

- **100% 纯正 macOS 原生应用**：彻底移除对外部历史 CLI（gwtm/gmux）及 rust-core 的依赖，蜕变为完全独立自包含、超轻量（仅 ~5.5MB）、高性能的纯原生 SwiftUI/AppKit 桌面端。
- **全局界面现代化重构**：
  - **工作树 (Worktrees)**：升级为 Apple 原生高密度数据表格，支持列头排序、实时状态胶囊与底部可折叠控制台。
  - **分支同步 (Branch Sync)**：全新流向拓扑管道、精简三大执行模式（同步环境、合并全部、自定义目标）与实时日志抽屉。
  - **合并请求 (MR)**：高密度原生表格、审批与 CI 状态胶囊、吸顶式批量审批合并操作条及深度检查器。
  - **系统设置 (Settings)**：全新 3 Tab 架构（本地与工作树、平台凭据池、发布策略模板），集成运行健康诊断雷达。
- **多托管平台智能归类与自动路由**：自动根据 Git Remote 区分 GitHub 与私有 GitLab 仓库，侧边栏支持整洁的折叠分组。
- **终端与 IDE 深度集成**：
  - 本地终端自动探测（已原生支持 Otty、Ghostty、Terminal 等），并支持进入目录后自动执行命令钩子（Startup Hook）。
  - 本地 IDE 自动探测（新增 Zed、IntelliJ IDEA、Sublime 等支持），支持一键测试唤起。
- **工作树存储路径通配符模板**：支持 \`\${rootDir}/\${project}/\${branch}\` 通配符定制与实时落盘物理路径高亮预览。
- **环境分支与映射表深度复用**：环境分支与分支映射表实现双向联动，支持一键基于环境分支生成标准合流映射。
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
