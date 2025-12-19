#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_11_mode-ok.sh (source mode)
## Purpose: Handle OK mode - no-op, exit parent with success

function hook:run() {
  [[ "${__CI_SCRIPT_MODE}" != "OK" ]] && return 0

  echo "[mode] OK: no-op, exiting with success" >&2
  # In source mode, we can't exit the parent - set flag instead
  export __CI_MODE_EXIT=0
  export __CI_MODE_TERMINATE=true
}
