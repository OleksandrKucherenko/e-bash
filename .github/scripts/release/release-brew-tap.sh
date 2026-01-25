#!/usr/bin/env bash
#
# Update Homebrew Tap Formula
# Usage: .github/scripts/release/release-brew-tap.sh <version>
#

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-25
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

set -e

VERSION="${1:-}"
TAP_REPO="artfulbits-se/homebrew-tap"
FORMULA_PATH="Formula/e-bash.rb"

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>"
    exit 1
fi

# Remove 'v' prefix if present
VERSION="${VERSION#v}"
TAG="v${VERSION}"
ARCHIVE_URL="https://github.com/OleksandrKucherenko/e-bash/archive/refs/tags/${TAG}.tar.gz"

echo "🍺 Updating Homebrew Formula for e-bash ${VERSION}..."

# 1. Calculate SHA256 of the remote archive
echo "   Downloading and calculating SHA256..."
SHA256=$(curl -sL "$ARCHIVE_URL" | sha256sum | awk '{print $1}')

if [[ -z "$SHA256" ]]; then
    echo "Error: Failed to calculate SHA256 for $ARCHIVE_URL"
    exit 1
fi
echo "   SHA256: $SHA256"

# 2. Determine working directory (Worktree or Temp Clone)
WORK_DIR=""
CLEANUP=false

if [[ -d ".worktrees/homebrew-tap" ]]; then
    echo "   Using local worktree: .worktrees/homebrew-tap"
    WORK_DIR=".worktrees/homebrew-tap"
    cd "$WORK_DIR"
    git pull origin main
elif [[ -n "$TAP_GITHUB_TOKEN" ]]; then
    echo "   Cloning tap repository (CI mode)..."
    WORK_DIR=$(mktemp -d)
    CLEANUP=true
    git clone "https://x-access-token:${TAP_GITHUB_TOKEN}@github.com/${TAP_REPO}.git" "$WORK_DIR"
    cd "$WORK_DIR"
else
    echo "Error: Neither local worktree (.worktrees/homebrew-tap) nor TAP_GITHUB_TOKEN found."
    exit 1
fi

# 3. Update Formula
if [[ ! -f "$FORMULA_PATH" ]]; then
    echo "Error: Formula not found at $WORK_DIR/$FORMULA_PATH"
    exit 1
fi

# Use sed to update url and sha256
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS sed requires empty string for -i without backup
    sed -i '' "s|url \".*\"|url \"$ARCHIVE_URL\"|" "$FORMULA_PATH"
    sed -i '' "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$FORMULA_PATH"
else
    sed -i "s|url \".*\"|url \"$ARCHIVE_URL\"|" "$FORMULA_PATH"
    sed -i "s|sha256 \".*\"|sha256 \"$SHA256\"|" "$FORMULA_PATH"
fi

echo "   Updated $FORMULA_PATH"

# 4. Commit and Push
if [[ -n "$(git status --porcelain)" ]]; then
    git config user.name "e-bash Release Bot"
    git config user.email "bot@e-bash.com"

    git add "$FORMULA_PATH"
    git commit -m "feat: update e-bash to ${TAG}"
    git push origin main
    echo "🚀 Successfully updated Homebrew tap!"
else
    echo "   No changes detected."
fi

# 5. Cleanup
if [[ "$CLEANUP" == "true" ]]; then
    rm -rf "$WORK_DIR"
fi
