#!/usr/bin/env bash
# shellspec.format.sh - Cross-platform wrapper for formatting ShellSpec test files
#
# This script handles formatting of ShellSpec test files using altshfmt when available.
# It gracefully handles different OS environments (Linux, macOS, Windows/WSL2).
#
# Usage: shellspec.format.sh <file-path>

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

readonly SCRIPT_FILE="${1:-}"

if [[ -z "$SCRIPT_FILE" ]]; then
  echo "Usage: $0 <file-path>" >&2
  exit 1
fi

# Check if file exists
if [[ ! -f "$SCRIPT_FILE" ]]; then
  echo "Error: File not found: $SCRIPT_FILE" >&2
  exit 1
fi

# Check if file is a ShellSpec test file
if [[ ! "$SCRIPT_FILE" =~ _spec\.sh$ ]]; then
  echo "Warning: File does not appear to be a ShellSpec test file (doesn't end with _spec.sh)" >&2
  echo "Skipping formatting." >&2
  exit 0
fi

# Function to find altshfmt
find_altshfmt() {
  local altshfmt_path=""

  # Check environment variable first (set by .envrc)
  if [[ -n "${ALTSHFMT:-}" ]] && [[ -x "$ALTSHFMT" ]]; then
    echo "$ALTSHFMT"
    return 0
  fi

  # Check common locations
  local common_paths=(
    "$(dirname "$(dirname "$(realpath "$0")")")/../altshfmt/altshfmt"
    "$HOME/workspace/altshfmt/altshfmt"
    "$HOME/.local/bin/altshfmt"
    "/usr/local/bin/altshfmt"
  )

  for path in "${common_paths[@]}"; do
    if [[ -x "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  # Check if altshfmt is in PATH
  if command -v altshfmt &>/dev/null; then
    command -v altshfmt
    return 0
  fi

  return 1
}

# Detect OS and check if altshfmt is supported
detect_os_and_check_support() {
  case "$(uname -s)" in
    Linux*)
      return 0  # Supported
      ;;
    Darwin*)
      return 0  # Supported (macOS)
      ;;
    CYGWIN*|MINGW*|MSYS*)
      echo "Warning: altshfmt is not supported on native Windows." >&2
      echo "Please use WSL2 or format files manually." >&2
      return 1
      ;;
    *)
      echo "Warning: Unknown OS. altshfmt may not be available." >&2
      return 1
      ;;
  esac
}

# Main execution
main() {
  # Check OS support
  if ! detect_os_and_check_support; then
    exit 0  # Exit gracefully on unsupported OS
  fi

  # Find altshfmt
  local altshfmt_bin
  if ! altshfmt_bin=$(find_altshfmt); then
    echo "Warning: altshfmt not found. ShellSpec test files should be formatted with altshfmt." >&2
    echo "Install it from: https://github.com/shellspec/altshfmt" >&2
    echo "Or ensure ALTSHFMT environment variable points to the binary." >&2
    exit 0  # Exit gracefully if not found
  fi

  # Format the file
  echo "Formatting $SCRIPT_FILE with altshfmt..." >&2
  "$altshfmt_bin" -w "$SCRIPT_FILE"

  echo "✓ Formatted successfully" >&2
}

main "$@"
