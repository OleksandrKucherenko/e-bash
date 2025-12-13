#!/usr/bin/env bash
# shellcheck disable=SC2207
#
# chunk-tests.sh - Divide test files into chunks for parallel execution
#
# Usage:
#   chunk-tests.sh <total_chunks> <chunk_index>
#
# Example:
#   chunk-tests.sh 4 0  # Returns test files for chunk 0 of 4
#   chunk-tests.sh 4 1  # Returns test files for chunk 1 of 4
#
# This script distributes test files across chunks using:
# 1. Optimal bin-packing based on historical timing data (if available)
# 2. Static weight-based distribution (fallback)
# 3. Simple alphabetical distribution (legacy fallback)
#
# Timing data is cached in .test-timings.json and generated from JUnit XML reports.

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse arguments
TOTAL_CHUNKS="${1:-4}"
CHUNK_INDEX="${2:-0}"

# Validate arguments
if ! [[ "$TOTAL_CHUNKS" =~ ^[0-9]+$ ]] || [ "$TOTAL_CHUNKS" -lt 1 ]; then
  echo "Error: total_chunks must be a positive integer" >&2
  exit 1
fi

if ! [[ "$CHUNK_INDEX" =~ ^[0-9]+$ ]] || [ "$CHUNK_INDEX" -ge "$TOTAL_CHUNKS" ]; then
  echo "Error: chunk_index must be between 0 and $((TOTAL_CHUNKS - 1))" >&2
  exit 1
fi

# Check for timing-based optimal distribution
TIMING_FILE="$PROJECT_ROOT/.test-timings.json"

if [ -f "$TIMING_FILE" ] && command -v bun >/dev/null 2>&1; then
  # Use optimal bin-packing algorithm with timing data
  if bun "$SCRIPT_DIR/calculate-optimal-chunks.ts" "$TIMING_FILE" "$TOTAL_CHUNKS" "$CHUNK_INDEX" 2>/dev/null; then
    # Success - optimal distribution used
    exit 0
  else
    # Fall through to fallback method
    echo "⚠️  Failed to use timing-based distribution, falling back to simple method" >&2
  fi
fi

# Find all test files
# We search in both spec/ and spec/bin/ directories
TEST_FILES=()
while IFS= read -r -d '' file; do
  TEST_FILES+=("$file")
done < <(find "$PROJECT_ROOT/spec" -name "*_spec.sh" -type f -print0)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
  echo "Error: No test files found in $PROJECT_ROOT/spec" >&2
  exit 1
fi

# Sort the array (portable - works on both macOS and Linux)
# Using bash's built-in sorting via process substitution
IFS=$'\n' TEST_FILES=($(sort <<<"${TEST_FILES[*]}"))

# Calculate chunk size
TOTAL_FILES=${#TEST_FILES[@]}
FILES_PER_CHUNK=$(((TOTAL_FILES + TOTAL_CHUNKS - 1) / TOTAL_CHUNKS))

# Calculate start and end indices for this chunk
START_INDEX=$((CHUNK_INDEX * FILES_PER_CHUNK))
END_INDEX=$((START_INDEX + FILES_PER_CHUNK))

# Ensure we don't exceed array bounds
if [ $START_INDEX -ge $TOTAL_FILES ]; then
  # This chunk has no files
  exit 0
fi

if [ $END_INDEX -gt $TOTAL_FILES ]; then
  END_INDEX=$TOTAL_FILES
fi

# Output the test files for this chunk (relative to project root)
for ((i = START_INDEX; i < END_INDEX; i++)); do
  # Convert absolute path to relative path
  relative_path="${TEST_FILES[$i]#$PROJECT_ROOT/}"
  echo "$relative_path"
done
