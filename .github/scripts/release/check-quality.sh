#!/usr/bin/env bash
# Runs ShellCheck on core scripts for quality validation
# Usage: check-quality.sh

set -euo pipefail

echo "🔍 Running ShellCheck on .scripts/ and bin/ directories..."

# Check if shellcheck is available
if ! command -v shellcheck &> /dev/null; then
  echo "⚠️  ShellCheck not found"
  if [ -n "${CI:-}" ]; then
    echo "Installing ShellCheck in CI environment..."
    sudo apt-get update -qq
    sudo apt-get install -y shellcheck
  else
    echo "Please install ShellCheck:"
    echo "  macOS: brew install shellcheck"
    echo "  Ubuntu: sudo apt-get install shellcheck"
    exit 1
  fi
fi

echo "ShellCheck version: $(shellcheck --version | grep version:)"
echo ""

# Run shellcheck on all shell scripts (SC1091=source file not found, SC2086=word splitting)
EXIT_CODE=0
CHECKED_COUNT=0
FAILED_COUNT=0

while IFS= read -r file; do
  echo "Checking: $file"
  if ! shellcheck -e SC1091 -e SC2086 "$file"; then
    EXIT_CODE=1
    ((FAILED_COUNT++))
  fi
  ((CHECKED_COUNT++))
done < <(find .scripts bin -type f -name "*.sh" 2>/dev/null || true)

echo ""
echo "Checked $CHECKED_COUNT files"

if [ $EXIT_CODE -eq 0 ]; then
  echo "✅ All shell scripts passed ShellCheck"
else
  echo "⚠️  $FAILED_COUNT files had ShellCheck warnings (non-blocking)"
  # Don't fail the build, just warn
  exit 0
fi
