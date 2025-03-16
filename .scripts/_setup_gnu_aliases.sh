#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

#
# Smart script to set up GNU tool aliases on Linux systems
# This script detects if we're on Linux and adds appropriate aliases
# to maintain compatibility with MacOS scripts that use ggrep/gsed
#

# Function to check if a command is available
command_exists() {
  command -v "$1" &>/dev/null
}

# Function to check if an alias is already defined
alias_exists() {
  alias "$1" &>/dev/null
}

# Only set up aliases if we're on Linux
if [[ "$(uname -s)" == "Linux" ]]; then
  # Check if GNU grep is available and ggrep alias doesn't exist
  if command_exists grep && ! alias_exists ggrep; then
    # Check if it's actually GNU grep
    if grep --version | grep -q 'GNU grep'; then
      alias ggrep=grep
      # Set verbose output only if not being sourced in a startup file
      if [[ -n "$PS1" ]]; then
        echo "✓ Set up alias: ggrep → grep (GNU version)"
      fi
    fi
  fi

  # Check if GNU sed is available and gsed alias doesn't exist
  if command_exists sed && ! alias_exists gsed; then
    # Check if it's actually GNU sed
    if sed --version | grep -q 'GNU sed'; then
      alias gsed=sed
      # Set verbose output only if not being sourced in a startup file
      if [[ -n "$PS1" ]]; then
        echo "✓ Set up alias: gsed → sed (GNU version)"
      fi
    fi
  fi
fi
