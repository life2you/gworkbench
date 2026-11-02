cask "gworkbench" do
  version "0.2.9"

  on_arm do
    sha256 "2965d76a041e63f15a2b18fe8b7fbc9c109f13e8d55a27ef2261842ce622d4eb"
    url "https://github.com/life2you/gworkbench/releases/download/v#{version}/GWorkbench-macos-arm64-v#{version}.zip"
  end

  on_intel do
    sha256 "2becc40ed826cbdd48e1f605e87318e2f7f61806dfbab4b9d1bf2a7754f880a3"
    url "https://github.com/life2you/gworkbench/releases/download/v#{version}/GWorkbench-macos-x86_64-v#{version}.zip"
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
