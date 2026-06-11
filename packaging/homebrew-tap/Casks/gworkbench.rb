cask "gworkbench" do
  version "0.1.0"

  on_arm do
    sha256 "a98b64bd9e9e7d44a4e32e59817e3d230d32d06dd9182f73cabc680bb94342ec"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.0/GWorkbench-macos-arm64-v0.1.0.zip"
  end

  on_intel do
    sha256 "0ed86b8ba426051ba72cbce9db72ff9ac03b99829ec212e4cc318f41f2549e3a"
    url "https://github.com/life2you/gworkbench/releases/download/v0.1.0/GWorkbench-macos-x86_64-v0.1.0.zip"
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
