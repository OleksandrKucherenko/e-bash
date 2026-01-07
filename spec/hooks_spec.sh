#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# shellcheck disable=SC2288
% TEST_HOOKS_DIR: "$SHELLSPEC_TMPBASE/test_hooks"

export SCRIPT_DIR=".scripts"
export E_BASH="$(pwd)/${SCRIPT_DIR}"

# Enable debug output for hooks module to verify execution paths
export DEBUG="hooks"

# Mock logger functions to output to STDERR for test verification
# Logger output is our verification point - it shows which code paths executed
Mock printf:Hooks
  printf "$@" >&2
End

Mock echo:Hooks
  echo "$@" >&2
End

Mock echo:Error
  echo "$@" >&2
End

# Helper functions to strip ANSI color codes for comparison
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' ' | sed 's/^ *//; s/ *$//'; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' ' | sed 's/^ *//; s/ *$//'; }

# Test isolation helper functions
setup_test_hooks_dir() {
  mkdir -p "$TEST_HOOKS_DIR"
  export HOOKS_DIR="$TEST_HOOKS_DIR"
}

cleanup_test_hooks_dir() {
  rm -rf "$TEST_HOOKS_DIR"
}

Describe '_hooks.sh /'
  Include ".scripts/_hooks.sh"

  # Cleanup mechanism
  AfterEach 'cleanup_test_hooks_dir'
  AfterAll 'hooks:reset'

  Context 'Hook definition /'
    It 'defines multiple hooks successfully'
      When call hooks:declare begin end decide error rollback

      The status should be success
      # Verify each hook was registered via logger output
      The result of function no_colors_stderr should include "Registered hook: begin"
      The result of function no_colors_stderr should include "Registered hook: end"
      The result of function no_colors_stderr should include "Registered hook: decide"
      The result of function no_colors_stderr should include "Registered hook: error"
      The result of function no_colors_stderr should include "Registered hook: rollback"
    End

    It 'rejects invalid hook names with special characters'
      When call hooks:declare "invalid@hook"

      The status should be failure
      The result of function no_colors_stderr should include "invalid hook name"
    End

    It 'accepts hook names with underscores and dashes'
      When call hooks:declare my_hook my-hook

      The status should be success
      # Verify both hooks were registered via logger output
      The result of function no_colors_stderr should include "Registered hook: my_hook"
      The result of function no_colors_stderr should include "Registered hook: my-hook"
    End

  End

  Context 'Hooks bootstrap /'
    It 'declares begin and end hooks'
      setup() {
        hooks:reset
        export HOOKS_AUTO_TRAP="false"
        hooks:bootstrap
      }
      BeforeCall 'setup'

      run_bootstrap() {
        hooks:do begin >/dev/null
      }

      When call run_bootstrap

      The status should be success
      The result of function no_colors_stderr should include "Executing hook: begin"
    End

    It 'loads trap:on helper'
      check_trap_helper() {
        type trap:on >/dev/null
      }

      When call check_trap_helper

      The status should be success
    End
  End

  Context 'Hook execution with functions /'
    It 'executes hook function when defined'
      setup() {
        hooks:declare test_hook
        hook:test_hook() {
          echo "Hook executed"
        }
      }
      BeforeCall 'setup'

      When call hooks:do test_hook

      The status should be success
      The output should eq "Hook executed"
      # Verify via logger that the function was called
      The result of function no_colors_stderr should include "[function] hook:test_hook"
      The result of function no_colors_stderr should include "exit code: 0"
    End

    It 'passes parameters to hook function'
      setup() {
        hooks:declare test_hook
        hook:test_hook() {
          echo "Params: $*"
        }
      }
      BeforeCall 'setup'

      When call hooks:do test_hook param1 param2

      The status should be success
      The output should eq "Params: param1 param2"
      # Verify hook execution logged
      The result of function no_colors_stderr should include "Executing hook: test_hook"
    End

    It 'captures return value from hook function'
      setup() {
        hooks:declare decide
        hook:decide() {
          echo "yes"
          return 0
        }
      }
      BeforeCall 'setup'

      When call hooks:do decide

      The status should be success
      The output should eq "yes"
      # Verify successful completion logged
      The result of function no_colors_stderr should include "Completed hook 'decide'"
      The result of function no_colors_stderr should include "exit code: 0"
    End

    It 'propagates hook function exit code'
      setup() {
        hooks:declare error_hook
        hook:error_hook() {
          echo "Error occurred"
          return 42
        }
      }
      BeforeCall 'setup'

      When call hooks:do error_hook

      The status should eq 42
      The output should eq "Error occurred"
      # Verify exit code propagation logged
      The result of function no_colors_stderr should include "exit code: 42"
    End

    It 'silently skips undefined hooks'
      When call hooks:do undefined_hook

      The status should be success
      The output should eq ''
      # Verify logger shows hook was skipped (not defined)
      The result of function no_colors_stderr should include "not defined, skipping"
    End

    It 'silently skips defined but not implemented hooks'
      BeforeCall 'hooks:declare not_implemented'

      When call hooks:do not_implemented

      The status should be success
      The output should eq ''
      # Verify logger shows no implementation found
      The result of function no_colors_stderr should include "⚪ No implementations found for hook"
    End
  End

  Context 'Hook execution with scripts /'
    setup_hooks_dir() {
      setup_test_hooks_dir
      
    }

    cleanup_hooks_dir() {
      rm -rf "$TEST_HOOKS_DIR"
    }

    BeforeAll 'setup_hooks_dir'
    AfterAll 'cleanup_hooks_dir'

    It 'executes hook script when present'
      test_script_hook() {
        # Set up test environment
        setup_test_hooks_dir
        
        hooks:declare script_hook
        cat > "$TEST_HOOKS_DIR/script_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
echo "Script hook executed"
EOF
        chmod +x "$TEST_HOOKS_DIR"/script_hook-test.sh
        
        hooks:do script_hook
        
        # Clean up
      }

      When call test_script_hook

      The status should be success
      The output should eq "Script hook executed"
      The result of function no_colors_stderr should include "[script 1/1] script_hook-test.sh"
      The result of function no_colors_stderr should include "exit code: 0"
    End

    It 'passes parameters to hook script'
      test_script_params() {
        # Set up test environment
        setup_test_hooks_dir
        
        hooks:declare script_hook
        cat > "$TEST_HOOKS_DIR/script_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
echo "Script params: $*"
EOF
        chmod +x "$TEST_HOOKS_DIR"/script_hook-test.sh
        
        hooks:do script_hook arg1 arg2
        
        # Clean up
      }

      When call test_script_params

      The status should be success
      The output should eq "Script params: arg1 arg2"
      The result of function no_colors_stderr should include "Executing hook: script_hook"
    End

    It 'propagates script exit code'
      test_script_exit_code() {
        # Set up test environment
        setup_test_hooks_dir
        
        
        hooks:declare fail_hook
        cat > "$TEST_HOOKS_DIR/fail_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
exit 13
EOF
        chmod +x "$TEST_HOOKS_DIR"/fail_hook-test.sh
        
        # Execute hook and capture exit code
        hooks:do fail_hook
        local exit_code=$?
        
        # Clean up
        
        # Return the captured exit code
        return $exit_code
      }

      When call test_script_exit_code

      The status should eq 13
      The result of function no_colors_stderr should include "exit code: 13"
    End

    It 'executes function first, then scripts when both exist'
      test_priority_hook() {
        # Set up test environment
        setup_test_hooks_dir
        
        
        hooks:declare priority_hook
        hook:priority_hook() {
          echo "Function implementation"
        }
        cat > "$TEST_HOOKS_DIR/priority_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
echo "Script implementation"
EOF
        chmod +x "$TEST_HOOKS_DIR"/priority_hook-test.sh
        
        hooks:do priority_hook
        
        # Clean up
      }

      When call test_priority_hook

      The status should be success
      The line 1 should eq "Function implementation"
      The line 2 should eq "Script implementation"
      The result of function no_colors_stderr should include "[function] hook:priority_hook"
      The result of function no_colors_stderr should include "[script 1/1]"
    End

    It 'executes registered functions and scripts in one alphabetical sequence'
      setup() {
        setup_test_hooks_dir
        hooks:declare merge_order
        hook:merge_order() { echo "function"; }
        func_alpha() { echo "alpha"; }
        func_charlie() { echo "charlie"; }
        hooks:register merge_order "10-alpha" func_alpha
        hooks:register merge_order "30-charlie" func_charlie
        cat > "$TEST_HOOKS_DIR/merge_order-20-bravo.sh" <<'EOF'
#!/usr/bin/env bash
echo "bravo"
EOF
        chmod +x "$TEST_HOOKS_DIR"/merge_order-20-bravo.sh
      }
      BeforeCall 'setup'

      When call hooks:do merge_order

      The status should be success
      The line 1 should eq "function"
      The line 2 should eq "alpha"
      The line 3 should eq "bravo"
      The line 4 should eq "charlie"
      The result of function no_colors_stderr should include "Executing hook: merge_order"
    End

    It 'skips non-executable script files'
      test_non_executable() {
        # Set up test environment
        setup_test_hooks_dir
        
        
        hooks:declare no_exec_hook
        cat > "$TEST_HOOKS_DIR/no_exec_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
echo "This should not execute"
EOF
        # Intentionally not making it executable
        
        hooks:do no_exec_hook
        
        # Clean up
      }

      When call test_non_executable

      The status should be success
      The output should eq ''
      The result of function no_colors_stderr should include "⚪ No implementations found"
    End
  End

  Context 'Multiple hook scripts with ci-cd pattern /'
    It 'executes scripts with numbered pattern in order'
      test_numbered_scripts() {
        # Set up test environment
        setup_test_hooks_dir
        
        
        hooks:declare begin
        cat > "$TEST_HOOKS_DIR/begin_01_init.sh" <<'EOF'
#!/usr/bin/env bash
echo "Step 1: Init"
EOF
        cat > "$TEST_HOOKS_DIR/begin_02_validate.sh" <<'EOF'
#!/usr/bin/env bash
echo "Step 2: Validate"
EOF
        cat > "$TEST_HOOKS_DIR/begin_10_finalize.sh" <<'EOF'
#!/usr/bin/env bash
echo "Step 10: Finalize"
EOF
        chmod +x "$TEST_HOOKS_DIR"/begin_*.sh
        
        hooks:do begin
        
        # Clean up
      }

      When call test_numbered_scripts

      The status should be success
      # Scripts execute in lexicographic order: 01 < 02 < 10
      The line 1 should eq "Step 1: Init"
      The line 2 should eq "Step 2: Validate"
      The line 3 should eq "Step 10: Finalize"
      The result of function no_colors_stderr should include "Found 3 script(s) for hook 'begin'"
    End

    It 'passes parameters to all hook scripts'
      setup() {
        setup_test_hooks_dir
        hooks:declare process
        cat > "$TEST_HOOKS_DIR/process-validate.sh" <<'EOF'
#!/usr/bin/env bash
echo "Validate: $1"
EOF
        cat > "$TEST_HOOKS_DIR/process-execute.sh" <<'EOF'
#!/usr/bin/env bash
echo "Execute: $1"
EOF
        chmod +x "$TEST_HOOKS_DIR"/process-*.sh
      }
      BeforeCall 'setup'

      When call hooks:do process "data.txt"

      The status should be success
      The line 1 should eq "Execute: data.txt"
      The line 2 should eq "Validate: data.txt"
      # Verify execution was logged
      The result of function no_colors_stderr should include "Executing hook: process"
    End

    It 'returns exit code of last executed script'
      setup() {
        setup_test_hooks_dir
        hooks:declare test_hook
        cat > "$TEST_HOOKS_DIR/test_hook-first.sh" <<'EOF'
#!/usr/bin/env bash
echo "First"
exit 0
EOF
        cat > "$TEST_HOOKS_DIR/test_hook-second.sh" <<'EOF'
#!/usr/bin/env bash
echo "Second"
exit 42
EOF
        chmod +x "$TEST_HOOKS_DIR"/test_hook-*.sh
      }
      BeforeCall 'setup'

      When call hooks:do test_hook

      The status should eq 42
      The output should include "First"
      The output should include "Second"
      # Verify exit codes were logged
      The result of function no_colors_stderr should include "exit code: 0"
      The result of function no_colors_stderr should include "exit code: 42"
    End

    It 'skips non-matching script names'
      setup() {
        setup_test_hooks_dir
        hooks:declare specific_hook
        cat > "$TEST_HOOKS_DIR/specific_hook-valid.sh" <<'EOF'
#!/usr/bin/env bash
echo "Valid script"
EOF
        cat > "$TEST_HOOKS_DIR/other_hook-invalid.sh" <<'EOF'
#!/usr/bin/env bash
echo "Should not execute"
EOF
        chmod +x "$TEST_HOOKS_DIR"/*.sh
      }
      BeforeCall 'setup'

      When call hooks:do specific_hook

      The status should be success
      The output should eq "Valid script"
      The output should not include "Should not execute"
      # Verify only matching script was executed
      The result of function no_colors_stderr should include "Found 1 script(s) for hook 'specific_hook'"
    End

    It 'supports both dash and underscore patterns'
      setup() {
        setup_test_hooks_dir
        hooks:declare flexible
        cat > "$TEST_HOOKS_DIR/flexible-dash.sh" <<'EOF'
#!/usr/bin/env bash
echo "Dash pattern"
EOF
        cat > "$TEST_HOOKS_DIR/flexible_underscore.sh" <<'EOF'
#!/usr/bin/env bash
echo "Underscore pattern"
EOF
        chmod +x "$TEST_HOOKS_DIR"/flexible*.sh
      }
      BeforeCall 'setup'

      When call hooks:do flexible

      The status should be success
      The output should include "Dash pattern"
      The output should include "Underscore pattern"
      # Verify scripts with both patterns were found
      The result of function no_colors_stderr should include "Found 2 script(s) for hook 'flexible'"
    End
  End

  Context 'Hook introspection /'
    It 'lists defined hooks when none exist'
      setup() {
        hooks:reset
        # Re-source to reinitialize
        source ".scripts/_hooks.sh"
      }
      BeforeCall 'setup'

      When call hooks:list

      The status should be success
      The output should eq "No hooks defined"
    End

    It 'lists defined hooks with implementation status'
      setup() {
        hooks:reset
        source ".scripts/_hooks.sh"
        hooks:declare test1 test2
        hook:test1() { :; }
      }
      BeforeCall 'setup'

      When call hooks:list

      The status should be success
      The output should include "test1: implemented (function)"
      The output should include "test2: not implemented"
      # Verify hooks were registered via logger
      The result of function no_colors_stderr should include "Registered hook: test1"
      The result of function no_colors_stderr should include "Registered hook: test2"
    End

    It 'checks if hook is defined'
      setup() {
        hooks:declare existing_hook
      }
      BeforeCall 'setup'

      When call hooks:known existing_hook

      The status should be success
      # Verify hook was registered
      The result of function no_colors_stderr should include "Registered hook: existing_hook"
    End

    It 'returns false for undefined hooks'
      When call hooks:known nonexistent_hook

      The status should be failure
    End

    It 'checks if hook has implementation - function'
      setup() {
        hooks:declare impl_hook
        hook:impl_hook() { :; }
      }
      BeforeCall 'setup'

      When call hooks:runnable impl_hook

      The status should be success
      # Verify hook registration
      The result of function no_colors_stderr should include "Registered hook: impl_hook"
    End

    It 'checks if hook has implementation - script'
      setup() {
        setup_test_hooks_dir
        hooks:declare impl_hook
        cat > "$TEST_HOOKS_DIR/impl_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
:
EOF
        chmod +x "$TEST_HOOKS_DIR/impl_hook-test.sh"
      }
      BeforeCall 'setup'

      When call hooks:runnable impl_hook

      The status should be success
      # Verify hook registration
      The result of function no_colors_stderr should include "Registered hook: impl_hook"
    End

    It 'returns false when hook has no implementation'
      setup() {
        hooks:declare no_impl_hook
      }
      BeforeCall 'setup'

      When call hooks:runnable no_impl_hook

      The status should be failure
      # Verify hook was registered but has no implementation
      The result of function no_colors_stderr should include "Registered hook: no_impl_hook"
    End
  End

  Context 'Sourced execution mode /'
    setup_source_dir() {
      TEST_SOURCE_DIR="${SHELLSPEC_TMPBASE}/test_source"
      mkdir -p "$TEST_SOURCE_DIR"
      export HOOKS_DIR="$TEST_SOURCE_DIR"
      export HOOKS_EXEC_MODE="source"
    }

    cleanup_source_dir() {
      rm -rf "$TEST_SOURCE_DIR"
      export HOOKS_EXEC_MODE="exec"
    }

    BeforeAll 'setup_source_dir'
    AfterAll 'cleanup_source_dir'

    It 'sources script and calls hook:run function'
      setup() {
        hooks:declare test_source
        cat > "$TEST_SOURCE_DIR/test_source-script.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Sourced execution"
}
EOF
        chmod +x "$TEST_SOURCE_DIR/test_source-script.sh"
      }
      BeforeCall 'setup'

      When call hooks:do test_source

      The status should be success
      The output should include "Sourced execution"
      # Verify source mode execution logged
      The result of function no_colors_stderr should include "sourced mode"
    End

    It 'passes parameters to hook:run function'
      setup() {
        hooks:declare test_params
        cat > "$TEST_SOURCE_DIR"/test_params-script.sh <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Params: $*"
}
EOF
        chmod +x "$TEST_SOURCE_DIR"/test_params-script.sh
      }
      BeforeCall 'setup'

      When call hooks:do test_params arg1 arg2

      The status should be success
      The output should include "Params: arg1 arg2"
      # Verify hook execution logged
      The result of function no_colors_stderr should include "Executing hook: test_params"
    End

    It 'outputs warning when script lacks hook:run function'
      # Note: In source mode, top-level code always executes when sourced.
      # This is fundamental bash behavior - we can only warn after sourcing.
      setup() {
        export DEBUG="hooks"
        hooks:declare test_no_func
        cat > "$TEST_SOURCE_DIR"/test_no_func-script.sh <<'EOF'
#!/usr/bin/env bash
echo "Top-level code executes"
EOF
        chmod +x "$TEST_SOURCE_DIR"/test_no_func-script.sh
      }
      BeforeCall 'setup'
      AfterCall 'export DEBUG=""'

      When call hooks:do test_no_func

      The status should be success
      # Top-level code runs when sourced (this is bash behavior)
      The output should include "Top-level code executes"
      # But we still warn about missing hook:run function
      The stderr should include "No hook:run function found"
    End

    It 'can access parent shell variables in sourced mode'
      setup() {
        hooks:declare test_env
        export TEST_VAR="parent_value"
        cat > "$TEST_SOURCE_DIR"/test_env-script.sh <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "TEST_VAR=$TEST_VAR"
  TEST_VAR="modified"
}
EOF
        chmod +x "$TEST_SOURCE_DIR"/test_env-script.sh
      }
      BeforeCall 'setup'

      check_var() {
        hooks:do test_env
        echo "After hook: TEST_VAR=$TEST_VAR"
      }

      When call check_var

      The status should be success
      The output should include "TEST_VAR=parent_value"
      The output should include "After hook: TEST_VAR=modified"
      # Verify hook execution logged
      The result of function no_colors_stderr should include "Executing hook: test_env"
    End
  End

  Context 'Nested hooks support /'
    setup_nested_test() {
      TEST_NESTED_DIR="${SHELLSPEC_TMPBASE}/test_nested"
      mkdir -p "$TEST_NESTED_DIR"
      export HOOKS_DIR="$TEST_NESTED_DIR"
    }

    cleanup_nested_test() {
      rm -rf "$TEST_NESTED_DIR"
      hooks:reset
    }

    BeforeEach 'setup_nested_test'
    AfterEach 'cleanup_nested_test'

    It 'detects when same hook is defined from multiple contexts'
      # Create a helper script that defines a hook
      cat > "$TEST_NESTED_DIR/helper.sh" <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:declare deploy
EOF

      # Source the helper script (defines deploy from helper context)
      # Redirect stderr to avoid polluting test output
      source "$TEST_NESTED_DIR/helper.sh" 2>/dev/null || true

      # Define the same hook from current context (should warn)
      When call hooks:declare deploy

      The status should be success
      # Verify warning about multiple contexts
      The result of function no_colors_stderr should include "Warning: Hook 'deploy' is being defined from multiple contexts"
    End

    It 'skips redefinition from same context silently'
      # Note: ShellSpec runs the setup and When call from different internal contexts,
      # so we test this behavior using a wrapper function that defines twice.
      test_redefine() {
        export DEBUG="hooks"
        hooks:declare deploy 2>&1
        hooks:declare deploy 2>&1
      }

      When call test_redefine

      The status should be success
      # Output goes to stdout since we redirect stderr there
      # First define succeeds, second is silently skipped (no warning)
      The output should include "Registered hook: deploy"
      The output should include "already registered from this context, skipping"
    End

    It 'tracks contexts for each hook'
      # Create two helper scripts
      cat > "$TEST_NESTED_DIR"/helper1.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:declare build
EOF

      cat > "$TEST_NESTED_DIR"/helper2.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:declare build
EOF

      # Source both helpers
      source "$TEST_NESTED_DIR"/helper1.sh 2>/dev/null || true
      source "$TEST_NESTED_DIR"/helper2.sh 2>/dev/null || true

      # Check that context tracking works
      test_contexts() {
        # The hook should be defined
        if [[ -n ${__HOOKS_DEFINED[build]+x} ]]; then
          echo "Hook defined: yes"
        else
          echo "Hook defined: no"
        fi

        # Should have multiple contexts
        local contexts="${__HOOKS_CONTEXTS[build]}"
        local count=$(echo "$contexts" | tr '|' '\n' | wc -l | tr -d ' ')
        echo "Context count: $count"
      }

      When call test_contexts

      The status should be success
      The line 1 should eq "Hook defined: yes"
      The line 2 should eq "Context count: 2"
    End

    It 'executes hooks defined from multiple contexts'
      # Create a script implementation
      cat > "$TEST_NESTED_DIR"/multi_ctx_hook-test.sh <<'EOF'
#!/usr/bin/env bash
echo "Hook executed"
exit 0
EOF
      chmod +x "$TEST_NESTED_DIR"/multi_ctx_hook-test.sh

      # Create helper that defines the hook
      cat > "$TEST_NESTED_DIR"/helper.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:declare multi_ctx_hook
EOF

      # Source helper and define from current context
      source "$TEST_NESTED_DIR"/helper.sh 2>/dev/null || true
      hooks:declare multi_ctx_hook 2>/dev/null || true

      # Execute the hook - should work even with multiple contexts
      When call hooks:do multi_ctx_hook

      The status should be success
      The output should include "Hook executed"
      # Verify hook execution via logger
      The result of function no_colors_stderr should include "Executing hook: multi_ctx_hook"
    End
  End

  Context 'Function registration /'
    setup_registration_test() {
      hooks:reset
    }

    AfterEach 'setup_registration_test'

    It 'registers a function for a hook'
      test_func() {
        echo "Test function executed"
      }

      # Silence setup output
      hooks:declare build 2>/dev/null
      hooks:register build "10-test" test_func 2>/dev/null

      When call hooks:do build

      The status should be success
      The output should include "Test function executed"
      # Verify execution via logger
      The result of function no_colors_stderr should include "[registered 1/1] 10-test"
      The result of function no_colors_stderr should include "exit code: 0"
    End

    It 'registers multiple functions for same hook in alphabetical order'
      func_a() { echo "Function A"; }
      func_b() { echo "Function B"; }
      func_c() { echo "Function C"; }

      # Silence setup output
      hooks:declare deploy 2>/dev/null
      hooks:register deploy "30-third" func_c 2>/dev/null
      hooks:register deploy "10-first" func_a 2>/dev/null
      hooks:register deploy "20-second" func_b 2>/dev/null

      When call hooks:do deploy

      The status should be success
      The line 1 should eq "Function A"
      The line 2 should eq "Function B"
      The line 3 should eq "Function C"
      # Verify execution order via logger
      The result of function no_colors_stderr should include "Found 3 registered function(s)"
    End

    It 'unregisters a function from a hook'
      test_func() { echo "Test function"; }

      # Silence setup output
      hooks:declare clean 2>/dev/null
      hooks:register clean "test" test_func 2>/dev/null
      hooks:unregister clean "test" 2>/dev/null

      When call hooks:do clean

      The status should be success
      The output should not include "Test function"
      # Verify no implementations found after unregister
      The result of function no_colors_stderr should include "⚪ No implementations found"
    End

    It 'fails to register if function does not exist'
      # Silence setup output
      hooks:declare test_hook 2>/dev/null

      When call hooks:register test_hook "friendly" non_existent_func

      The status should be failure
      The result of function no_colors_stderr should include "function 'non_existent_func' does not exist"
    End

    It 'fails to register duplicate friendly name'
      test_func1() { echo "Func 1"; }
      test_func2() { echo "Func 2"; }

      # Silence setup output
      hooks:declare test_hook 2>/dev/null
      hooks:register test_hook "same-name" test_func1 2>/dev/null

      When call hooks:register test_hook "same-name" test_func2

      The status should be failure
      The result of function no_colors_stderr should include "friendly name 'same-name' already registered"
    End

    It 'executes hook:prefix function before registered functions'
      hook:build() { echo "Hook function"; }
      registered_func() { echo "Registered function"; }

      # Silence setup output
      hooks:declare build 2>/dev/null
      hooks:register build "50-registered" registered_func 2>/dev/null

      When call hooks:do build

      The status should be success
      The line 1 should eq "Hook function"
      The line 2 should eq "Registered function"
      # Verify both function and registered function were executed
      The result of function no_colors_stderr should include "[function] hook:build"
      The result of function no_colors_stderr should include "[registered 1/1]"
    End

    It 'handles unregistering from non-existent hook'
      When call hooks:unregister non_existent_hook "friendly"

      The status should be failure
      The result of function no_colors_stderr should include "no registrations found for hook 'non_existent_hook'"
    End

    It 'handles unregistering non-existent friendly name'
      test_func() { echo "Test"; }

      # Silence setup output
      hooks:declare test_hook 2>/dev/null
      hooks:register test_hook "exists" test_func 2>/dev/null

      When call hooks:unregister test_hook "does_not_exist"

      The status should be failure
      The result of function no_colors_stderr should include "registration 'does_not_exist' not found"
    End

    It 'can register functions for forwarding to external scripts'
      external_script="/tmp/external_test.sh"
      cat > "$external_script" <<'EOF'
#!/usr/bin/env bash
echo "External script via function"
exit 0
EOF
      chmod +x "$external_script"

      forward_to_external() {
        "$external_script" "$@"
      }

      # Silence setup output
      hooks:declare process 2>/dev/null
      hooks:register process "external" forward_to_external 2>/dev/null

      When call hooks:do process

      The status should be success
      The output should include "External script via function"
      # Verify execution via logger
      The result of function no_colors_stderr should include "[registered 1/1] external"

      rm -f "$external_script"
    End
  End

  Context 'Middleware registration /'
    It 'registers middleware per hook and logs it'
      setup() {
        hooks:declare mid_hook
        middleware:noop() { return 0; }
      }
      BeforeCall 'setup'

      When call hooks:middleware mid_hook middleware:noop

      The status should be success
      The result of function no_colors_stderr should include "Registered middleware"
    End

    It 'resets middleware to default when only hook name provided'
      setup() {
        hooks:declare mid_hook
        middleware:noop() { return 0; }
        hooks:middleware mid_hook middleware:noop
      }
      BeforeCall 'setup'

      When call hooks:middleware mid_hook

      The status should be success
      The result of function no_colors_stderr should include "Reset middleware"
    End
  End

  Context 'Middleware behavior /'
    It 'replays stdout/stderr unchanged via default middleware'
      setup() {
        hooks:declare cap_hook
        hook:cap_hook() {
          echo "out"
          echo "err" >&2
          return 7
        }
      }
      BeforeCall 'setup'

      When call hooks:do cap_hook

      The status should eq 7
      The output should eq "out"
      The error should include "err"
    End

    It 'fails when middleware call lacks separator'
      setup() {
        hooks:declare sep_hook
        hook:sep_hook() { echo "ok"; }
      }
      BeforeCall 'setup'

      When call _hooks:middleware:default sep_hook 0 missing_separator

      The status should be failure
      The result of function no_colors_stderr should include "expects '--' separator"
    End

    It 'ignores extra args without separator in modes middleware'
      run_without_separator() {
        local cap=("1: payload")
        _hooks:middleware:modes mode_hook 0 cap "extra"
      }

      When call run_without_separator

      The status should be success
      The output should eq "payload"
      The result of function no_colors_stderr should include "middleware is processing hook: 'mode_hook'"
      The result of function no_colors_stderr should include "total captured lines for 'mode_hook': 1"
    End

    It 'allows middleware to set parent-shell variables'
      setup() {
        hooks:declare mid_hook
        hook:mid_hook() { echo "contract:mode=dry"; }
        middleware:mode() {
          local hook_name="$1" exit_code="$2" capture_var="$3"
          local -n capture_ref="$capture_var"
          local line
          for line in "${capture_ref[@]}"; do
            [[ "$line" == "1: contract:mode=dry" ]] && export DRY_RUN=true
          done
          return "$exit_code"
        }
        hooks:middleware mid_hook middleware:mode
      }
      BeforeCall 'setup'

      check_dry_run() {
        hooks:do mid_hook
        echo "DRY_RUN=${DRY_RUN}"
      }

      When call check_dry_run

      The status should be success
      The output should eq "DRY_RUN=true"
      The result of function no_colors_stderr should include "Executing hook: mid_hook"
    End

    It 'applies contract env set via modes middleware'
      setup() {
        hooks:declare env_set
        hook:env_set() { echo "contract:env:FOO=bar"; }
        hooks:middleware env_set _hooks:middleware:modes
      }
      BeforeCall 'setup'

      check_env_set() {
        unset FOO
        hooks:do env_set >/dev/null
        echo "FOO=${FOO:-}"
      }

      When call check_env_set

      The status should be success
      The output should eq "FOO=bar"
      The result of function no_colors_stderr should include "Executing hook: env_set"
    End

    It 'replays contract lines while applying side effects'
      setup() {
        hooks:declare env_replay
        hook:env_replay() {
          echo "contract:env:FOO=bar"
          echo "payload"
        }
        hooks:middleware env_replay _hooks:middleware:modes
      }
      BeforeCall 'setup'

      run_replay() {
        unset FOO
        hooks:do env_replay
        echo "FOO=${FOO:-}"
      }

      When call run_replay

      The status should be success
      The result of function no_colors_stdout should include "contract:env:FOO=bar"
      The result of function no_colors_stdout should include "payload"
      The result of function no_colors_stdout should include "FOO=bar"
      The result of function no_colors_stderr should include "Executing hook: env_replay"
    End

    It 'applies contract env append via modes middleware'
      setup() {
        hooks:declare env_append
        hook:env_append() { echo "contract:env:HOOKS_TEST_PATH+=/opt/bin"; }
        hooks:middleware env_append _hooks:middleware:modes
      }
      BeforeCall 'setup'

      check_env_append() {
        HOOKS_TEST_PATH="/bin"
        hooks:do env_append >/dev/null
        echo "HOOKS_TEST_PATH=${HOOKS_TEST_PATH}"
      }

      When call check_env_append

      The status should be success
      The output should eq "HOOKS_TEST_PATH=/bin:/opt/bin"
      The result of function no_colors_stderr should include "Executing hook: env_append"
    End

    It 'applies contract env prepend via modes middleware'
      setup() {
        hooks:declare env_prepend
        hook:env_prepend() { echo "contract:env:HOOKS_TEST_PATH^=/opt/bin"; }
        hooks:middleware env_prepend _hooks:middleware:modes
      }
      BeforeCall 'setup'

      check_env_prepend() {
        HOOKS_TEST_PATH="/bin"
        hooks:do env_prepend >/dev/null
        echo "HOOKS_TEST_PATH=${HOOKS_TEST_PATH}"
      }

      When call check_env_prepend

      The status should be success
      The output should eq "HOOKS_TEST_PATH=/opt/bin:/bin"
      The result of function no_colors_stderr should include "Executing hook: env_prepend"
    End

    It 'applies contract env remove via modes middleware'
      setup() {
        hooks:declare env_remove
        hook:env_remove() { echo "contract:env:HOOKS_TEST_PATH-=/opt/bin"; }
        hooks:middleware env_remove _hooks:middleware:modes
      }
      BeforeCall 'setup'

      check_env_remove() {
        HOOKS_TEST_PATH="/bin:/opt/bin:/usr/bin"
        hooks:do env_remove >/dev/null
        echo "HOOKS_TEST_PATH=${HOOKS_TEST_PATH}"
      }

      When call check_env_remove

      The status should be success
      The output should eq "HOOKS_TEST_PATH=/bin:/usr/bin"
      The result of function no_colors_stderr should include "Executing hook: env_remove"
    End

    It 'applies contract route via modes middleware'
      setup() {
        hooks:declare route_hook
        route_script="$(mktemp)"
        cat > "$route_script" <<'EOF'
echo "routed"
__HOOKS_FLOW_EXIT_CODE=5
EOF
        hook:route_hook() { echo "contract:route:${route_script}"; }
        hooks:middleware route_hook _hooks:middleware:modes
      }
      BeforeCall 'setup'

      run_route() {
        hooks:do route_hook >/dev/null
        local routed_output=""
        routed_output="$( (hooks:flow:apply) )"
        local routed_code=$?
        if [[ -n "${routed_output}" ]]; then
          printf '%s\n' "${routed_output}"
        fi
        printf 'code=%s\n' "${routed_code}"
      }

      When call run_route

      The status should be success
      The output should eq "routed
code=5"
      The result of function no_colors_stderr should include "Executing hook: route_hook"
    End

    It 'applies contract exit via modes middleware'
      setup() {
        hooks:declare exit_hook
        hook:exit_hook() { echo "contract:exit:12"; }
        hooks:middleware exit_hook _hooks:middleware:modes
      }
      BeforeCall 'setup'

      run_exit() {
        hooks:do exit_hook >/dev/null
        local exit_output=""
        exit_output="$( (hooks:flow:apply) )"
        local exit_code=$?
        if [[ -n "${exit_output}" ]]; then
          printf '%s\n' "${exit_output}"
        fi
        printf 'code=%s\n' "${exit_code}"
      }

      When call run_exit

      The status should be success
      The output should eq "code=12"
      The result of function no_colors_stderr should include "Executing hook: exit_hook"
    End

    It 'bypasses middleware for source-mode scripts'
      setup() {
        setup_test_hooks_dir
        export HOOKS_EXEC_MODE="source"
        hooks:declare source_hook
        cat > "$TEST_HOOKS_DIR/source_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "source-out"
}
EOF
        chmod +x "$TEST_HOOKS_DIR"/source_hook-test.sh
        middleware:noop() { return 9; }
        hooks:middleware source_hook middleware:noop
      }
      BeforeCall 'setup'
      AfterCall 'export HOOKS_EXEC_MODE="exec"'

      When call hooks:do source_hook

      The status should be success
      The output should include "source-out"
      The result of function no_colors_stderr should include "sourced mode"
    End

    It 'allows middleware to override exit code'
      setup() {
        hooks:declare code_hook
        hook:code_hook() { return 2; }
        middleware:override() { return 11; }
        hooks:middleware code_hook middleware:override
      }
      BeforeCall 'setup'

      When call hooks:do code_hook

      The status should eq 11
      The result of function no_colors_stderr should include "Executing hook: code_hook"
    End

    It 'provides prefixed capture lines to middleware'
      setup() {
        hooks:declare cap_format
        hook:cap_format() { echo "a"; echo "b" >&2; }
        middleware:inspect() {
          local hook_name="$1" exit_code="$2" capture_var="$3"
          local -n capture_ref="$capture_var"
          printf '%s\n' "${capture_ref[0]}"
          printf '%s\n' "${capture_ref[1]}"
          return "$exit_code"
        }
        hooks:middleware cap_format middleware:inspect
      }
      BeforeCall 'setup'

      When call hooks:do cap_format

      The output should include "1: a"
      The output should include "2: b"
      The result of function no_colors_stderr should include "Executing hook: cap_format"
    End
  End

  Context 'Pattern registration /'
    setup_pattern_test() {
      hooks:reset
      source ".scripts/_hooks.sh"
    }

    AfterEach 'setup_pattern_test'

    It 'determines execution mode with hooks:exec:mode for source patterns'
      setup() {
        hooks:pattern:source "config-*.sh" 2>/dev/null
        hooks:pattern:script "notify-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:exec:mode "config-init.sh"

      The status should be success
      The output should eq "source"
    End

    It 'determines execution mode with hooks:exec:mode for script patterns'
      setup() {
        hooks:pattern:source "config-*.sh" 2>/dev/null
        hooks:pattern:script "notify-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:exec:mode "notify-slack.sh"

      The status should be success
      The output should eq "exec"
    End

    It 'falls back to global HOOKS_EXEC_MODE for unmatched patterns'
      setup() {
        export HOOKS_EXEC_MODE="source"
        hooks:pattern:source "config-*.sh" 2>/dev/null
        hooks:pattern:script "notify-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:exec:mode "random-script.sh"

      The status should be success
      The output should eq "source"
    End

    It 'prioritizes source patterns over script patterns'
      setup() {
        hooks:pattern:script "test-*.sh" 2>/dev/null
        hooks:pattern:source "test-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:exec:mode "test-example.sh"

      The status should be success
      The output should eq "source"
    End

    It 'handles wildcard patterns correctly'
      setup() {
        hooks:pattern:source "*-init.sh" 2>/dev/null
        hooks:pattern:script "*-cleanup.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      test_patterns() {
        local mode1 mode2 mode3
        mode1=$(hooks:exec:mode "begin-init.sh")
        mode2=$(hooks:exec:mode "end-cleanup.sh")
        mode3=$(hooks:exec:mode "middle-process.sh")
        echo "init:$mode1 cleanup:$mode2 process:$mode3"
      }

      When call test_patterns

      The status should be success
      The output should eq "init:source cleanup:exec process:exec"
    End
  End

  Context 'Pattern-based execution mode integration /'
    setup_pattern_integration() {
      TEST_PATTERN_DIR="${SHELLSPEC_TMPBASE}/test_patterns"
      mkdir -p "$TEST_PATTERN_DIR"
      hooks:reset
      export HOOKS_DIR="$TEST_PATTERN_DIR"
      export HOOKS_EXEC_MODE="exec"  # Default to exec mode
      source ".scripts/_hooks.sh"
    }

    cleanup_pattern_integration() {
      rm -rf "$TEST_PATTERN_DIR"
      export HOOKS_EXEC_MODE="exec"
    }

    BeforeAll 'setup_pattern_integration'
    AfterAll 'cleanup_pattern_integration'

    It 'executes scripts in source mode when pattern matches'
      test_pattern_source() {
        # Register pattern first
        hooks:pattern:source "test_pattern-*.sh" 2>/dev/null
        
        # Define hook
        hooks:declare test_pattern
        
        # Create script in the current HOOKS_DIR
        cat > "$HOOKS_DIR/test_pattern-config.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Sourced via pattern"
}
EOF
        chmod +x "$HOOKS_DIR"/test_pattern-config.sh
        
        # Execute hook
        hooks:do test_pattern
        
        # Clean up
        rm -f "$HOOKS_DIR/test_pattern-config.sh"
      }

      When call test_pattern_source

      The status should be success
      The output should include "Sourced via pattern"
      The result of function no_colors_stderr should include "sourced mode"
    End

    It 'executes scripts in exec mode when pattern matches'
      test_exec_script() {
        # Register pattern first
        hooks:pattern:script "test_exec-*.sh" 2>/dev/null
        
        # Define hook
        hooks:declare test_exec
        
        # Create script
        cat > "$HOOKS_DIR/test_exec-notify.sh" <<'EOF'
#!/usr/bin/env bash
echo "Executed as script"
EOF
        chmod +x "$HOOKS_DIR"/test_exec-notify.sh
        
        # Execute hook
        hooks:do test_exec
        
        # Clean up
        rm -f "$HOOKS_DIR/test_exec-notify.sh"
      }

      When call test_exec_script

      The status should be success
      The output should include "Executed as script"
      The result of function no_colors_stderr should include "exec mode"
    End

    It 'overrides global HOOKS_EXEC_MODE with source pattern'
      test_override_source() {
        export HOOKS_EXEC_MODE="exec"  # Global setting
        
        # Register pattern first
        hooks:pattern:source "override_test-*.sh" 2>/dev/null
        
        # Define hook
        hooks:declare override_test
        
        # Create script
        cat > "$HOOKS_DIR/override_test-config.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Pattern overrode global mode"
}
EOF
        chmod +x "$HOOKS_DIR"/override_test-config.sh
        
        # Execute hook
        hooks:do override_test
        
        # Clean up
        rm -f "$HOOKS_DIR/override_test-config.sh"
      }

      When call test_override_source

      The status should be success
      The output should include "Pattern overrode global mode"
      The result of function no_colors_stderr should include "sourced mode"
    End

    It 'overrides global HOOKS_EXEC_MODE with script pattern'
      test_override_script() {
        export HOOKS_EXEC_MODE="source"  # Global setting
        
        # Register pattern first
        hooks:pattern:script "script_override-*.sh" 2>/dev/null
        
        # Define hook
        hooks:declare script_override
        
        # Create script
        cat > "$HOOKS_DIR/script_override-notify.sh" <<'EOF'
#!/usr/bin/env bash
echo "Script pattern overrode global source mode"
EOF
        chmod +x "$HOOKS_DIR"/script_override-notify.sh
        
        # Execute hook
        hooks:do script_override
        
        # Clean up
        rm -f "$HOOKS_DIR/script_override-notify.sh"
      }

      When call test_override_script

      The status should be success
      The output should include "Script pattern overrode global source mode"
      The result of function no_colors_stderr should include "exec mode"
    End

    It 'handles multiple scripts with different patterns'
      test_mixed_patterns() {
        # Register patterns first
        hooks:pattern:source "mixed_patterns-config*.sh" 2>/dev/null
        hooks:pattern:script "mixed_patterns-notify*.sh" 2>/dev/null
        
        # Define hook
        hooks:declare mixed_patterns
        
        # Create scripts
        cat > "$HOOKS_DIR/mixed_patterns-config.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Config sourced"
}
EOF
        cat > "$HOOKS_DIR/mixed_patterns-notify.sh" <<'EOF'
#!/usr/bin/env bash
echo "Notify executed"
EOF
        chmod +x "$HOOKS_DIR"/mixed_patterns-*.sh
        
        # Execute hook
        hooks:do mixed_patterns
        
        # Clean up
        rm -f "$HOOKS_DIR/mixed_patterns-"*.sh
      }

      When call test_mixed_patterns

      The status should be success
      The output should include "Config sourced"
      The output should include "Notify executed"
      The result of function no_colors_stderr should include "sourced mode"
      The result of function no_colors_stderr should include "exec mode"
    End
  End
End
