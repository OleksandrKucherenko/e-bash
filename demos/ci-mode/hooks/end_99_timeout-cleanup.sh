#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Global end hook: Cleanup timeout background process (source mode)

function hook:run() {
  if [[ -n "${__CI_TIMEOUT_PID}" ]]; then
    echo "[mode] Cleaning up timeout watcher (PID: ${__CI_TIMEOUT_PID})" >&2
    kill "${__CI_TIMEOUT_PID}" 2>/dev/null || true
  fi
}
