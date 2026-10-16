cask "gworkbench" do
  version "0.2.2"

  on_arm do
    sha256 "4fb6b613bd4a3562a90dc008ebde3df1330e615b23b1fc7495d5392ae4da5c90"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.2/GWorkbench-macos-arm64-v0.2.2.zip"
  end

  on_intel do
    sha256 "b90b3a25d91479bb200e8dfa2c14e262dc83c0a4e621390a39f18ca29c216488"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.2/GWorkbench-macos-x86_64-v0.2.2.zip"
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
