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
declare help version verbose output format

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
args:d "-o" "Output file path." "options"
args:d "-f" "Output format (text, json, csv)." "options"

if [[ "$help" == "1" ]]; then
  echo "demo.completion.sh - demonstrates completion generation from ARGS_DEFINITION"
  echo ""
  echo "Usage: demos/demo.completion.sh [flags]"
  echo ""
  print:help
  echo "Completion generation:"
  echo "  demos/demo.completion.sh --generate-completion bash"
  echo "  demos/demo.completion.sh --generate-completion zsh"
  exit 0
fi

# Handle --generate-completion (manual check since it's meta, not part of ARGS_DEFINITION)
for arg in "$@"; do
  if [[ "$arg" == "--generate-completion" ]]; then
    shift
    shell_type="${1:-bash}"
    args:completion "$shell_type" "demo.completion.sh"
    exit 0
  fi
done

cat <<OUTPUT
Demo completion script
  version: ${version}
  verbose: ${verbose}
  output:  ${output}
  format:  ${format}

Samples:
  demos/demo.completion.sh --help
  demos/demo.completion.sh --verbose -o result.txt -f json

Generate completion scripts:
  demos/demo.completion.sh --generate-completion bash > ~/.local/share/bash-completion/completions/demo.completion.sh
  demos/demo.completion.sh --generate-completion zsh  > ~/.zsh/completion/_demo_completion

Or use args:completion directly (after sourcing _arguments.sh):
  args:completion bash demo.completion.sh
  args:completion zsh demo.completion.sh /path/to/_demo_completion
OUTPUT
