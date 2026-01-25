#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-25
## Version: 2.7.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

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

## -----------------------------------------------------------------------------
## Module: _gnu
## -----------------------------------------------------------------------------
##
## Purpose:
## GNU tools compatibility layer for macOS/Linux cross-platform development.
## This script creates symbolic links in bin/gnubin/ to provide g-prefixed
## GNU tools (ggrep, gsed, gawk, etc.) on Linux, matching macOS GNU coreutils
## naming conventions.
##
## References:
## - docs/public/installation.md: Installation and setup documentation
## - bin/gnubin/: Directory containing GNU tool symlinks
## - .scripts/_colors.sh: Module that uses gnubin tools for color detection
## - All scripts requiring GNU text processing tools (grep, sed, awk)
##
## Globals Introduced:
## - BIN_DIR - Path to bin/gnubin directory (created if not exists)
##
## Platform Behavior:
## - Linux: Creates symlinks for ggrep, gsed, gawk, gfind, gmv, gcp, gln, greadlink, gdate
## - macOS: Does nothing (GNU tools already available with 'g' prefix via coreutils)
## - WSL: Same as Linux (creates symlinks)
##
## Function Categories:
## - Initialization: (none - script runs inline when sourced)
## - Note: This is a configuration script, not a function library. It executes
##   initialization code when sourced rather than providing reusable functions.
##
