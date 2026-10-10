cask "gworkbench" do
  version "0.1.9"

  on_arm do
    sha256 "bcd947a328d1b6b467c27b87476093e805ea0301967f5ca87bf450f9cb0aa6f6"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.9/GWorkbench-macos-arm64-v0.1.9.zip"
  end

  on_intel do
    sha256 "a1eb99881eca8b60c528a7ee6bcc413ce800cd621c9e6406f779b175699991e4"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.9/GWorkbench-macos-x86_64-v0.1.9.zip"
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
