#!/usr/bin/env bash
# Scenario 4: Wizard-style modal dialog — multiple sequential editors
# Tests: each editor saves cleanly, output from previous remains visible,
#        no position drift between steps
#
# Expected flow:
#   Step 1: "Enter name" (stream, 1 line editor)
#   Step 2: "Enter description" (stream, 3 line editor)
#   Step 3: "Enter notes" (stream, 3 line editor)
#   Final: print all captured values as summary
#
# What pilotty verifies:
#   - Each step label remains visible
#   - No overlap or position drift between steps
#   - All three values captured correctly

[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../../../.scripts" 2>&- && pwd); }
# shellcheck disable=SC1090,SC1091
source "$E_BASH/_commons.sh"

echo "=== Configuration Wizard ==="
echo ""

# Step 1
echo "Step 1/3: Enter component name (Ctrl+D to confirm):"
name=$(input:multi-line -m stream -h 1 --no-status)
name_exit=$?
[[ $name_exit -ne 0 ]] && { echo "Wizard cancelled at step 1"; sleep 1; exit 1; }
echo "  -> Name: $name"
echo ""

# Step 2
echo "Step 2/3: Enter description (Ctrl+D to confirm):"
desc=$(input:multi-line -m stream -h 3 --no-status)
desc_exit=$?
[[ $desc_exit -ne 0 ]] && { echo "Wizard cancelled at step 2"; sleep 1; exit 1; }
echo "  -> Description: $desc"
echo ""

# Step 3
echo "Step 3/3: Enter additional notes (Ctrl+D to confirm):"
notes=$(input:multi-line -m stream -h 3 --no-status)
notes_exit=$?
[[ $notes_exit -ne 0 ]] && { echo "Wizard cancelled at step 3"; sleep 1; exit 1; }
echo "  -> Notes: $notes"
echo ""

echo "=== Wizard Complete ==="
echo "RESULT_NAME:$name"
echo "RESULT_DESC:$desc"
echo "RESULT_NOTES:$notes"
echo "=== END ==="
sleep 2
