#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_11_mode-ok.sh (exec mode)
## Purpose: Handle OK mode - no-op, exit parent with success

script_name="${1:-unknown}"
script_name_safe="${script_name//[^a-zA-Z0-9_]/_}"
mode_var="HOOKS_FLOW_MODE_${script_name_safe}"
mode="${!mode_var:-${HOOKS_FLOW_MODE:-EXEC}}"

[[ "$mode" != "OK" ]] && exit 0

echo "contract:exit:0"
