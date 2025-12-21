#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Hook: begin_15_mode-test.sh (exec mode)
## Purpose: Handle TEST mode - run mock script instead

script_name="${1:-unknown}"
script_name_safe="${script_name//[^a-zA-Z0-9_]/_}"
mode_var="HOOKS_FLOW_MODE_${script_name_safe}"
mode="${!mode_var:-${HOOKS_FLOW_MODE:-EXEC}}"

[[ -f "$mode" ]] || exit 0

echo "contract:route:${mode}"
