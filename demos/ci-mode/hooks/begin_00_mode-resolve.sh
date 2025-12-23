#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_00_mode-resolve.sh (source mode)
## Purpose: Resolve HOOKS_FLOW_MODE from environment variables
## Sets: __HOOKS_FLOW_MODE for other hooks to check

function hook:run() {
  local script_name="${1:-unknown}"
  local script_name_safe="${script_name//[^a-zA-Z0-9_]/_}"

  # Mode resolution: per-script > global > default (EXEC)
  local mode_var="HOOKS_FLOW_MODE_${script_name_safe}"
  __HOOKS_FLOW_MODE="${!mode_var:-${HOOKS_FLOW_MODE:-EXEC}}"
  export __HOOKS_FLOW_MODE

  echo "[modes] Resolved: script='${script_name}' mode='${__HOOKS_FLOW_MODE}'" >&2
}
