#!/usr/bin/env bash
# Apply ShellSpec timeout patch (Ubuntu/Linux)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.17.9
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
find_shellspec_dir() {
  local shellspec_bin
  if ! shellspec_bin="$(command -v shellspec 2>/dev/null)"; then
    log_error "ShellSpec not found in PATH"
    return 1
  fi
  
  local install_dir
  install_dir="$(dirname "$shellspec_bin")"
  
  # Resolve symlinks
  if [[ -L "$shellspec_bin" ]]; then
    local resolved_link
    resolved_link="$(readlink "$shellspec_bin")"
    if [[ "$resolved_link" != /* ]]; then
      resolved_link="$(cd "$install_dir" && pwd)/$resolved_link"
    fi
     while [[ -L "$resolved_link" ]]; do
       local link_dir
       link_dir="$(dirname "$resolved_link")"
       resolved_link="$(readlink "$resolved_link")"
       if [[ "$resolved_link" != /* ]]; then
         resolved_link="$link_dir/$resolved_link"
       fi
     done
     install_dir="$(dirname "$resolved_link")"
  fi
  
  # Check for some known file to be sure (ShellSpec root usually has 'lib' and 'shellspec')
  if [[ -f "$install_dir/shellspec" ]] && [[ -d "$install_dir/lib" ]]; then
      echo "$install_dir"
      return 0
  fi
  
  # Handle Homebrew-style layout where we might have landed in bin/ and need to go up?
  # Usually resolving symlinks takes us to the real root.
  # Let's trust the resolved path for now or check parent if we ended up in bin
  local parent_dir
  parent_dir="$(dirname "$install_dir")"
  if [[ -f "$parent_dir/shellspec" ]] && [[ -d "$parent_dir/lib" ]]; then
       echo "$parent_dir"
       return 0
  fi
  
  # If we are here, we might be in the root already if we didn't have symlinks?
  echo "$install_dir"
}

if ! SHELLSPEC_DIR="$(find_shellspec_dir)"; then
  log_error "Could not determine ShellSpec installation directory."
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
log_info "Applying patch (ignoring partial errors)..."
patch -p1 -N < "$PATCH_FILE" || true

# 5. Handle bin/shellspec.rej (Harmless)
if [[ -f "bin/shellspec.rej" ]]; then
    log_info "Removing harmless bin/shellspec.rej..."
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
    # Verification failed, try force as last resort
    log_warn "Standard patch didn't result in working timeout. Trying force apply..."
    if patch -p1 -N -f < "$PATCH_FILE"; then 
         log_info "Forced patch applied."
    else
         log_warn "Forced patch returned errors (expected if partial)."
    fi
    
    if "$SHELLSPEC_DIR/shellspec" --help | grep -q timeout; then
        VERSION="$("$SHELLSPEC_DIR/shellspec" --version)"
        log_info "Success (after force)! Version: $VERSION"
        touch "$MARKER_FILE"
        exit 0
    else
        log_error "Verification failed even after force apply."
        exit 1
    fi
fi

# 5. Handle bin/shellspec.rej (Harmless)
if [[ -f "bin/shellspec.rej" ]]; then
    log_info "Removing harmless bin/shellspec.rej..."
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
    log_error "Verification failed."
    exit 1
fi
