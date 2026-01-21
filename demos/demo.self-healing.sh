#!/usr/bin/env bash
## Copyright (C) 2026-present, Oleksandr Kucherenko
## Self-Healing Script Demo - Automatically installs e-bash if missing
## Version: 1.0.0 | License: MIT
##
## This script demonstrates the "self-healing" pattern where a script:
## 1. Detects if e-bash library is available
## 2. Automatically installs e-bash globally if missing
## 3. Continues execution without any manual setup required
##
## This makes scripts truly portable - just copy and run anywhere!

# ============================================================================
# SELF-HEALING BOOTSTRAP - Copy this section to any script for portability
# ============================================================================

function ebash:bootstrap() {
  local install_url="https://git.new/e-bash"
  local install_needed=false

  # Check if E_BASH is already set and valid
  if [[ -n "${E_BASH:-}" ]] && [[ -d "$E_BASH" ]]; then
    echo "✓ e-bash found: $E_BASH" >&2
    return 0
  fi

  # Try to discover e-bash (project-local or global)
  local _src="${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$0}}"
  local project_local
  project_local=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo "")
  local global_location="$HOME/.e-bash/.scripts"

  if [[ -d "$project_local" ]] && [[ -f "$project_local/_dependencies.sh" ]]; then
    E_BASH="$project_local"
    readonly E_BASH
    export E_BASH
    echo "✓ e-bash found (project): $E_BASH" >&2
  elif [[ -d "$global_location" ]] && [[ -f "$global_location/_dependencies.sh" ]]; then
    E_BASH="$global_location"
    readonly E_BASH
    export E_BASH
    echo "✓ e-bash found (global): $E_BASH" >&2
  else
    install_needed=true
  fi

  # Install e-bash globally if not found
  if [[ "$install_needed" == "true" ]]; then
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "⚠ e-bash library not found" >&2
    echo "" >&2
    echo "This script requires the e-bash library to run." >&2
    echo "Installing e-bash globally to: $HOME/.e-bash" >&2
    echo "" >&2
    echo "This is a one-time setup and takes ~5 seconds." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2

    # Check for required tools
    if ! command -v curl >/dev/null 2>&1; then
      echo "Error: curl is required for e-bash installation" >&2
      echo "Please install curl and try again" >&2
      exit 1
    fi

    # Perform global installation
    echo "→ Downloading e-bash installer..." >&2
    if curl -sSL "$install_url" | bash -s -- --global install; then
      E_BASH="$global_location"
      readonly E_BASH
      export E_BASH

      echo "" >&2
      echo "✓ e-bash installed successfully to: $E_BASH" >&2
      echo "" >&2
    else
      echo "" >&2
      echo "✗ Failed to install e-bash" >&2
      echo "" >&2
      echo "Manual installation:" >&2
      echo "  curl -sSL $install_url | bash -s -- --global install" >&2
      echo "" >&2
      exit 1
    fi
  fi

  # Load GNU tools
  if [[ -f "$E_BASH/_gnu.sh" ]]; then
    # shellcheck disable=SC1091
    . "$E_BASH/_gnu.sh"
    local gnubin_path
    gnubin_path=$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd || echo "")
    if [[ -n "$gnubin_path" ]]; then
      PATH="$gnubin_path:$PATH"
      export PATH
    fi
  fi

  return 0
}

# Execute bootstrap - installs e-bash if needed
ebash:bootstrap

# ============================================================================
# END OF SELF-HEALING BOOTSTRAP
# ============================================================================

# Now we can use e-bash modules normally
# shellcheck disable=SC1091
source "$E_BASH/_dependencies.sh"
source "$E_BASH/_logger.sh"
source "$E_BASH/_colors.sh"
source "$E_BASH/_dryrun.sh"
source "$E_BASH/_traps.sh"

# ============================================================================
# SCRIPT CONFIGURATION
# ============================================================================

DEBUG=${DEBUG:-"demo"}

# Initialize logger
logger:init demo "[${cl_cyan}Demo]${cl_reset} " ">&2"

# Declare dependencies (with auto-install in CI)
dependency bash "5.*.*" "brew install bash"

# Optional dependencies (won't fail if missing, just warn)
optional jq "1.*" "brew install jq"
optional tree "*" "brew install tree"

# Setup cleanup
trap:on "echo:Demo '${cl_yellow}Cleanup complete${cl_reset}'" EXIT

# Setup dry-run wrappers
dryrun rm mkdir

# ============================================================================
# DEMO LOGIC
# ============================================================================

main() {
  echo:Demo "${cl_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${cl_reset}"
  echo:Demo "${cl_green}Self-Healing Script Demo${cl_reset}"
  echo:Demo "${cl_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${cl_reset}"
  echo:Demo ""
  echo:Demo "This script demonstrates the ${cl_yellow}self-healing pattern${cl_reset}:"
  echo:Demo ""
  echo:Demo "  1. ✓ Detected and/or installed e-bash library"
  echo:Demo "  2. ✓ Validated all dependencies"
  echo:Demo "  3. ✓ Set up logging, dry-run, and cleanup"
  echo:Demo "  4. ✓ Ready to execute main logic"
  echo:Demo ""
  echo:Demo "${cl_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${cl_reset}"
  echo:Demo ""

  # Show environment info
  echo:Demo "${cl_cyan}Environment Information:${cl_reset}"
  echo:Demo "  E_BASH: ${cl_yellow}$E_BASH${cl_reset}"
  echo:Demo "  Bash version: ${cl_yellow}$BASH_VERSION${cl_reset}"
  echo:Demo "  Script: ${cl_yellow}${BASH_SOURCE[0]}${cl_reset}"
  echo:Demo ""

  # Demonstrate some e-bash features
  echo:Demo "${cl_cyan}Demonstrating e-bash features:${cl_reset}"
  echo:Demo ""

  # Dry-run example
  echo:Demo "→ Testing dry-run wrapper:"
  local temp_dir="/tmp/self-healing-demo-$$"
  dry:mkdir -p "$temp_dir"
  echo:Demo "  ${cl_green}✓${cl_reset} Created temp directory (dry-run mode respects DRY_RUN env var)"
  echo:Demo ""

  # Dependency check example
  echo:Demo "→ Testing dependency validation:"
  echo:Demo "  ${cl_green}✓${cl_reset} bash $(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  if command -v jq >/dev/null 2>&1; then
    echo:Demo "  ${cl_green}✓${cl_reset} jq $(jq --version | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')"
  fi
  echo:Demo ""

  # Logger example
  echo:Demo "→ Testing logger (controlled by DEBUG env var):"
  echo:Demo "  Current DEBUG setting: ${cl_yellow}${DEBUG:-"(not set)"}${cl_reset}"
  echo:Demo "  Try: ${cl_yellow}DEBUG=* $0${cl_reset} to see all logs"
  echo:Demo ""

  # Cleanup trap example
  echo:Demo "→ Testing cleanup trap:"
  echo:Demo "  Trap registered for EXIT signal"
  echo:Demo "  Cleanup will run automatically when script exits"
  echo:Demo ""

  echo:Demo "${cl_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${cl_reset}"
  echo:Demo "${cl_green}Demo Complete!${cl_reset}"
  echo:Demo "${cl_green}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${cl_reset}"
  echo:Demo ""
  echo:Demo "${cl_cyan}Key Benefits:${cl_reset}"
  echo:Demo "  • ${cl_green}Portable${cl_reset}: Copy this script anywhere and run it"
  echo:Demo "  • ${cl_green}Self-healing${cl_reset}: Automatically installs missing dependencies"
  echo:Demo "  • ${cl_green}Zero setup${cl_reset}: No manual installation or configuration needed"
  echo:Demo "  • ${cl_green}CI-ready${cl_reset}: Works in CI/CD pipelines without extra steps"
  echo:Demo ""
  echo:Demo "${cl_cyan}Try these commands:${cl_reset}"
  echo:Demo "  ${cl_yellow}DEBUG=* $0${cl_reset}         # Enable all debug output"
  echo:Demo "  ${cl_yellow}DRY_RUN=true $0${cl_reset}    # Preview mode (no actual execution)"
  echo:Demo ""
}

# Execute main function
main "$@"
