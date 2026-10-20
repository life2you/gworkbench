cask "gworkbench" do
  version "0.2.5"

  on_arm do
    sha256 "f9d1c746129772e95cc4adb6c4a38ec6021fcfdd584d097e4ccea933489a2c1f"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.5/GWorkbench-macos-arm64-v0.2.5.zip"
  end

  on_intel do
    sha256 "c7a113f6ff939ab6b83a8eb1ecc6a3ca4c07c9160bf97c9e036663009ec17847"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.5/GWorkbench-macos-x86_64-v0.2.5.zip"
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
