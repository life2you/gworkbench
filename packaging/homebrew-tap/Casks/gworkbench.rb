cask "gworkbench" do
  version "0.2.8"

  on_arm do
    sha256 "f6c90d6bee4755890f0f13f46ad6b0dd26aba70a40e5371e0b7784824a546cd5"
    url "https://github.com/life2you/gworkbench/releases/download/v#{version}/GWorkbench-macos-arm64-v#{version}.zip"
  end

  on_intel do
    sha256 "06c6f2ee43daca5dd80dd31f2bafd0465f1de2fdfedb789b0ec1a0da9198b662"
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
