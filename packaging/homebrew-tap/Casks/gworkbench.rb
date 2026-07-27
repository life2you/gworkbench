cask "gworkbench" do
  version "0.1.6"

  on_arm do
    sha256 "107bb4c76084be6aae490ce39dd590c8eb4bc0847efdb46b0b90b0f681f915a2"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.6/GWorkbench-macos-arm64-v0.1.6.zip"
  end

  on_intel do
    sha256 "566ec31603f87d55d37628a7b9bf7c345d60ef0251c2971006d373ac95e9c13b"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.6/GWorkbench-macos-x86_64-v0.1.6.zip"
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
