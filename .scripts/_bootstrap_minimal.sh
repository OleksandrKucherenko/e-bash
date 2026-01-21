#!/usr/bin/env bash
## Copyright (C) 2026-present, Oleksandr Kucherenko
## Minimal e-bash Bootstrap - Self-healing with minimal output
## Version: 1.0.0 | License: MIT
##
## Purpose: Automatically detect or install e-bash library silently
## Usage: source this file at the start of your script, then call ebash:bootstrap

# ============================================================================
# DETECTION - Find e-bash in standard locations
# ============================================================================

ebash:detect_location() {
  # Check E_BASH variable
  if [[ -n "${E_BASH:-}" ]] && [[ -f "$E_BASH/_dependencies.sh" ]]; then
    echo "$E_BASH"
    return 0
  fi

  # Check project-local
  local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$0}}"
  local project_local
  project_local=$(cd "${script_path%/*}/../.scripts" 2>/dev/null && pwd || echo "")

  if [[ -n "$project_local" ]] && [[ -f "$project_local/_dependencies.sh" ]]; then
    echo "$project_local"
    return 0
  fi

  # Check global
  local global_location="$HOME/.e-bash/.scripts"
  if [[ -f "$global_location/_dependencies.sh" ]]; then
    echo "$global_location"
    return 0
  fi

  return 1
}

# ============================================================================
# INSTALLATION - Install e-bash globally
# ============================================================================

ebash:install_globally() {
  local install_url="https://git.new/e-bash"
  local target_dir="$HOME/.e-bash/.scripts"

  # Check prerequisites
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl required for e-bash installation" >&2
    echo "Install: brew install curl  (macOS) or  sudo apt-get install curl  (Ubuntu)" >&2
    return 1
  fi

  # Notify user
  echo "→ Installing e-bash to $target_dir ..." >&2

  # Install
  if ! curl -sSL "$install_url" | bash -s -- --global install >/dev/null 2>&1; then
    echo "Error: Installation failed" >&2
    echo "Manual install: curl -sSL $install_url | bash -s -- --global install" >&2
    return 1
  fi

  # Verify
  if [[ ! -f "$target_dir/_dependencies.sh" ]]; then
    echo "Error: Installation verification failed" >&2
    return 1
  fi

  echo "✓ e-bash installed successfully" >&2

  echo "$target_dir"
  return 0
}

# ============================================================================
# ENVIRONMENT SETUP - Configure PATH and GNU tools
# ============================================================================

ebash:setup_environment() {
  local ebash_dir="$1"

  # Load GNU tools
  if [[ -f "$ebash_dir/_gnu.sh" ]]; then
    # shellcheck disable=SC1090
    source "$ebash_dir/_gnu.sh"
  fi

  # Add gnubin to PATH
  local gnubin_path
  gnubin_path=$(cd "$ebash_dir/../bin/gnubin" 2>/dev/null && pwd || echo "")

  if [[ -n "$gnubin_path" ]] && [[ -d "$gnubin_path" ]]; then
    PATH="$gnubin_path:$PATH"
    export PATH
  fi
}

# ============================================================================
# MAIN ORCHESTRATION
# ============================================================================

ebash:bootstrap() {
  # Detect existing installation
  local ebash_location
  ebash_location=$(ebash:detect_location)

  if [[ -n "$ebash_location" ]]; then
    # Found - use it silently
    E_BASH="$ebash_location"
    readonly E_BASH
    export E_BASH
    ebash:setup_environment "$E_BASH"
    return 0
  fi

  # Not found - install
  local installed_location
  if ! installed_location=$(ebash:install_globally); then
    exit 1
  fi

  # Configure
  E_BASH="$installed_location"
  readonly E_BASH
  export E_BASH
  ebash:setup_environment "$E_BASH"
  return 0
}

# Functions available for explicit invocation
