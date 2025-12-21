#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_14_mode-timeout.sh (source mode)
## Purpose: Handle TIMEOUT mode - fail after N seconds

function hook:run() {
  [[ "${__HOOKS_FLOW_MODE}" != TIMEOUT:* ]] && return 0

  local timeout_secs="${__HOOKS_FLOW_MODE#TIMEOUT:}"
  echo "[modes] TIMEOUT: will fail after ${timeout_secs}s" >&2

  export HOOKS_FLOW_TIMEOUT="${timeout_secs}"
  
  # Schedule alarm signal in background (target parent shell)
  ( sleep "${timeout_secs}" && kill -ALRM $PPID 2>/dev/null ) &
  export __HOOKS_FLOW_TIMEOUT_PID=$!

  # Set up trap in parent shell 
  trap 'echo "[modes] TIMEOUT: Script exceeded ${HOOKS_FLOW_TIMEOUT}s" >&2; exit 124' ALRM
}
