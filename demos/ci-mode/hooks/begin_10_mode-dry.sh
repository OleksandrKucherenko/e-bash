#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_10_mode-dry.sh (source mode)
## Purpose: Handle DRY mode - enable dry-run for all commands

function hook:run() {
  [[ "${__HOOKS_FLOW_MODE}" != "DRY" ]] && return 0

  echo "[modes] DRY: enabling dry-run for all commands" >&2
  export DRY_RUN=true
}
