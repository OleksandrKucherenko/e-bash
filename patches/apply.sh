#!/usr/bin/env bash
# Apply ShellSpec timeout patch (Ubuntu/Linux)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-19
## Version: 2.0.4
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/shellspec-0.28.1-to-0.29.0-timeout.patch"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# 1. Verify Patch File Exists
if [[ ! -f "$PATCH_FILE" ]]; then
  log_error "Patch file not found: $PATCH_FILE"
  exit 1
fi

# 2. Find ShellSpec Directory
# 2. Find ShellSpec Directory
find_shellspec_dir() {
  local shellspec_bin
  if ! shellspec_bin="$(command -v shellspec 2>/dev/null)"; then
    log_error "ShellSpec not found in PATH"
    return 1
  fi

  # Resolve symlink to find the actual binary location
  local resolved_bin="$shellspec_bin"
  if [[ -L "$shellspec_bin" ]]; then
       local resolved="$(readlink "$shellspec_bin")"
       local bin_dir="$(dirname "$shellspec_bin")"
       # Handle relative link
       if [[ "$resolved" != /* ]]; then
          resolved="$(cd "$bin_dir" && pwd)/$resolved"
       fi
       # Recursively resolve
       while [[ -L "$resolved" ]]; do
          local link_dir="$(dirname "$resolved")"
          resolved="$(readlink "$resolved")"
          if [[ "$resolved" != /* ]]; then
              resolved="$link_dir/$resolved"
          fi
       done
       resolved_bin="$resolved"
  fi

  local bin_dir
  bin_dir="$(cd "$(dirname "$resolved_bin")" && pwd)"

  # Candidate #1: the directory that already contains shellspec
  if [[ -f "$bin_dir/lib/core/core.sh" ]]; then
      echo "$bin_dir"
      return 0
  fi

  # Candidate #2: parent of bin/shellspec style installs
  local parent_dir
  parent_dir="$(cd "$bin_dir/.." && pwd)"
  if [[ -f "$parent_dir/lib/core/core.sh" ]]; then
      echo "$parent_dir"
      return 0
  elif [[ -f "$parent_dir/lib/shellspec/lib/core/core.sh" ]]; then
      echo "$parent_dir/lib/shellspec"
      return 0
  fi

  # Fallback to the directory that owns the binary.
  echo "$bin_dir"
}

if ! SHELLSPEC_DIR="$(find_shellspec_dir)"; then
  log_error "Could not determine ShellSpec installation directory."
  exit 1
fi

if [[ ! -f "$SHELLSPEC_DIR/lib/core/core.sh" ]]; then
  log_error "ShellSpec core not found under $SHELLSPEC_DIR"
  exit 1
fi

log_info "ShellSpec Dir: $SHELLSPEC_DIR"

# 3. Check if already patched
MARKER_FILE="$SHELLSPEC_DIR/.patched-timeout"
if [[ -f "$MARKER_FILE" ]]; then
  exit 0
fi

if "$SHELLSPEC_DIR/shellspec" --help 2>/dev/null | grep -q -- '--timeout'; then
  touch "$MARKER_FILE"
  exit 0
fi

# 4. Apply Patch
log_step "Applying timeout patch..."
cd "$SHELLSPEC_DIR"

if ! command -v patch >/dev/null 2>&1; then
    log_error "patch command not found"
    exit 1
fi

# Apply patch
# Apply patch (tolerant of partials)
PATCH_OPTS=(--batch --forward -p1 -N)
log_info "Checking patch applicability..."
if ! patch "${PATCH_OPTS[@]}" --dry-run -i "$PATCH_FILE" >/dev/null; then
    log_error "Patch dry-run failed. Please ensure ShellSpec sources match 0.28.1"
    exit 1
fi

log_info "Applying patch..."
patch "${PATCH_OPTS[@]}" -i "$PATCH_FILE"

# 5. Handle bin/shellspec.rej (Harmless)
if [[ -f "bin/shellspec.rej" ]]; then
    log_info "Removing harmless bin/shellspec.rej..."
    rm "bin/shellspec.rej"
fi

# 5. Verify patch was applied
log_step "Verifying patch..."

# Functional verification: Create a test that times out
TEST_FILE="$SHELLSPEC_DIR/timeout_verification_spec.sh"
cat <<'EOF' > "$TEST_FILE"
Describe "timeout verification"
  Example "should timeout in 1 second" % timeout:1
    sleep 2
    The status should equal 0
  End
End
EOF

# Run the test and measure duration
START_TIME=$(date +%s)
"$SHELLSPEC_DIR/shellspec" "$TEST_FILE" >/dev/null 2>&1 || true
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Cleanup test file
rm -f "$TEST_FILE"

# If timeout is working, test should abort before 2 seconds
if [[ $DURATION -lt 2 ]]; then
    VERSION="$("$SHELLSPEC_DIR/shellspec" --version)"
    log_info "Success! Timeout feature verified (Duration: ${DURATION}s). Version: $VERSION"
    touch "$MARKER_FILE"
    exit 0
else
    log_error "Verification failed. Test did not timeout (Duration: ${DURATION}s)."
    log_error "Expected duration < 2s, which would indicate timeout feature is working."
    exit 1
fi
