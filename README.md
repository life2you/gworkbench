[简体中文](README.zh-CN.md)

# GWorkbench

`GWorkbench` is a native macOS desktop app that combines `gwtm`-style worktree management and `gmux`-style GitLab merge workflows in one place.

## What It Does

- Scans local repositories and worktrees from configurable root directories
- Creates, opens, deletes, and annotates Git worktrees
- Supports local branch sync, one-source multi-target merge, and push flows
- Loads GitLab MR queues, shows approvals and authors, and supports approve/merge/close
- Supports one-click batch approve-and-merge for the current MR list
- Keeps its own desktop config at `~/.config/gworkbench/config.toml`
- Packages as a double-clickable macOS `.app`

## Project Layout

- `Sources/GWorkbenchApp`: SwiftUI macOS app
- `docs/`: UI and product notes
- `scripts/build-mac-app.sh`: build a local `.app`
- `scripts/package-release-assets.sh`: build release zip assets for macOS
- `scripts/update-homebrew-cask.sh`: generate the Homebrew Cask definition
- `scripts/release-and-upgrade-local.sh`: publish release assets, update tap, and refresh local Homebrew install
- `packaging/homebrew-tap/Casks/gworkbench.rb`: generated reference cask

## Requirements

- macOS 15 or newer
- Xcode / Swift toolchain
- Git
- Python 3 with `tomli`

## Run

Development mode:

```bash
swift run GWorkbenchApp
```

Build a local app:

```bash
./scripts/build-mac-app.sh
open dist/GWorkbench.app
```

## Homebrew

This project is prepared for Homebrew Cask distribution.

Once the release assets and `life2you/homebrew-tap` cask are published, install with:

```bash
brew install --cask life2you/tap/gworkbench
```

## Release Docs

- English: [`RELEASING.md`](RELEASING.md)
- 简体中文: [`RELEASING.zh-CN.md`](RELEASING.zh-CN.md)

## License

MIT
