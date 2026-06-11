# Signing and Notarization

`GWorkbench` can already be distributed as an unsigned app through GitHub Releases and Homebrew Cask.

For a smoother macOS install experience, the next step is code signing and notarization.

## What you need

- An Apple Developer account
- A Developer ID Application certificate in Keychain
- Your Apple Team ID
- An app-specific password or App Store Connect API key

## Local signing example

```bash
codesign --force --deep --options runtime \
  --sign "Developer ID Application: YOUR NAME (TEAMID)" \
  dist/GWorkbench.app
```

## Local notarization example

```bash
xcrun notarytool submit dist/release/GWorkbench-macos-arm64-v0.1.0.zip \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait
```

After success, staple the app:

```bash
xcrun stapler staple dist/GWorkbench.app
```

## Recommended future CI secrets

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_PASSWORD`
- `CODESIGN_IDENTITY`

## Recommendation

Keep Homebrew release automation active now, and add notarization only after the signing credentials are ready and stable.
