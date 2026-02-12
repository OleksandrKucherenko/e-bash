#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-11
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_commons.sh"

# Usage: Captures keypresses and shows their semantic tokens, hex bytes,
#        and bash literal representation. Useful for configuring ML_KEY_*
#        environment variables for input:multi-line keybindings.
#
# Example output:
#   Token                    Hex                      Bash literal
#   ctrl-up                  1b5b313b3541             $'\x1b\x5b\x31\x3b\x35\x41'
#   shift-f5                 1b5b31353b327e           $'\x1b\x5b\x31\x35\x3b\x32\x7e'
#   alt-a                    1b61                     $'\x1b\x61'

echo "Key Capture Diagnostic Tool"
echo "Press any key combination to see its token, hex bytes, and bash literal."
echo "Press Ctrl+D to exit."
echo ""

_input:capture-key
