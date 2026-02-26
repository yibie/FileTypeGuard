cask "filetypeguard" do
  version "1.2.0"
  sha256 "cbd3026d28389b057aa54207b390a35c34e857fbb1b850bc2f4621080246c094"

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
