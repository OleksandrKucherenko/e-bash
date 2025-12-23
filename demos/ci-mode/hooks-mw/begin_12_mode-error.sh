#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_12_mode-error.sh (exec mode)
## Purpose: Handle ERROR mode - exit parent with specified error code

script_name="${1:-unknown}"
script_name_safe="${script_name//[^a-zA-Z0-9_]/_}"
mode_var="HOOKS_FLOW_MODE_${script_name_safe}"
mode="${!mode_var:-${HOOKS_FLOW_MODE:-EXEC}}"

[[ "$mode" != "ERROR" ]] && exit 0

error_code="${HOOKS_FLOW_ERROR_CODE:-1}"
echo "contract:exit:${error_code}"
