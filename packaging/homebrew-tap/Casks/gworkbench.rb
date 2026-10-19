cask "gworkbench" do
  version "0.2.3"

  on_arm do
    sha256 "c7aba58bb7c1f66b40d00b62b5551310b716dfd18f2f6c8c49cfac57090eb41b"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.3/GWorkbench-macos-arm64-v0.2.3.zip"
  end

  on_intel do
    sha256 "7b3f8227ee094a0bc6574f7779d288a0dbba50af462648b05747ebcc83a0f330"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.3/GWorkbench-macos-x86_64-v0.2.3.zip"
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
