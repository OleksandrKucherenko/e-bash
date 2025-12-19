#!/usr/bin/env bash

# Script to identify tests that still need conversion from BeforeCall to inline setup

set -euo pipefail

SPEC_FILE="spec/hooks_spec.sh"

echo "=== Tests still using BeforeCall 'setup' pattern ==="
echo

# Find all tests that use BeforeCall 'setup' pattern
grep -n -A 10 -B 2 "BeforeCall 'setup'" "$SPEC_FILE" | while IFS= read -r line; do
    if [[ $line =~ ^[0-9]+-.*It\ \'([^\']+)\' ]]; then
        test_name="${BASH_REMATCH[1]}"
        line_num="${line%%:*}"
        echo "Line $line_num: $test_name"
    fi
done

echo
echo "=== Tests already converted to inline setup ==="
echo

# Find tests that use the new pattern (test_* functions)
grep -n -A 5 -B 2 "test_.*() {" "$SPEC_FILE" | while IFS= read -r line; do
    if [[ $line =~ ^[0-9]+-.*It\ \'([^\']+)\' ]]; then
        test_name="${BASH_REMATCH[1]}"
        line_num="${line%%:*}"
        echo "Line $line_num: $test_name (✅ FIXED)"
    fi
done

echo
echo "=== Summary ==="
echo

total_beforecall=$(grep -c "BeforeCall 'setup'" "$SPEC_FILE" || echo "0")
total_converted=$(grep -c "test_.*() {" "$SPEC_FILE" || echo "0")

echo "Tests still needing conversion: $total_beforecall"
echo "Tests already converted: $total_converted"
echo
echo "To fix a test, convert the BeforeCall pattern to inline setup as shown in MACOS_CI_FIX_GUIDE.md"