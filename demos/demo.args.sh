#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

export DEBUG=${DEBUG:-"-loader,-parser,-common"}

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

export SKIP_ARGS_PARSING=1 # skip initial parsing of arguments during script loading

# pre-declare variables to make shellcheck happy
declare help version \
  args_init args_pno args_new args_switch \
  args_command args_sub_command args_subsub_command

# pattern: "{argument_index},-{short},--{alias}={output_variable}:{default_initialize_value}:{reserved_args_quantity}"
ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" --version=version:1.0.0"
ARGS_DEFINITION+=" -d,--debug=DEBUG:demo"
ARGS_DEFINITION+=" -i,--init,--initialize=args_init"
ARGS_DEFINITION+=" -n,--new,--new-environment=args_new::1"
#ARGS_DEFINITION+=" -s,--switch=args_switch::1"
ARGS_DEFINITION+=" --id=args_pno::1"
ARGS_DEFINITION+=" \$1,<command>=args_command:dummy:1"
ARGS_DEFINITION+=" \$2,[sub-command]=args_sub_command:sub_dummy:1"
ARGS_DEFINITION+=" \$3,<sub-sub-command>=args_subsub_command:sub_sub_dummy:1"

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck source=../.scripts/_colors.sh
source /dev/null

# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_arguments.sh"

# args:i HELP -a "-h,--help" -h "Show help and exit."                                          # expected "-h,--help=HELP"
# args:i help -a "-h,--help" -h "Show help and exit."                                          # expected "-h,--help"
# args:i COMMAND -a "\$1,-c,--position,--command" -h "First positional argument as a command." # expected "\$1,-c,--position,--command=COMMAND"
# args:i COMMAND -a "\$1" -a "-c" -a ",--command" -h "First positional argument as a command." # expected "\$1,-c,--command=COMMAND"
# args:i version -a "--version" -d "1.0.0" -h "Show version and exit."
# args:i args_switch -a "-s,--switch" -q 1 -h "Switch to another environment."

# inject argument defintion into ARGS_DEFINITION via composer
COMPOSER="$(args:i args_switch -a "-s,--switch" -q 1 -h "Switch to another environment.")"
eval "$COMPOSER"

parse:arguments "$@" # time to parse arguments

logger "demo" "$@"
logger:redirect "demo" ">&2"
logger:prefix "demo" "[${cl_grey}demo${cl_reset}] "

# register commands as a group/collection
args:d "\$1" "Main command." "commands" 1
args:d "\$2" "Sub-command." "commands"
args:d "\$3" "More nested level of sub-commands." "commands"

# compose help instructions, use the shortest name as identifier
args:d '-h' 'Show help and exit.' "global"
args:d '--version' 'Show version and exit.' "global" 2
args:d '-s' 'Switch to another environment.'

args:d '-i' 'Initialize the environment.'
args:e '-i' 'PROJECT_NAME'

args:d '-n' 'Create a new environment.'
args:v '-s' 'staging'

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
args:e "--debug" "DEBUG=demo"
args:v "--debug" "<empty>"

# print help instructions
[[ "$help" == "1" ]] && {
  echo "${BASH_SOURCE[0]} - Demo application of arguments parsing."
  echo ""
  echo "Usage: ${BASH_SOURCE[0]} [global's] [command] [subcommand] [subsubcommand] [flags/options]"
  echo ""
  print:help
  # developer decide what to do next, or exit or continue
}

echo "Definitions: ${cl_red}$(echo "${ARGS_DEFINITION}" | sed 's/ /\n\t/g')${cl_reset}"
echo ""
echo "Parsed call arguments/options:"
echo "  -h, --help: $help"
echo "  --version: $version"
echo "  -i, --init: $args_init"
echo "  -n, --new: $args_new"
echo "  -s, --switch: $args_switch"
echo "  --id: $args_pno"
echo "  <1-3>: 1:$args_command 2:$args_sub_command 3:$args_subsub_command"
echo "  DEBUG: $DEBUG"

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
echo "  DEBUG=- demos/demo.args.sh try   # no logs"
echo ""
echo "Special cases:"
echo "  demos/demo.args.sh --id=            # <empty> value"
echo "  demos/demo.args.sh first -- second  # -- is ignored"
echo "  demos/demo.args.sh -ih              # -h and -i combined but not recognised"
