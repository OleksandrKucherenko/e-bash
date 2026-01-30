#!/usr/bin/env bash
# Apply ShellSpec timeout patch (Ubuntu/Linux/MacOs)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-30
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

SHELLSPEC_BIN="$(command -v shellspec 2>/dev/null)"
if [[ -n "$SHELLSPEC_BIN" ]]; then
  # is timeout patch already applied?
  if ! "$SHELLSPEC_BIN" --help 2>/dev/null | grep -q -- '--timeout'; then
    echo "Applying ShellSpec timeout patch..."

    if [[ "$(uname -s)" == "Darwin" ]]; then
      if [[ -f "$PWD/patches/apply.macos.sh" ]]; then
        "$PWD/patches/apply.macos.sh"
      fi
    else
      if [[ -f "$PWD/patches/apply.linux.sh" ]]; then
        "$PWD/patches/apply.linux.sh"
      fi
    fi
  fi
fi
