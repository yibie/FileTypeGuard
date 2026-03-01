cask "filetypeguard" do
  version "1.2.2"
  sha256 "f805c5f28516d12a9b13e92d9943c370467a2135ecb15ca1bd4431f54d3b4ba8"

  url "https://github.com/yibie/FileTypeGuard/releases/download/v#{version}/FileTypeGuard-#{version}.zip"
  name "FileTypeGuard"
  desc "Locks file type associations and automatically restores them when changed"
  homepage "https://github.com/yibie/FileTypeGuard"

  app "FileTypeGuard.app"

  zap trash: [
    "~/Library/Application Support/FileTypeGuard",
    "~/Library/Preferences/com.filetypeguard.mac.plist",
    "~/Library/Caches/com.filetypeguard.mac",
  ]
end
