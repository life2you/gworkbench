# Releasing GWorkbench

## Version

1. Update `VERSION`.
2. Commit the release changes.
3. Create an annotated tag:

```bash
git tag -a v<version> -m "v<version>"
```

## Local publish flow

Preferred local release flow:

```bash
./scripts/release-and-upgrade-local.sh <version>
```

This script will:

1. Push the current branch and tag
2. Build macOS release assets for Apple Silicon and Intel
3. Create or replace the GitHub Release
4. Generate the Homebrew Cask
5. Update `life2you/homebrew-tap`
6. Run local `brew update` and `brew upgrade/install --cask life2you/tap/gworkbench`

## Manual asset build

```bash
./scripts/package-release-assets.sh
```

Generated assets:

- `dist/release/GWorkbench-macos-arm64-v<version>.zip`
- `dist/release/GWorkbench-macos-x86_64-v<version>.zip`

## Homebrew Cask update

Generate a cask file after the GitHub Release assets are public:

```bash
./scripts/update-homebrew-cask.sh <version>
```

## Release notes

Every release should include highlights in both English and Simplified Chinese, especially when new release-flow or upgrade-flow capabilities were added.
