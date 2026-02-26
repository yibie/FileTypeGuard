cask "filetypeguard" do
  version "1.2.1"
  sha256 "a389dcf8b225c987d6b8f746ab7fdbfbd98255e0d0386a065c8c135b86140a90"

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
