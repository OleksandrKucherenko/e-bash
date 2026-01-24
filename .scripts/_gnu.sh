#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-15
## Version: 2.0.1
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

##
## This script creates symbolic links in the bin directory for GNU tools
## when running on Linux, providing ggrep/gsed commands for compatibility
##
## References:
## - demo: (not directly used, but bin/gnubin/ is used by many scripts)
## - bin: All scripts that require GNU tools (grep, sed, awk, etc.)
## - documentation: Referenced in docs/public/installation.md
#
## Globals:
## - BIN_DIR - Path to bin/gnubin directory
#
## Platform:
## - Linux: Creates symlinks for ggrep, gsed, gawk, gfind, gmv, gcp, gln, greadlink, gdate
## - macOS: Does nothing (GNU tools are already available with 'g' prefix)
##