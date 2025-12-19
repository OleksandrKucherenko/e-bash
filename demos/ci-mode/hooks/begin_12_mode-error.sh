#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_12_mode-error.sh (source mode)
## Purpose: Handle ERROR mode - exit parent with specified error code

function hook:run() {
  [[ "${__CI_SCRIPT_MODE}" != "ERROR" ]] && return 0

  local error_code="${CI_SCRIPT_ERROR_CODE:-1}"
  echo "[mode] ERROR: exiting with code ${error_code}" >&2
  export __CI_MODE_EXIT="${error_code}"
  export __CI_MODE_TERMINATE=true
}
