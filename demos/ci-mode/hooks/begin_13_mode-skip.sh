#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_13_mode-skip.sh (source mode)
## Purpose: Handle SKIP mode - disabled step, exit parent with success

function hook:run() {
  [[ "${__HOOKS_FLOW_MODE}" != "SKIP" ]] && return 0

  echo "[modes] SKIP: step disabled, exiting" >&2
  export __HOOKS_FLOW_EXIT_CODE=0
  export __HOOKS_FLOW_TERMINATE=true
}
