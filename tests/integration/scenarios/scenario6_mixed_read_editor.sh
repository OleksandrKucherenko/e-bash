#!/usr/bin/env bash
# Scenario 6: Mixed read + editor + read + editor (alternating)
# Tests: repeated transitions between simple read and multiline editor
#        with output interspersed - verifies no state leakage between calls
#
# Expected flow:
#   1. read: "Username: " -> user types
#   2. editor: "Bio:" (stream, 2 lines) -> user types + Ctrl+D
#   3. read: "Email: " -> user types
#   4. editor: "SSH Key:" (stream, 3 lines) -> user types + Ctrl+D
#   5. Print summary

[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../../../.scripts" 2>&- && pwd); }
# shellcheck disable=SC1090,SC1091
source "$E_BASH/_commons.sh"

echo "=== User Profile Setup ==="
echo ""

read -rp "Username: " username
echo ""

echo "Enter bio (Ctrl+D to save):"
bio=$(input:multi-line -m stream -h 2 --no-status)
echo "  Bio saved."
echo ""

read -rp "Email: " email
echo ""

echo "Paste SSH public key (Ctrl+D to save):"
sshkey=$(input:multi-line -m stream -h 3 --no-status)
echo "  Key saved."
echo ""

echo "=== Profile Summary ==="
echo "RESULT_USER:$username"
echo "RESULT_BIO:$bio"
echo "RESULT_EMAIL:$email"
echo "RESULT_KEY:$sshkey"
echo "=== END ==="
sleep 2
