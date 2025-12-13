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
# This script distributes test files evenly across chunks, attempting to
# balance the load by considering the size/complexity of each test file.

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

# Find all test files
# We search in both spec/ and spec/bin/ directories
TEST_FILES=()
while IFS= read -r -d '' file; do
  TEST_FILES+=("$file")
done < <(find "$PROJECT_ROOT/spec" -name "*_spec.sh" -type f -print0 | sort -z)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
  echo "Error: No test files found in $PROJECT_ROOT/spec" >&2
  exit 1
fi

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
