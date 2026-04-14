#!/usr/bin/env bash
# Scenario integration tests for input:multi-line using pilotty
# Tests real-world usage patterns: sequential prompts, full buffer,
# box positioning, wizard dialogs, mixed read+editor workflows.
#
# Requires: pilotty (npm install -g pilotty)

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
E_BASH="$PROJECT_DIR/.scripts"
SDIR="$SCRIPT_DIR/scenarios"
SESSION_PREFIX="ml-scen-$$"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()

cl_green=$'\033[32m'
cl_red=$'\033[31m'
cl_yellow=$'\033[33m'
cl_grey=$'\033[90m'
cl_reset=$'\033[0m'

_session() { echo "${SESSION_PREFIX}-${1}"; }

_spawn() {
  local name="$1" script="$2"
  local session
  session=$(_session "$name")
  pilotty kill -s "$session" 2>/dev/null || true
  sleep 0.1
  pilotty spawn --name "$session" --cwd "$PROJECT_DIR" \
    bash -c "export E_BASH='$E_BASH'; export TERM=xterm-256color; bash '$script' ${3:-}; sleep 3" \
    2>/dev/null
  sleep 2
}

_type() { local s; s=$(_session "$1"); shift; pilotty type -s "$s" "$@" 2>/dev/null; }
_key() { local s; s=$(_session "$1"); shift; pilotty key -s "$s" "$@" 2>/dev/null; }
_snap() { local s; s=$(_session "$1"); pilotty snapshot -s "$s" --format text 2>/dev/null; }
_kill() { local s; s=$(_session "$1"); pilotty kill -s "$s" 2>/dev/null || true; }

_screen_contains() { echo "$1" | grep -qF "$2"; }
_screen_not_contains() { ! echo "$1" | grep -qF "$2"; }

run_test() {
  local name="$1" func="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "  %-60s" "$name"
  if "$func" 2>/tmp/ml-scen-err-$$; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "${cl_green}PASS${cl_reset}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "${cl_red}FAIL${cl_reset}"
    FAILURES+=("$name")
    cat /tmp/ml-scen-err-$$ 2>/dev/null | sed 's/^/    /'
  fi
  rm -f /tmp/ml-scen-err-$$
}

# --- Scenario 1: Sequential Q&A prompts ---

test_s1_prompts_visible_during_editor() {
  _spawn "s1a" "$SDIR/scenario1_sequential_prompts.sh"
  _type "s1a" "TestApp" && _key "s1a" Enter
  sleep 0.3
  _type "s1a" "Author" && _key "s1a" Enter
  sleep 1.5
  local screen
  screen=$(_snap "s1a")
  # The header and at least one prompt should still be visible
  _screen_contains "$screen" "Enter description" || { echo "FAIL: 'Enter description' not visible" >&2; _kill "s1a"; return 1; }
  _kill "s1a"
}

test_s1_captures_all_values() {
  _spawn "s1b" "$SDIR/scenario1_sequential_prompts.sh"
  _type "s1b" "MyProject" && _key "s1b" Enter
  sleep 0.3
  _type "s1b" "Me" && _key "s1b" Enter
  sleep 1.5
  _type "s1b" "Great project" && _key "s1b" Ctrl+D
  sleep 1
  local screen
  screen=$(_snap "s1b")
  _screen_contains "$screen" "Name: MyProject" || { echo "FAIL: name not captured" >&2; _kill "s1b"; return 1; }
  _screen_contains "$screen" "Author: Me" || { echo "FAIL: author not captured" >&2; _kill "s1b"; return 1; }
  _screen_contains "$screen" "Description: Great project" || { echo "FAIL: description not captured" >&2; _kill "s1b"; return 1; }
  _kill "s1b"
}

# --- Scenario 2: Full buffer ---

test_s2_editor_after_full_buffer() {
  _spawn "s2a" "$SDIR/scenario2_full_buffer.sh"
  local screen
  screen=$(_snap "s2a")
  # Should see the prompt and some log lines
  _screen_contains "$screen" "Buffer filled" || { echo "FAIL: prompt not visible" >&2; _kill "s2a"; return 1; }
  _type "s2a" "Buffer note" && _key "s2a" Ctrl+D
  sleep 1
  screen=$(_snap "s2a")
  _screen_contains "$screen" "OUTPUT_START" || { echo "FAIL: output not found" >&2; _kill "s2a"; return 1; }
  _screen_contains "$screen" "Buffer note" || { echo "FAIL: text not captured" >&2; _kill "s2a"; return 1; }
  _kill "s2a"
}

# --- Scenario 3: Box positions ---

test_s3_box_top_position() {
  _spawn "s3t" "$SDIR/scenario3_box_positions.sh" "top"
  local screen
  screen=$(_snap "s3t")
  # Status bar should be near the top
  _screen_contains "$screen" "Ctrl+D" || { echo "FAIL: status bar not visible" >&2; _kill "s3t"; return 1; }
  # Dot background should be visible (not entirely overwritten)
  _screen_contains "$screen" "....." || { echo "FAIL: background not visible" >&2; _kill "s3t"; return 1; }
  _type "s3t" "Top" && _key "s3t" Ctrl+D
  sleep 0.5
  screen=$(_snap "s3t")
  _screen_contains "$screen" "Top" || { echo "FAIL: text not captured" >&2; _kill "s3t"; return 1; }
  _kill "s3t"
}

test_s3_box_center_position() {
  _spawn "s3c" "$SDIR/scenario3_box_positions.sh" "center"
  local screen
  screen=$(_snap "s3c")
  _screen_contains "$screen" "Ctrl+D" || { echo "FAIL: status bar not visible" >&2; _kill "s3c"; return 1; }
  _type "s3c" "Center" && _key "s3c" Ctrl+D
  sleep 0.5
  screen=$(_snap "s3c")
  _screen_contains "$screen" "Center" || { echo "FAIL: text not captured" >&2; _kill "s3c"; return 1; }
  _kill "s3c"
}

test_s3_box_bottom_position() {
  _spawn "s3b" "$SDIR/scenario3_box_positions.sh" "bottom"
  local screen
  screen=$(_snap "s3b")
  _screen_contains "$screen" "Ctrl+D" || { echo "FAIL: status bar not visible" >&2; _kill "s3b"; return 1; }
  _type "s3b" "Bottom" && _key "s3b" Ctrl+D
  sleep 0.5
  screen=$(_snap "s3b")
  _screen_contains "$screen" "Bottom" || { echo "FAIL: text not captured" >&2; _kill "s3b"; return 1; }
  _kill "s3b"
}

# --- Scenario 4: Wizard (multiple sequential editors) ---

test_s4_wizard_completes_all_steps() {
  _spawn "s4" "$SDIR/scenario4_wizard_modal.sh"
  # Step 1
  _type "s4" "AuthModule" && _key "s4" Ctrl+D
  sleep 2
  # Step 2
  _type "s4" "JWT handler" && _key "s4" Ctrl+D
  sleep 2
  # Step 3
  _type "s4" "Needs Redis" && _key "s4" Ctrl+D
  sleep 2
  local screen
  screen=$(_snap "s4")
  _screen_contains "$screen" "RESULT_NAME:AuthModule" || { echo "FAIL: name not captured" >&2; _kill "s4"; return 1; }
  _screen_contains "$screen" "RESULT_DESC:JWT handler" || { echo "FAIL: desc not captured" >&2; _kill "s4"; return 1; }
  _screen_contains "$screen" "RESULT_NOTES:Needs Redis" || { echo "FAIL: notes not captured" >&2; _kill "s4"; return 1; }
  _screen_contains "$screen" "=== Wizard Complete ===" || { echo "FAIL: wizard didn't complete" >&2; _kill "s4"; return 1; }
  _kill "s4"
}

test_s4_wizard_cancel_at_step2() {
  _spawn "s4c" "$SDIR/scenario4_wizard_modal.sh"
  # Step 1
  _type "s4c" "CompA" && _key "s4c" Ctrl+D
  sleep 2
  # Cancel step 2
  _key "s4c" Escape
  sleep 1
  local screen
  screen=$(_snap "s4c")
  _screen_contains "$screen" "cancelled at step 2" || { echo "FAIL: cancel message not shown" >&2; _kill "s4c"; return 1; }
  _kill "s4c"
}

# --- Scenario 5: Inline prompt ---

test_s5_inline_prompt_preserved() {
  _spawn "s5" "$SDIR/scenario5_inline_prompt.sh"
  local screen
  screen=$(_snap "s5")
  _screen_contains "$screen" "Message:" || { echo "FAIL: inline prompt not visible" >&2; _kill "s5"; return 1; }
  _type "s5" "Hello from inline" && _key "s5" Ctrl+D
  sleep 1
  screen=$(_snap "s5")
  _screen_contains "$screen" "Hello from inline" || { echo "FAIL: text not captured" >&2; _kill "s5"; return 1; }
  _kill "s5"
}

# --- Scenario 6: Mixed read + editor ---

test_s6_mixed_flow_captures_all() {
  _spawn "s6" "$SDIR/scenario6_mixed_read_editor.sh"
  # Username (read)
  _type "s6" "testuser" && _key "s6" Enter
  sleep 2
  # Bio (editor)
  _type "s6" "Dev bio" && _key "s6" Ctrl+D
  sleep 2
  # Email (read)
  _type "s6" "test@test.com" && _key "s6" Enter
  sleep 2
  # SSH key (editor)
  _type "s6" "ssh-rsa AAA" && _key "s6" Ctrl+D
  sleep 2
  local screen
  screen=$(_snap "s6")
  _screen_contains "$screen" "RESULT_USER:testuser" || { echo "FAIL: user not captured" >&2; _kill "s6"; return 1; }
  _screen_contains "$screen" "RESULT_BIO:Dev bio" || { echo "FAIL: bio not captured" >&2; _kill "s6"; return 1; }
  _screen_contains "$screen" "RESULT_EMAIL:test@test.com" || { echo "FAIL: email not captured" >&2; _kill "s6"; return 1; }
  _screen_contains "$screen" "RESULT_KEY:ssh-rsa AAA" || { echo "FAIL: key not captured" >&2; _kill "s6"; return 1; }
  _kill "s6"
}

# --- Main ---

main() {
  echo ""
  echo "=== Multiline Editor Scenario Tests (pilotty) ==="
  echo ""

  if ! command -v pilotty >/dev/null 2>&1; then
    echo "${cl_red}ERROR${cl_reset}: pilotty not found"
    exit 1
  fi

  echo "  ${cl_grey}pilotty $(pilotty --version 2>&1)${cl_reset}"
  echo ""

  echo "${cl_yellow}Scenario 1: Sequential Q&A + Editor${cl_reset}"
  run_test "prompts remain visible when editor opens" test_s1_prompts_visible_during_editor
  run_test "all values captured (name, author, desc)" test_s1_captures_all_values
  echo ""

  echo "${cl_yellow}Scenario 2: Full Buffer${cl_reset}"
  run_test "editor works after 40 lines of output" test_s2_editor_after_full_buffer
  echo ""

  echo "${cl_yellow}Scenario 3: Box Mode Positions${cl_reset}"
  run_test "box at top-left" test_s3_box_top_position
  run_test "box at center" test_s3_box_center_position
  run_test "box at bottom" test_s3_box_bottom_position
  echo ""

  echo "${cl_yellow}Scenario 4: Wizard (Sequential Editors)${cl_reset}"
  run_test "wizard completes all 3 steps" test_s4_wizard_completes_all_steps
  run_test "wizard cancel at step 2" test_s4_wizard_cancel_at_step2
  echo ""

  echo "${cl_yellow}Scenario 5: Inline Prompt + Editor${cl_reset}"
  run_test "inline prompt preserved, text captured" test_s5_inline_prompt_preserved
  echo ""

  echo "${cl_yellow}Scenario 6: Mixed Read + Editor${cl_reset}"
  run_test "alternating read/editor captures all 4 values" test_s6_mixed_flow_captures_all
  echo ""

  echo "=== Results ==="
  echo "  Total:  $TESTS_RUN"
  echo "  ${cl_green}Passed: $TESTS_PASSED${cl_reset}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "  ${cl_red}Failed: $TESTS_FAILED${cl_reset}"
    echo ""
    for f in "${FAILURES[@]}"; do echo "    - $f"; done
  fi

  # Cleanup
  for session in $(pilotty list-sessions 2>/dev/null | jq -r '.sessions[]?.name // empty' 2>/dev/null); do
    [[ "$session" == ${SESSION_PREFIX}* ]] && pilotty kill -s "$session" 2>/dev/null || true
  done

  [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
