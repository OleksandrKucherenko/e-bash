#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2024-01-02
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=loader

# pattern: "{argument},-{short},--{alias}={output_variable}:{default_initialize_value}:{reserved_args_quantity}"
ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" --version=version:1.0.0"
ARGS_DEFINITION+=" -i,--init,--initialize=args_init"
ARGS_DEFINITION+=" -n,--new,--new-environment=args_new::1"
ARGS_DEFINITION+=" -s,--switch=args_switch::1"

# shellcheck source=../.scripts/_colors.sh
# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)/.scripts"
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$scripts_dir/_arguments.sh"

# compose help instructions
args:d '-h' 'Show help and exit.'
args:d '--version' 'Show version and exit.'
args:d '-i' 'Initialize the environment.'
args:d '-n' 'Create a new environment.'
args:d '-s' 'Switch to another environment.'
args:d "--debug" "Force debug output of the tool;" "global"
args:e "--debug" "DEBUG=*"
args:v "--debug" "<empty>"

# print help instructions
print:help

echo "Call Arguments:"
echo "  -h, --help: $help"
echo "  --version: $version"
echo "  -i, --init: $args_init"
echo "  -n, --new: $args_new"
echo "  -s, --switch: $args_switch"