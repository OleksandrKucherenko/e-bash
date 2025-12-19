#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

export SCRIPT_DIR=".scripts"
export E_BASH="$(pwd)/.scripts"

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

# Helper functions to strip ANSI color codes for comparison
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' ' | sed 's/^ *//; s/ *$//'; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' ' | sed 's/^ *//; s/ *$//'; }

Describe '_hooks.sh /'
  Include ".scripts/_hooks.sh"

  # Cleanup mechanism
  AfterAll 'hooks:cleanup'

  Context 'Hook definition /'
    It 'defines single hook successfully'
      When call hooks:define begin

      The status should be success
      # Verify via logger that hook was actually registered
      The result of function no_colors_stderr should include "Registered hook: begin"
    End

    It 'defines multiple hooks successfully'
      When call hooks:define begin end decide error rollback

      The status should be success
      # Verify each hook was registered via logger output
      The result of function no_colors_stderr should include "Registered hook: begin"
      The result of function no_colors_stderr should include "Registered hook: end"
      The result of function no_colors_stderr should include "Registered hook: decide"
      The result of function no_colors_stderr should include "Registered hook: error"
      The result of function no_colors_stderr should include "Registered hook: rollback"
    End

    It 'rejects invalid hook names with special characters'
      When call hooks:define "invalid@hook"

      The status should be failure
      The error should include "Invalid hook name"
    End

    It 'accepts hook names with underscores and dashes'
      When call hooks:define my_hook my-hook

      The status should be success
      # Verify both hooks were registered via logger output
      The result of function no_colors_stderr should include "Registered hook: my_hook"
      The result of function no_colors_stderr should include "Registered hook: my-hook"
    End

    It 'can define custom hook names'
      When call hooks:define custom_pre_process after_validate

      The status should be success
      # Verify custom hook names were registered
      The result of function no_colors_stderr should include "Registered hook: custom_pre_process"
      The result of function no_colors_stderr should include "Registered hook: after_validate"
    End
  End

  Context 'Hook execution with functions /'
    It 'executes hook function when defined'
      setup() {
        hooks:define test_hook
        hook:test_hook() {
          echo "Hook executed"
        }
      }
      BeforeCall 'setup'

      When call on:hook test_hook

      The status should be success
      The output should eq "Hook executed"
      # Verify via logger that the function was called
      The result of function no_colors_stderr should include "[function] hook:test_hook"
      The result of function no_colors_stderr should include "exit code: 0"
    End

    It 'passes parameters to hook function'
      setup() {
        hooks:define test_hook
        hook:test_hook() {
          echo "Params: $*"
        }
      }
      BeforeCall 'setup'

      When call on:hook test_hook param1 param2

      The status should be success
      The output should eq "Params: param1 param2"
      # Verify hook execution logged
      The result of function no_colors_stderr should include "Executing hook: test_hook"
    End

    It 'captures return value from hook function'
      setup() {
        hooks:define decide
        hook:decide() {
          echo "yes"
          return 0
        }
      }
      BeforeCall 'setup'

      When call on:hook decide

      The status should be success
      The output should eq "yes"
      # Verify successful completion logged
      The result of function no_colors_stderr should include "Completed hook 'decide'"
      The result of function no_colors_stderr should include "exit code: 0"
    End

    It 'propagates hook function exit code'
      setup() {
        hooks:define error_hook
        hook:error_hook() {
          echo "Error occurred"
          return 42
        }
      }
      BeforeCall 'setup'

      When call on:hook error_hook

      The status should eq 42
      The output should eq "Error occurred"
      # Verify exit code propagation logged
      The result of function no_colors_stderr should include "exit code: 42"
    End

    It 'silently skips undefined hooks'
      When call on:hook undefined_hook

      The status should be success
      The output should eq ''
      # Verify logger shows hook was skipped (not defined)
      The result of function no_colors_stderr should include "not defined, skipping"
    End

    It 'silently skips defined but not implemented hooks'
      BeforeCall 'hooks:define not_implemented'

      When call on:hook not_implemented

      The status should be success
      The output should eq ''
      # Verify logger shows no implementation found
      The result of function no_colors_stderr should include "No implementations found for hook"
    End
  End

  Context 'Hook execution with scripts /'
    setup_hooks_dir() {
      mkdir -p /tmp/test_hooks
      export HOOKS_DIR=/tmp/test_hooks
    }

    cleanup_hooks_dir() {
      rm -rf /tmp/test_hooks
    }

    BeforeAll 'setup_hooks_dir'
    AfterAll 'cleanup_hooks_dir'

    It 'executes hook script when present'
      test_script_hook() {
        # Set up test environment
        mkdir -p /tmp/test_hooks
        export HOOKS_DIR=/tmp/test_hooks
        
        hooks:define script_hook
        cat > /tmp/test_hooks/script_hook-test.sh <<'EOF'
#!/usr/bin/env bash
echo "Script hook executed"
EOF
        chmod +x /tmp/test_hooks/script_hook-test.sh
        
        on:hook script_hook
        
        # Clean up
        rm -f /tmp/test_hooks/script_hook-test.sh
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
        mkdir -p /tmp/test_hooks
        export HOOKS_DIR=/tmp/test_hooks
        
        hooks:define script_hook
        cat > /tmp/test_hooks/script_hook-test.sh <<'EOF'
#!/usr/bin/env bash
echo "Script params: $*"
EOF
        chmod +x /tmp/test_hooks/script_hook-test.sh
        
        on:hook script_hook arg1 arg2
        
        # Clean up
        rm -f /tmp/test_hooks/script_hook-test.sh
      }

      When call test_script_params

      The status should be success
      The output should eq "Script params: arg1 arg2"
      The result of function no_colors_stderr should include "Executing hook: script_hook"
    End

    It 'propagates script exit code'
      test_script_exit_code() {
        # Set up test environment
        mkdir -p /tmp/test_hooks
        export HOOKS_DIR=/tmp/test_hooks
        
        hooks:define fail_hook
        cat > /tmp/test_hooks/fail_hook-test.sh <<'EOF'
#!/usr/bin/env bash
exit 13
EOF
        chmod +x /tmp/test_hooks/fail_hook-test.sh
        
        # Execute hook and capture exit code
        on:hook fail_hook
        local exit_code=$?
        
        # Clean up
        rm -f /tmp/test_hooks/fail_hook-test.sh
        
        # Return the captured exit code
        return $exit_code
      }

      When call test_script_exit_code

      The status should eq 13
      The result of function no_colors_stderr should include "exit code: 13"
    End

    It 'executes function first, then scripts when both exist'
      setup() {
        hooks:define priority_hook
        hook:priority_hook() {
          echo "Function implementation"
        }
        cat > /tmp/test_hooks/priority_hook-test.sh <<'EOF'
#!/usr/bin/env bash
echo "Script implementation"
EOF
        chmod +x /tmp/test_hooks/priority_hook-test.sh
      }
      BeforeCall 'setup'

      When call on:hook priority_hook

      The status should be success
      The line 1 should eq "Function implementation"
      The line 2 should eq "Script implementation"
      # Verify both function and script were executed
      The result of function no_colors_stderr should include "[function] hook:priority_hook"
      The result of function no_colors_stderr should include "[script 1/1]"
    End

    It 'skips non-executable script files'
      setup() {
        hooks:define no_exec_hook
        cat > /tmp/test_hooks/no_exec_hook-test.sh <<'EOF'
#!/usr/bin/env bash
echo "This should not execute"
EOF
        # Intentionally not making it executable
      }
      BeforeCall 'setup'

      When call on:hook no_exec_hook

      The status should be success
      The output should eq ''
      # Verify logger shows no implementations or script not found
      The result of function no_colors_stderr should include "No implementations found"
    End
  End

  Context 'Multiple hook scripts with ci-cd pattern /'
    setup_cicd_dir() {
      mkdir -p /tmp/test_cicd
      export HOOKS_DIR=/tmp/test_cicd
    }

    cleanup_cicd_dir() {
      rm -rf /tmp/test_cicd
    }

    BeforeAll 'setup_cicd_dir'
    AfterAll 'cleanup_cicd_dir'

    It 'executes multiple scripts in alphabetical order'
      setup() {
        hooks:define deploy
        cat > /tmp/test_cicd/deploy-backup.sh <<'EOF'
#!/usr/bin/env bash
echo "1: Backup"
EOF
        cat > /tmp/test_cicd/deploy-update.sh <<'EOF'
#!/usr/bin/env bash
echo "2: Update"
EOF
        cat > /tmp/test_cicd/deploy-restart.sh <<'EOF'
#!/usr/bin/env bash
echo "3: Restart"
EOF
        chmod +x /tmp/test_cicd/deploy-*.sh
      }
      BeforeCall 'setup'

      When call on:hook deploy

      The status should be success
      # Scripts execute in alphabetical order by filename: backup < restart < update
      The line 1 should eq "1: Backup"
      The line 2 should eq "3: Restart"
      The line 3 should eq "2: Update"
      # Verify via logger that 3 scripts were found and executed
      The result of function no_colors_stderr should include "Found 3 script(s) for hook 'deploy'"
      The result of function no_colors_stderr should include "[script 1/3] deploy-backup.sh"
      The result of function no_colors_stderr should include "[script 2/3] deploy-restart.sh"
      The result of function no_colors_stderr should include "[script 3/3] deploy-update.sh"
    End

    It 'executes scripts with numbered pattern in order'
      setup() {
        hooks:define begin
        cat > /tmp/test_cicd/begin_01_init.sh <<'EOF'
#!/usr/bin/env bash
echo "Step 1: Init"
EOF
        cat > /tmp/test_cicd/begin_02_validate.sh <<'EOF'
#!/usr/bin/env bash
echo "Step 2: Validate"
EOF
        cat > /tmp/test_cicd/begin_10_finalize.sh <<'EOF'
#!/usr/bin/env bash
echo "Step 10: Finalize"
EOF
        chmod +x /tmp/test_cicd/begin_*.sh
      }
      BeforeCall 'setup'

      When call on:hook begin

      The status should be success
      # Scripts execute in lexicographic order: 01 < 02 < 10
      The line 1 should eq "Step 1: Init"
      The line 2 should eq "Step 2: Validate"
      The line 3 should eq "Step 10: Finalize"
      # Verify via logger that scripts were executed in order
      The result of function no_colors_stderr should include "Found 3 script(s) for hook 'begin'"
    End

    It 'passes parameters to all hook scripts'
      setup() {
        hooks:define process
        cat > /tmp/test_cicd/process-validate.sh <<'EOF'
#!/usr/bin/env bash
echo "Validate: $1"
EOF
        cat > /tmp/test_cicd/process-execute.sh <<'EOF'
#!/usr/bin/env bash
echo "Execute: $1"
EOF
        chmod +x /tmp/test_cicd/process-*.sh
      }
      BeforeCall 'setup'

      When call on:hook process "data.txt"

      The status should be success
      The line 1 should eq "Execute: data.txt"
      The line 2 should eq "Validate: data.txt"
      # Verify execution was logged
      The result of function no_colors_stderr should include "Executing hook: process"
    End

    It 'returns exit code of last executed script'
      setup() {
        hooks:define test_hook
        cat > /tmp/test_cicd/test_hook-first.sh <<'EOF'
#!/usr/bin/env bash
echo "First"
exit 0
EOF
        cat > /tmp/test_cicd/test_hook-second.sh <<'EOF'
#!/usr/bin/env bash
echo "Second"
exit 42
EOF
        chmod +x /tmp/test_cicd/test_hook-*.sh
      }
      BeforeCall 'setup'

      When call on:hook test_hook

      The status should eq 42
      The output should include "First"
      The output should include "Second"
      # Verify exit codes were logged
      The result of function no_colors_stderr should include "exit code: 0"
      The result of function no_colors_stderr should include "exit code: 42"
    End

    It 'executes function before scripts'
      setup() {
        hooks:define mixed_hook
        hook:mixed_hook() {
          echo "Function executed"
        }
        cat > /tmp/test_cicd/mixed_hook-script.sh <<'EOF'
#!/usr/bin/env bash
echo "Script executed"
EOF
        chmod +x /tmp/test_cicd/mixed_hook-script.sh
      }
      BeforeCall 'setup'

      When call on:hook mixed_hook

      The status should be success
      The line 1 should eq "Function executed"
      The line 2 should eq "Script executed"
      # Verify both function and script execution logged
      The result of function no_colors_stderr should include "[function] hook:mixed_hook"
      The result of function no_colors_stderr should include "[script 1/1]"
    End

    It 'skips non-matching script names'
      setup() {
        hooks:define specific_hook
        cat > /tmp/test_cicd/specific_hook-valid.sh <<'EOF'
#!/usr/bin/env bash
echo "Valid script"
EOF
        cat > /tmp/test_cicd/other_hook-invalid.sh <<'EOF'
#!/usr/bin/env bash
echo "Should not execute"
EOF
        chmod +x /tmp/test_cicd/*.sh
      }
      BeforeCall 'setup'

      When call on:hook specific_hook

      The status should be success
      The output should eq "Valid script"
      The output should not include "Should not execute"
      # Verify only matching script was executed
      The result of function no_colors_stderr should include "Found 1 script(s) for hook 'specific_hook'"
    End

    It 'lists multiple script implementations'
      setup() {
        hooks:define multi_hook
        cat > /tmp/test_cicd/multi_hook-a.sh <<'EOF'
#!/usr/bin/env bash
:
EOF
        cat > /tmp/test_cicd/multi_hook-b.sh <<'EOF'
#!/usr/bin/env bash
:
EOF
        cat > /tmp/test_cicd/multi_hook-c.sh <<'EOF'
#!/usr/bin/env bash
:
EOF
        chmod +x /tmp/test_cicd/multi_hook-*.sh
      }
      BeforeCall 'setup'

      When call hooks:list

      The status should be success
      The output should include "multi_hook: implemented (3 script(s))"
      # Verify hook listing was logged
      The result of function no_colors_stderr should include "Registered hook: multi_hook"
    End

    It 'supports both dash and underscore patterns'
      setup() {
        hooks:define flexible
        cat > /tmp/test_cicd/flexible-dash.sh <<'EOF'
#!/usr/bin/env bash
echo "Dash pattern"
EOF
        cat > /tmp/test_cicd/flexible_underscore.sh <<'EOF'
#!/usr/bin/env bash
echo "Underscore pattern"
EOF
        chmod +x /tmp/test_cicd/flexible*.sh
      }
      BeforeCall 'setup'

      When call on:hook flexible

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
        hooks:cleanup
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
        hooks:cleanup
        source ".scripts/_hooks.sh"
        hooks:define test1 test2
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
        hooks:define existing_hook
      }
      BeforeCall 'setup'

      When call hooks:is_defined existing_hook

      The status should be success
      # Verify hook was registered
      The result of function no_colors_stderr should include "Registered hook: existing_hook"
    End

    It 'returns false for undefined hooks'
      When call hooks:is_defined nonexistent_hook

      The status should be failure
    End

    It 'checks if hook has implementation - function'
      setup() {
        hooks:define impl_hook
        hook:impl_hook() { :; }
      }
      BeforeCall 'setup'

      When call hooks:has_implementation impl_hook

      The status should be success
      # Verify hook registration
      The result of function no_colors_stderr should include "Registered hook: impl_hook"
    End

    It 'checks if hook has implementation - script'
      setup() {
        mkdir -p /tmp/test_hooks2
        export HOOKS_DIR=/tmp/test_hooks2
        hooks:define impl_hook
        cat > /tmp/test_hooks2/impl_hook-test.sh <<'EOF'
#!/usr/bin/env bash
:
EOF
        chmod +x /tmp/test_hooks2/impl_hook-test.sh
      }
      cleanup() {
        rm -rf /tmp/test_hooks2
      }
      BeforeCall 'setup'
      AfterCall 'cleanup'

      When call hooks:has_implementation impl_hook

      The status should be success
      # Verify hook registration
      The result of function no_colors_stderr should include "Registered hook: impl_hook"
    End

    It 'returns false when hook has no implementation'
      setup() {
        hooks:define no_impl_hook
      }
      BeforeCall 'setup'

      When call hooks:has_implementation no_impl_hook

      The status should be failure
      # Verify hook was registered but has no implementation
      The result of function no_colors_stderr should include "Registered hook: no_impl_hook"
    End
  End

  Context 'Sourced execution mode /'
    setup_source_dir() {
      mkdir -p /tmp/test_source
      export HOOKS_DIR=/tmp/test_source
      export HOOKS_EXEC_MODE="source"
    }

    cleanup_source_dir() {
      rm -rf /tmp/test_source
      export HOOKS_EXEC_MODE="exec"
    }

    BeforeAll 'setup_source_dir'
    AfterAll 'cleanup_source_dir'

    It 'sources script and calls hook:run function'
      setup() {
        hooks:define test_source
        cat > /tmp/test_source/test_source-script.sh <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Sourced execution"
}
EOF
        chmod +x /tmp/test_source/test_source-script.sh
      }
      BeforeCall 'setup'

      When call on:hook test_source

      The status should be success
      The output should include "Sourced execution"
      # Verify source mode execution logged
      The result of function no_colors_stderr should include "sourced mode"
    End

    It 'passes parameters to hook:run function'
      setup() {
        hooks:define test_params
        cat > /tmp/test_source/test_params-script.sh <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Params: $*"
}
EOF
        chmod +x /tmp/test_source/test_params-script.sh
      }
      BeforeCall 'setup'

      When call on:hook test_params arg1 arg2

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
        hooks:define test_no_func
        cat > /tmp/test_source/test_no_func-script.sh <<'EOF'
#!/usr/bin/env bash
echo "Top-level code executes"
EOF
        chmod +x /tmp/test_source/test_no_func-script.sh
      }
      BeforeCall 'setup'
      AfterCall 'export DEBUG=""'

      When call on:hook test_no_func

      The status should be success
      # Top-level code runs when sourced (this is bash behavior)
      The output should include "Top-level code executes"
      # But we still warn about missing hook:run function
      The stderr should include "No hook:run function found"
    End

    It 'can access parent shell variables in sourced mode'
      setup() {
        hooks:define test_env
        export TEST_VAR="parent_value"
        cat > /tmp/test_source/test_env-script.sh <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "TEST_VAR=$TEST_VAR"
  TEST_VAR="modified"
}
EOF
        chmod +x /tmp/test_source/test_env-script.sh
      }
      BeforeCall 'setup'

      check_var() {
        on:hook test_env
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

  Context 'Real-world usage patterns /'
    It 'simulates begin/end hook pattern'
      setup() {
        hooks:define begin end
        hook:begin() {
          echo "Starting process"
        }
        hook:end() {
          echo "Ending process"
        }
      }
      BeforeCall 'setup'

      do_work() {
        on:hook begin
        echo "Doing work"
        on:hook end
      }

      When call do_work

      The status should be success
      The line 1 should eq "Starting process"
      The line 2 should eq "Doing work"
      The line 3 should eq "Ending process"
      # Verify hooks were registered and executed
      The result of function no_colors_stderr should include "Registered hook: begin"
      The result of function no_colors_stderr should include "Registered hook: end"
    End

    It 'simulates decision hook with conditional'
      setup() {
        hooks:define decide
        hook:decide() {
          echo "yes"
        }
      }
      BeforeCall 'setup'

      do_conditional() {
        local result=$(on:hook decide)
        if [[ "$result" == "yes" ]]; then
          echo "Decision was yes"
        else
          echo "Decision was no"
        fi
      }

      When call do_conditional

      The status should be success
      The output should eq "Decision was yes"
      # Verify hook was registered
      The result of function no_colors_stderr should include "Registered hook: decide"
    End

    It 'simulates error hook with parameters'
      setup() {
        hooks:define error
        hook:error() {
          local error_msg="$1"
          local error_code="$2"
          echo "Error: $error_msg (code: $error_code)"
        }
      }
      BeforeCall 'setup'

      handle_error() {
        on:hook error "Something went wrong" 404
      }

      When call handle_error

      The status should be success
      The output should eq "Error: Something went wrong (code: 404)"
      # Verify hook execution
      The result of function no_colors_stderr should include "Executing hook: error"
    End

    It 'simulates rollback hook'
      setup() {
        hooks:define rollback
        hook:rollback() {
          echo "Rolling back changes"
          return 0
        }
      }
      BeforeCall 'setup'

      do_rollback() {
        on:hook rollback
        echo "Rollback complete"
      }

      When call do_rollback

      The status should be success
      The line 1 should eq "Rolling back changes"
      The line 2 should eq "Rollback complete"
      # Verify successful rollback logged
      The result of function no_colors_stderr should include "Completed hook 'rollback'"
    End
  End

  Context 'Nested hooks support /'
    setup_nested_test() {
      mkdir -p /tmp/test_nested
      export HOOKS_DIR=/tmp/test_nested
    }

    cleanup_nested_test() {
      rm -rf /tmp/test_nested
      hooks:cleanup
    }

    BeforeEach 'setup_nested_test'
    AfterEach 'cleanup_nested_test'

    It 'detects when same hook is defined from multiple contexts'
      # Create a helper script that defines a hook
      cat > /tmp/test_nested/helper.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:define deploy
EOF

      # Source the helper script (defines deploy from helper context)
      # Redirect stderr to avoid polluting test output
      source /tmp/test_nested/helper.sh 2>/dev/null || true

      # Define the same hook from current context (should warn)
      When call hooks:define deploy

      The status should be success
      # Verify warning about multiple contexts
      The result of function no_colors_stderr should include "Warning: Hook 'deploy' is being defined from multiple contexts"
    End

    It 'skips redefinition from same context silently'
      # Note: ShellSpec runs the setup and When call from different internal contexts,
      # so we test this behavior using a wrapper function that defines twice.
      test_redefine() {
        export DEBUG="hooks"
        hooks:define deploy 2>&1
        hooks:define deploy 2>&1
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
      cat > /tmp/test_nested/helper1.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:define build
EOF

      cat > /tmp/test_nested/helper2.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:define build
EOF

      # Source both helpers
      source /tmp/test_nested/helper1.sh 2>/dev/null || true
      source /tmp/test_nested/helper2.sh 2>/dev/null || true

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
        local count=$(echo "$contexts" | tr '|' '\n' | wc -l)
        echo "Context count: $count"
      }

      When call test_contexts

      The status should be success
      The line 1 should eq "Hook defined: yes"
      The line 2 should eq "Context count: 2"
    End

    It 'shows context count in hooks:list for multiple contexts'
      # Create helper script
      cat > /tmp/test_nested/helper.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:define test_hook
EOF

      # Source helper and define from current context
      source /tmp/test_nested/helper.sh 2>/dev/null || true
      hooks:define test_hook 2>/dev/null || true

      When call hooks:list

      The status should be success
      The output should include "test_hook"
      The output should include "defined in 2 contexts"
    End

    It 'executes hooks defined from multiple contexts'
      # Create a script implementation
      cat > /tmp/test_nested/multi_ctx_hook-test.sh <<'EOF'
#!/usr/bin/env bash
echo "Hook executed"
exit 0
EOF
      chmod +x /tmp/test_nested/multi_ctx_hook-test.sh

      # Create helper that defines the hook
      cat > /tmp/test_nested/helper.sh <<'EOF'
#!/usr/bin/env bash
set +e  # Prevent logger conditionals from causing exit
source "$E_BASH/_hooks.sh"
set -e
hooks:define multi_ctx_hook
EOF

      # Source helper and define from current context
      source /tmp/test_nested/helper.sh 2>/dev/null || true
      hooks:define multi_ctx_hook 2>/dev/null || true

      # Execute the hook - should work even with multiple contexts
      When call on:hook multi_ctx_hook

      The status should be success
      The output should include "Hook executed"
      # Verify hook execution via logger
      The result of function no_colors_stderr should include "Executing hook: multi_ctx_hook"
    End
  End

  Context 'Function registration /'
    setup_registration_test() {
      hooks:cleanup
    }

    AfterEach 'setup_registration_test'

    It 'registers a function for a hook'
      test_func() {
        echo "Test function executed"
      }

      # Silence setup output
      hooks:define build 2>/dev/null
      hook:register build "10-test" test_func 2>/dev/null

      When call on:hook build

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
      hooks:define deploy 2>/dev/null
      hook:register deploy "30-third" func_c 2>/dev/null
      hook:register deploy "10-first" func_a 2>/dev/null
      hook:register deploy "20-second" func_b 2>/dev/null

      When call on:hook deploy

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
      hooks:define clean 2>/dev/null
      hook:register clean "test" test_func 2>/dev/null
      hook:unregister clean "test" 2>/dev/null

      When call on:hook clean

      The status should be success
      The output should not include "Test function"
      # Verify no implementations found after unregister
      The result of function no_colors_stderr should include "No implementations found"
    End

    It 'fails to register if function does not exist'
      # Silence setup output
      hooks:define test_hook 2>/dev/null

      When call hook:register test_hook "friendly" non_existent_func

      The status should be failure
      The stderr should include "Function 'non_existent_func' does not exist"
    End

    It 'fails to register duplicate friendly name'
      test_func1() { echo "Func 1"; }
      test_func2() { echo "Func 2"; }

      # Silence setup output
      hooks:define test_hook 2>/dev/null
      hook:register test_hook "same-name" test_func1 2>/dev/null

      When call hook:register test_hook "same-name" test_func2

      The status should be failure
      The stderr should include "Friendly name 'same-name' already registered"
    End

    It 'executes hook:prefix function before registered functions'
      hook:build() { echo "Hook function"; }
      registered_func() { echo "Registered function"; }

      # Silence setup output
      hooks:define build 2>/dev/null
      hook:register build "50-registered" registered_func 2>/dev/null

      When call on:hook build

      The status should be success
      The line 1 should eq "Hook function"
      The line 2 should eq "Registered function"
      # Verify both function and registered function were executed
      The result of function no_colors_stderr should include "[function] hook:build"
      The result of function no_colors_stderr should include "[registered 1/1]"
    End

    It 'shows registered functions in hooks:list'
      func1() { echo "F1"; }
      func2() { echo "F2"; }

      # Silence setup output
      hooks:define deploy 2>/dev/null
      hook:register deploy "10-first" func1 2>/dev/null
      hook:register deploy "20-second" func2 2>/dev/null

      When call hooks:list

      The status should be success
      The output should include "deploy: implemented (2 registered)"
    End

    It 'handles unregistering from non-existent hook'
      When call hook:unregister non_existent_hook "friendly"

      The status should be failure
      The stderr should include "No registrations found for hook 'non_existent_hook'"
    End

    It 'handles unregistering non-existent friendly name'
      test_func() { echo "Test"; }

      # Silence setup output
      hooks:define test_hook 2>/dev/null
      hook:register test_hook "exists" test_func 2>/dev/null

      When call hook:unregister test_hook "does_not_exist"

      The status should be failure
      The stderr should include "Registration 'does_not_exist' not found"
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
      hooks:define process 2>/dev/null
      hook:register process "external" forward_to_external 2>/dev/null

      When call on:hook process

      The status should be success
      The output should include "External script via function"
      # Verify execution via logger
      The result of function no_colors_stderr should include "[registered 1/1] external"

      rm -f "$external_script"
    End
  End

  Context 'Pattern registration /'
    setup_pattern_test() {
      hooks:cleanup
      source ".scripts/_hooks.sh"
    }

    AfterEach 'setup_pattern_test'

    It 'registers source patterns with hook:as:source'
      When call hook:as:source "config-*.sh" "env-*.sh"

      The status should be success
      # Verify patterns were added to the array
      The result of function no_colors_stderr should include "Registered pattern for sourced execution: config-*.sh"
      The result of function no_colors_stderr should include "Registered pattern for sourced execution: env-*.sh"
    End

    It 'registers script patterns with hook:as:script'
      When call hook:as:script "notify-*.sh" "cleanup-*.sh"

      The status should be success
      # Verify patterns were added to the array
      The result of function no_colors_stderr should include "Registered pattern for script execution: notify-*.sh"
      The result of function no_colors_stderr should include "Registered pattern for script execution: cleanup-*.sh"
    End

    It 'accumulates multiple pattern registrations'
      setup() {
        hook:as:source "first-*.sh" 2>/dev/null
        hook:as:source "second-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hook:as:source "third-*.sh"

      The status should be success
      # Verify all patterns are registered
      The result of function no_colors_stderr should include "Registered pattern for sourced execution: third-*.sh"
    End

    It 'determines execution mode with hooks:get_exec_mode for source patterns'
      setup() {
        hook:as:source "config-*.sh" 2>/dev/null
        hook:as:script "notify-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:get_exec_mode "config-init.sh"

      The status should be success
      The output should eq "source"
    End

    It 'determines execution mode with hooks:get_exec_mode for script patterns'
      setup() {
        hook:as:source "config-*.sh" 2>/dev/null
        hook:as:script "notify-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:get_exec_mode "notify-slack.sh"

      The status should be success
      The output should eq "exec"
    End

    It 'falls back to global HOOKS_EXEC_MODE for unmatched patterns'
      setup() {
        export HOOKS_EXEC_MODE="source"
        hook:as:source "config-*.sh" 2>/dev/null
        hook:as:script "notify-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:get_exec_mode "random-script.sh"

      The status should be success
      The output should eq "source"
    End

    It 'prioritizes source patterns over script patterns'
      setup() {
        hook:as:script "test-*.sh" 2>/dev/null
        hook:as:source "test-*.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      When call hooks:get_exec_mode "test-example.sh"

      The status should be success
      The output should eq "source"
    End

    It 'handles wildcard patterns correctly'
      setup() {
        hook:as:source "*-init.sh" 2>/dev/null
        hook:as:script "*-cleanup.sh" 2>/dev/null
      }
      BeforeCall 'setup'

      test_patterns() {
        local mode1 mode2 mode3
        mode1=$(hooks:get_exec_mode "begin-init.sh")
        mode2=$(hooks:get_exec_mode "end-cleanup.sh")
        mode3=$(hooks:get_exec_mode "middle-process.sh")
        echo "init:$mode1 cleanup:$mode2 process:$mode3"
      }

      When call test_patterns

      The status should be success
      The output should eq "init:source cleanup:exec process:exec"
    End
  End

  Context 'Pattern-based execution mode integration /'
    setup_pattern_integration() {
      mkdir -p /tmp/test_patterns
      export HOOKS_DIR=/tmp/test_patterns
      export HOOKS_EXEC_MODE="exec"  # Default to exec mode
      hooks:cleanup
      source ".scripts/_hooks.sh"
    }

    cleanup_pattern_integration() {
      rm -rf /tmp/test_patterns
      export HOOKS_EXEC_MODE="exec"
    }



    It 'executes scripts in source mode when pattern matches'
      test_pattern_source() {
        # Use the existing HOOKS_DIR (ci-cd)
        echo "Using HOOKS_DIR: $HOOKS_DIR"
        echo "Current working directory: $(pwd)"
        
        # Create HOOKS_DIR if it doesn't exist
        mkdir -p "$HOOKS_DIR"
        
        # Register pattern first
        hook:as:source "test_pattern-*.sh" 2>/dev/null
        
        # Define hook
        hooks:define test_pattern
        
        # Create script in the current HOOKS_DIR
        cat > "$HOOKS_DIR/test_pattern-config.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Sourced via pattern"
}
EOF
        chmod +x "$HOOKS_DIR/test_pattern-config.sh"
        
        # Execute hook
        on:hook test_pattern
        
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
        # Create HOOKS_DIR if it doesn't exist
        mkdir -p "$HOOKS_DIR"
        
        # Register pattern first
        hook:as:script "test_exec-*.sh" 2>/dev/null
        
        # Define hook
        hooks:define test_exec
        
        # Create script
        cat > "$HOOKS_DIR/test_exec-notify.sh" <<'EOF'
#!/usr/bin/env bash
echo "Executed as script"
EOF
        chmod +x "$HOOKS_DIR/test_exec-notify.sh"
        
        # Execute hook
        on:hook test_exec
        
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
        
        # Create HOOKS_DIR if it doesn't exist
        mkdir -p "$HOOKS_DIR"
        
        # Register pattern first
        hook:as:source "override_test-*.sh" 2>/dev/null
        
        # Define hook
        hooks:define override_test
        
        # Create script
        cat > "$HOOKS_DIR/override_test-config.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "Pattern overrode global mode"
}
EOF
        chmod +x "$HOOKS_DIR/override_test-config.sh"
        
        # Execute hook
        on:hook override_test
        
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
        
        # Create HOOKS_DIR if it doesn't exist
        mkdir -p "$HOOKS_DIR"
        
        # Register pattern first
        hook:as:script "script_override-*.sh" 2>/dev/null
        
        # Define hook
        hooks:define script_override
        
        # Create script
        cat > "$HOOKS_DIR/script_override-notify.sh" <<'EOF'
#!/usr/bin/env bash
echo "Script pattern overrode global source mode"
EOF
        chmod +x "$HOOKS_DIR/script_override-notify.sh"
        
        # Execute hook
        on:hook script_override
        
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
        # Create HOOKS_DIR if it doesn't exist
        mkdir -p "$HOOKS_DIR"
        
        # Register patterns first
        hook:as:source "mixed_patterns-config*.sh" 2>/dev/null
        hook:as:script "mixed_patterns-notify*.sh" 2>/dev/null
        
        # Define hook
        hooks:define mixed_patterns
        
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
        chmod +x "$HOOKS_DIR/mixed_patterns-"*.sh
        
        # Execute hook
        on:hook mixed_patterns
        
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
