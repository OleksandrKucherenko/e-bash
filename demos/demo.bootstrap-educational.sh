#!/usr/bin/env bash
## Copyright (C) 2026-present, Oleksandr Kucherenko
## Educational Bootstrap Demo - Copy-paste this entire function into your scripts
## Version: 1.0.0 | License: MIT

# ============================================================================
# COPY-PASTE SECTION START - Educational Bootstrap
# ============================================================================
# This is a standalone, self-contained bootstrap function with detailed
# educational messages. Perfect for scripts where users might be learning
# or need to understand what's happening.
# ============================================================================

function ebash:bootstrap() {
  echo "" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "🔍 DETECTING e-bash LIBRARY" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "" >&2

  local ebash_location=""
  local install_type="unknown"

  # Check 1: E_BASH variable
  if [[ -n "${E_BASH:-}" ]] && [[ -f "$E_BASH/_dependencies.sh" ]]; then
    ebash_location="$E_BASH"
    install_type="environment variable"
  fi

  # Check 2: Project-local
  if [[ -z "$ebash_location" ]]; then
    local script_path="${BASH_SOURCE[0]:-$0}"
    local project_local
    project_local=$(cd "${script_path%/*}/../.scripts" 2>/dev/null && pwd || echo "")

    if [[ -n "$project_local" ]] && [[ -f "$project_local/_dependencies.sh" ]]; then
      ebash_location="$project_local"
      install_type="project-local"
    fi
  fi

  # Check 3: Global
  if [[ -z "$ebash_location" ]]; then
    local global_location="$HOME/.e-bash/.scripts"
    if [[ -f "$global_location/_dependencies.sh" ]]; then
      ebash_location="$global_location"
      install_type="global"
    fi
  fi

  # Found existing installation
  if [[ -n "$ebash_location" ]]; then
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

  # Not found - need to install
  echo "⚠ e-bash not found in any standard location" >&2
  echo "" >&2
  echo "Checked locations:" >&2
  echo "  1. Environment variable: E_BASH=${E_BASH:-(not set)}" >&2
  echo "  2. Project-local: (script directory)/../.scripts" >&2
  echo "  3. Global: $HOME/.e-bash/.scripts" >&2
  echo "" >&2

  # Verify curl
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
    exit 1
  fi

  # Install
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
    exit 1
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
    exit 1
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
# COPY-PASTE SECTION END - Educational Bootstrap
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
echo:Demo "Educational Bootstrap Demo"
echo:Demo "════════════════════════════════════════════════════════════════"
echo:Demo ""
echo:Demo "This script uses the EDUCATIONAL bootstrap version."
echo:Demo ""
echo:Demo "Features:"
echo:Demo "  • Detailed explanations of what's happening"
echo:Demo "  • Clear progress indicators (Step 1/3, 2/3, 3/3)"
echo:Demo "  • Helpful error messages with solutions"
echo:Demo "  • Educational content about e-bash"
echo:Demo ""
echo:Demo "E_BASH location: ${cl_yellow}$E_BASH${cl_reset}"
echo:Demo ""
echo:Demo "Perfect for:"
echo:Demo "  • Learning scripts and tutorials"
echo:Demo "  • Onboarding new developers"
echo:Demo "  • Scripts where users need context"
echo:Demo "  • Debugging installation issues"
echo:Demo ""
echo:Demo "════════════════════════════════════════════════════════════════"
