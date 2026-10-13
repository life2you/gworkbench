cask "gworkbench" do
  version "0.2.0"

  on_arm do
    sha256 "e87c1aef7a06e6b0f823356de9000d9ad4ae563f9c46ae9ebf2d8b0255122497"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.0/GWorkbench-macos-arm64-v0.2.0.zip"
  end

  on_intel do
    sha256 "98167e099a80f13c372e84334960db05c00758befb1433868f88245b3b145a94"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.0/GWorkbench-macos-x86_64-v0.2.0.zip"
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
