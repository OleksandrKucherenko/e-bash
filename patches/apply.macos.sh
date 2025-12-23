#!/usr/bin/env bash
# Apply ShellSpec timeout patch (macOS)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/shellspec-0.28.1-to-0.29.0-timeout.patch"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# 2. Find ShellSpec Dir (macOS/Homebrew specific)
# 2. Find ShellSpec Dir (macOS/Homebrew specific)
find_shellspec_dir() {
    local shellspec_bin
    if ! shellspec_bin="$(command -v shellspec)"; then
        log_error "ShellSpec not found"
        return 1
    fi
    
    # Resolve symlink to find the actual binary location
    local resolved_bin="$shellspec_bin"
    if [[ -L "$shellspec_bin" ]]; then
         local resolved
         resolved="$(readlink "$shellspec_bin")"
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
    
    # We have the absolute path to bin/shellspec. 
    # The installation root relative to 'bin' is usually one level up.
    local install_root
    install_root="$(cd "$(dirname "$resolved_bin")/.." && pwd)"
    
    # Heuristic: Check where lib/core/core.sh lives relative to this root.
    # 1. Standard: $ROOT/lib/core/core.sh
    # 2. Homebrew: $ROOT/lib/shellspec/lib/core/core.sh -> We want $ROOT/lib/shellspec as the patch root.
    
    if [[ -f "$install_root/lib/core/core.sh" ]]; then
        echo "$install_root"
        return 0
    elif [[ -f "$install_root/lib/shellspec/lib/core/core.sh" ]]; then
        echo "$install_root/lib/shellspec"
        return 0
    fi
    
    # Fallback: Just return install_root and hope
    echo "$install_root" 
}

if ! SHELLSPEC_DIR="$(find_shellspec_dir)"; then
    log_error "Could not find ShellSpec dir"
    exit 1
fi

log_info "ShellSpec Dir: $SHELLSPEC_DIR"

# 3. Check Marker
MARKER_FILE="$SHELLSPEC_DIR/.patched-timeout"
if [[ -f "$MARKER_FILE" ]]; then
  exit 0
fi

if "$SHELLSPEC_DIR/shellspec" --help 2>/dev/null | grep -q -- '--timeout'; then
  touch "$MARKER_FILE"
  exit 0
fi

# 4. Apply Patch
log_step "Applying patch..."
cd "$SHELLSPEC_DIR"

if ! command -v patch >/dev/null 2>&1; then
    log_error "patch command missing"
    exit 1
fi

log_info "Applying patch (ignoring partial errors)..."
patch -p1 -N < "$PATCH_FILE" || true

# 5. Handle bin/shellspec.rej
if [[ -f "bin/shellspec.rej" ]]; then
    rm "bin/shellspec.rej"
fi

# 6. Verify (Functional)
log_step "Verifying..."

# Create a temporary test file
TEST_FILE="$SHELLSPEC_DIR/timeout_verification_spec.sh"
cat <<EOF > "$TEST_FILE"
Example "timeout test" % timeout:1
  sleep 2
  The status should equal 0
End
EOF

START_TIME=$(date +%s)
"$SHELLSPEC_DIR/shellspec" "$TEST_FILE" >/dev/null 2>&1 || true
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
rm "$TEST_FILE"

if [[ $DURATION -lt 2 ]]; then
     VERSION="$("$SHELLSPEC_DIR/shellspec" --version)"
     log_info "Success! Timeout functional. Version: $VERSION"
     touch "$MARKER_FILE"
     exit 0
else 
     log_error "Verification failed (Duration: ${DURATION}s)."
     exit 1
fi


