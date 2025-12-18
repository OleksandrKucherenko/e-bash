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

Describe '_hooks.sh /'
  Include ".scripts/_hooks.sh"

  # Cleanup mechanism
  AfterAll 'hooks:cleanup'

  Context 'Hook definition /'
    It 'defines single hook successfully'
      When call hooks:define begin

      The status should be success
      The output should eq ''
    End

    It 'defines multiple hooks successfully'
      When call hooks:define begin end decide error rollback

      The status should be success
      The output should eq ''
    End

    It 'rejects invalid hook names with special characters'
      When call hooks:define "invalid@hook"

      The status should be failure
      The error should include "Invalid hook name"
    End

    It 'accepts hook names with underscores and dashes'
      When call hooks:define my_hook my-hook

      The status should be success
    End

    It 'can define custom hook names'
      When call hooks:define custom_pre_process after_validate

      The status should be success
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
    End

    It 'silently skips undefined hooks'
      When call on:hook undefined_hook

      The status should be success
      The output should eq ''
    End

    It 'silently skips defined but not implemented hooks'
      BeforeCall 'hooks:define not_implemented'

      When call on:hook not_implemented

      The status should be success
      The output should eq ''
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
      setup() {
        hooks:define script_hook
        cat > /tmp/test_hooks/script_hook.sh <<'EOF'
#!/usr/bin/env bash
echo "Script hook executed"
EOF
        chmod +x /tmp/test_hooks/script_hook.sh
      }
      BeforeCall 'setup'

      When call on:hook script_hook

      The status should be success
      The output should eq "Script hook executed"
    End

    It 'passes parameters to hook script'
      setup() {
        hooks:define script_hook
        cat > /tmp/test_hooks/script_hook.sh <<'EOF'
#!/usr/bin/env bash
echo "Script params: $*"
EOF
        chmod +x /tmp/test_hooks/script_hook.sh
      }
      BeforeCall 'setup'

      When call on:hook script_hook arg1 arg2

      The status should be success
      The output should eq "Script params: arg1 arg2"
    End

    It 'propagates script exit code'
      setup() {
        hooks:define fail_hook
        cat > /tmp/test_hooks/fail_hook.sh <<'EOF'
#!/usr/bin/env bash
exit 13
EOF
        chmod +x /tmp/test_hooks/fail_hook.sh
      }
      BeforeCall 'setup'

      When call on:hook fail_hook

      The status should eq 13
    End

    It 'prefers function over script when both exist'
      setup() {
        hooks:define priority_hook
        hook:priority_hook() {
          echo "Function implementation"
        }
        cat > /tmp/test_hooks/priority_hook.sh <<'EOF'
#!/usr/bin/env bash
echo "Script implementation"
EOF
        chmod +x /tmp/test_hooks/priority_hook.sh
      }
      BeforeCall 'setup'

      When call on:hook priority_hook

      The status should be success
      The output should eq "Function implementation"
    End

    It 'skips non-executable script files'
      setup() {
        hooks:define no_exec_hook
        cat > /tmp/test_hooks/no_exec_hook.sh <<'EOF'
#!/usr/bin/env bash
echo "This should not execute"
EOF
        # Intentionally not making it executable
      }
      BeforeCall 'setup'

      When call on:hook no_exec_hook

      The status should be success
      The output should eq ''
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
      The line 1 should eq "1: Backup"
      The line 2 should eq "2: Update"
      The line 3 should eq "3: Restart"
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
      The line 1 should eq "Step 1: Init"
      The line 2 should eq "Step 10: Finalize"
      The line 3 should eq "Step 2: Validate"
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
    End

    It 'checks if hook is defined'
      setup() {
        hooks:define existing_hook
      }
      BeforeCall 'setup'

      When call hooks:is_defined existing_hook

      The status should be success
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
    End

    It 'checks if hook has implementation - script'
      setup() {
        mkdir -p /tmp/test_hooks2
        export HOOKS_DIR=/tmp/test_hooks2
        hooks:define impl_hook
        cat > /tmp/test_hooks2/impl_hook.sh <<'EOF'
#!/usr/bin/env bash
:
EOF
        chmod +x /tmp/test_hooks2/impl_hook.sh
      }
      cleanup() {
        rm -rf /tmp/test_hooks2
      }
      BeforeCall 'setup'
      AfterCall 'cleanup'

      When call hooks:has_implementation impl_hook

      The status should be success
    End

    It 'returns false when hook has no implementation'
      setup() {
        hooks:define no_impl_hook
      }
      BeforeCall 'setup'

      When call hooks:has_implementation no_impl_hook

      The status should be failure
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
    End
  End
End
