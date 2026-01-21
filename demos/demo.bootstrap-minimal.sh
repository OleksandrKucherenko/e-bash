#!/usr/bin/env bash
## Copyright (C) 2026-present, Oleksandr Kucherenko
## Minimal Bootstrap Demo - Copy-paste this entire function into your scripts
## Version: 1.0.0 | License: MIT

# ============================================================================
# COPY-PASTE SECTION START - Minimal Bootstrap
# ============================================================================
# This is a standalone, self-contained bootstrap function with minimal output.
# Perfect for production scripts where you want clean, quiet operation.
# ============================================================================

function ebash:bootstrap() {
  local ebash_location=""

  # Check E_BASH variable
  if [[ -n "${E_BASH:-}" ]] && [[ -f "$E_BASH/_dependencies.sh" ]]; then
    ebash_location="$E_BASH"
  fi

  # Check project-local
  if [[ -z "$ebash_location" ]]; then
    local script_path="${BASH_SOURCE[0]:-$0}"
    local project_local
    project_local=$(cd "${script_path%/*}/../.scripts" 2>/dev/null && pwd || echo "")

    if [[ -n "$project_local" ]] && [[ -f "$project_local/_dependencies.sh" ]]; then
      ebash_location="$project_local"
    fi
  fi

  # Check global
  if [[ -z "$ebash_location" ]]; then
    local global_location="$HOME/.e-bash/.scripts"
    if [[ -f "$global_location/_dependencies.sh" ]]; then
      ebash_location="$global_location"
    fi
  fi

  # Found - use it
  if [[ -n "$ebash_location" ]]; then
    E_BASH="$ebash_location"
    readonly E_BASH
    export E_BASH

    # Setup environment
    if [[ -f "$E_BASH/_gnu.sh" ]]; then
      # shellcheck disable=SC1091
      source "$E_BASH/_gnu.sh"
    fi

    local gnubin_path
    gnubin_path=$(cd "$E_BASH/../bin/gnubin" 2>/dev/null && pwd || echo "")
    if [[ -n "$gnubin_path" ]] && [[ -d "$gnubin_path" ]]; then
      PATH="$gnubin_path:$PATH"
      export PATH
    fi

    return 0
  fi

  # Not found - install
  if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl required" >&2
    echo "Install: brew install curl (macOS) or sudo apt-get install curl (Ubuntu)" >&2
    exit 1
  fi

  local install_url="https://git.new/e-bash"
  local target_dir="$HOME/.e-bash/.scripts"

  echo "→ Installing e-bash..." >&2

  if ! curl -sSL "$install_url" | bash -s -- --global install >/dev/null 2>&1; then
    echo "Error: Installation failed" >&2
    echo "Manual: curl -sSL $install_url | bash -s -- --global install" >&2
    exit 1
  fi

  if [[ ! -f "$target_dir/_dependencies.sh" ]]; then
    echo "Error: Verification failed" >&2
    exit 1
  fi

  echo "✓ e-bash installed" >&2

  E_BASH="$target_dir"
  readonly E_BASH
  export E_BASH

  # Setup environment
  if [[ -f "$E_BASH/_gnu.sh" ]]; then
    # shellcheck disable=SC1091
    source "$E_BASH/_gnu.sh"
  fi

  local gnubin_path
  gnubin_path=$(cd "$E_BASH/../bin/gnubin" 2>/dev/null && pwd || echo "")
  if [[ -n "$gnubin_path" ]] && [[ -d "$gnubin_path" ]]; then
    PATH="$gnubin_path:$PATH"
    export PATH
  fi

  return 0
}

# ============================================================================
# COPY-PASTE SECTION END - Minimal Bootstrap
# ============================================================================

# Execute the bootstrap
ebash:bootstrap

# ============================================================================
# YOUR SCRIPT STARTS HERE
# ============================================================================

# Now you can use e-bash modules
# shellcheck disable=SC1091
source "$E_BASH/_dependencies.sh"
source "$E_BASH/_logger.sh"
source "$E_BASH/_colors.sh"

# Example usage
DEBUG=${DEBUG:-"demo"}
logger:init demo "[${cl_cyan}Demo]${cl_reset} " ">&2"

echo:Demo "════════════════════════════════════════════════════════════════"
echo:Demo "Minimal Bootstrap Demo"
echo:Demo "════════════════════════════════════════════════════════════════"
echo:Demo ""
echo:Demo "This script uses the MINIMAL bootstrap version."
echo:Demo ""
echo:Demo "Features:"
echo:Demo "  • Quiet operation (minimal output)"
echo:Demo "  • Fast detection and installation"
echo:Demo "  • Clean, production-ready"
echo:Demo "  • Only shows errors when needed"
echo:Demo ""
echo:Demo "E_BASH location: ${cl_yellow}$E_BASH${cl_reset}"
echo:Demo ""
echo:Demo "Perfect for:"
echo:Demo "  • Production automation scripts"
echo:Demo "  • CI/CD pipelines"
echo:Demo "  • Background jobs and cron"
echo:Demo "  • Scripts run by advanced users"
echo:Demo ""
echo:Demo "Output when e-bash found: (none)"
echo:Demo "Output when installing:    '→ Installing e-bash... ✓ e-bash installed'"
echo:Demo ""
echo:Demo "════════════════════════════════════════════════════════════════"
