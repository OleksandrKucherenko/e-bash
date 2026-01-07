#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_12_mode-error.sh (source mode)
## Purpose: Handle ERROR mode - exit parent with specified error code

function hook:run() {
  [[ "${__HOOKS_FLOW_MODE}" != "ERROR" ]] && return 0

  local error_code="${HOOKS_FLOW_ERROR_CODE:-1}"
  echo "[modes] ERROR: exiting with code ${error_code}" >&2
  export __HOOKS_FLOW_EXIT_CODE="${error_code}"
  export __HOOKS_FLOW_TERMINATE=true
}
