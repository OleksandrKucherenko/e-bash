#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-11
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# include other scripts: _colors, _logger, _commons
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_commons.sh"

# Usage: multi-line text editor with configurable dimensions
# Controls: Arrow keys to navigate, Enter for newline, Ctrl+D to save, Esc to cancel
#           Ctrl+W delete word, Ctrl+U delete line, Tab inserts 2 spaces
#           paste via terminal paste (bracketed paste supported)

mode="${1:-box}"

echo "Multi-line editor demo [mode=${mode}] (Ctrl+D to save, Esc to cancel):"
echo "---"

if [[ "$mode" == "stream" ]]; then
  text=$(input:multi-line -m stream -h 5)
elif [[ "$mode" == "box" ]]; then
  text=$(input:multi-line -m box -x 10 -y 10 -w 60 -h 10)
else
  echo "Unknown mode: '$mode' (use: box|stream)" >&2
  exit 2
fi
exit_code=$?

echo "---"
if [[ $exit_code -eq 0 ]]; then
  echo "Captured text:"
  echo "$text"
else
  echo "Input cancelled."
fi
