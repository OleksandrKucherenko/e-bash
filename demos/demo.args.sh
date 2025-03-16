#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

export DEBUG="-loader,common"

# pattern: "{argument_index},-{short},--{alias}={output_variable}:{default_initialize_value}:{reserved_args_quantity}"
ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" --version=version:1.0.0"
ARGS_DEFINITION+=" -i,--init,--initialize=args_init"
ARGS_DEFINITION+=" -n,--new,--new-environment=args_new::1"
ARGS_DEFINITION+=" -s,--switch=args_switch::1"
ARGS_DEFINITION+=" \$1,-c,--command=args_command:dummy:1"
ARGS_DEFINITION+=" \$2,--sub-command=args_sub_command:sub_dummy:1"
ARGS_DEFINITION+=" -d,--debug=DEBUG:*"

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck source=../.scripts/_colors.sh
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_arguments.sh"

logger "demo" "$@"
logger:redirect "demo" ">&2"
logger:prefix "demo" "[${cl_grey}demo${cl_reset}] "

# compose help instructions
args:d '-h' 'Show help and exit.'
args:d '--version' 'Show version and exit.' "global"
args:d '-i' 'Initialize the environment.'
args:d '-n' 'Create a new environment.'
args:d '-s' 'Switch to another environment.'

# configure in pipe
# WARNING: pipe force execution in sub-shell, which makes all changes
#   isolated in own scope and lost. That is why pipeline should be used
#   only for composing the temporary state.
args:d '-s' 'Switch to another environment (pipe).' | (
  read -r -t 0.1 flag
  echo:Demo "pipeline provides: $flag (${cl_lblue}${st_i}only ${st_b}visible${st_no_b} when ${st_u}--debug${st_no_u} set${cl_reset})"
)

args:d "--debug" "Force debug output of the tool;" "global"

# specify environment variable, defaults and description of the "--debug" argument
args:e "--debug" "DEBUG=*"
args:v "--debug" "<empty>"

# print help instructions
[[ "$help" == "1" ]] && {
  echo ""
  print:help
}

echo "Parsed call arguments/options:"
echo "  -h, --help: $help"
echo "  --version: $version"
echo "  -i, --init: $args_init"
echo "  -n, --new: $args_new"
echo "  -s, --switch: $args_switch"
echo "  <1,2>: $args_command $args_sub_command"

# Examples how to use:
echo ""
echo "Samples:"
echo "  demos/demo.args.sh --debug       # enable debug output"
echo "  demos/demo.args.sh --version     # predefined value"
echo "  demos/demo.args.sh -h            # ask for help"
echo "  demos/demo.args.sh -i            # boolean flag/option"
echo "  demos/demo.args.sh -n test       # create new environment"
echo "  demos/demo.args.sh -s one -s two # override argument by second value"
echo "  demos/demo.args.sh try           # positional argument as a command"
echo "  demos/demo.args.sh try sub       # command with sub-command"
