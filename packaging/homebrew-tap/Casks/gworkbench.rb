cask "gworkbench" do
  version "0.2.4"

  on_arm do
    sha256 "6445c4151a3eaaa156c8b105f5047baedef4b18af939fcb2806754ef3b9f780a"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.4/GWorkbench-macos-arm64-v0.2.4.zip"
  end

  on_intel do
    sha256 "d494c3fc67e2e5e3136b4719d682dfd118dbf15559ed977d6573ed9553374d20"
    url "https://github.com/life2you/gworkbench/releases/download/v0.2.4/GWorkbench-macos-x86_64-v0.2.4.zip"
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
