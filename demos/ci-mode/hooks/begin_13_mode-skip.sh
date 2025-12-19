#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_13_mode-skip.sh (source mode)
## Purpose: Handle SKIP mode - disabled step, exit parent with success

function hook:run() {
  [[ "${__CI_SCRIPT_MODE}" != "SKIP" ]] && return 0

  echo "[mode] SKIP: step disabled, exiting" >&2
  export __CI_MODE_EXIT=0
  export __CI_MODE_TERMINATE=true
}
