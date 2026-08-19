cask "gworkbench" do
  version "0.1.8"

  on_arm do
    sha256 "9acee1dad9cf102592d9de4b1304f99e13a3486ca63dd98f7cd9dece3802dce7"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.8/GWorkbench-macos-arm64-v0.1.8.zip"
  end

  on_intel do
    sha256 "78bbd87816eee95b4d24dfe4f8606bee940f31db5141b9eda6396bd29c1e006d"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.8/GWorkbench-macos-x86_64-v0.1.8.zip"
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
