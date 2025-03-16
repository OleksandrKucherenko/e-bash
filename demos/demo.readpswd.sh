#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_commons.sh"

# Usage:
echo -n "Enter password: "
password=$(input:readpwd) && echo "" && echo "Password: $password"
