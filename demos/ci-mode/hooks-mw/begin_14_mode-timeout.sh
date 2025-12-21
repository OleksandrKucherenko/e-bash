#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_14_mode-timeout.sh (exec mode)
## Purpose: Handle TIMEOUT mode - fail after N seconds

script_name="${1:-unknown}"
script_name_safe="${script_name//[^a-zA-Z0-9_]/_}"
mode_var="HOOKS_FLOW_MODE_${script_name_safe}"
mode="${!mode_var:-${HOOKS_FLOW_MODE:-EXEC}}"

[[ "$mode" != TIMEOUT:* ]] && exit 0

timeout_secs="${mode#TIMEOUT:}"
if [[ "$timeout_secs" =~ ^[0-9]+$ ]] && ((timeout_secs > 0)); then
  printf '[modes] TIMEOUT: ' >&2
  for ((i = 1; i <= timeout_secs; i++)); do
    printf '.' >&2
    sleep 1
  done
  printf ' timeout after %ss\n' "$timeout_secs" >&2
fi

echo "contract:exit:124"
