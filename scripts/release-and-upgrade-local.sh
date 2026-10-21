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

- **New: copy IDE project settings into new worktrees**
  - Creating a worktree now optionally copies a whitelist of `.idea` config files from the
    main repository into the new worktree, so IDE state no longer has to be reconfigured
    every time.
  - Default whitelist: `.gitignore`, `misc.xml`, `compiler.xml`, `encodings.xml`,
    `jarRepositories.xml`, `vcs.xml`. Only 4.2 KB in total.
  - Deliberately excluded: `workspace.xml` (personal session state, breakpoints, absolute
    paths), `shelf/` (local shelved patches), `.cache/` (plugin binary caches), and plugin
    config files that embed plaintext access tokens.
  - The copy runs before the IDE is launched. This matters: IntelliJ IDEA reads
    `compiler.xml` and `misc.xml` at startup and rewrites them afterwards, so copying later
    would be overwritten.
  - Configurable in Settings → IDE Integration: master toggle plus an editable
    comma-separated whitelist with a "restore defaults" button. Also toggleable per
    creation in the new-worktree sheet.
  - New config keys under `[worktree]`: `sync_ide_configs` (default `false`) and
    `ide_config_sync_items`.
- **New: search filter for the "existing branch" mode when creating a worktree**
  - The existing-branch picker previously listed every local and remote branch with no way
    to filter. A large repository can easily have hundreds of branches.
  - Added a search field above the picker with case-insensitive substring matching and a
    clear button, matching the interaction style already used elsewhere in the app.
  - The currently selected branch is always kept in the filtered result, so the picker never
    renders blank when the active selection does not match the keyword.
  - Shows an inline hint when the keyword matches nothing.

## 简体中文

- **新增：新建工作树时复制 IDE 项目配置**
  - 新建工作树时可选择性从主仓库复制白名单内的 `.idea` 配置文件到新工作树，
    不必再为每个新工作树重新配置 IDE。
  - 默认白名单：`.gitignore`、`misc.xml`、`compiler.xml`、`encodings.xml`、
    `jarRepositories.xml`、`vcs.xml`，合计仅 4.2 KB。
  - 默认排除：`workspace.xml`（个人会话状态、断点、绝对路径）、`shelf/`（本地暂存改动）、
    `.cache/`（插件二进制缓存），以及内嵌明文访问令牌的插件配置文件。
  - 复制发生在拉起 IDE 之前。这一点很关键：IntelliJ IDEA 启动时会读取并随后重写
    `compiler.xml` 与 `misc.xml`，复制过晚会被覆盖。
  - 可在「设置 → IDE 编辑器外部集成」中配置：总开关 + 可编辑的逗号分隔白名单 +
    「恢复默认」按钮；新建工作树弹窗中也可按次开关。
  - 新增配置项（位于 `[worktree]`）：`sync_ide_configs`（默认 `false`）、
    `ide_config_sync_items`。
- **新增：新建工作树「已有分支」模式支持搜索**
  - 已有分支下拉框原先会列出全部本地与远端分支且无法过滤，大仓库动辄数百条。
  - 在下拉框上方增加搜索框，支持大小写不敏感的子串匹配与一键清空，
    交互风格与 App 内其它搜索框保持一致。
  - 当前已选中的分支始终保留在过滤结果中，避免选中项不匹配关键词时下拉框显示空白。
  - 关键词无匹配时展示行内提示。
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
