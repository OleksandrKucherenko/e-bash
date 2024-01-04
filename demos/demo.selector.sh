#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.scripts"
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$scripts_dir/_commons.sh"

# Usage:
declare -A -g connections && connections=(["d"]="production" ["s"]="cors-proxy-staging" ["p"]="cors-proxy-local")
echo -n "Select connection type: " && tput civis # hide cursor
selected=$(input:selector "connections") && echo "${cl_blue}$selected${cl_reset}"
