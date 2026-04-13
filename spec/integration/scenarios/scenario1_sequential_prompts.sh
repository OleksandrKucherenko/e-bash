#!/usr/bin/env bash
# Scenario 1: Sequential Q&A prompts followed by multiline editor
# Tests: editor appears below prompts, no overlap, clean output after save
#
# Expected flow:
#   1. Show "Project Setup" header
#   2. read: "Project name: " -> user types name + Enter
#   3. read: "Author: " -> user types author + Enter
#   4. echo "Enter description:"
#   5. input:multi-line (stream, 4 lines) -> user types + Ctrl+D
#   6. echo summary of all captured values
#
# What pilotty verifies:
#   - Prompts 1-3 remain visible while editor is open
#   - Editor renders on correct row (below prompts)
#   - After save, summary prints below without overwriting prompts

[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../../../.scripts" 2>&- && pwd); }
# shellcheck disable=SC1090,SC1091
source "$E_BASH/_commons.sh"

echo "=== Project Setup ==="
echo ""

# Simple read prompts
read -rp "Project name: " project_name
read -rp "Author: " author

echo ""
echo "Enter description (Ctrl+D to save):"
description=$(input:multi-line -m stream -h 4 --no-status)
desc_exit=$?

echo ""
echo "--- Summary ---"
echo "Name: $project_name"
echo "Author: $author"
if [[ $desc_exit -eq 0 ]]; then
  echo "Description: $description"
else
  echo "Description: (cancelled)"
fi
echo "--- Done ---"
sleep 2
