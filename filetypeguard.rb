cask "filetypeguard" do
  version "1.1"
  sha256 "afffef2fc04a5d214f88d2dd0af2c8aa90eebe26b9b8f0b1376799c5693ccc0c"

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
