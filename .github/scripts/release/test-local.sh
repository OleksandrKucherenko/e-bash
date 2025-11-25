#!/usr/bin/env bash
# Local testing script for release pipeline
# Usage: ./.github/scripts/release/test-local.sh [test-version]

set -euo pipefail

VERSION="${1:-1.2.3-test}"
TAG="v${VERSION}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "================================================="
echo "🧪 Testing Release Pipeline Locally"
echo "================================================="
echo "Version: $VERSION"
echo "Tag: $TAG"
echo ""

# Ensure we're in repository root
cd "$SCRIPT_DIR/../../.."
echo "Working directory: $(pwd)"
echo ""

# Test 1: Validate version
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Testing: validate-version.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./.github/scripts/release/validate-version.sh "$VERSION" "$TAG"; then
  echo "✅ Validation passed"
else
  echo "❌ Validation failed"
  exit 1
fi
echo ""

# Test 2: Check quality
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Testing: check-quality.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./.github/scripts/release/check-quality.sh; then
  echo "✅ Quality check passed"
else
  echo "⚠️  Quality check had warnings (non-blocking)"
fi
echo ""

# Test 3: Verify contents
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  Testing: verify-contents.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./.github/scripts/release/verify-contents.sh; then
  echo "✅ Content verification passed"
else
  echo "❌ Content verification failed"
  exit 1
fi
echo ""

# Test 4: Create archive
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  Testing: create-archive.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./.github/scripts/release/create-archive.sh "$VERSION"; then
  echo "✅ Archive creation passed"
  ARCHIVE_NAME="e-bash.${VERSION}.zip"
  CHECKSUM=$(cat "${ARCHIVE_NAME}.sha256" | cut -d' ' -f1)
else
  echo "❌ Archive creation failed"
  exit 1
fi
echo ""

# Test 5: Generate release notes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Testing: generate-release-notes.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
COMMIT_SHA=$(git rev-parse HEAD)
if ./.github/scripts/release/generate-release-notes.sh "$VERSION" "$TAG" "$COMMIT_SHA" "$CHECKSUM" "$ARCHIVE_NAME"; then
  echo "✅ Release notes generation passed"
else
  echo "❌ Release notes generation failed"
  exit 1
fi
echo ""

# Test 6: Generate release summary (to stdout)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6️⃣  Testing: release-summary.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ./.github/scripts/release/release-summary.sh "$VERSION" "$TAG" "$COMMIT_SHA" "$CHECKSUM" "$ARCHIVE_NAME"; then
  echo ""
  echo "✅ Release summary generation passed"
else
  echo "❌ Release summary generation failed"
  exit 1
fi
echo ""

# Summary
echo "================================================="
echo "✅ All Tests Passed!"
echo "================================================="
echo ""
echo "📦 Generated files:"
echo "  - $ARCHIVE_NAME"
echo "  - ${ARCHIVE_NAME}.sha256"
echo "  - release_notes.md"
echo ""
echo "🧹 Cleanup (optional):"
echo "  rm $ARCHIVE_NAME ${ARCHIVE_NAME}.sha256 release_notes.md"
echo ""
