cask "gworkbench" do
  version "0.1.2"

  on_arm do
    sha256 "b43dafa7ba7de07ee1d3dce11f1a751d4c918709a4b95dd054e71c2913079454"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.2/GWorkbench-macos-arm64-v0.1.2.zip"
  end

  on_intel do
    sha256 "a28d7aed4681460e5cab67315bccef1fdeb5d62b62b5bc71c542f3d82d60b73b"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.2/GWorkbench-macos-x86_64-v0.1.2.zip"
  end

  name "GWorkbench"
  desc "Native macOS desktop app for Git worktrees and GitLab merge workflows"
  homepage "https://github.com/life2you/gworkbench"

  depends_on macos: :sequoia

  app "GWorkbench.app"

  zap trash: [
    "~/.config/gworkbench",
  ]
end
