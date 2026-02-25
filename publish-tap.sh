#!/bin/bash
# publish-tap.sh — Publish FileTypeGuard cask to yibie/homebrew-tap
# Run this after release.sh completes successfully

set -euo pipefail

GITHUB_USER="yibie"
TAP_REPO="$GITHUB_USER/homebrew-tap"
CASK_FILE="$(cd "$(dirname "$0")" && pwd)/filetypeguard.rb"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
step()  { echo -e "\n${YELLOW}━━━ $* ━━━${NC}"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

[ -f "$CASK_FILE" ] || error "filetypeguard.rb not found. Run release.sh first."

# ─── Ensure tap repo exists ───────────────────────────────────────────────────
step "Checking tap repo: $TAP_REPO"

if ! gh repo view "$TAP_REPO" &>/dev/null; then
  info "Creating $TAP_REPO..."
  gh repo create "$TAP_REPO" --public --description "Homebrew tap for yibie's apps"
  sleep 2
fi
info "Tap repo ready"

# ─── Clone / update tap ───────────────────────────────────────────────────────
step "Syncing tap repo"

TAP_DIR="/tmp/homebrew-tap-$$"
gh repo clone "$TAP_REPO" "$TAP_DIR"
mkdir -p "$TAP_DIR/Casks"

# ─── Copy cask ────────────────────────────────────────────────────────────────
cp "$CASK_FILE" "$TAP_DIR/Casks/filetypeguard.rb"
info "Copied cask formula"

# ─── Commit and push ──────────────────────────────────────────────────────────
step "Publishing to GitHub"

VERSION=$(grep 'version ' "$CASK_FILE" | head -1 | grep -o '"[^"]*"' | tr -d '"')

cd "$TAP_DIR"
git add Casks/filetypeguard.rb
git diff --cached --stat

git commit -m "Add filetypeguard $VERSION"
git push
info "Pushed to $TAP_REPO"

# ─── Cleanup ──────────────────────────────────────────────────────────────────
cd /
rm -rf "$TAP_DIR"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━ Tap published! ━━━${NC}"
echo ""
echo "Users can now install with:"
echo ""
echo "  brew tap $TAP_REPO"
echo "  brew install --cask filetypeguard"
