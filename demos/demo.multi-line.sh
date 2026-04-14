#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-12
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
#           Ctrl+E readline edit, Ctrl+W delete word, Ctrl+U delete line, Tab inserts 2 spaces
#           Page Up/Down to scroll, --alt-buffer preserves scroll history
# Modes: box (default, explicit positioning) or stream (cursor-based, inline)
# Paste: bracketed paste (Ctrl+V via terminal) and clipboard paste (Ctrl+V via xclip/pbpaste)

mode=${1:-"box"}

if [[ "$mode" == "stream" ]]; then
  echo "Stream mode demo (cursor-based, 5-line editor):"
  echo "Features: auto-detects cursor position, scrolls if at terminal bottom"
  text=$(input:multi-line -m stream -h 5)
else
  echo "Box mode demo (Ctrl+D to save, Esc to cancel):"
  echo "Features: status bar, Ctrl+E readline edit, Page Up/Down, resize handling"
  echo "---"
  text=$(input:multi-line -x 10 -y 10  -w 60 -h 10)
fi
exit_code=$?

echo "---"
if [[ $exit_code -eq 0 ]]; then
  echo "Captured text:"
  echo "$text"
else
  echo "Input cancelled."
fi
