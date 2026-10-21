cask "gworkbench" do
  version "0.2.6"

  on_arm do
    sha256 "f0e28286744a2beb687be8ffe8e46a259ee193b11c5ace7c8b4b2a0d5afecac4"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.6/GWorkbench-macos-arm64-v0.2.6.zip"
  end

  on_intel do
    sha256 "7cc408159b6d8bdf7b9e4c8360cbb4ec4e3984025e9fcfe58d6e755cdf420b1e"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.6/GWorkbench-macos-x86_64-v0.2.6.zip"
  end

  name "GWorkbench"
  desc "Native macOS desktop app for Git worktrees and GitLab merge workflows"
  homepage "https://github.com/life2you/gworkbench"

  depends_on macos: ">= :sonoma"

  app "GWorkbench.app"

  zap trash: [
    "~/.config/gworkbench",
  ]
end
