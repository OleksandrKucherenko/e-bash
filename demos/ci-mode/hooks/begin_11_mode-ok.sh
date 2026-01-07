#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_11_mode-ok.sh (source mode)
## Purpose: Handle OK mode - no-op, exit parent with success

function hook:run() {
  [[ "${__HOOKS_FLOW_MODE}" != "OK" ]] && return 0

  echo "[modes] OK: no-op, exiting with success" >&2
  # In source mode, we can't exit the parent - set flag instead
  export __HOOKS_FLOW_EXIT_CODE=0
  export __HOOKS_FLOW_TERMINATE=true
}
