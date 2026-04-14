#!/usr/bin/env bash
# Integration tests for input:multi-line using pilotty terminal automation
# Requires: pilotty (npm install -g pilotty)
#
# These tests spawn the multiline editor in a real PTY via pilotty,
# send keystrokes, and verify screen output and captured text.

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
E_BASH="$PROJECT_DIR/.scripts"
DEMO_SCRIPT="$PROJECT_DIR/demos/demo.multi-line-test.sh"
SESSION_PREFIX="ml-integ-$$"
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()

# --- Terminal colors ---
cl_green=$'\033[32m'
cl_red=$'\033[31m'
cl_yellow=$'\033[33m'
cl_grey=$'\033[90m'
cl_reset=$'\033[0m'

# --- Helpers ---

_session_name() {
  echo "${SESSION_PREFIX}-${1}"
}

_spawn_editor() {
  local name="$1" mode="${2:-stream}" height="${3:-5}" width="${4:-40}" extra="${5:-}"
  local session
  session=$(_session_name "$name")

  pilotty kill -s "$session" 2>/dev/null || true
  sleep 0.1

  pilotty spawn --name "$session" --cwd "$PROJECT_DIR" \
    bash -c "export E_BASH='$E_BASH'; export TERM=xterm-256color; bash '$DEMO_SCRIPT' '$mode' '$height' '$width' '$extra'; sleep 3" \
    2>/dev/null

  # Wait for editor to render
  sleep 1.5
}

_type() {
  local session
  session=$(_session_name "$1")
  shift
  pilotty type -s "$session" "$@" 2>/dev/null
}

_key() {
  local session
  session=$(_session_name "$1")
  shift
  pilotty key -s "$session" "$@" 2>/dev/null
}

_snap() {
  local session
  session=$(_session_name "$1")
  pilotty snapshot -s "$session" --format text 2>/dev/null
}

_snap_json() {
  local session
  session=$(_session_name "$1")
  pilotty snapshot -s "$session" 2>/dev/null
}

_kill() {
  local session
  session=$(_session_name "$1")
  pilotty kill -s "$session" 2>/dev/null || true
}

_wait_for() {
  local session text timeout
  session=$(_session_name "$1")
  text="$2"
  timeout="${3:-5000}"
  pilotty wait-for -s "$session" "$text" -t "$timeout" 2>/dev/null
}

_assert_screen_contains() {
  local screen="$1" expected="$2" test_label="$3"
  if echo "$screen" | grep -qF "$expected"; then
    return 0
  else
    echo "  ${cl_red}FAIL${cl_reset}: screen does not contain '$expected'" >&2
    echo "  ${cl_grey}Screen:${cl_reset}" >&2
    echo "$screen" | head -10 | sed 's/^/    /' >&2
    return 1
  fi
}

_assert_screen_not_contains() {
  local screen="$1" unexpected="$2"
  if echo "$screen" | grep -qF "$unexpected"; then
    echo "  ${cl_red}FAIL${cl_reset}: screen unexpectedly contains '$unexpected'" >&2
    return 1
  fi
  return 0
}

_assert_output_equals() {
  local screen="$1" expected="$2"
  # Extract text between OUTPUT_START and OUTPUT_END
  local captured
  captured=$(echo "$screen" | sed -n '/^OUTPUT_START$/,/^OUTPUT_END$/p' | sed '1d;$d')
  if [[ "$captured" == "$expected" ]]; then
    return 0
  else
    echo "  ${cl_red}FAIL${cl_reset}: output mismatch" >&2
    echo "  ${cl_grey}Expected:${cl_reset} $(echo "$expected" | head -5)" >&2
    echo "  ${cl_grey}Got:${cl_reset}      $(echo "$captured" | head -5)" >&2
    return 1
  fi
}

_assert_output_contains() {
  local screen="$1" expected="$2"
  local captured
  captured=$(echo "$screen" | sed -n '/^OUTPUT_START$/,/^OUTPUT_END$/p' | sed '1d;$d')
  if echo "$captured" | grep -qF "$expected"; then
    return 0
  else
    echo "  ${cl_red}FAIL${cl_reset}: output does not contain '$expected'" >&2
    echo "  ${cl_grey}Got:${cl_reset} $(echo "$captured" | head -5)" >&2
    return 1
  fi
}

_assert_cancelled() {
  local screen="$1"
  if echo "$screen" | grep -qF "CANCELLED"; then
    return 0
  else
    echo "  ${cl_red}FAIL${cl_reset}: expected CANCELLED but not found" >&2
    return 1
  fi
}

run_test() {
  local name="$1"
  local func="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  printf "  %-60s" "$name"
  if "$func" 2>/tmp/ml-test-err-$$; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "${cl_green}PASS${cl_reset}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "${cl_red}FAIL${cl_reset}"
    FAILURES+=("$name")
    cat /tmp/ml-test-err-$$ 2>/dev/null | sed 's/^/    /'
  fi
  rm -f /tmp/ml-test-err-$$
}

# --- Test Cases ---

test_basic_typing_and_save() {
  _spawn_editor "basic" stream 5
  _type "basic" "Hello World"
  _key "basic" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "basic")
  _assert_output_equals "$screen" "Hello World"
  _kill "basic"
}

test_multiline_typing() {
  _spawn_editor "multiline" stream 5
  _type "multiline" "Line 1"
  _key "multiline" Enter
  _type "multiline" "Line 2"
  _key "multiline" Enter
  _type "multiline" "Line 3"
  _key "multiline" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "multiline")
  _assert_output_equals "$screen" "Line 1
Line 2
Line 3"
  _kill "multiline"
}

test_escape_cancels() {
  _spawn_editor "cancel" stream 5
  _type "cancel" "Some text"
  _key "cancel" Escape
  sleep 0.5
  local screen
  screen=$(_snap "cancel")
  _assert_cancelled "$screen"
  _kill "cancel"
}

test_backspace_deletes_char() {
  _spawn_editor "bksp" stream 5
  _type "bksp" "Helloo"
  _key "bksp" Backspace
  _type "bksp" " World"
  _key "bksp" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "bksp")
  _assert_output_equals "$screen" "Hello World"
  _kill "bksp"
}

test_arrow_key_navigation() {
  _spawn_editor "arrows" stream 5
  _type "arrows" "ABCD"
  # Move left twice, type 'X' between B and C
  _key "arrows" Left
  _key "arrows" Left
  _type "arrows" "X"
  _key "arrows" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "arrows")
  _assert_output_equals "$screen" "ABXCD"
  _kill "arrows"
}

test_home_end_keys() {
  _spawn_editor "homeend" stream 5
  _type "homeend" "Middle"
  _key "homeend" Home
  _type "homeend" "Start "
  _key "homeend" End
  _type "homeend" " End"
  _key "homeend" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "homeend")
  _assert_output_equals "$screen" "Start Middle End"
  _kill "homeend"
}

test_up_down_navigation() {
  _spawn_editor "updown" stream 5
  _type "updown" "First line"
  _key "updown" Enter
  _type "updown" "Second line"
  # Go up to first line
  _key "updown" Up
  _key "updown" End
  _type "updown" " EDITED"
  _key "updown" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "updown")
  _assert_output_contains "$screen" "First line EDITED"
  _assert_output_contains "$screen" "Second line"
  _kill "updown"
}

test_ctrl_w_delete_word() {
  _spawn_editor "delword" stream 5
  _type "delword" "Hello World Test"
  _key "delword" Ctrl+W
  _key "delword" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "delword")
  _assert_output_equals "$screen" "Hello World "
  _kill "delword"
}

test_ctrl_u_delete_line() {
  _spawn_editor "delline" stream 5
  _type "delline" "Delete this line"
  _key "delline" Ctrl+U
  _type "delline" "New content"
  _key "delline" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "delline")
  _assert_output_equals "$screen" "New content"
  _kill "delline"
}

test_tab_inserts_spaces() {
  _spawn_editor "tab" stream 5
  _key "tab" Tab
  _type "tab" "indented"
  _key "tab" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "tab")
  _assert_output_equals "$screen" "  indented"
  _kill "tab"
}

test_delete_key_forward() {
  _spawn_editor "delkey" stream 5
  _type "delkey" "ABCD"
  _key "delkey" Home
  # Delete first character
  _key "delkey" Delete
  _key "delkey" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "delkey")
  _assert_output_equals "$screen" "BCD"
  _kill "delkey"
}

test_backspace_joins_lines() {
  _spawn_editor "joinline" stream 5
  _type "joinline" "First"
  _key "joinline" Enter
  _type "joinline" "Second"
  _key "joinline" Home
  # Backspace at start of line 2 should join with line 1
  _key "joinline" Backspace
  _key "joinline" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "joinline")
  _assert_output_equals "$screen" "FirstSecond"
  _kill "joinline"
}

test_empty_save() {
  _spawn_editor "empty" stream 5
  # Immediately save without typing
  _key "empty" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "empty")
  _assert_output_equals "$screen" ""
  _kill "empty"
}

test_screen_shows_typed_text() {
  _spawn_editor "screen" stream 5
  _type "screen" "Visible text"
  sleep 0.3
  local screen
  screen=$(_snap "screen")
  _assert_screen_contains "$screen" "Visible text" "screen shows typed text"
  _kill "screen"
}

test_tilde_on_empty_lines() {
  _spawn_editor "tilde" stream 5
  _type "tilde" "Line 1"
  sleep 0.3
  local screen
  screen=$(_snap "tilde")
  # Empty lines below should show tilde
  _assert_screen_contains "$screen" "~" "tilde on empty lines"
  _kill "tilde"
}

test_cursor_column_clamping() {
  # When moving from a long line to a short line, cursor should clamp
  _spawn_editor "clamp" stream 5
  _type "clamp" "Long line here"
  _key "clamp" Enter
  _type "clamp" "Hi"
  _key "clamp" Up
  # Cursor should be on long line (col 14), now move down to short line
  _key "clamp" Down
  # Type after clamped position
  _type "clamp" "X"
  _key "clamp" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "clamp")
  _assert_output_contains "$screen" "HiX"
  _kill "clamp"
}

test_multiple_enter_empty_lines() {
  _spawn_editor "emptylines" stream 5
  _type "emptylines" "A"
  _key "emptylines" Enter
  _key "emptylines" Enter
  _type "emptylines" "B"
  _key "emptylines" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "emptylines")
  _assert_output_equals "$screen" "A

B"
  _kill "emptylines"
}

test_page_down_and_scrolling() {
  _spawn_editor "scroll" stream 5
  # Type more lines than the editor height
  local i
  for i in 1 2 3 4 5 6 7; do
    _type "scroll" "Line $i"
    [[ $i -lt 7 ]] && _key "scroll" Enter
  done
  sleep 0.3
  local screen
  screen=$(_snap "scroll")
  # Last typed lines should be visible (scrolled)
  _assert_screen_contains "$screen" "Line 7" "shows last line after scroll"
  _key "scroll" Ctrl+D
  sleep 0.5
  screen=$(_snap "scroll")
  _assert_output_contains "$screen" "Line 1"
  _assert_output_contains "$screen" "Line 7"
  _kill "scroll"
}

test_box_mode_basic() {
  _spawn_editor "boxmode" box 8 40
  _type "boxmode" "Box mode text"
  _key "boxmode" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "boxmode")
  _assert_output_equals "$screen" "Box mode text"
  _kill "boxmode"
}

test_stream_status_bar() {
  _spawn_editor "status" stream-status 5
  _type "status" "hello"
  sleep 0.3
  local screen
  screen=$(_snap "status")
  # Status bar should show cursor position info
  _assert_screen_contains "$screen" "Ctrl+D" "status bar shows help"
  _kill "status"
}

test_special_chars_typing() {
  _spawn_editor "special" stream 5
  _type "special" "Hello! @#\$%"
  _key "special" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "special")
  _assert_output_contains "$screen" "Hello!"
  _kill "special"
}

test_rapid_typing() {
  _spawn_editor "rapid" stream 5
  # Type quickly without delays
  _type "rapid" "abcdefghijklmnopqrstuvwxyz"
  _key "rapid" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "rapid")
  _assert_output_equals "$screen" "abcdefghijklmnopqrstuvwxyz"
  _kill "rapid"
}

test_long_line_wrapping() {
  _spawn_editor "longline" stream 5
  # Type a line longer than typical display width
  local longtext="This is a very long line that should test how the editor handles text that extends beyond the visible area of the editor"
  _type "longline" "$longtext"
  _key "longline" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "longline")
  _assert_output_contains "$screen" "This is a very long line"
  _kill "longline"
}

test_insert_in_middle_of_text() {
  _spawn_editor "insert" stream 5
  _type "insert" "HelloWorld"
  # Move left 5 times (before "World")
  _key "insert" "Left Left Left Left Left"
  _type "insert" " "
  _key "insert" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "insert")
  _assert_output_equals "$screen" "Hello World"
  _kill "insert"
}

test_delete_all_text_and_retype() {
  _spawn_editor "delall" stream 5
  _type "delall" "Delete me"
  _key "delall" Ctrl+U
  _type "delall" "Fresh start"
  _key "delall" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "delall")
  _assert_output_equals "$screen" "Fresh start"
  _kill "delall"
}

test_multiple_words_delete_word() {
  _spawn_editor "multiword" stream 5
  _type "multiword" "one two three four"
  _key "multiword" Ctrl+W
  _key "multiword" Ctrl+W
  _key "multiword" Ctrl+D
  sleep 0.5
  local screen
  screen=$(_snap "multiword")
  _assert_output_equals "$screen" "one two "
  _kill "multiword"
}

# --- Main ---

main() {
  echo ""
  echo "=== Multiline Editor Integration Tests (pilotty) ==="
  echo ""

  # Verify pilotty is available
  if ! command -v pilotty >/dev/null 2>&1; then
    echo "${cl_red}ERROR${cl_reset}: pilotty not found. Install with: npm install -g pilotty"
    exit 1
  fi

  # Verify test harness exists
  if [[ ! -x "$DEMO_SCRIPT" ]]; then
    echo "${cl_red}ERROR${cl_reset}: Test harness not found: $DEMO_SCRIPT"
    exit 1
  fi

  echo "  ${cl_grey}Using pilotty $(pilotty --version 2>&1)${cl_reset}"
  echo ""

  # Basic editing
  echo "${cl_yellow}Basic Editing${cl_reset}"
  run_test "types text and saves with Ctrl+D" test_basic_typing_and_save
  run_test "types multiple lines" test_multiline_typing
  run_test "Esc cancels input" test_escape_cancels
  run_test "empty save returns empty string" test_empty_save
  run_test "rapid typing preserved correctly" test_rapid_typing
  echo ""

  # Character operations
  echo "${cl_yellow}Character Operations${cl_reset}"
  run_test "backspace deletes character" test_backspace_deletes_char
  run_test "delete key removes forward character" test_delete_key_forward
  run_test "tab inserts spaces" test_tab_inserts_spaces
  run_test "insert in middle of text" test_insert_in_middle_of_text
  run_test "special characters" test_special_chars_typing
  echo ""

  # Navigation
  echo "${cl_yellow}Navigation${cl_reset}"
  run_test "left/right arrow navigation" test_arrow_key_navigation
  run_test "home/end keys" test_home_end_keys
  run_test "up/down line navigation" test_up_down_navigation
  run_test "cursor column clamping on line change" test_cursor_column_clamping
  echo ""

  # Line operations
  echo "${cl_yellow}Line Operations${cl_reset}"
  run_test "Ctrl+W deletes word" test_ctrl_w_delete_word
  run_test "Ctrl+U deletes entire line" test_ctrl_u_delete_line
  run_test "multiple Ctrl+W deletes multiple words" test_multiple_words_delete_word
  run_test "delete all and retype" test_delete_all_text_and_retype
  run_test "backspace at line start joins lines" test_backspace_joins_lines
  run_test "multiple Enter creates empty lines" test_multiple_enter_empty_lines
  echo ""

  # Scrolling and display
  echo "${cl_yellow}Scrolling and Display${cl_reset}"
  run_test "screen shows typed text in real-time" test_screen_shows_typed_text
  run_test "tilde markers on empty lines" test_tilde_on_empty_lines
  run_test "scrolling with many lines" test_page_down_and_scrolling
  run_test "long line handling" test_long_line_wrapping
  echo ""

  # Modes
  echo "${cl_yellow}Modes${cl_reset}"
  run_test "box mode basic operation" test_box_mode_basic
  run_test "stream mode with status bar" test_stream_status_bar
  echo ""

  # Summary
  echo "=== Results ==="
  echo "  Total:  $TESTS_RUN"
  echo "  ${cl_green}Passed: $TESTS_PASSED${cl_reset}"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "  ${cl_red}Failed: $TESTS_FAILED${cl_reset}"
    echo ""
    echo "  ${cl_red}Failed tests:${cl_reset}"
    for f in "${FAILURES[@]}"; do
      echo "    - $f"
    done
    echo ""
  fi

  # Cleanup all sessions
  for session in $(pilotty list-sessions 2>/dev/null | jq -r '.sessions[]?.name // empty' 2>/dev/null); do
    [[ "$session" == ${SESSION_PREFIX}* ]] && pilotty kill -s "$session" 2>/dev/null || true
  done

  [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
