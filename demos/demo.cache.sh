#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-15
## Version: 2.0.14
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck source=../.scripts/_colors.sh
source /dev/null # trick to make shellcheck happy
# shellcheck source=../.scripts/_commons.sh
source /dev/null # trick to make shellcheck happy
# shellcheck source=../.scripts/_logger.sh
source /dev/null # trick to make shellcheck happy
# shellcheck source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"

logger:init dbg "${cl_gray}[dbg]${cl_reset} " # no prefix, to stderr

# Cache commands using bkt if installed
# https://github.com/dimo414/bkt
dependency bkt "0.8.*" "brew install bkt" 1>&2 || {
  # If bkt isn't installed skip its arguments and just execute directly.
  bkt() {
    echo:Ver "bkt: ${cl_gray}$@${cl_reset}"
    while [[ "$1" == --* ]]; do shift; done
    "$@"
  }
  echo:Dbg "${cl_grey}bkt is not installed. Fallback to bkt fake wrapper (no caching).${cl_reset}"
}

bkt --ttl=1m -- dig google.com
