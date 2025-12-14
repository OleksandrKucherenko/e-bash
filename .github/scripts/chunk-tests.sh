#!/usr/bin/env bash
# shellcheck disable=SC2207
#
# chunk-tests.sh - Divide test files into chunks for parallel execution
#
# Usage:
#   chunk-tests.sh <total_chunks> <chunk_index> [--granularity=file|example|hybrid]
#
# Example:
#   chunk-tests.sh 4 0                     # Returns test files for chunk 0 of 4 (file granularity)
#   chunk-tests.sh 4 1 --granularity=file  # Explicit file granularity
#   chunk-tests.sh 4 2 --granularity=example  # Per-example distribution
#   chunk-tests.sh 4 3 --granularity=hybrid   # Auto-split large files
#
# Granularity options:
#   file (default): Distribute whole spec files
#   example:        Distribute individual examples (requires v2.0 timing data)
#   hybrid:         Auto-split large files into examples when beneficial
#
# This script distributes test files across chunks using:
# 1. Optimal bin-packing based on historical timing data (if available)
# 2. Static weight-based distribution (fallback)
# 3. Simple alphabetical distribution (legacy fallback)
#
# Timing data is cached in .test-timings.json and generated from JUnit XML reports.

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Parse arguments
TOTAL_CHUNKS="${1:-4}"
CHUNK_INDEX="${2:-0}"
GRANULARITY=""

# Parse optional arguments
shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --granularity=*)
      GRANULARITY="${1#*=}"
      shift
      ;;
    *)
      echo "Warning: Unknown argument: $1" >&2
      shift
      ;;
  esac
done

# Validate arguments
if ! [[ "$TOTAL_CHUNKS" =~ ^[0-9]+$ ]] || [ "$TOTAL_CHUNKS" -lt 1 ]; then
  echo "Error: total_chunks must be a positive integer" >&2
  exit 1
fi

if ! [[ "$CHUNK_INDEX" =~ ^[0-9]+$ ]] || [ "$CHUNK_INDEX" -ge "$TOTAL_CHUNKS" ]; then
  echo "Error: chunk_index must be between 0 and $((TOTAL_CHUNKS - 1))" >&2
  exit 1
fi

# Validate granularity
if [ -n "$GRANULARITY" ] && [[ ! "$GRANULARITY" =~ ^(file|example|hybrid)$ ]]; then
  echo "Warning: Invalid granularity '$GRANULARITY', using 'file'" >&2
  GRANULARITY="file"
fi

# Build granularity argument if specified
GRANULARITY_ARG=""
if [ -n "$GRANULARITY" ]; then
  GRANULARITY_ARG="--granularity=$GRANULARITY"
fi

# Check for timing-based optimal distribution
DEFAULT_TIMING_FILE="$PROJECT_ROOT/.test-timings.json"
TIMING_FILE="$DEFAULT_TIMING_FILE"
JUNIT_SCRIPT_DIR="$SCRIPT_DIR/junit"

detect_ci_os_slug() {
  local os="${RUNNER_OS:-}"

  if [ -z "$os" ]; then
    case "$(uname -s 2>/dev/null || true)" in
      Darwin) os="macOS" ;;
      Linux) os="Linux" ;;
      *) os="" ;;
    esac
  fi

  case "$os" in
    Linux) echo "linux" ;;
    macOS) echo "macos" ;;
    *) echo "" ;;
  esac
}

# Prefer a committed baseline timing file when present.
# Override via E_BASH_TIMING_FILE (absolute or repo-relative path).
if [ -n "${E_BASH_TIMING_FILE:-}" ]; then
  if [[ "$E_BASH_TIMING_FILE" = /* ]]; then
    if [ -f "$E_BASH_TIMING_FILE" ]; then
      TIMING_FILE="$E_BASH_TIMING_FILE"
    fi
  else
    if [ -f "$PROJECT_ROOT/$E_BASH_TIMING_FILE" ]; then
      TIMING_FILE="$PROJECT_ROOT/$E_BASH_TIMING_FILE"
    fi
  fi
else
  OS_SLUG="$(detect_ci_os_slug)"
  BASELINE_TIMING_FILE="$PROJECT_ROOT/ci/test-timings/${OS_SLUG}/test-timings.json"
  if [ -n "$OS_SLUG" ] && [ -f "$BASELINE_TIMING_FILE" ]; then
    TIMING_FILE="$BASELINE_TIMING_FILE"
  fi
fi

if [ -f "$TIMING_FILE" ] && command -v bun >/dev/null 2>&1 && [ -f "$JUNIT_SCRIPT_DIR/calculate-optimal-chunks.ts" ]; then
  # Use optimal bin-packing algorithm with timing data
  if [[ "$TIMING_FILE" = "$PROJECT_ROOT/"* ]]; then
    echo "📈 Timing source: ${TIMING_FILE#$PROJECT_ROOT/}" >&2
  else
    echo "📈 Timing source: $TIMING_FILE" >&2
  fi
  if bun "$JUNIT_SCRIPT_DIR/calculate-optimal-chunks.ts" "$TIMING_FILE" "$TOTAL_CHUNKS" "$CHUNK_INDEX" $GRANULARITY_ARG; then
    # Success - optimal distribution used
    exit 0
  else
    # Fall through to fallback method
    echo "⚠️  Failed to use timing-based distribution, falling back to simple method" >&2
  fi
fi

# Fallback: Simple alphabetical distribution (file-level only)
if [ -n "$GRANULARITY" ] && [ "$GRANULARITY" != "file" ]; then
  echo "⚠️  Fallback mode only supports file granularity, ignoring '$GRANULARITY'" >&2
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
