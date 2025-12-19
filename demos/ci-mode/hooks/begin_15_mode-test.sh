#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_15_mode-test.sh (source mode)
## Purpose: Handle TEST mode - run mock script instead

function hook:run() {
  # Check if mode is a file path (TEST mode)
  [[ ! -f "${__CI_SCRIPT_MODE}" ]] && return 0

  echo "[mode] TEST: sourcing ${__CI_SCRIPT_MODE}" >&2
  # shellcheck disable=SC1090
  source "${__CI_SCRIPT_MODE}"
  export __CI_MODE_EXIT="${__CI_MODE_EXIT_CODE:-0}"
  export __CI_MODE_TERMINATE=true
}
