#!/usr/bin/env bash
# Creates distribution ZIP archive with integrity verification
# Usage: create-archive.sh <version>

set -euo pipefail

VERSION="${1:-}"

if [ -z "$VERSION" ]; then
  echo "❌ ERROR: Usage: $0 <version>"
  exit 1
fi

ARCHIVE_NAME="e-bash.${VERSION}.zip"

echo "📦 Creating distribution archive: $ARCHIVE_NAME"

# Create ZIP archive with specified contents
zip -r "$ARCHIVE_NAME" \
  .scripts/ \
  bin/ \
  docs/ \
  demos/ \
  README.md \
  LICENSE \
  -x "*.git*" \
  -x "*__pycache__*" \
  -x "*.pyc" \
  -x "*node_modules*" \
  -x "*.DS_Store"

# Verify archive was created
if [ ! -f "$ARCHIVE_NAME" ]; then
  echo "❌ ERROR: Failed to create archive"
  exit 1
fi

# Verify archive integrity
echo ""
echo "🔍 Verifying archive integrity..."
if unzip -t "$ARCHIVE_NAME" >/dev/null 2>&1; then
  echo "✅ Archive integrity verified"
else
  echo "❌ ERROR: Archive integrity check failed"
  exit 1
fi

# Calculate checksum
echo ""
echo "🔐 Calculating checksum..."
CHECKSUM=$(sha256sum "$ARCHIVE_NAME" | cut -d' ' -f1)
echo "SHA256: $CHECKSUM"

# Show archive info
echo ""
echo "✅ Archive created successfully"
ls -lh "$ARCHIVE_NAME"
echo ""
echo "📋 Archive contents (first 50 files):"
unzip -l "$ARCHIVE_NAME" | head -n 52

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "archive_name=$ARCHIVE_NAME" >> "$GITHUB_OUTPUT"
  echo "checksum=$CHECKSUM" >> "$GITHUB_OUTPUT"
fi

# Also create a checksum file for local verification
echo "$CHECKSUM  $ARCHIVE_NAME" > "${ARCHIVE_NAME}.sha256"
echo ""
echo "💾 Checksum saved to: ${ARCHIVE_NAME}.sha256"
