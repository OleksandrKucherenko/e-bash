#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-23
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

export SCRIPT_DIR=".scripts"
export E_BASH=".scripts"
# Disable debug output for tests to avoid pollution
export DEBUG=""

# Mock logger functions to prevent "command not found" errors
# But still produce output so tests can verify messages
# Note: Logger functions output to STDERR, not STDOUT
Mock printf:Trap
  printf "$@" >&2
End

Mock echo:Trap
  echo "$@" >&2
End

Describe '_traps.sh nested loading:'
  Include ".scripts/_traps.sh"

  Describe 'Sequential sourcing:'
    setup_test_scripts() {
      # Create temporary test scripts
      cat > /tmp/test_trap_script_a.sh << 'EOF'
#!/usr/bin/env bash
export E_BASH="${E_BASH:-.scripts}"
export DEBUG=""
source "$E_BASH/_traps.sh" >/dev/null 2>&1

cleanup_a() {
  echo "cleanup_a"
}

trap:on cleanup_a EXIT
EOF

      cat > /tmp/test_trap_script_b.sh << 'EOF'
#!/usr/bin/env bash
export E_BASH="${E_BASH:-.scripts}"
export DEBUG=""
source "$E_BASH/_traps.sh" >/dev/null 2>&1

cleanup_b() {
  echo "cleanup_b"
}

trap:on cleanup_b EXIT
EOF

      chmod +x /tmp/test_trap_script_a.sh
      chmod +x /tmp/test_trap_script_b.sh
    }

    Before 'setup_test_scripts'

    It 'accumulates handlers when scripts sourced sequentially'
      # Source both scripts
      source /tmp/test_trap_script_a.sh
      source /tmp/test_trap_script_b.sh

      # Both handlers should be registered
      When call trap:list EXIT
      The output should include "cleanup_a"
      The output should include "cleanup_b"
    End

    It 'preserves handler registration order'
      source /tmp/test_trap_script_a.sh
      source /tmp/test_trap_script_b.sh

      # Get the list and check order
      result=$(trap:list EXIT | grep "EXIT:")

      # cleanup_a should appear before cleanup_b in the output
      When call trap:list EXIT
      The output should include "cleanup_a cleanup_b"
    End
  End

  Describe 'Multiple sourcing prevention:'
    dup_cleanup() { echo "dup_cleanup"; }

    It 'warns on duplicate handler registration'
      trap:on dup_cleanup EXIT
      When call trap:on dup_cleanup EXIT

      The status should be success
      The output should include "already registered"
    End

    It 'does not duplicate handler without flag'
      dup_cleanup2() { echo "dup2"; }

      trap:on dup_cleanup2 EXIT
      trap:on dup_cleanup2 EXIT

      # Should only appear once
      output=$(trap:list EXIT)
      count=$(echo "$output" | grep -o "dup_cleanup2" | wc -l)

      The variable count should eq 1
    End

    It 'allows duplicates with --allow-duplicates flag'
      dup_cleanup3() { echo "dup3"; }

      trap:on dup_cleanup3 EXIT
      trap:on --allow-duplicates dup_cleanup3 EXIT

      # Should appear twice
      output=$(trap:list EXIT)
      count=$(echo "$output" | grep -o "dup_cleanup3" | wc -l)

      The variable count should eq 2
    End
  End

  Describe 'Scoped handlers with push/pop:'
    outer_handler() { echo "outer"; }
    inner_handler() { echo "inner"; }

    It 'restores handler state after pop'
      # Setup outer scope
      trap:on outer_handler EXIT

      # Push and add inner
      trap:push EXIT
      trap:on inner_handler EXIT

      # Both should be active
      list1=$(trap:list EXIT)

      # Pop state
      trap:pop EXIT

      # Only outer should remain
      When call trap:list EXIT
      The output should include "outer_handler"
      The output should not include "inner_handler"
    End

    It 'supports nested push/pop (depth 3)'
      h1() { echo "1"; }
      h2() { echo "2"; }
      h3() { echo "3"; }

      # Level 1
      trap:on h1 EXIT
      trap:push EXIT

      # Level 2
      trap:on h2 EXIT
      trap:push EXIT

      # Level 3
      trap:on h3 EXIT

      # All should be active
      list=$(trap:list EXIT)
      [ -n "$(echo "$list" | grep h1)" ] || return 1
      [ -n "$(echo "$list" | grep h2)" ] || return 1
      [ -n "$(echo "$list" | grep h3)" ] || return 1

      # Pop to level 2
      trap:pop EXIT
      list=$(trap:list EXIT)
      [ -n "$(echo "$list" | grep h1)" ] || return 1
      [ -n "$(echo "$list" | grep h2)" ] || return 1
      [ -z "$(echo "$list" | grep h3)" ] || return 1

      # Pop to level 1
      trap:pop EXIT

      # Only h1 should remain
      When call trap:list EXIT
      The output should include "h1"
      The output should not include "h2"
      The output should not include "h3"
    End

    It 'maintains separate stacks for different signals'
      sig1_handler() { echo "sig1"; }
      sig2_handler() { echo "sig2"; }

      # Setup different handlers for different signals
      trap:on sig1_handler INT
      trap:on sig2_handler TERM

      # Push only INT
      trap:push INT

      # Add new handler to INT
      sig1_new() { echo "sig1_new"; }
      trap:on sig1_new INT

      # Pop INT - should restore
      trap:pop INT

      # INT should only have sig1_handler
      int_list=$(trap:list INT)
      term_list=$(trap:list TERM)

      # Verify INT was restored
      [ -n "$(echo "$int_list" | grep sig1_handler)" ] || return 1
      [ -z "$(echo "$int_list" | grep sig1_new)" ] || return 1

      # Verify TERM unchanged
      When call trap:list TERM
      The output should include "sig2_handler"
    End
  End

  Describe 'Scoped cleanup pattern:'
    scoped_handler() { echo "scoped"; }
    global_handler() { echo "global"; }

    It 'auto-cleans handlers with scope:begin/end'
      # Global handler
      trap:on global_handler EXIT

      # Scoped section
      trap:scope:begin EXIT
      trap:on scoped_handler EXIT
      trap:scope:end EXIT

      # Only global should remain
      When call trap:list EXIT
      The output should include "global_handler"
      The output should not include "scoped_handler"
    End

    It 'supports nested scopes'
      g1() { echo "g1"; }
      s1() { echo "s1"; }
      s2() { echo "s2"; }

      trap:on g1 EXIT

      # Outer scope
      trap:scope:begin EXIT
      trap:on s1 EXIT

      # Inner scope
      trap:scope:begin EXIT
      trap:on s2 EXIT
      trap:scope:end EXIT

      # End outer scope
      trap:scope:end EXIT

      # Only g1 should remain
      When call trap:list EXIT
      The output should include "g1"
      The output should not include "s1"
    End
  End

  Describe 'Library pattern (reusable sourcing):'
    setup_library() {
      cat > /tmp/test_trap_lib_db.sh << 'EOF'
#!/usr/bin/env bash
# Library initialization guard
if [[ "${LIB_DB_TRAP_LOADED}" != "yes" ]]; then
  export LIB_DB_TRAP_LOADED="yes"
  export E_BASH="${E_BASH:-.scripts}"
  export DEBUG=""
  source "$E_BASH/_traps.sh" >/dev/null 2>&1

  db_cleanup() {
    echo "db_cleanup"
  }

  # Only register if not already registered
  if ! trap:list EXIT 2>/dev/null | grep -q "db_cleanup"; then
    trap:on db_cleanup EXIT
  fi
fi
EOF
      chmod +x /tmp/test_trap_lib_db.sh
    }

    Before 'setup_library'

    It 'prevents duplicate registration via guard pattern'
      # Source library twice
      source /tmp/test_trap_lib_db.sh
      source /tmp/test_trap_lib_db.sh

      # Should only be registered once
      output=$(trap:list EXIT)
      count=$(echo "$output" | grep -o "db_cleanup" | wc -l)

      The variable count should eq 1
    End
  End

  Describe 'Stack level tracking:'
    It 'tracks stack level correctly'
      # Initial level should be 0
      [ "$__TRAP_STACK_LEVEL" -eq 0 ] || return 1

      trap:push EXIT
      [ "$__TRAP_STACK_LEVEL" -eq 1 ] || return 1

      trap:push EXIT
      [ "$__TRAP_STACK_LEVEL" -eq 2 ] || return 1

      trap:pop EXIT
      [ "$__TRAP_STACK_LEVEL" -eq 1 ] || return 1

      trap:pop EXIT

      When call echo "$__TRAP_STACK_LEVEL"
      The output should eq "0"
    End

    It 'prevents pop when stack is empty'
      # Ensure stack is empty
      while [ "$__TRAP_STACK_LEVEL" -gt 0 ]; do
        trap:pop EXIT 2>/dev/null || break
      done

      When call trap:pop EXIT
      The status should be failure
      The output should include "No trap state to pop"
    End
  End

  Describe 'Multiple signals with scoping:'
    multi_handler() { echo "multi"; }

    It 'pushes and pops multiple signals together'
      # Register for multiple signals
      trap:on multi_handler INT TERM HUP

      # Push all
      trap:push INT TERM HUP

      # Add new handlers
      new_int() { echo "new_int"; }
      new_term() { echo "new_term"; }
      trap:on new_int INT
      trap:on new_term TERM

      # Pop all
      trap:pop INT TERM HUP

      # Original multi_handler should remain for all
      int_list=$(trap:list INT)
      term_list=$(trap:list TERM)
      hup_list=$(trap:list HUP)

      [ -n "$(echo "$int_list" | grep multi_handler)" ] || return 1
      [ -n "$(echo "$term_list" | grep multi_handler)" ] || return 1
      [ -n "$(echo "$hup_list" | grep multi_handler)" ] || return 1

      # New handlers should be gone
      [ -z "$(echo "$int_list" | grep new_int)" ] || return 1

      When call trap:list TERM
      The output should not include "new_term"
    End
  End

  Describe 'Error handling in nested contexts:'
    It 'handles missing function gracefully during registration'
      When call trap:on nonexistent_nested_handler EXIT
      The status should be failure
      The output should include "does not exist"
    End

    It 'recovers from stack corruption'
      # Manually corrupt stack by unsetting variable
      trap:push EXIT
      unset "__TRAP_STACK_${__TRAP_STACK_LEVEL}"

      When call trap:pop EXIT
      The status should be failure
      The output should include "Stack corruption"
    End
  End
End
