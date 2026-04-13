#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-13
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# shellcheck disable=SC2288
% TEST_HOOKS_DIR: "$SHELLSPEC_TMPBASE/test_strict_hooks"

export SCRIPT_DIR=".scripts"
export E_BASH="$(pwd)/${SCRIPT_DIR}"

Describe 'strict mode compatibility (set -euo pipefail) /'

  Context 'Issue #85.3: echo:Tag returns 0 when tag is disabled /'
    Include ".scripts/_logger.sh"

    AfterAll 'logger:cleanup'

    It 'echo:Tag returns exit code 0 when tag is disabled'
      setup() {
        export DEBUG=""
        logger common
        TAGS[common]=0
      }
      BeforeCall 'setup'

      When call echo:Common "this should be silent"

      The status should be success
      The output should eq ''
    End

    It 'echo:Tag returns exit code 0 when tag is enabled'
      setup() {
        export DEBUG="*"
        logger common
        TAGS[common]=1
      }
      BeforeCall 'setup'

      When call echo:Common "visible message"

      The status should be success
      The output should include 'visible message'
    End

    It 'printf:Tag returns exit code 0 when tag is disabled'
      setup() {
        export DEBUG=""
        logger common
        TAGS[common]=0
      }
      BeforeCall 'setup'

      When call printf:Common "%s" "this should be silent"

      The status should be success
      The output should eq ''
    End

    It 'printf:Tag returns exit code 0 when tag is enabled'
      setup() {
        export DEBUG="*"
        logger common
        TAGS[common]=1
      }
      BeforeCall 'setup'

      When call printf:Common "%s" "visible message"

      The status should be success
      The output should include 'visible message'
    End

    It 'disabled echo:Tag does not abort script under set -e'
      test_set_e() {
        set -e
        export DEBUG=""
        logger test_sete
        TAGS[test_sete]=0
        echo:Test_sete "should not abort"
        echo "script continued"
      }

      When call test_set_e

      The status should be success
      The output should include 'script continued'
    End

    It 'disabled printf:Tag does not abort script under set -e'
      test_set_e() {
        set -e
        export DEBUG=""
        logger test_sete2
        TAGS[test_sete2]=0
        printf:Test_sete2 "%s" "should not abort"
        echo "script continued"
      }

      When call test_set_e

      The status should be success
      The output should include 'script continued'
    End

    It 'multiple disabled echo:Tag calls do not accumulate exit codes'
      test_multiple_calls() {
        set -e
        export DEBUG=""
        logger multi
        TAGS[multi]=0
        echo:Multi "first"
        echo:Multi "second"
        echo:Multi "third"
        echo "all passed"
      }

      When call test_multiple_calls

      The status should be success
      The output should include 'all passed'
    End
  End

  Context 'Issue #85.3: config:logger:Tag returns 0 under set -e /'
    Include ".scripts/_logger.sh"

    AfterAll 'logger:cleanup'

    It 'logger initialization succeeds under set -e with tag not in DEBUG'
      test_config_set_e() {
        set -e
        export DEBUG="other"
        logger myapp
        echo "init succeeded"
      }

      When call test_config_set_e

      The status should be success
      The output should include 'init succeeded'
    End

    It 'logger initialization succeeds under set -e with DEBUG=*'
      test_config_set_e() {
        set -e
        export DEBUG="*"
        logger myapp2
        echo "init succeeded"
      }

      When call test_config_set_e

      The status should be success
      The output should include 'init succeeded'
    End
  End

  Context 'Issue #85.3: read -d heredoc returns 0 under set -e /'
    Include ".scripts/_logger.sh"

    AfterAll 'logger:cleanup'

    It 'logger:compose:eval does not fail under set -e'
      test_compose_eval() {
        set -e
        export DEBUG="*"
        TAGS[ctest]=1
        TAGS_PREFIX[ctest]=""
        TAGS_REDIRECT[ctest]=""
        logger:compose:eval "ctest" "Ctest"
        echo:Ctest "compose works"
      }

      When call test_compose_eval

      The status should be success
      The output should include 'compose works'
    End

    It 'logger:compose:helpers:eval does not fail under set -e'
      test_helpers_eval() {
        set -e
        export DEBUG="*"
        TAGS[htest]=1
        logger:compose:eval "htest" "Htest"
        logger:compose:helpers:eval "htest" "Htest"
        echo "helpers ok"
      }

      When call test_helpers_eval

      The status should be success
      The output should include 'helpers ok'
    End
  End

  Context 'Issue #85.1: EXIT trap preserves exit code under set -e /'

    It 'script exits with 0 when logic succeeds and hooks are loaded'
      test_exit_code() {
        bash -c '
          export E_BASH="'"$E_BASH"'"
          export DEBUG="hooks"
          export HOOKS_AUTO_TRAP=false
          set +eu
          source "$E_BASH/_logger.sh"
          source "$E_BASH/_hooks.sh"
          set -eu
          echo "done"
        ' 2>/dev/null
      }

      When call test_exit_code

      The status should be success
      The output should include 'done'
    End

    It 'script exits with 0 when only logger is loaded under set -e'
      test_exit_code() {
        bash -c '
          export E_BASH="'"$E_BASH"'"
          export DEBUG="myapp"
          set +eu
          source "$E_BASH/_logger.sh"
          set -eu
          logger myapp
          echo:Myapp "hello" 2>/dev/null
          echo "done"
        ' 2>/dev/null
      }

      When call test_exit_code

      The status should be success
      The output should include 'done'
    End
  End

  Context 'Issue #85.2: hooks:do handles unbound variables under set -u /'
    Include ".scripts/_hooks.sh"

    # Mock logger functions that hooks module needs
    Mock echo:Hooks
      echo "$@" >&2
    End

    Mock echo:Error
      echo "$@" >&2
    End

    Mock echo:Modes
      echo "$@" >&2
    End

    Mock echo:Loader
      echo "$@" >&2
    End

    Mock printf:Hooks
      printf "$@" >&2
    End

    # Test isolation helper functions
    setup_test_hooks_dir() {
      mkdir -p "$TEST_HOOKS_DIR"
      export HOOKS_DIR="$TEST_HOOKS_DIR"
    }

    cleanup_test_hooks_dir() {
      rm -rf "$TEST_HOOKS_DIR"
    }

    AfterEach 'cleanup_test_hooks_dir'

    It 'hooks:do does not fail on unregistered hook under set -u'
      test_hooks_do_set_u() {
        set -u
        hooks:declare test_unbound_hook
        hooks:do test_unbound_hook
        echo "survived"
      }

      When call test_hooks_do_set_u

      The status should be success
      The output should include 'survived'
      The error should include 'Registered hook: test_unbound_hook'
    End

    It 'hooks:register does not fail on first registration under set -u'
      test_hooks_register_set_u() {
        set -u
        hooks:declare test_reg_hook
        my_handler() { echo "handled"; }
        hooks:register test_reg_hook "handler1" my_handler
        echo "registered ok"
      }

      When call test_hooks_register_set_u

      The status should be success
      The output should include 'registered ok'
      The error should include 'Registered hook: test_reg_hook'
    End
  End

  Context 'Issue #85.4: _hooks.sh respects explicit empty DEBUG /'
    It 'does not override DEBUG="" when explicitly set'
      test_debug_empty() {
        bash -c '
          export E_BASH="'"$E_BASH"'"
          export HOOKS_AUTO_TRAP=false
          export DEBUG=""
          source "$E_BASH/_hooks.sh"
          echo "DEBUG=$DEBUG"
        ' 2>/dev/null
      }

      When call test_debug_empty

      The status should be success
      The output should eq 'DEBUG='
    End

    It 'sets DEBUG=error when DEBUG is truly unset'
      test_debug_unset() {
        bash -c '
          export E_BASH="'"$E_BASH"'"
          export HOOKS_AUTO_TRAP=false
          unset DEBUG
          source "$E_BASH/_hooks.sh"
          echo "DEBUG=$DEBUG"
        ' 2>/dev/null
      }

      When call test_debug_unset

      The status should be success
      The output should eq 'DEBUG=error'
    End

    It 'appends error to non-empty DEBUG that lacks error tag'
      test_debug_append() {
        bash -c '
          export E_BASH="'"$E_BASH"'"
          export HOOKS_AUTO_TRAP=false
          export DEBUG="hooks"
          source "$E_BASH/_hooks.sh"
          echo "DEBUG=$DEBUG"
        ' 2>/dev/null
      }

      When call test_debug_append

      The status should be success
      The output should eq 'DEBUG=hooks,error'
    End

    It 'does not duplicate error in DEBUG that already has it'
      test_debug_existing() {
        bash -c '
          export E_BASH="'"$E_BASH"'"
          export HOOKS_AUTO_TRAP=false
          export DEBUG="error,hooks"
          source "$E_BASH/_hooks.sh"
          echo "DEBUG=$DEBUG"
        ' 2>/dev/null
      }

      When call test_debug_existing

      The status should be success
      The output should eq 'DEBUG=error,hooks'
    End

    It 'does not modify DEBUG=* (wildcard already includes error)'
      test_debug_wildcard() {
        bash -c '
          export E_BASH="'"$E_BASH"'"
          export HOOKS_AUTO_TRAP=false
          export DEBUG="*"
          source "$E_BASH/_hooks.sh"
          echo "DEBUG=$DEBUG"
        ' 2>/dev/null
      }

      When call test_debug_wildcard

      The status should be success
      The output should eq 'DEBUG=*'
    End
  End

  Context 'Combined strict mode: set -euo pipefail /'

    It 'full strict mode script with logger succeeds'
      test_full_strict() {
        bash -c '
          set -euo pipefail
          export E_BASH="'"$E_BASH"'"
          export DEBUG="myapp"
          set +eu
          source "$E_BASH/_logger.sh"
          set -eu
          logger myapp
          echo:Myapp "logging under strict mode" 2>/dev/null
          echo "strict mode ok"
        ' 2>/dev/null
      }

      When call test_full_strict

      The status should be success
      The output should include 'strict mode ok'
    End

    It 'full strict mode script with hooks bootstrap succeeds'
      test_full_strict_hooks() {
        bash -c '
          set -euo pipefail
          export E_BASH="'"$E_BASH"'"
          export DEBUG="hooks"
          export HOOKS_AUTO_TRAP=false
          set +eu
          source "$E_BASH/_logger.sh"
          source "$E_BASH/_hooks.sh"
          set -eu
          hooks:declare my_strict_hook
          hooks:do my_strict_hook
          echo "strict hooks ok"
        ' 2>/dev/null
      }

      When call test_full_strict_hooks

      The status should be success
      The output should include 'strict hooks ok'
    End
  End
End
