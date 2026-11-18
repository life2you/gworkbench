cask "gworkbench" do
  version "0.3.2"

  on_arm do
    sha256 "ced9a4c25978fe5823b22ef0de945ac4f1011f7a013bfe83ffb791b0c99bacfa"
    url "https://github.com/life2you/gworkbench/releases/download/v#{version}/GWorkbench-macos-arm64-v#{version}.zip"
  end

  on_intel do
    sha256 "678b23989ebdca9fc51f8dd019837bf8c71aa720ba71555ead8bdc40a8e21ffb"
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
