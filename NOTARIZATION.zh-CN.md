# 签名与公证

`GWorkbench` 现在已经可以通过 GitHub Releases 和 Homebrew Cask 作为未签名应用分发。

如果你想让 macOS 安装体验更顺滑，下一步就是补代码签名和 notarization 公证。

## 需要准备的东西

- Apple Developer 账号
- Keychain 里的 `Developer ID Application` 证书
- Apple Team ID
- app-specific password，或者 App Store Connect API key

## 本地签名示例

```bash
codesign --force --deep --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  dist/GWorkbench.app
```

## 本地公证示例

```bash
xcrun notarytool submit dist/release/GWorkbench-macos-arm64-v0.1.0.zip \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait
```

公证成功后再做 staple：

```bash
xcrun stapler staple dist/GWorkbench.app
```

## 后续建议放到 CI 的 secrets

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`
- `CODESIGN_IDENTITY`

## 建议

现在先保留已经跑通的 Homebrew 发布自动化；等签名凭据准备稳定后，再把签名和公证接进 CI。
