#!/usr/bin/env bash
# Validates semver format for release tags
# Usage: validate-version.sh <version> <tag>

set -euo pipefail

VERSION="${1:-}"
TAG="${2:-}"

if [ -z "$VERSION" ] || [ -z "$TAG" ]; then
  echo "❌ ERROR: Usage: $0 <version> <tag>"
  exit 1
fi

echo "🔍 Validating semver format for: $VERSION"

# Semver regex pattern (supports major.minor.patch with optional pre-release and build metadata)
# Examples: 1.0.0, 1.0.0-alpha, 1.0.0-beta.1, 1.0.0+meta, 1.0.0-rc.1+build.123
SEMVER_REGEX='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'

if [[ ! "$VERSION" =~ $SEMVER_REGEX ]]; then
  echo "❌ ERROR: Tag '$TAG' does not follow semantic versioning format"
  echo "Expected format: vMAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]"
  echo "Examples: v1.0.0, v1.0.0-alpha, v1.0.0-beta.1, v1.0.0-rc.1+build.123"

  # Write error to GitHub step summary if running in CI
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    cat >> "$GITHUB_STEP_SUMMARY" << EOF
## ❌ Release Validation Failed

**Tag:** \`$TAG\`
**Version:** \`$VERSION\`

### Issue
Tag does not follow semantic versioning format.

### Expected Format
\`vMAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]\`

### Valid Examples
- \`v1.0.0\` - Standard release
- \`v1.0.0-alpha\` - Pre-release
- \`v1.0.0-beta.1\` - Pre-release with number
- \`v1.0.0-rc.1+build.123\` - Pre-release with build metadata

### Action Required
Please create a new tag following the semver format.
EOF
  fi

  exit 1
fi

echo "✅ Valid semver format: $VERSION"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "is_valid=true" >> "$GITHUB_OUTPUT"
fi
