#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


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
