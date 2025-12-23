#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.3
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

#
# This script creates symbolic links in the bin directory for GNU tools
# when running on Linux, providing ggrep/gsed commands for compatibility
#

# Only proceed if we're on Linux
if [[ "$(uname -s)" == "Linux" ]]; then
  BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gnubin"

  # Create bin directory if it doesn't exist
  mkdir -p "$BIN_DIR"

  TOOLS=("grep" "sed" "find" "awk" "mv" "cp" "ln" "readlink" "date")

  for tool in "${TOOLS[@]}"; do
    # Create symbolic link for g${tool} if it doesn't exist
    if [[ ! -e "$BIN_DIR/g${tool}" ]] && command -v "$tool" &>/dev/null; then
      ln -sf "$(command -v "$tool")" "$BIN_DIR/g${tool}"
      echo "Created symbolic link: bin/g${tool} -> $(command -v "$tool")"
    fi
  done
fi
