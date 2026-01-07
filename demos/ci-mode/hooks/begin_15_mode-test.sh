#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_15_mode-test.sh (source mode)
## Purpose: Handle TEST mode - run mock script instead

function hook:run() {
  # Check if mode is a file path (TEST mode)
  [[ ! -f "${__HOOKS_FLOW_MODE}" ]] && return 0

  echo "[modes] TEST: sourcing ${__HOOKS_FLOW_MODE}" >&2
  # shellcheck disable=SC1090
  source "${__HOOKS_FLOW_MODE}"
  export __HOOKS_FLOW_EXIT_CODE="${__HOOKS_FLOW_EXIT_CODE:-0}"
  export __HOOKS_FLOW_TERMINATE=true
}
