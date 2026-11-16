cask "gworkbench" do
  version "0.3.0"

  on_arm do
    sha256 "f51f385c3ba3711466c5f084ebd981c71f867105b88bbe5de3da251bc9c654d3"
    url "https://github.com/life2you/gworkbench/releases/download/v#{version}/GWorkbench-macos-arm64-v#{version}.zip"
  end

  on_intel do
    sha256 "dd8583aebc41fb931913efae559ed1bda2559316537d2fdc52409098f6f54262"
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
