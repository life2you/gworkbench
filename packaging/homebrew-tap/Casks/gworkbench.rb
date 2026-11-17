cask "gworkbench" do
  version "0.3.1"

  on_arm do
    sha256 "4e85422684429b22d63f9fe6b4b5b9b9f165864c252a50b057ce4e887003683a"
    url "https://github.com/life2you/gworkbench/releases/download/v#{version}/GWorkbench-macos-arm64-v#{version}.zip"
  end

  on_intel do
    sha256 "576ed58b7d624592a5054b6b120cbddac79b25388e1c3082112ac554ad21659a"
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
