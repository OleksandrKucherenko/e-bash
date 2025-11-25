#!/usr/bin/env bash
# Verifies required files and directories exist for distribution
# Usage: verify-contents.sh

set -euo pipefail

echo "🔍 Verifying distribution contents..."

# Required directories
REQUIRED_DIRS=(.scripts bin docs demos)

# Required files
REQUIRED_FILES=(README.md LICENSE)

EXIT_CODE=0

# Check directories
for dir in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "❌ ERROR: Directory $dir not found"
    EXIT_CODE=1
  else
    echo "✅ Directory: $dir"
  fi
done

# Check files
for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "❌ ERROR: File $file not found"
    EXIT_CODE=1
  else
    echo "✅ File: $file"
  fi
done

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "❌ Distribution verification failed"
  exit 1
fi

echo ""
echo "✅ All required files and directories present"
