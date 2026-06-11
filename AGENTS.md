# AGENTS.md

## Scope

This repository ships a native macOS desktop app and is prepared for Homebrew Cask distribution.

## AI Collaboration Rules

- Prefer `gh` for GitHub operations. Before using raw `git`, `curl`, or manual browser steps for releases, workflows, PRs, issues, tags, or repository inspection, first check whether `gh` is installed and authenticated with `command -v gh` and `gh auth status`.
- Keep `VERSION`, release tags, packaged app assets, generated Homebrew cask content, and GitHub Release notes aligned.
- Do not hand-edit Homebrew checksum values. Use `scripts/update-homebrew-cask.sh`.
- For local release publishing, prefer `scripts/release-and-upgrade-local.sh`. It pushes the current branch and tag, publishes release assets, updates `life2you/homebrew-tap`, and refreshes the local Homebrew installation.
- GitHub release automation lives in `.github/workflows/release.yml` and can update `life2you/homebrew-tap` automatically when the `HOMEBREW_TAP_PUSH_TOKEN` repository secret is configured.
- When a release includes new release-flow or upgrade-flow capabilities, add those upgrade highlights to the GitHub Release page notes/changelog for that version in both English and Chinese.
- Before shipping a release, run at minimum `swift build` and `./scripts/build-mac-app.sh`.
