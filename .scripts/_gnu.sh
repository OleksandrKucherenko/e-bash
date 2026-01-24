#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-15
## Version: 2.0.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash
## Description: GNU tool shims for macOS/Linux compatibility

# Module: _gnu.sh
#
# Description:
#   Creates symbolic links in bin/gnubin/ directory to provide unified GNU tool names
#   across macOS and Linux. On Linux, creates g* aliases (ggrep, gsed, etc.) that point
#   to standard tools. On macOS, these are expected to be installed via Homebrew.
#
# Purpose:
#   - Ensures consistent tool names across platforms (ggrep, gsed, gfind, etc.)
#   - Allows scripts to use g* commands universally without platform checks
#   - Prevents "command not found" errors when PATH includes bin/gnubin/
#
# Usage:
#   source "$E_BASH/_gnu.sh"
#   PATH="$E_BASH/../bin/gnubin:$PATH"  # Add gnubin to PATH
#
# Side Effects:
#   - Creates bin/gnubin/ directory if it doesn't exist
#   - On Linux: Creates symbolic links for grep->ggrep, sed->gsed, etc.
#   - On macOS: No symlinks created (expects Homebrew gnu-* packages)
#
# Tools Aliased:
#   grep, sed, find, awk, mv, cp, ln, readlink, date
#

# Determine gnubin directory path
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gnubin"

# Always create gnubin directory (even on macOS) to prevent cd errors
mkdir -p "$BIN_DIR"

# Only create symlinks on Linux
if [[ "$(uname -s)" == "Linux" ]]; then
  TOOLS=("grep" "sed" "find" "awk" "mv" "cp" "ln" "readlink" "date")

  for tool in "${TOOLS[@]}"; do
    # Create symbolic link for g${tool} if it doesn't exist
    if [[ ! -e "$BIN_DIR/g${tool}" ]] && command -v "$tool" &>/dev/null; then
      ln -sf "$(command -v "$tool")" "$BIN_DIR/g${tool}"
      echo "Created symbolic link: bin/g${tool} -> $(command -v "$tool")"
    fi
  done
fi
