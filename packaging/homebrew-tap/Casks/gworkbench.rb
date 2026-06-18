cask "gworkbench" do
  version "0.1.3"

  on_arm do
    sha256 "ce25449c9de33a5ac920231a16eb094deb863f5318a6e23052472d3d4dee0740"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.3/GWorkbench-macos-arm64-v0.1.3.zip"
  end

  on_intel do
    sha256 "f87bcb58094a2de362544265e47db9eab24649c7ece78b14c8737fcfd961ced7"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.3/GWorkbench-macos-x86_64-v0.1.3.zip"
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
