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
find_shellspec_dir() {
    # Try brew --prefix first
    if command -v brew >/dev/null 2>&1; then
        if brew list shellspec >/dev/null 2>&1; then
             local brew_prefix
             brew_prefix="$(brew --prefix shellspec)"
             # In Homebrew, the actual files are in libenv/ or similar? 
             # Actually brew --prefix points to /opt/homebrew/opt/shellspecUsually,
             # which is a symlink to celler.
             # But shellspec installs into lib/shellspec in some versions.
             # best is to follow the bin/shellspec
             true 
        fi
    fi
    
    local shellspec_bin
    if ! shellspec_bin="$(command -v shellspec)"; then
        log_error "ShellSpec no found"
        return 1
    fi
    
    # Resolve symlink
    local install_dir
    install_dir="$(dirname "$shellspec_bin")"
    if [[ -L "$shellspec_bin" ]]; then
         local resolved
         resolved="$(readlink "$shellspec_bin")"
         # Handle relative link
         if [[ "$resolved" != /* ]]; then
            resolved="$(cd "$install_dir" && pwd)/$resolved"
         fi
         # Recursively resolve
         while [[ -L "$resolved" ]]; do
            local link_dir
            link_dir="$(dirname "$resolved")"
            resolved="$(readlink "$resolved")"
            if [[ "$resolved" != /* ]]; then
                resolved="$link_dir/$resolved"
            fi
        done
        install_dir="$(dirname "$resolved")"
    fi
    
    echo "$install_dir"
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

# 6. Verify
log_step "Verifying..."
if "$SHELLSPEC_DIR/shellspec" --help | grep -q timeout; then
    VERSION="$("$SHELLSPEC_DIR/shellspec" --version)"
    log_info "Success! Version: $VERSION"
    touch "$MARKER_FILE"
    exit 0
else
    log_warn "clean patch failed. Attempting force apply..."
    if patch -p1 -N -f < "$PATCH_FILE"; then
         log_info "Patch applied with force."
    else
         log_warn "Force patch returned errors."
    fi
    
    if "$SHELLSPEC_DIR/shellspec" --help | grep -q timeout; then
        VERSION="$("$SHELLSPEC_DIR/shellspec" --version)"
        log_info "Success! Version: $VERSION"
        touch "$MARKER_FILE"
        exit 0
    else
        log_error "Verification failed"
        exit 1
    fi
fi

# 5. Handle bin/shellspec.rej
if [[ -f "bin/shellspec.rej" ]]; then
    rm "bin/shellspec.rej"
fi

# 6. Verify
log_step "Verifying..."
if "$SHELLSPEC_DIR/shellspec" --help | grep -q timeout; then
    VERSION="$("$SHELLSPEC_DIR/shellspec" --version)"
    log_info "Success! Version: $VERSION"
    touch "$MARKER_FILE"
    exit 0
else
    log_error "Verification failed"
    exit 1
fi
