#!/usr/bin/env bash
## Copyright (C) 2026-present, Oleksandr Kucherenko
## Educational e-bash Bootstrap - Self-healing with detailed explanations
## Version: 1.0.0 | License: MIT
##
## Purpose: Automatically detect or install e-bash library with educational messages
## Usage: source this file at the start of your script, then call ebash:bootstrap

# ============================================================================
# DETECTION - Pure logic to find e-bash
# ============================================================================

# Returns the path to e-bash if found, empty string otherwise
# Checks in order: E_BASH variable -> project-local -> global
ebash:detect_location() {
  # Priority 1: E_BASH already set (user override or previous detection)
  if [[ -n "${E_BASH:-}" ]] && [[ -f "$E_BASH/_dependencies.sh" ]]; then
    echo "$E_BASH"
    return 0
  fi

  # Priority 2: Project-local installation (.scripts/ relative to script)
  local script_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]:-$0}}"
  local project_local
  project_local=$(cd "${script_path%/*}/../.scripts" 2>/dev/null && pwd || echo "")

  if [[ -n "$project_local" ]] && [[ -f "$project_local/_dependencies.sh" ]]; then
    echo "$project_local"
    return 0
  fi

  # Priority 3: Global installation (~/.e-bash/.scripts)
  local global_location="$HOME/.e-bash/.scripts"
  if [[ -f "$global_location/_dependencies.sh" ]]; then
    echo "$global_location"
    return 0
  fi

  # Not found anywhere
  echo ""
  return 1
}

# ============================================================================
# VALIDATION - Verify required tools
# ============================================================================

ebash:verify_prerequisites() {
  if ! command -v curl >/dev/null 2>&1; then
    cat >&2 <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ MISSING PREREQUISITE: curl
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The e-bash installer requires curl to download files.

Please install curl and try again:

  • macOS:    brew install curl
  • Ubuntu:   sudo apt-get install curl
  • RHEL:     sudo yum install curl
  • Alpine:   apk add curl

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
    return 1
  fi
  return 0
}

# ============================================================================
# INSTALLATION - Download and install e-bash
# ============================================================================

ebash:install_globally() {
  local install_url="https://git.new/e-bash"
  local target_dir="$HOME/.e-bash/.scripts"

  cat >&2 <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 INSTALLING e-bash LIBRARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

What is e-bash?
  A professional Bash framework providing logging, dependency management,
  argument parsing, dry-run support, and more.

Why install?
  This script requires e-bash to function properly.

Where will it be installed?
  $target_dir

What happens next?
  1. Download installer from $install_url
  2. Run global installation (no sudo required)
  3. Verify installation succeeded
  4. Continue script execution

This is a one-time setup and takes approximately 5 seconds.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

  echo "→ Step 1/3: Downloading e-bash installer..." >&2

  if ! curl -sSL "$install_url" | bash -s -- --global install 2>&1 | sed 's/^/  /' >&2; then
    cat >&2 <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ INSTALLATION FAILED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Automatic installation encountered an error.

Common causes:
  • Network connectivity issues
  • GitHub rate limiting
  • Insufficient disk space
  • File permission issues

Manual installation:
  Run this command in your terminal:

  curl -sSL $install_url | bash -s -- --global install

For help or issues:
  https://github.com/OleksandrKucherenko/e-bash/issues

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
    return 1
  fi

  echo "" >&2
  echo "→ Step 2/3: Verifying installation..." >&2

  if [[ ! -f "$target_dir/_dependencies.sh" ]]; then
    cat >&2 <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ VERIFICATION FAILED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Installation appeared to succeed but files are not in expected location.

Expected: $target_dir/_dependencies.sh
Found:    (file missing)

Please try manual installation or report this issue.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
    return 1
  fi

  echo "  ✓ Installation verified" >&2
  echo "" >&2
  echo "→ Step 3/3: Setting environment variables..." >&2

  cat >&2 <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ INSTALLATION SUCCESSFUL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

e-bash has been installed to: $target_dir

What this means:
  • All future scripts will find e-bash automatically
  • No additional setup needed
  • You can update anytime with: curl -sSL $install_url | bash -s --

Continuing script execution...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

  echo "$target_dir"
  return 0
}

# ============================================================================
# ENVIRONMENT SETUP - Configure PATH and GNU tools
# ============================================================================

ebash:setup_environment() {
  local ebash_dir="$1"

  # Load GNU tools for macOS compatibility
  if [[ -f "$ebash_dir/_gnu.sh" ]]; then
    # shellcheck disable=SC1090
    source "$ebash_dir/_gnu.sh"
  fi

  # Add gnubin to PATH for GNU tool wrappers
  local gnubin_path
  gnubin_path=$(cd "$ebash_dir/../bin/gnubin" 2>/dev/null && pwd || echo "")

  if [[ -n "$gnubin_path" ]] && [[ -d "$gnubin_path" ]]; then
    PATH="$gnubin_path:$PATH"
    export PATH
  fi
}

# ============================================================================
# MAIN ORCHESTRATION - Coordinate detection, installation, setup
# ============================================================================

ebash:bootstrap() {
  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "🔍 DETECTING e-bash LIBRARY" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "" >&2

  # Attempt detection
  local ebash_location
  ebash_location=$(ebash:detect_location)

  if [[ -n "$ebash_location" ]]; then
    # Found existing installation
    local install_type="unknown"
    if [[ "$ebash_location" == *"/.e-bash/.scripts" ]]; then
      install_type="global"
    else
      install_type="project-local"
    fi

    cat >&2 <<EOF
✓ e-bash found ($install_type)

Location: $ebash_location

This script will use the existing installation.
No installation needed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

    E_BASH="$ebash_location"
    readonly E_BASH
    export E_BASH

    ebash:setup_environment "$E_BASH"
    return 0
  fi

  # Not found - need to install
  echo "⚠ e-bash not found in any standard location" >&2
  echo "" >&2
  echo "Checked locations:" >&2
  echo "  1. Environment variable: E_BASH=${E_BASH:-(not set)}" >&2
  echo "  2. Project-local: (script directory)/../.scripts" >&2
  echo "  3. Global: $HOME/.e-bash/.scripts" >&2
  echo "" >&2

  # Verify prerequisites
  if ! ebash:verify_prerequisites; then
    exit 1
  fi

  # Perform installation
  local installed_location
  if ! installed_location=$(ebash:install_globally); then
    exit 1
  fi

  # Export and setup
  E_BASH="$installed_location"
  readonly E_BASH
  export E_BASH

  ebash:setup_environment "$E_BASH"
  return 0
}

# Make functions available but don't auto-execute
# User must call ebash:bootstrap explicitly
