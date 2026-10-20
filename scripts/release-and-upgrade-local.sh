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

- **Fixed: Repositories intermittently misclassified into the Local group**
  - Symptom: some GitLab/GitHub repositories briefly appeared under "本地仓库" and jumped back on the next refresh
  - Cause: bootstrap ran three independent full scans (worktrees, branch sync, merge requests) at once, spawning hundreds of git processes in a burst; intermittent fork/exec failures made `git config --get remote.origin.url` return nothing, and `try?` silently treated that as "no remote configured", falling back to Local
  - Platform probing is now tri-state: resolved URL / genuinely no remote (git exit 1) / probe failed
  - Transient probe failures retry up to 3 times with backoff
  - Added a pure file-based `.git/config` parser as fallback, immune to process launch failure
  - Added per-repository platform cache so a known GitLab/GitHub repo can never be downgraded to Local by a transient error
  - Added inference from `origin/*` tracked refs and the configured GitLab host when probing fails
- **Performance and robustness**
  - Project scan now uses a 1.5s TTL cache plus a single-flight guard, so all three callers share one scan instead of spawning concurrent process storms
  - Scan concurrency is bounded to min(6, CPU count) instead of an unbounded parallel loop
  - Fixed a pipe-read race in `ProcessRunner` (readabilityHandler + waitUntilExit could drop output); replaced with dedicated reader threads coordinated by a DispatchGroup
- **Verification**
  - 600 concurrent origin probes: 0 launch failures, 0 empty-but-successful outputs
  - 200 rounds of high-concurrency scanning across 6 repositories: 0 platform flicker
  - Fallback chain verified end to end: cache -> .git/config -> remote-tracked refs

## 简体中文

- **修复：仓库偶发被错误归入「本地仓库」分组**
  - 现象：部分 GitLab/GitHub 仓库会短暂出现在「本地仓库」分组，过一会又跳回原分组
  - 原因：启动时工作树、分支同步、合并请求三个模块各自执行一次全量扫描，短时间拉起数百个 git 进程；偶发的 fork/exec 失败使 `git config --get remote.origin.url` 读不到内容，而 `try?` 把它静默当成「未配置远端」，于是回退为本地
  - 远端探测改为三态：读取成功 / 确实未配置（git 退出码 1）/ 探测失败
  - 偶发失败自动退避重试，最多 3 次
  - 新增纯文件解析 `.git/config` 的兜底路径，不受进程启动失败影响
  - 新增每个仓库的平台缓存，已知的 GitLab/GitHub 仓库绝不会因偶发错误被降级为本地
  - 探测失败时根据 `origin/*` 远端跟踪分支与配置的 GitLab 主机进行兜底推断
- **性能与健壮性**
  - 项目扫描引入 1.5 秒 TTL 缓存与单飞保护，三个调用方共享同一次扫描，不再重复拉起并发进程风暴
  - 扫描并发度收敛为 min(6, CPU 核数)，替代原先无上限的并行循环
  - 修复 `ProcessRunner` 的管道读取竞态（readabilityHandler 配合 waitUntilExit 可能丢输出），改用独立读取线程 + DispatchGroup 协调
- **验证**
  - 600 次并发远端探测：0 次启动失败，0 次「退出码 0 但输出为空」
  - 6 个仓库各 200 轮高并发扫描：0 次平台抖动
  - 兜底链完整验证：平台缓存 -> `.git/config` 文件解析 -> 远端跟踪分支推断
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
