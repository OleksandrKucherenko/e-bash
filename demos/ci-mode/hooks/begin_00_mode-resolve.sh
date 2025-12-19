#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_00_mode-resolve.sh (source mode)
## Purpose: Resolve CI_SCRIPT_MODE from environment variables
## Sets: __CI_SCRIPT_MODE for other hooks to check

function hook:run() {
  local script_name="${1:-unknown}"
  local script_name_safe="${script_name//[^a-zA-Z0-9_]/_}"

  # Mode resolution: per-script > global > default (EXEC)
  local mode_var="CI_SCRIPT_MODE_${script_name_safe}"
  __CI_SCRIPT_MODE="${!mode_var:-${CI_SCRIPT_MODE:-EXEC}}"
  export __CI_SCRIPT_MODE

  echo "[mode] Resolved: script='${script_name}' mode='${__CI_SCRIPT_MODE}'" >&2
}
