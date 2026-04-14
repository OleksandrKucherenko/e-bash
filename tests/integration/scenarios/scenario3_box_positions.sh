#!/usr/bin/env bash
# Scenario 3: Box mode at various positions
# Tests: explicit box positioning, clean render and restore
#
# Takes position as argument: "top" "center" "bottom"
#
# What pilotty verifies:
#   - Box renders at correct terminal position
#   - Content outside the box area is not corrupted
#   - After save, box area is cleaned up

[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../../../.scripts" 2>&- && pwd); }
# shellcheck disable=SC1090,SC1091
source "$E_BASH/_commons.sh"

position=${1:-"top"}
term_h=$(tput lines 2>/dev/null || echo 24)
term_w=$(tput cols 2>/dev/null || echo 80)

box_w=40
box_h=6

case "$position" in
  top)
    box_x=2
    box_y=1
    ;;
  center)
    box_x=$(( (term_w - box_w) / 2 ))
    box_y=$(( (term_h - box_h) / 2 ))
    ;;
  bottom)
    box_x=2
    box_y=$(( term_h - box_h - 2 ))
    ;;
  *)
    box_x=0
    box_y=0
    ;;
esac

# Draw background pattern so we can detect corruption
for row in $(seq 1 "$term_h"); do
  printf "\033[%d;1H" "$row"
  printf "%-${term_w}s" "$(printf '.%.0s' $(seq 1 "$term_w"))"
done
printf "\033[1;1H" >&2
echo "Box at ($box_x,$box_y) ${box_w}x${box_h} - position: $position" >&2

text=$(input:multi-line -m box -x "$box_x" -y "$box_y" -w "$box_w" -h "$box_h")
exit_code=$?

# Move below the box area for output
printf "\033[%d;1H" "$((box_y + box_h + 2))" >&2
if [[ $exit_code -eq 0 ]]; then
  echo "OUTPUT_START"
  echo "$text"
  echo "OUTPUT_END"
else
  echo "CANCELLED"
fi
sleep 2
