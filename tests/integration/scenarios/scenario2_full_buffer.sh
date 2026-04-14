#!/usr/bin/env bash
# Scenario 2: Terminal buffer full, editor must appear at bottom
# Tests: when terminal is full of output, stream mode scrolls correctly
#        and allocates space at the bottom without glitching
#
# Expected flow:
#   1. Print 40 numbered lines to fill the terminal buffer
#   2. Print "Enter notes:" prompt
#   3. input:multi-line (stream, 5 lines) -> user types + Ctrl+D
#   4. Print captured text
#
# What pilotty verifies:
#   - Editor renders at bottom rows without corruption
#   - Previous output is scrolled up properly
#   - After save, output appears cleanly below

[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../../../.scripts" 2>&- && pwd); }
# shellcheck disable=SC1090,SC1091
source "$E_BASH/_commons.sh"

# Fill terminal buffer
for i in $(seq 1 40); do
  echo "Log line $i: $(date +%H:%M:%S) - Processing step $i of 40..."
done

echo ""
echo "Buffer filled. Enter your notes (Ctrl+D to save):"
notes=$(input:multi-line -m stream -h 5 --no-status)
notes_exit=$?

echo ""
if [[ $notes_exit -eq 0 ]]; then
  echo "OUTPUT_START"
  echo "$notes"
  echo "OUTPUT_END"
else
  echo "CANCELLED"
fi
sleep 2
