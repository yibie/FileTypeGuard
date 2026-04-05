#!/bin/bash
# release.sh — Build, sign, notarize, and publish FileTypeGuard to Homebrew Cask
# Usage: ./release.sh [version]
# Example: ./release.sh 1.0.0

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
VERSION="${1:-1.0.0}"
APP_NAME="FileTypeGuard"
BUNDLE_ID="com.filetypeguard.mac"
TEAM_ID="26H6NRHWR6"
SIGN_IDENTITY="Developer ID Application: Chan Oliver (26H6NRHWR6)"
GITHUB_REPO="yibie/FileTypeGuard"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
XCODEPROJ="$PROJECT_DIR/FileTypeGuard.xcodeproj"

# Notarytool credentials — stored in keychain profile "notarytool"
# First-time setup: run this once manually:
#   xcrun notarytool store-credentials "notarytool" \
#     --apple-id "YOUR_APPLE_ID" \
#     --team-id "26H6NRHWR6" \
#     --password "YOUR_APP_SPECIFIC_PASSWORD"
NOTARYTOOL_PROFILE="notarytool"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; exit 1; }
step()    { echo -e "\n${YELLOW}━━━ $* ━━━${NC}"; }

# ─── Preflight checks ─────────────────────────────────────────────────────────
step "Preflight checks"

command -v xcodebuild >/dev/null || error "xcodebuild not found"
command -v gh >/dev/null         || error "GitHub CLI not found. Install: brew install gh"

security find-identity -v -p codesigning | grep -q "$SIGN_IDENTITY" \
  || error "Signing identity not found: $SIGN_IDENTITY"

info "Version:  $VERSION"
info "Repo:     $GITHUB_REPO"
info "Identity: $SIGN_IDENTITY"

# Check notarytool profile exists
xcrun notarytool history --keychain-profile "$NOTARYTOOL_PROFILE" &>/dev/null || {
  warn "Notarytool keychain profile '$NOTARYTOOL_PROFILE' not found."
  echo ""
  echo "Run this once to set it up:"
  echo "  xcrun notarytool store-credentials \"notarytool\" \\"
  echo "    --apple-id \"YOUR_APPLE_ID\" \\"
  echo "    --team-id \"$TEAM_ID\" \\"
  echo "    --password \"YOUR_APP_SPECIFIC_PASSWORD\""
  echo ""
  echo "Get an app-specific password at: https://appleid.apple.com/account/manage"
  error "Please set up notarytool credentials first."
}

# ─── Step 1: Build ────────────────────────────────────────────────────────────
step "Step 1/6: Build Release"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild \
  -project "$XCODEPROJ" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
  archive \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  MARKETING_VERSION="$VERSION" \
  ENABLE_HARDENED_RUNTIME=YES \
  | grep -E "^(Build|Archive|error:|warning: )" || true

APP_PATH="$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app"
[ -d "$APP_PATH" ] || error "Build failed — .app not found at $APP_PATH"
info "Built: $APP_PATH"

# ─── Step 2: Verify signature ─────────────────────────────────────────────────
step "Step 2/6: Verify code signature"

codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1 | tail -3
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep "Authority\|TeamID" | head -5
info "Signature OK"

# ─── Step 3: Package ──────────────────────────────────────────────────────────
step "Step 3/6: Package into zip"

ZIP_NAME="${APP_NAME}-${VERSION}.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
info "Packaged: $ZIP_PATH ($(du -sh "$ZIP_PATH" | cut -f1))"

rm -f "$DMG_PATH"
stage_dir="$BUILD_DIR/dmg-stage"
rm -rf "$stage_dir"
mkdir -p "$stage_dir"
cp -R "$APP_PATH" "$stage_dir/"
ln -s /Applications "$stage_dir/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$stage_dir"
info "Packaged: $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"

# ─── Step 4: Notarize ─────────────────────────────────────────────────────────
step "Step 4/6: Submit for notarization (this takes ~1-3 min)"

xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARYTOOL_PROFILE" \
  --wait \
  --timeout 300

info "Notarization complete"

# Staple
xcrun stapler staple "$APP_PATH"
info "Staple applied"

# Repackage after stapling
rm "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
info "Repackaged after staple"

# ─── Step 5: Compute SHA256 ───────────────────────────────────────────────────
step "Step 5/6: Compute SHA256"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
info "SHA256: $SHA256"

# ─── Step 6: Create GitHub Release ───────────────────────────────────────────
step "Step 6/6: Create GitHub Release and generate Cask"

TAG="v$VERSION"

# Check if tag already exists
if gh release view "$TAG" --repo "$GITHUB_REPO" &>/dev/null; then
  warn "Release $TAG already exists, updating notes and uploading asset..."
  gh release edit "$TAG" --repo "$GITHUB_REPO" \
    --title "$APP_NAME $VERSION" \
    --notes "## $APP_NAME $VERSION

### Changes
- Add URL scheme / protocol handler protection
- Prevent apps from hijacking default handlers for web links and other protocols

### Install via Homebrew
\`\`\`bash
brew tap yibie/tap
brew install --cask filetypeguard
\`\`\`

### Manual Install
Download \`$DMG_NAME\` or \`$ZIP_NAME\` below and move \`$APP_NAME.app\` to /Applications."
  gh release upload "$TAG" "$ZIP_PATH" "$DMG_PATH" --repo "$GITHUB_REPO" --clobber
else
  gh release create "$TAG" "$ZIP_PATH" "$DMG_PATH" \
    --repo "$GITHUB_REPO" \
    --title "$APP_NAME $VERSION" \
    --notes "## $APP_NAME $VERSION

### Changes
- Initial release

### Install via Homebrew
\`\`\`bash
brew tap yibie/tap
brew install --cask filetypeguard
\`\`\`

### Manual Install
Download \`$DMG_NAME\` or \`$ZIP_NAME\` below and move \`$APP_NAME.app\` to /Applications."
fi

DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$TAG/$ZIP_NAME"
info "Release URL: $DOWNLOAD_URL"

# ─── Generate Cask formula ────────────────────────────────────────────────────
CASK_FILE="$PROJECT_DIR/filetypeguard.rb"

cat > "$CASK_FILE" <<EOF
cask "filetypeguard" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$GITHUB_REPO/releases/download/v#{version}/${APP_NAME}-#{version}.zip"
  name "$APP_NAME"
  desc "Locks file type associations and automatically restores them when changed"
  homepage "https://github.com/$GITHUB_REPO"

  app "$APP_NAME.app"

  zap trash: [
    "~/Library/Application Support/$APP_NAME",
    "~/Library/Preferences/$BUNDLE_ID.plist",
    "~/Library/Caches/$BUNDLE_ID",
  ]
end
EOF

info "Cask formula written: $CASK_FILE"

# ─── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━ Done! ━━━${NC}"
echo ""
echo "  Version:      $VERSION"
echo "  SHA256:       $SHA256"
echo "  Download URL: $DOWNLOAD_URL"
echo "  Cask file:    $CASK_FILE"
echo ""
echo "Next steps:"
echo ""
echo "  Option A — Self-hosted tap (faster, no review needed):"
echo "    1. Create repo: https://github.com/new  (name: homebrew-tap)"
echo "    2. Run: ./publish-tap.sh"
echo ""
echo "  Option B — Official homebrew-cask (requires PR review):"
echo "    1. Fork: https://github.com/Homebrew/homebrew-cask"
echo "    2. Copy $CASK_FILE → Casks/f/filetypeguard.rb"
echo "    3. brew audit --cask --new filetypeguard"
echo "    4. Submit PR with title: 'Add filetypeguard $VERSION'"
