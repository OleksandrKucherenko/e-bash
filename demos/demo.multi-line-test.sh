#!/usr/bin/env bash
# shellcheck disable=SC2034
# Test harness for pilotty integration tests of input:multi-line

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Bootstrap
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

source "$E_BASH/_commons.sh"

mode=${1:-"stream"}
height=${2:-5}
width=${3:-40}
extra_args=${4:-""}

case "$mode" in
  stream)
    # shellcheck disable=SC2086
    text=$(input:multi-line -m stream -h "$height" --no-status $extra_args)
    ;;
  stream-status)
    # shellcheck disable=SC2086
    text=$(input:multi-line -m stream -h "$height" $extra_args)
    ;;
  box)
    # shellcheck disable=SC2086
    text=$(input:multi-line -m box -x 0 -y 0 -w "$width" -h "$height" $extra_args)
    ;;
  *)
    echo "Unknown mode: $mode" >&2
    exit 2
    ;;
esac
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
  printf "OUTPUT_START\n%s\nOUTPUT_END\n" "$text"
else
  echo "CANCELLED"
fi
exit $exit_code
