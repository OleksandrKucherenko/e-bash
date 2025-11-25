#!/usr/bin/env bash
# Generates release summary for GitHub Actions
# Usage: release-summary.sh <version> <tag> <commit_sha> <checksum> <archive_name> <repository>

set -euo pipefail

VERSION="${1:-}"
TAG="${2:-}"
COMMIT_SHA="${3:-}"
CHECKSUM="${4:-}"
ARCHIVE_NAME="${5:-}"
REPOSITORY="${6:-OleksandrKucherenko/e-bash}"

if [ -z "$VERSION" ] || [ -z "$TAG" ] || [ -z "$COMMIT_SHA" ] || [ -z "$CHECKSUM" ] || [ -z "$ARCHIVE_NAME" ]; then
  echo "❌ ERROR: Usage: $0 <version> <tag> <commit_sha> <checksum> <archive_name> [repository]"
  exit 1
fi

RELEASE_URL="https://github.com/${REPOSITORY}/releases/tag/${TAG}"

# Write to GitHub step summary if in CI, otherwise to stdout
OUTPUT="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

cat >> "$OUTPUT" << EOF
## 🎉 Release Created Successfully!

### 📋 Release Information
- **Version:** \`${VERSION}\`
- **Tag:** \`${TAG}\`
- **Commit:** [\`${COMMIT_SHA:0:7}\`](https://github.com/${REPOSITORY}/commit/${COMMIT_SHA})
- **Release URL:** ${RELEASE_URL}

### 📦 Distribution Package
- **Archive:** \`${ARCHIVE_NAME}\`
- **SHA256:** \`${CHECKSUM}\`

### 📥 Quick Download
\`\`\`bash
wget https://github.com/${REPOSITORY}/releases/download/${TAG}/${ARCHIVE_NAME}
\`\`\`

### ✅ Next Steps
- View the release: ${RELEASE_URL}
- Verify checksum after download
- Update documentation if needed

---
🚀 Distribution package is now available in [GitHub Releases](${RELEASE_URL})
EOF

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "✅ Release summary written to GitHub Actions"
fi
