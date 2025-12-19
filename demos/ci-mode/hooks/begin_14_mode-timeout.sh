#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_14_mode-timeout.sh (source mode)
## Purpose: Handle TIMEOUT mode - fail after N seconds

function hook:run() {
  [[ "${__CI_SCRIPT_MODE}" != TIMEOUT:* ]] && return 0

  local timeout_secs="${__CI_SCRIPT_MODE#TIMEOUT:}"
  echo "[mode] TIMEOUT: will fail after ${timeout_secs}s" >&2

  export CI_SCRIPT_TIMEOUT="${timeout_secs}"
  
  # Schedule alarm signal in background (target parent shell)
  ( sleep "${timeout_secs}" && kill -ALRM $PPID 2>/dev/null ) &
  export __CI_TIMEOUT_PID=$!

  # Set up trap in parent shell 
  trap 'echo "[mode] TIMEOUT: Script exceeded ${CI_SCRIPT_TIMEOUT}s" >&2; exit 124' ALRM
}
