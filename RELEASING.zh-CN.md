# 发布 GWorkbench

## 版本号

1. 更新 `VERSION`
2. 提交本次 release 改动
3. 创建带注释的 tag：

```bash
git tag -a v<version> -m "v<version>"
```

## 本地发布流程

推荐直接使用：

```bash
./scripts/release-and-upgrade-local.sh <version>
```

这个脚本会自动完成：

1. 推送当前分支和 tag
2. 构建 Apple Silicon 和 Intel 两套 macOS release 资产
3. 创建或替换 GitHub Release
4. 生成 Homebrew Cask
5. 更新 `life2you/homebrew-tap`
6. 在本机执行 `brew update` 和 `brew upgrade/install --cask life2you/tap/gworkbench`

## 手动构建发布资产

```bash
./scripts/package-release-assets.sh
```

生成结果：

- `dist/release/GWorkbench-macos-arm64-v<version>.zip`
- `dist/release/GWorkbench-macos-x86_64-v<version>.zip`

## 更新 Homebrew Cask

当 GitHub Release 资产已经公开可下载后，可以生成 cask：

```bash
./scripts/update-homebrew-cask.sh <version>
```

## Release 说明

每次发布都要同时补英文和简体中文说明。  
如果本次更新涉及发布流程、升级流程或 Homebrew 安装体验，也要在 Release 页面里明确写出来。
