cask "gworkbench" do
  version "0.2.1"

  on_arm do
    sha256 "d2b908b5b43183690ffea27ec0f8ff966ba179576a169d95f881821cb74a1571"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.1/GWorkbench-macos-arm64-v0.2.1.zip"
  end

  on_intel do
    sha256 "c8cb21e740331dbd128d21738369b839f493430dab633c32451408a4ba53ef48"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.1/GWorkbench-macos-x86_64-v0.2.1.zip"
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
