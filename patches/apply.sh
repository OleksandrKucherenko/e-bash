#!/usr/bin/env bash
# Apply ShellSpec timeout patch from the patches/ directory
#
# This script applies the timeout feature patch to the local ShellSpec installation.
# The timeout feature adds support for:
#   --timeout SECONDS    Set global timeout for tests
#   --no-timeout         Disable timeout
#   %timeout:N           Per-test timeout override
#
# Usage: ./patches/apply.sh
#
# Environment Variables:
#   SHELLSPEC_INSTALL_DIR  Override auto-detection (useful for non-standard installs)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.17.8
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/shellspec-timeout.patch"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_step() {
  echo -e "${BLUE}[STEP]${NC} $*"
}

# Check if patch file exists
if [[ ! -f "$PATCH_FILE" ]]; then
  log_error "Patch file not found: $PATCH_FILE"
  log_info "Current directory: $(pwd)"
  exit 1
fi

# Function to find ShellSpec installation directory
find_shellspec_dir() {
  local shellspec_bin

  # If override is set, use it
  if [[ -n "${SHELLSPEC_INSTALL_DIR:-}" ]]; then
    if [[ -d "$SHELLSPEC_INSTALL_DIR" ]]; then
      echo "$SHELLSPEC_INSTALL_DIR"
      return 0
    else
      log_error "SHELLSPEC_INSTALL_DIR is set but directory not found: $SHELLSPEC_INSTALL_DIR"
      return 1
    fi
  fi

  # Find shellspec binary
  if ! shellspec_bin="$(command -v shellspec 2>/dev/null)"; then
    log_error "ShellSpec is not installed or not in PATH"
    log_info "Install it with: brew install shellspec" >&2
    log_info "              or: mise use -g shellspec" >&2
    return 1
  fi

  log_info "Found shellspec at: $shellspec_bin" >&2

  # Resolve the installation directory
  local install_dir
  install_dir="$(dirname "$shellspec_bin")"

  # If shellspec is a symlink, resolve it
  if [[ -L "$shellspec_bin" ]]; then
    local resolved_link
    resolved_link="$(readlink "$shellspec_bin")"

    # Handle relative symlinks
    if [[ "$resolved_link" != /* ]]; then
      resolved_link="$(cd "$install_dir" && pwd)/$resolved_link"
    fi

    # Resolve again if it's another symlink (mise version directories are symlinks)
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

  # Make sure we have the actual installation root
  log_info "Candidate install dir: $install_dir" >&2
  ls -F "$install_dir" | sed 's/^/  /' >&2
  
  # Look for characteristic ShellSpec files/directories
  # Strict check: Require 'shellspec' AND 'lib' directory (avoids matching bin/ subdirectory)
  if [[ -f "$install_dir/shellspec" ]] && [[ -d "$install_dir/lib" ]]; then
    log_info "Detected standard structure at: $install_dir" >&2
    echo "$install_dir"
    return 0
  fi

  # Fallback: check for internal script location
  if [[ -f "$install_dir/lib/libexec/runner.sh" ]]; then
    log_info "Detected runner.sh at: $install_dir" >&2
    echo "$install_dir"
    return 0
  fi

  # Try going up one level (for mise-style installations)
  if [[ -d "$install_dir/lib/libexec" ]]; then
    log_info "Detected lib/libexec at: $install_dir" >&2
    echo "$install_dir"
    return 0
  fi

  # Handle Homebrew Cellar structure where symlink points to bin/shellspec
  # but the actual root is one level up (contains lib/, libexec/, shellspec)
  local parent_dir
  parent_dir="$(dirname "$install_dir")"
  log_info "Checking parent directory: $parent_dir" >&2
  ls -F "$parent_dir" | sed 's/^/  /' >&2

  # Check for standard 'make install' structure (Homebrew uses this)
  # Prefix/lib/shellspec/ contains the actual installation
  if [[ -d "$parent_dir/lib/shellspec" ]]; then
      log_info "Detected lib/shellspec subdirectory checking that..." >&2
      if [[ -f "$parent_dir/lib/shellspec/shellspec" ]]; then
         log_info "Detected real Homebrew root at: $parent_dir/lib/shellspec" >&2
         echo "$parent_dir/lib/shellspec"
         return 0
      fi
  fi

  if [[ -d "$parent_dir/lib" ]] && { [[ -f "$parent_dir/shellspec" ]] || [[ -f "$parent_dir/bin/shellspec" ]]; }; then
    log_info "Detected Homebrew-style structure at: $parent_dir" >&2
    echo "$parent_dir"
    return 0
  fi

  # Check for mise-specific structure
  local mise_base="$install_dir"
  while [[ "$mise_base" != "/" ]] && [[ ! -d "$mise_base/lib/libexec" ]]; do
    mise_base="$(dirname "$mise_base")"
  done

  if [[ -d "$mise_base/lib/libexec" ]]; then
    log_info "Detected Mise-style structure at: $mise_base" >&2
    echo "$mise_base"
    return 0
  fi

  log_error "Could not determine ShellSpec installation directory from: $shellspec_bin"
  log_info "You can override with: SHELLSPEC_INSTALL_DIR=/path/to/shellspec ./patches/apply.sh" >&2
  return 1
}

# Find the installation directory
if ! SHELLSPEC_DIR="$(find_shellspec_dir)"; then
  exit 1
fi

log_info "ShellSpec installation directory: $SHELLSPEC_DIR"
log_info "Directory contents:"
ls -F "$SHELLSPEC_DIR" | sed 's/^/  /' >&2



# Marker file location (in the installation directory itself)
MARKER_FILE="$SHELLSPEC_DIR/.patched-timeout"

# Locate shellspec binary
SHELLSPEC_BIN="$SHELLSPEC_DIR/shellspec"
if [[ ! -f "$SHELLSPEC_BIN" ]] && [[ -f "$SHELLSPEC_DIR/bin/shellspec" ]]; then
  SHELLSPEC_BIN="$SHELLSPEC_DIR/bin/shellspec"
fi

# Check if patch is already applied
if [[ -f "$MARKER_FILE" ]]; then
  log_info "Patch appears to be already applied (marker file exists)"
  log_info "Marker file: $MARKER_FILE"
  log_info "To re-apply, remove the marker file: rm '$MARKER_FILE'"
  exit 0
fi

# Check if patch is already applied by looking for --timeout option
if "$SHELLSPEC_BIN" --help 2>/dev/null | grep -q -- '--timeout'; then
  log_info "Patch appears to be already applied (--timeout option found in help)"
  touch "$MARKER_FILE"
  log_info "Created marker file: $MARKER_FILE"
  exit 0
fi

# Check if patch tool is available
if ! command -v patch >/dev/null 2>&1; then
  log_error "patch command is not available"
  log_info "Install it with: brew install patch  # macOS"
  log_info "              or: sudo apt-get install patch  # Ubuntu/Debian"
  exit 1
fi

# Create backup
BACKUP_DIR="$HOME/.shellspec-backup-$(date +%Y%m%d_%H%M%S)"
log_step "Creating backup at: $BACKUP_DIR"
cp -r "$SHELLSPEC_DIR" "$BACKUP_DIR"

# Apply the patch
log_step "Applying timeout patch..."
cd "$SHELLSPEC_DIR"

# Clean up any .rej/.orig files from previous attempts
find "$SHELLSPEC_DIR" -name "*.rej" -delete 2>/dev/null || true
find "$SHELLSPEC_DIR" -name "*.orig" -delete 2>/dev/null || true

# Handle Homebrew layout where shellspec is in bin/ but not in root
# Copy it to root so patch can modify it (symlinks can cause issues with patch)
RESTORE_BIN_SHELLSPEC=0
if [[ ! -f "shellspec" ]] && [[ -f "bin/shellspec" ]]; then
  log_info "Homebrew layout detected: copying bin/shellspec to ./shellspec for patching"
  cp "bin/shellspec" "shellspec"
  RESTORE_BIN_SHELLSPEC=1
fi

# Dry run first
if patch -p1 --dry-run -N < "$PATCH_FILE" >/dev/null 2>&1; then
  if patch -p1 -N < "$PATCH_FILE"; then
    # Sync back to bin/shellspec if needed
    if [[ "$RESTORE_BIN_SHELLSPEC" -eq 1 ]]; then
      log_info "Updating bin/shellspec with patched version..."
      cp "shellspec" "bin/shellspec"
      chmod +x "bin/shellspec"
    fi
    
    # Create marker file
    touch "$MARKER_FILE"
    log_info "✓ Patch applied successfully!"
    log_info "Backup saved at: $BACKUP_DIR"
    log_info ""
    log_info "To verify, run:"
    log_info "  shellspec --help | grep -A 3 timeout"
    log_info ""
    log_info "To rollback if needed:"
    log_info "  rm -rf '$SHELLSPEC_DIR'"
    log_info "  mv '$BACKUP_DIR' '$SHELLSPEC_DIR'"
  else
    log_error "Failed to apply patch"
    log_info "Restoring from backup..."
    rm -rf "$SHELLSPEC_DIR"
    mv "$BACKUP_DIR" "$SHELLSPEC_DIR"
    exit 1
  fi
else
  log_warn "Patch cannot be applied cleanly (dry-run failed)"
  log_info "This may mean:"
  log_info "  1. The patch is already applied"
  log_info "  2. Your ShellSpec version is incompatible with this patch"
  log_info "  3. ShellSpec has been modified"
  log_info ""
  log_info "Applying with --force (some rejections are expected)..."

  # Apply with --force, ignoring exit code since some files (docs, CLAUDE.md)
  # won't exist in vanilla ShellSpec and that's expected
  patch -p1 -N -f < "$PATCH_FILE" 2>&1 | tee "/tmp/shellspec-patch.log" || true
  
  # Sync back to bin/shellspec if needed (even for forced patch)
  if [[ "$RESTORE_BIN_SHELLSPEC" -eq 1 ]]; then
    log_info "Updating bin/shellspec with patched version..."
    cp "shellspec" "bin/shellspec"
    chmod +x "bin/shellspec"
  fi
  
  log_info ""
  log_info "Patch application completed (some rejections are expected)"
  log_info "Verifying timeout feature is functional..."
  
  # Verify the critical files were patched by checking if --timeout works
  if "$SHELLSPEC_BIN" --help 2>/dev/null | grep -q -- '--timeout'; then
    touch "$MARKER_FILE"
    log_info ""
    log_info "✓ Timeout feature verified working!"
    log_info "Backup saved at: $BACKUP_DIR"
    log_info ""
    log_info "NOTE: Some hunks may have failed - this is expected for documentation"
    log_info "      files (CLAUDE.md, docs/, etc.) that don't exist in vanilla ShellSpec."
  else
    log_error "Timeout feature not working after patch"
    log_info "Restoring from backup..."
    rm -rf "$SHELLSPEC_DIR"
    mv "$BACKUP_DIR" "$SHELLSPEC_DIR"
    log_info "Check /tmp/shellspec-patch.log for details"
    exit 1
  fi
fi

log_info ""
log_info "Done!"
