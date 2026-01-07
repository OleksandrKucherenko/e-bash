#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 3.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Auto-generate CHANGELOG.md using Gemini CLI
# Usage: generate-changelog.sh [version]
#
# This script:
# 1. Auto-detects the last release tag in the repository
# 2. Extracts commit messages from last tag to HEAD
# 3. Uses Gemini CLI to generate a formatted changelog

set -euo pipefail

VERSION="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$REPO_ROOT"

# Detect the last release tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -z "$LAST_TAG" ]]; then
  echo "ℹ️  No previous tag found, using all commits" >&2
  RANGE="HEAD"
  RANGE_DESC="all commits"
else
  echo "ℹ️  Generating changelog from $LAST_TAG to HEAD" >&2
  RANGE="${LAST_TAG}..HEAD"
  RANGE_DESC="$LAST_TAG → HEAD"
fi

# Count commits in range
COMMIT_COUNT=$(git rev-list --count "$RANGE" 2>/dev/null || echo "0")
echo "📊 Found $COMMIT_COUNT commits ($RANGE_DESC)" >&2

if [[ "$COMMIT_COUNT" -eq 0 ]]; then
  echo "⚠️  No commits found in range. Nothing to generate." >&2
  exit 0
fi

# Extract commits in conventional format
COMMITS=$(git log "$RANGE" --pretty=format:"- %s (%h)")

# Check if gemini CLI is available
if ! command -v gemini &>/dev/null; then
  echo "❌ ERROR: gemini CLI not found in PATH" >&2
  echo "Install with: npm install -g @anthropic-ai/gemini" >&2
  echo "" >&2
  echo "Raw commits:" >&2
  echo "$COMMITS"
  exit 1
fi

# Build version string for prompt
VERSION_STR=""
if [[ -n "$VERSION" ]]; then
  VERSION_STR=" for version $VERSION"
fi

# Generate changelog using Gemini CLI
PROMPT="Generate a release changelog${VERSION_STR} from the following git commits.

Group commits by category using these headers:
## ✨ Features
## 🐛 Bug Fixes  
## ♻️ Refactoring
## 📚 Documentation
## 🔧 Other Changes

Rules:
- Only include categories that have commits
- Each commit should be a bullet point
- Keep the commit hash in parentheses
- Format as clean markdown
- Add a brief summary paragraph at the top

Commits:
$COMMITS"

echo "" >&2
echo "🤖 Generating changelog with Gemini CLI..." >&2

echo "$COMMITS" | gemini -p "$PROMPT"

echo "" >&2
echo "✅ Changelog generated successfully" >&2
