cask "gworkbench" do
  version "0.1.1"

  on_arm do
    sha256 "444c78daf134353afb3c40cf53d9e01ca48aef97c96a48f5af06869912fc4ee6"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.1/GWorkbench-macos-arm64-v0.1.1.zip"
  end

  on_intel do
    sha256 "9aebf028187756978d8064fd24fdefdc9d04db06378acf35f37b18624306bbd7"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.1/GWorkbench-macos-x86_64-v0.1.1.zip"
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
