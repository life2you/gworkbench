cask "gworkbench" do
  version "0.2.7"

  on_arm do
    sha256 "0a5904a65f7e0694a5a9132991cd9adf6fc656b2b1047cbba5f1ed716f9e8aeb"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.7/GWorkbench-macos-arm64-v0.2.7.zip"
  end

  on_intel do
    sha256 "c1c1f6366620e21bd95bbf428544cb7a7b29f25ed454d16024b21ed69200b2ba"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.7/GWorkbench-macos-x86_64-v0.2.7.zip"
  end

  name "GWorkbench"
  desc "Native macOS desktop app for Git worktrees and GitLab merge workflows"
  homepage "https://github.com/life2you/gworkbench"

  depends_on macos: :sonoma

  app "GWorkbench.app"

  zap trash: [
    "~/.config/gworkbench",
  ]
end
