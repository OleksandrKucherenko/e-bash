#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-31
## Version: 0.1.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

export DEBUG=${DEBUG:-"demo-curl,-loader,-parser,-common"}

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || {
  _src=${BASH_SOURCE:-$0}
  E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts)
  readonly E_BASH
}

export SKIP_ARGS_PARSING=1

# shellcheck disable=SC1090 source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

# pre-declare variables to make shellcheck happy
declare help request header data url verbose args_command

ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" -X,--request=request::1"
ARGS_DEFINITION+=" -H,--header=header::1"
ARGS_DEFINITION+=" -d,--data=data::1"
ARGS_DEFINITION+=" --url=url::1"
ARGS_DEFINITION+=" -v,--verbose"
ARGS_DEFINITION+=" \$1,<command>=args_command:dummy:1"

function demo:completion:emit() {
  local args_qt="" flag="" idx="" keys="" key=""
  local -a flags=() value_flags=() commands=() request_enum=()

  parse:mapping

  for flag in "${!lookup_arguments[@]}"; do
    [[ "$flag" == \$* ]] && continue
    flags+=("$flag")
  done

  for idx in "${!index_to_args_qt[@]}"; do
    args_qt="${index_to_args_qt[$idx]}"
    [[ "$args_qt" -gt 0 ]] || continue
    keys="${index_to_keys[$idx]}"
    for key in $keys; do
      value_flags+=("$key")
    done
  done

  IFS=$'\n' flags=($(printf '%s\n' "${flags[@]}" | sort -u))
  IFS=$'\n' value_flags=($(printf '%s\n' "${value_flags[@]}" | sort -u))

  commands=(get post head put delete)
  request_enum=(GET POST PUT DELETE HEAD)

  echo "FLAGS=${flags[*]}"
  echo "VALUE_FLAGS=${value_flags[*]}"
  echo "COMMANDS=${commands[*]}"
  echo "REQUEST_ENUM=${request_enum[*]}"
}

if [[ "$1" == "--completion-data" ]]; then
  demo:completion:emit
  exit 0
fi

parse:arguments "$@"

# register commands and flags for help output
args:d "\$1" "HTTP subcommand (get/post/head/put/delete)." "commands" 1

args:d "-h" "Show help and exit." "global"
args:d "-X" "HTTP method (overrides subcommand)." "global"
args:d "-H" "Add request header." "global"
args:d "-d" "Request body data." "global"
args:d "--url" "Request URL (optional if positional URL used)." "global"
args:d "-v" "Enable verbose output." "global"

args:v "-X" "GET"

if [[ "$help" == "1" ]]; then
  echo "demo.curl.sh - mock curl-like CLI for completion testing"
  echo ""
  echo "Usage: demos/demo.curl.sh [global flags] <command> [flags]"
  echo ""
  print:help
  exit 0
fi

cat <<OUTPUT
Demo curl-like command
  command: ${args_command}
  request: ${request}
  header:  ${header}
  data:    ${data}
  url:     ${url}
  verbose: ${verbose}
OUTPUT

cat <<'SAMPLES'
Samples:
  demos/demo.curl.sh get --url https://example.test
  demos/demo.curl.sh post -X POST -d '{"a":1}' --url https://example.test
  demos/demo.curl.sh head -H 'Accept: */*' --url https://example.test

Completion data:
  demos/demo.curl.sh --completion-data
SAMPLES
