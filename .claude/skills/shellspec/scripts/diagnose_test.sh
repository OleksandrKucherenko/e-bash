#!/usr/bin/env bash
# diagnose_test.sh - Quick diagnostic tool for ShellSpec test failures

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

spec_file="${1:-}"
line_number="${2:-}"

if [ -z "$spec_file" ]; then
  echo "Usage: $0 <spec_file> [line_number]"
  echo
  echo "Examples:"
  echo "  $0 spec/my_module_spec.sh"
  echo "  $0 spec/my_module_spec.sh 42"
  exit 1
fi

if [ ! -f "$spec_file" ]; then
  echo "Error: File not found: $spec_file"
  exit 1
fi

echo "═══════════════════════════════════════════════"
echo "  ShellSpec Test Diagnostics"
echo "═══════════════════════════════════════════════"
echo
echo "Analyzing: $spec_file"
[ -n "$line_number" ] && echo "Line: $line_number"
echo

test_target="$spec_file"
[ -n "$line_number" ] && test_target="$spec_file:$line_number"

# Step 1: Syntax Check
echo "─────────────────────────────────────────────────"
echo "1. Syntax Check"
echo "─────────────────────────────────────────────────"
if shellspec --syntax-check "$spec_file" 2>&1; then
  echo "✓ Spec syntax is valid"
else
  echo "✗ Syntax errors found - fix these first"
  exit 1
fi
echo

# Step 2: Dry Run
echo "─────────────────────────────────────────────────"
echo "2. Dry Run (what would execute)"
echo "─────────────────────────────────────────────────"
shellspec --dry-run "$test_target" 2>&1 | head -20
echo "... (showing first 20 lines)"
echo

# Step 3: Translation
echo "─────────────────────────────────────────────────"
echo "3. Translation (generated shell code)"
echo "─────────────────────────────────────────────────"
shellspec --translate "$spec_file" 2>&1 | head -30
echo "... (showing first 30 lines)"
echo

# Step 4: Run Test
echo "─────────────────────────────────────────────────"
echo "4. Running Test"
echo "─────────────────────────────────────────────────"
if shellspec "$test_target" 2>&1; then
  echo
  echo "✓ Test passed!"
  echo
  echo "If this was failing before:"
  echo "  - Check recent changes"
  echo "  - Verify not flaky (run multiple times)"
  echo "  - Check if fails with full suite"
else
  echo
  echo "✗ Test failed"
  echo
  echo "Next steps:"
  echo "  1. Run with trace: shellspec --xtrace $test_target"
  echo "  2. Add Dump directive after 'When call'"
  echo "  3. Check script has source guard"
  echo "  4. Verify all dependencies are mocked"
  echo "  5. Check for global state leakage"
fi
echo

# Step 5: Recommendations
echo "─────────────────────────────────────────────────"
echo "5. Quick Diagnostic Commands"
echo "─────────────────────────────────────────────────"
echo
echo "Run with execution trace:"
echo "  shellspec --xtrace $test_target"
echo
echo "Focus on this test:"
echo "  # Add 'f' prefix (fIt or fDescribe)"
echo "  shellspec --focus"
echo
echo "Run only failures:"
echo "  shellspec --quick"
echo
echo "Profile slow tests:"
echo "  shellspec --profile --profile-limit 10"
echo

echo "═══════════════════════════════════════════════"
echo "  Diagnostics Complete"
echo "═══════════════════════════════════════════════"
