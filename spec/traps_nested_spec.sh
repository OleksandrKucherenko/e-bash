#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

export SCRIPT_DIR=".scripts"
export E_BASH=".scripts"
# Disable debug output for tests to avoid pollution
export DEBUG=""

# Mock logger functions to prevent "command not found" errors
# But respect DEBUG environment variable to avoid pollution
# Note: Logger functions output to STDERR, not STDOUT
Mock printf:Trap
  # Only output if Trap is in DEBUG
  [[ "$DEBUG" == *"Trap"* || "$DEBUG" == "*" ]] && printf "$@" >&2 || true
End

Mock echo:Trap
  # Only output if Trap is in DEBUG
  [[ "$DEBUG" == *"Trap"* || "$DEBUG" == "*" ]] && echo "$@" >&2 || true
End

Describe '_traps.sh nested loading:'
  Include ".scripts/_traps.sh"

  # Redirect diagnostic output to file for debugging
  BeforeAll 'export TRAP_TEST_STDERR="/tmp/trap_test_stderr_$$.log"'
  AfterAll 'rm -f "$TRAP_TEST_STDERR"'

  Describe 'Sequential sourcing:'
    setup_test_scripts() {
      # Create temporary test scripts
      cat >/tmp/test_trap_script_a.sh <<'EOF'
#!/usr/bin/env bash
export E_BASH="${E_BASH:-.scripts}"
export DEBUG=""
source "$E_BASH/_traps.sh" >/dev/null 2>&1

cleanup_a() {
  echo "cleanup_a" >/dev/null
}

trap:on cleanup_a EXIT
EOF

      cat >/tmp/test_trap_script_b.sh <<'EOF'
#!/usr/bin/env bash
export E_BASH="${E_BASH:-.scripts}"
export DEBUG=""
source "$E_BASH/_traps.sh" >/dev/null 2>&1

cleanup_b() {
  echo "cleanup_b" >/dev/null
}

trap:on cleanup_b EXIT
EOF

      chmod +x /tmp/test_trap_script_a.sh
      chmod +x /tmp/test_trap_script_b.sh
    }

    Before 'setup_test_scripts'

    It 'accumulates handlers when scripts sourced sequentially'
      # Source both scripts (redirect diagnostic stderr to file)
      source /tmp/test_trap_script_a.sh 2>>"$TRAP_TEST_STDERR"
      source /tmp/test_trap_script_b.sh 2>>"$TRAP_TEST_STDERR"

      # Both handlers should be registered
      When call trap:list EXIT
      The output should include "cleanup_a"
      The output should include "cleanup_b"
    End

    It 'preserves handler registration order'
      source /tmp/test_trap_script_a.sh 2>>"$TRAP_TEST_STDERR"
      source /tmp/test_trap_script_b.sh 2>>"$TRAP_TEST_STDERR"

      # cleanup_a should appear before cleanup_b in the output
      When call trap:list EXIT
      The output should include "cleanup_a cleanup_b"
    End
  End

  Describe 'Multiple sourcing prevention:'
    dup_cleanup() { echo "dup_cleanup" >/dev/null; }

    It 'warns on duplicate handler registration'
      setup() {
        trap:on dup_cleanup EXIT 2>>"$TRAP_TEST_STDERR"
      }
      BeforeCall 'setup 2>>"$TRAP_TEST_STDERR"'

      test_duplicate() {
        DEBUG=Trap trap:on dup_cleanup EXIT
      }

      When call test_duplicate
      The status should be success
      The error should include "already registered"
    End

    It 'does not duplicate handler without flag'
      dup_cleanup2() { echo "dup2" >/dev/null; }

      trap:on dup_cleanup2 EXIT 2>>"$TRAP_TEST_STDERR"
      trap:on dup_cleanup2 EXIT 2>>"$TRAP_TEST_STDERR"

      # Should only appear once
      output=$(trap:list EXIT 2>>"$TRAP_TEST_STDERR")
      count=$(echo "$output" | grep -o "dup_cleanup2" | wc -l)

      When call echo "$count"
      The output should eq 1
    End

    It 'allows duplicates with --allow-duplicates flag'
      dup_cleanup3() { echo "dup3" >/dev/null; }

      trap:on dup_cleanup3 EXIT 2>>"$TRAP_TEST_STDERR"
      trap:on --allow-duplicates dup_cleanup3 EXIT 2>>"$TRAP_TEST_STDERR"

      # Should appear twice
      output=$(trap:list EXIT 2>>"$TRAP_TEST_STDERR")
      count=$(echo "$output" | grep -o "dup_cleanup3" | wc -l)

      When call echo "$count"
      The output should eq 2
    End
  End

  Describe 'Scoped handlers with push/pop:'
    outer_handler() { echo "outer" >/dev/null; }
    inner_handler() { echo "inner" >/dev/null; }

    It 'restores handler state after pop'
      # Setup outer scope
      trap:on outer_handler EXIT 2>>"$TRAP_TEST_STDERR"

      # Push and add inner
      trap:push EXIT 2>>"$TRAP_TEST_STDERR"
      trap:on inner_handler EXIT 2>>"$TRAP_TEST_STDERR"

      # Pop state
      trap:pop EXIT 2>>"$TRAP_TEST_STDERR"

      # Only outer should remain
      When call trap:list EXIT
      The output should include "outer_handler"
      The output should not include "inner_handler"
    End

    It 'supports nested push/pop (depth 3)'
      h1() { echo "1" >/dev/null; }
      h2() { echo "2" >/dev/null; }
      h3() { echo "3" >/dev/null; }

      # Level 1
      trap:on h1 EXIT 2>>"$TRAP_TEST_STDERR"
      trap:push EXIT 2>>"$TRAP_TEST_STDERR"

      # Level 2
      trap:on h2 EXIT 2>>"$TRAP_TEST_STDERR"
      trap:push EXIT 2>>"$TRAP_TEST_STDERR"

      # Level 3
      trap:on h3 EXIT 2>>"$TRAP_TEST_STDERR"

      # Pop to level 2
      trap:pop EXIT 2>>"$TRAP_TEST_STDERR"

      # Pop to level 1
      trap:pop EXIT 2>>"$TRAP_TEST_STDERR"

      # Only h1 should remain
      When call trap:list EXIT
      The output should include "h1"
      The output should not include "h2"
      The output should not include "h3"
    End

    It 'maintains separate stacks for different signals'
      sig1_handler() { echo "sig1" >/dev/null; }
      sig2_handler() { echo "sig2" >/dev/null; }

      # Setup different handlers for different signals
      trap:on sig1_handler INT 2>>"$TRAP_TEST_STDERR"
      trap:on sig2_handler TERM 2>>"$TRAP_TEST_STDERR"

      # Push only INT
      trap:push INT 2>>"$TRAP_TEST_STDERR"

      # Add new handler to INT
      sig1_new() { echo "sig1_new" >/dev/null; }
      trap:on sig1_new INT 2>>"$TRAP_TEST_STDERR"

      # Pop INT - should restore
      trap:pop INT 2>>"$TRAP_TEST_STDERR"

      # Verify TERM unchanged
      When call trap:list TERM
      The output should include "sig2_handler"
    End
  End

  Describe 'Scoped cleanup pattern:'
    scoped_handler() { echo "scoped" >/dev/null; }
    global_handler() { echo "global" >/dev/null; }

    It 'auto-cleans handlers with scope:begin/end'
      # Global handler
      trap:on global_handler EXIT 2>>"$TRAP_TEST_STDERR"

      # Scoped section
      trap:scope:begin EXIT 2>>"$TRAP_TEST_STDERR"
      trap:on scoped_handler EXIT 2>>"$TRAP_TEST_STDERR"
      trap:scope:end EXIT 2>>"$TRAP_TEST_STDERR"

      # Only global should remain
      When call trap:list EXIT
      The output should include "global_handler"
      The output should not include "scoped_handler"
    End

    It 'supports nested scopes'
      g1() { echo "g1" >/dev/null; }
      s1() { echo "s1" >/dev/null; }
      s2() { echo "s2" >/dev/null; }

      trap:on g1 EXIT 2>>"$TRAP_TEST_STDERR"

      # Outer scope
      trap:scope:begin EXIT 2>>"$TRAP_TEST_STDERR"
      trap:on s1 EXIT 2>>"$TRAP_TEST_STDERR"

      # Inner scope
      trap:scope:begin EXIT 2>>"$TRAP_TEST_STDERR"
      trap:on s2 EXIT 2>>"$TRAP_TEST_STDERR"
      trap:scope:end EXIT 2>>"$TRAP_TEST_STDERR"

      # End outer scope
      trap:scope:end EXIT 2>>"$TRAP_TEST_STDERR"

      # Only g1 should remain
      When call trap:list EXIT
      The output should include "g1"
      The output should not include "s1"
    End
  End

  Describe 'Library pattern (reusable sourcing):'
    setup_library() {
      cat >/tmp/test_trap_lib_db.sh <<'EOF'
#!/usr/bin/env bash
# Library initialization guard
if [[ "${LIB_DB_TRAP_LOADED}" != "yes" ]]; then
  export LIB_DB_TRAP_LOADED="yes"
  export E_BASH="${E_BASH:-.scripts}"
  export DEBUG=""
  source "$E_BASH/_traps.sh" >/dev/null 2>&1

  db_cleanup() {
    echo "db_cleanup" >/dev/null
  }

  # Only register if not already registered
  if ! trap:list EXIT 2>>"$TRAP_TEST_STDERR" | grep -q "db_cleanup"; then
    trap:on db_cleanup EXIT
  fi
fi
EOF
      chmod +x /tmp/test_trap_lib_db.sh
    }

    Before 'setup_library'

    It 'prevents duplicate registration via guard pattern'
      # Source library twice (redirect diagnostic stderr to file)
      source /tmp/test_trap_lib_db.sh 2>>"$TRAP_TEST_STDERR"
      source /tmp/test_trap_lib_db.sh 2>>"$TRAP_TEST_STDERR"

      # Should only be registered once
      output=$(trap:list EXIT 2>>"$TRAP_TEST_STDERR")
      count=$(echo "$output" | grep -o "db_cleanup" | wc -l)

      When call echo "$count"
      The output should eq 1
    End
  End

  Describe 'Stack level tracking:'
    It 'tracks stack level correctly'
      # Initial level should be 0
      trap:push EXIT 2>>"$TRAP_TEST_STDERR"
      trap:push EXIT 2>>"$TRAP_TEST_STDERR"
      trap:pop EXIT 2>>"$TRAP_TEST_STDERR"
      trap:pop EXIT 2>>"$TRAP_TEST_STDERR"

      When call echo "$__TRAP_STACK_LEVEL"
      The output should eq "0"
    End

    It 'prevents pop when stack is empty'
      setup() {
        # Ensure stack is empty
        while [ "$__TRAP_STACK_LEVEL" -gt 0 ]; do
          trap:pop EXIT 2>>"$TRAP_TEST_STDERR" || break
        done
      }
      BeforeCall 'setup 2>>"$TRAP_TEST_STDERR"'

      test_empty_pop() {
        DEBUG=Trap trap:pop EXIT
      }

      When call test_empty_pop
      The status should be failure
      The error should include "No trap state to pop"
    End
  End

  Describe 'Multiple signals with scoping:'
    multi_handler() { echo "multi" >/dev/null; }

    It 'pushes and pops multiple signals together'
      # Register for multiple signals
      trap:on multi_handler INT TERM HUP 2>>"$TRAP_TEST_STDERR"

      # Push all
      trap:push INT TERM HUP 2>>"$TRAP_TEST_STDERR"

      # Add new handlers
      new_int() { echo "new_int" >/dev/null; }
      new_term() { echo "new_term" >/dev/null; }
      trap:on new_int INT 2>>"$TRAP_TEST_STDERR"
      trap:on new_term TERM 2>>"$TRAP_TEST_STDERR"

      # Pop all
      trap:pop INT TERM HUP 2>>"$TRAP_TEST_STDERR"

      When call trap:list TERM
      The output should not include "new_term"
      The output should include "multi_handler"
    End
  End

  Describe 'Error handling in nested contexts:'
    It 'handles missing function gracefully during registration'
      When call trap:on nonexistent_nested_handler EXIT
      The status should be failure
      The error should include "does not exist"
    End

    It 'recovers from stack corruption'
      # Manually corrupt stack by unsetting variable
      trap:push EXIT 2>>"$TRAP_TEST_STDERR"
      unset "__TRAP_STACK_${__TRAP_STACK_LEVEL}"

      When call trap:pop EXIT
      The status should be failure
      The error should include "Stack corruption"
    End
  End
End
