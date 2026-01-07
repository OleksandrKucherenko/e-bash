#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Global end hook: Cleanup timeout background process (source mode)

function hook:run() {
  if [[ -n "${__CI_TIMEOUT_PID}" ]]; then
    echo "[modes] Cleaning up timeout watcher (PID: ${__CI_TIMEOUT_PID})" >&2
    kill "${__CI_TIMEOUT_PID}" 2>/dev/null || true
  fi
}
