#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-06
## Version: 0.1.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

export DEBUG=${DEBUG:-"-loader,-parser,-common"}

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }

export SKIP_ARGS_PARSING=1

# pre-declare variables to make shellcheck happy
declare help version verbose output format completion install_completion

ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" -v,--version=version:1.0.0"
ARGS_DEFINITION+=" --verbose"
ARGS_DEFINITION+=" -o,--output=output::1"
ARGS_DEFINITION+=" -f,--format=format:text:1"

# shellcheck disable=SC1090 source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

parse:arguments "$@"

# Register descriptions for help and completion
args:d "-h" "Show help and exit." "global"
args:d "-v" "Show version and exit." "global"
args:d "--verbose" "Enable verbose output." "global"
args:d "--completion" "Print shell completion script (bash or zsh)." "global"
args:d "--install-completion" "Install shell completion to system directory." "global"
args:d "-o" "Output file path." "options"
args:d "-f" "Output format (text, json, csv)." "options"

# auto-dispatch --version, --debug, --completion, --install-completion
args:dispatch

if [[ "$help" == "1" ]]; then
  echo "demo.completion.sh - demonstrates completion generation from ARGS_DEFINITION"
  echo ""
  echo "Usage: demos/demo.completion.sh [flags]"
  echo ""
  print:help
  exit 0
fi

cat <<OUTPUT
Demo completion script
  version: ${version}
  verbose: ${verbose}
  output:  ${output}
  format:  ${format}

Samples:
  demos/demo.completion.sh --help
  demos/demo.completion.sh --verbose -o result.txt -f json

Completion (auto-dispatched by args:dispatch):
  demos/demo.completion.sh --completion bash
  demos/demo.completion.sh --completion zsh
  demos/demo.completion.sh --install-completion bash
  demos/demo.completion.sh --install-completion zsh

Or use the API directly (after sourcing _arguments.sh):
  args:completion:install bash demo.completion.sh    # auto-install
  args:completion bash demo.completion.sh            # print to stdout
OUTPUT
