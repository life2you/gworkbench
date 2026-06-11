[English](README.md)

# GWorkbench

`GWorkbench` 是一个原生 macOS 桌面应用，把 `gwtm` 风格的工作树管理和 `gmux` 风格的 GitLab MR 工作流放进同一个界面里。

## 功能

- 从可配置根目录扫描本地仓库和 worktree
- 创建、打开、删除并补充工作树描述
- 支持本地分支同步、单源多目标合并和推送
- 拉取 GitLab MR 队列，展示审批状态和创建人，并支持审批 / 合并 / 关闭
- 支持对当前 MR 列表一键批量审批并合并
- 使用独立桌面配置文件 `~/.config/gworkbench/config.toml`
- 可以打包成可双击启动的 macOS `.app`

## 项目结构

- `Sources/GWorkbenchApp`：SwiftUI macOS 应用
- `docs/`：UI 和产品说明
- `scripts/build-mac-app.sh`：构建本地 `.app`
- `scripts/package-release-assets.sh`：构建发布用 macOS zip 资产
- `scripts/update-homebrew-cask.sh`：生成 Homebrew Cask
- `scripts/release-and-upgrade-local.sh`：发布 release、更新 tap，并刷新本机 Homebrew 安装
- `packaging/homebrew-tap/Casks/gworkbench.rb`：生成后的参考 cask

## 依赖

- macOS 15 或更新版本
- Xcode / Swift 工具链
- Git
- Python 3 + `tomli`

## 运行

开发模式：

```bash
swift run GWorkbenchApp
```

构建本地应用：

```bash
./scripts/build-mac-app.sh
open dist/GWorkbench.app
```

## Homebrew

本项目已经按 Homebrew Cask 分发做了准备。

当 release 资产和 `life2you/homebrew-tap` 里的 cask 发布后，可以这样安装：

```bash
brew install --cask life2you/tap/gworkbench
```

## 发布文档

- English: [`RELEASING.md`](RELEASING.md)
- 简体中文: [`RELEASING.zh-CN.md`](RELEASING.zh-CN.md)

## 许可证

MIT
