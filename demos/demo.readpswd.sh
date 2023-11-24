#!/usr/bin/env bash
# shellcheck disable=SC2034

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.scripts"
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$scripts_dir/_commons.sh"

# Usage:
echo -n "Enter password: "
password=$(input:readpwd) && echo "" && echo "Password: $password"
