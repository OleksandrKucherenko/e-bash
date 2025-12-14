#!/usr/bin/env bash
#
# diagnose-shellmetrics-failure.sh - Diagnostic script for shellmetrics-compare.sh CI failures
#
# This script helps diagnose why shellmetrics-compare.sh might fail with exit code 1 in CI
#

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

echo "=================================="
echo "ShellMetrics CI Failure Diagnostics"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
  echo -e "${RED}✗${NC} $1"
}

check_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check if shellmetrics is installed
echo "1. Checking shellmetrics installation..."
if command -v shellmetrics >/dev/null 2>&1; then
  check_pass "shellmetrics is installed: $(which shellmetrics)"
  shellmetrics --help >/dev/null 2>&1 && check_pass "shellmetrics is executable"
else
  check_fail "shellmetrics is NOT installed"
  echo "   Install with: curl -fsSL https://raw.githubusercontent.com/shellspec/shellmetrics/master/shellmetrics > ~/.local/bin/shellmetrics && chmod +x ~/.local/bin/shellmetrics"
fi
echo ""

# 2. Check if shellmetrics-compare.sh exists
echo "2. Checking shellmetrics-compare.sh script..."
SCRIPT_PATH="./bin/shellmetrics-compare.sh"
if [ -f "$SCRIPT_PATH" ]; then
  check_pass "Script exists: $SCRIPT_PATH"
  if [ -x "$SCRIPT_PATH" ]; then
    check_pass "Script is executable"
  else
    check_warn "Script is not executable (might still work with bash)"
  fi
else
  check_fail "Script NOT found: $SCRIPT_PATH"
  exit 1
fi
echo ""

# 3. Check if there are shell scripts to analyze
echo "3. Checking for shell scripts in project..."
SCRIPT_COUNT=0

if [ -d ".scripts" ]; then
  COUNT=$(find .scripts -type f -name "*.sh" 2>/dev/null | wc -l)
  SCRIPT_COUNT=$((SCRIPT_COUNT + COUNT))
  if [ "$COUNT" -gt 0 ]; then
    check_pass "Found $COUNT shell scripts in .scripts/"
  else
    check_warn "No .sh files in .scripts/"
  fi
fi

if [ -d "bin" ]; then
  COUNT=$(find bin -type f -executable 2>/dev/null | while read -r script; do
    if head -n 1 "$script" 2>/dev/null | grep -qE '^#!/.*/(bash|sh|zsh|ksh)'; then
      echo "$script"
    fi
  done | wc -l)
  SCRIPT_COUNT=$((SCRIPT_COUNT + COUNT))
  if [ "$COUNT" -gt 0 ]; then
    check_pass "Found $COUNT shell scripts in bin/"
  else
    check_warn "No executable shell scripts in bin/"
  fi
fi

if [ "$SCRIPT_COUNT" -eq 0 ]; then
  check_fail "No shell scripts found to analyze!"
  echo "   Metrics collection will create empty CSV"
else
  check_pass "Total shell scripts found: $SCRIPT_COUNT"
fi
echo ""

# 4. Test collect command
echo "4. Testing 'collect' command..."
TEST_OUTPUT="/tmp/test-metrics-$$.csv"
if $SCRIPT_PATH collect "$TEST_OUTPUT" 2>&1; then
  check_pass "Collect command succeeded"
  
  if [ -f "$TEST_OUTPUT" ]; then
    check_pass "Output file created: $TEST_OUTPUT"
    
    LINE_COUNT=$(wc -l < "$TEST_OUTPUT")
    if [ "$LINE_COUNT" -gt 1 ]; then
      check_pass "CSV has $LINE_COUNT lines (including header)"
    elif [ "$LINE_COUNT" -eq 1 ]; then
      check_warn "CSV only has header (no metrics collected)"
    else
      check_fail "CSV is empty"
    fi
    
    # Check CSV format
    if head -n 1 "$TEST_OUTPUT" | grep -q "file,func,lineno,lloc,ccn,lines,comment,blank"; then
      check_pass "CSV header format is correct"
    else
      check_fail "CSV header format is incorrect"
      echo "   Expected: file,func,lineno,lloc,ccn,lines,comment,blank"
      echo "   Got: $(head -n 1 "$TEST_OUTPUT")"
    fi
  else
    check_fail "Output file was not created"
  fi
else
  check_fail "Collect command failed with exit code $?"
fi
echo ""

# 5. Test compare command with mock data
echo "5. Testing 'compare' command..."
BASE_CSV="/tmp/base-test-$$.csv"
CURRENT_CSV="/tmp/current-test-$$.csv"
REPORT_MD="/tmp/report-test-$$.md"

# Create mock CSVs
cat > "$BASE_CSV" <<'CSV'
file,func,lineno,lloc,ccn,lines,comment,blank
".scripts/test.sh","<begin>",1,0,0,50,5,2
".scripts/test.sh","func1",10,10,1,15,0,0
".scripts/test.sh","<end>",50,0,0,50,5,2
CSV

cat > "$CURRENT_CSV" <<'CSV'
file,func,lineno,lloc,ccn,lines,comment,blank
".scripts/test.sh","<begin>",1,0,0,60,6,3
".scripts/test.sh","func1",10,15,2,20,0,0
".scripts/test.sh","<end>",60,0,0,60,6,3
CSV

if $SCRIPT_PATH compare "$BASE_CSV" "$CURRENT_CSV" "$REPORT_MD" 2>&1; then
  check_pass "Compare command succeeded"
  
  if [ -f "$REPORT_MD" ]; then
    check_pass "Report file created: $REPORT_MD"
    
    if grep -q "ShellMetrics Code Complexity Report" "$REPORT_MD"; then
      check_pass "Report contains expected header"
    else
      check_fail "Report doesn't contain expected header"
    fi
  else
    check_fail "Report file was not created"
  fi
else
  check_fail "Compare command failed with exit code $?"
fi
echo ""

# 6. Simulate CI scenario
echo "6. Simulating CI workflow scenario..."

# Check for git repository
if git rev-parse --git-dir >/dev/null 2>&1; then
  check_pass "Running in git repository"
  
  # Try to simulate worktree scenario
  if git rev-parse origin/master >/dev/null 2>&1; then
    check_pass "origin/master branch exists"
    
    # Check if we can create a worktree
    TEST_WORKTREE="/tmp/test-worktree-$$"
    if git worktree add --detach "$TEST_WORKTREE" origin/master 2>&1; then
      check_pass "Created test worktree: $TEST_WORKTREE"
      
      # Copy script to worktree
      cp "$SCRIPT_PATH" "$TEST_WORKTREE/"
      
      # Try to collect metrics from worktree
      cd "$TEST_WORKTREE"
      if ./shellmetrics-compare.sh collect /tmp/worktree-metrics-$$.csv 2>&1; then
        check_pass "Collected metrics from worktree"
      else
        check_fail "Failed to collect metrics from worktree (exit code $?)"
        echo "   This might be the CI failure - script may not exist in base branch"
      fi
      cd - >/dev/null
      
      # Cleanup worktree
      git worktree remove --force "$TEST_WORKTREE" 2>/dev/null || true
    else
      check_warn "Could not create test worktree"
    fi
  else
    check_warn "origin/master branch not found (might be 'main' instead)"
  fi
else
  check_warn "Not in a git repository (can't test worktree scenario)"
fi
echo ""

# 7. Check for common issues
echo "7. Checking for common issues..."

# Check PATH
if echo "$PATH" | grep -q "$HOME/.local/bin"; then
  check_pass "\$HOME/.local/bin is in PATH"
else
  check_warn "\$HOME/.local/bin is NOT in PATH (might affect shellmetrics)"
  echo "   Add with: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Check for required tools
for tool in awk sed grep find; do
  if command -v "$tool" >/dev/null 2>&1; then
    check_pass "$tool is available"
  else
    check_fail "$tool is NOT available"
  fi
done
echo ""

# 8. Cleanup
echo "8. Cleaning up temporary files..."
rm -f "$TEST_OUTPUT" "$BASE_CSV" "$CURRENT_CSV" "$REPORT_MD" || true
check_pass "Cleanup complete"
echo ""

# Summary
echo "=================================="
echo "Diagnosis Complete"
echo "=================================="
echo ""
echo "If all checks passed, the script should work in CI."
echo "If any checks failed, review the errors above."
echo ""
echo "Common CI failure causes:"
echo "1. shellmetrics not installed before running script"
echo "2. Base branch doesn't have shellmetrics-compare.sh"
echo "3. No shell scripts to analyze (empty CSV)"
echo "4. File path issues (/tmp vs working directory)"
echo "5. Missing required tools (awk, sed, grep)"
echo ""
