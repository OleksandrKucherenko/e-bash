#!/bin/bash
# strip_colors.sh - Remove ANSI escape codes from input
#
# Usage: 
#   echo "colored text" | ./strip_colors.sh
#   ./strip_colors.sh < file.txt
#   ./strip_colors.sh "string with colors"
#
# Use in BATS tests:
#   run colorful_command
#   clean_output=$(echo "$output" | ./strip_colors.sh)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


if [ -n "$1" ]; then
    # Argument provided
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
else
    # Read from stdin
    sed 's/\x1b\[[0-9;]*m//g'
fi
