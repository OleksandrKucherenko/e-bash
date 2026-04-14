#!/usr/bin/env bash
# Scenario 5: Stream editor after partial-line prompt (no trailing newline)
# Tests: editor starts on the correct row, doesn't overwrite prompt prefix
#
# Expected flow:
#   1. printf "Message: " (no newline — cursor stays on the line)
#   2. input:multi-line (stream, 3 lines)
#   3. echo captured text
#
# What pilotty verifies:
#   - "Message: " prompt remains visible
#   - Editor starts on the row below (or same row without corruption)
#   - Captured text is correct

[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../../../.scripts" 2>&- && pwd); }
# shellcheck disable=SC1090,SC1091
source "$E_BASH/_commons.sh"

echo "=== Inline Prompt Test ==="
echo ""

# Partial line — no trailing newline
printf "Message: "

# Editor should appear on next row (stream mode queries cursor position)
text=$(input:multi-line -m stream -h 3 --no-status)
exit_code=$?

echo ""
if [[ $exit_code -eq 0 ]]; then
  echo "OUTPUT_START"
  echo "$text"
  echo "OUTPUT_END"
else
  echo "CANCELLED"
fi
sleep 2
