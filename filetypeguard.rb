cask "filetypeguard" do
  version "1.2.3"
  sha256 "930ee17f1b7efd74837ae707e47c8bc50a4baad4260019909870acae17fdbcd5"

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
