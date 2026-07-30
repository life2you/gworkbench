cask "gworkbench" do
  version "0.1.7"

  on_arm do
    sha256 "95d5d32110010d96b22fde754f74732c8c90f5572ca2ee3bdf0cda377a502da8"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.7/GWorkbench-macos-arm64-v0.1.7.zip"
  end

  on_intel do
    sha256 "4af5895d0810eac9358d636d51025dfc80597717cb333930882b0591c1ea943f"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.7/GWorkbench-macos-x86_64-v0.1.7.zip"
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
