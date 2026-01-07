#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 3.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Verify release version against script versions (go-forward-only policy)
# Usage: verify-versions.sh [target-version]
#
# This script:
# 1. Scans all .sh files for ## Version: headers
# 2. Reports files with versions higher than target
# 3. Suggests the minimum release version

set -euo pipefail

TARGET="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

cd "$REPO_ROOT"

MAX_VERSION="0.0.0"
MAX_FILE=""
VIOLATIONS=0

echo "🔍 Scanning script versions..."
echo ""

# Compare semver versions using sort -V (returns 0 if $1 > $2)
# Note: sort -V handles MAJOR.MINOR.PATCH correctly, sufficient for script versions
version_gt() {
  local v1="$1" v2="$2"
  [[ "$v1" != "$v2" ]] && [[ "$(printf '%s\n' "$v1" "$v2" | sort -V | tail -1)" == "$v1" ]]
}

# Scan .scripts and bin directories
while IFS=: read -r file line; do
  version=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  [[ -z "$version" ]] && continue
  
  # Track maximum version found
  if version_gt "$version" "$MAX_VERSION"; then
    MAX_VERSION="$version"
    MAX_FILE="$file"
  fi
  
  # Check for violations if target specified
  if [[ -n "$TARGET" ]] && version_gt "$version" "$TARGET"; then
    echo "⚠️  $file: $version > $TARGET"
    ((VIOLATIONS++)) || true
  fi
done < <(grep -rH "^## Version:" .scripts bin --include="*.sh" 2>/dev/null || true)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Highest version found: $MAX_VERSION"
echo "📁 File: $MAX_FILE"
echo "💡 Suggested minimum release version: $MAX_VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$TARGET" ]]; then
  echo ""
  if [[ "$VIOLATIONS" -gt 0 ]]; then
    echo "⚠️  Found $VIOLATIONS file(s) with version > $TARGET"
    echo "   Consider using version $MAX_VERSION or higher for the release."
  else
    echo "✅ All script versions are <= $TARGET"
  fi
fi

exit 0
