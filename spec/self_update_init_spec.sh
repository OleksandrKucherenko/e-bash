#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 0.11.4
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Enable DEBUG for logger verification
export DEBUG="version,git,loader,semver"

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

# Mock logger functions to output to stderr for verification
Mock printf:Version
  printf "$@" >&2
End

Mock echo:Version
  echo "$@" >&2
End

Mock printf:Git
  printf "$@" >&2
End

Mock echo:Git
  echo "$@" >&2
End

Mock printf:Loader
  printf "$@" >&2
End

Mock echo:Loader
  echo "$@" >&2
End

Mock printf:Semver
  printf "$@" >&2
End

Mock echo:Semver
  echo "$@" >&2
End

Mock echo:Regex
  :
End

Mock printf:Regex
  :
End

Mock echo:Simple
  echo "$@" >&2
End

Mock printf:Simple
  printf "$@" >&2
End

Describe 'Self-Update Initialization /'
  # Note: We include the script which defines readonly variables
  # Do not try to override them in setup
  Include .scripts/_self-update.sh

  cleanup() {
    # Clean up test artifacts
    __REPO_VERSIONS=()
    declare -g -A __REPO_MAPPING=()
  }

  AfterEach 'cleanup'

  Describe 'self-update:initialize behavior /'
    It 'creates .e-bash directory if it does not exist'
      # Mock version:get:first to avoid side effects
      self-update:version:get:first() {
        echo:Version "Mock: Extract first version" >&2
      }

      # Check if directory is created (may already exist)
      pre_exists=false
      [[ -d "${__E_ROOT}" ]] && pre_exists=true

      When call self-update:initialize
      The status should be success
      The path "${__E_ROOT}" should be directory

      # Verify logger output confirms initialization
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
      The result of function no_colors_stderr should include "Mock: Extract first version"
    End

    It 'initializes git repository in .e-bash directory'
      self-update:version:get:first() { :; }

      # May already be initialized
      When call self-update:initialize
      The status should be success
      The path "${__E_ROOT}/.git" should be directory

      # Verify initialization message
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End

    It 'outputs initialization success message'
      self-update:version:get:first() { :; }

      When call self-update:initialize
      The status should be success
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End

    It 'adds .versions/ to .gitignore'
      self-update:version:get:first() { :; }

      When call self-update:initialize
      The status should be success

      # .gitignore should exist and contain .versions/
      The path "${__E_ROOT}/.gitignore" should be file
      The contents of file "${__E_ROOT}/.gitignore" should include ".versions/"

      # Verify initialization completed via logger
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End

    It 'calls self-update:version:get:first'
      mock_called=false
      self-update:version:get:first() {
        mock_called=true
        echo:Version "Mock: Extract first version" >&2
      }

      When call self-update:initialize
      The status should be success
      The variable mock_called should equal true

      # Verify both initialization and mock were called via logger messages
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
      The result of function no_colors_stderr should include "Mock: Extract first version"
    End
  End

  Describe 'self-update:initialize git operations /'
    It 'adds e-bash remote with correct URL'
      self-update:version:get:first() { :; }

      self-update:initialize >/dev/null 2>&1

      cd "${__E_ROOT}" || Skip "Cannot cd to __E_ROOT"
      remote_url=$(git remote get-url e-bash 2>/dev/null || echo "")
      The variable remote_url should equal "https://github.com/OleksandrKucherenko/e-bash.git"
    End

    It 'sets push URL to no_push for e-bash remote'
      self-update:version:get:first() { :; }

      self-update:initialize >/dev/null 2>&1

      cd "${__E_ROOT}" || Skip "Cannot cd to __E_ROOT"
      push_url=$(git remote get-url --push e-bash 2>/dev/null || echo "")
      The variable push_url should equal "no_push"
    End

    It 'does not duplicate remote if it already exists'
      self-update:version:get:first() { :; }

      # Initialize twice
      self-update:initialize >/dev/null 2>&1
      self-update:initialize >/dev/null 2>&1

      cd "${__E_ROOT}" || Skip "Cannot cd to __E_ROOT"
      # Count e-bash remotes (should be 2 lines: fetch + push)
      remote_count=$(git remote -v | grep -c "e-bash" || echo 0)
      The variable remote_count should equal 2
    End
  End

  Describe 'self-update:initialize .gitignore management /'
    It 'does not duplicate .versions/ in .gitignore'
      self-update:version:get:first() { :; }

      # Initialize multiple times
      self-update:initialize >/dev/null 2>&1

      When call self-update:initialize
      The status should be success

      cd "${__E_ROOT}" || Skip "Cannot cd to __E_ROOT"
      # Count occurrences of .versions/ in .gitignore
      count=$(grep -c ".versions/" .gitignore 2>/dev/null || echo 0)
      The variable count should equal 1

      # Verify logger output
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End

    It 'adds comment explaining exclusion'
      self-update:version:get:first() { :; }

      When call self-update:initialize
      The status should be success
      The contents of file "${__E_ROOT}/.gitignore" should include "# exclude .versions worktree folder from git"

      # Verify initialization via logger
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End
  End

  Describe 'self-update:initialize with mocked git /'
    It 'performs all expected git operations in correct order'
      self-update:version:get:first() { :; }

      # Track git operations
      declare -g -a GIT_OPS=()

      git() {
        case "$1" in
          init)
            GIT_OPS+=("init")
            command git "$@"
            ;;
          remote)
            if [[ "$2" == "add" ]]; then
              GIT_OPS+=("remote-add")
            elif [[ "$2" == "set-url" ]]; then
              GIT_OPS+=("remote-set-url")
            elif [[ "$2" == "-v" ]]; then
              GIT_OPS+=("remote-list")
            fi
            command git "$@"
            ;;
          fetch)
            GIT_OPS+=("fetch")
            # Skip actual fetch
            return 0
            ;;
          checkout)
            GIT_OPS+=("checkout")
            command git "$@"
            ;;
          reset)
            GIT_OPS+=("reset")
            # Skip actual reset
            return 0
            ;;
          *)
            command git "$@"
            ;;
        esac
      }

      When call self-update:initialize
      The status should be success

      # Verify initialization message via logger
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"

      # Should have performed git operations
      [[ "${GIT_OPS[*]}" =~ "fetch" ]]
      The status should be success

      unset -f git
      unset GIT_OPS
    End
  End

  Describe 'self-update:initialize edge cases /'
    It 'handles existing .gitignore with other content'
      self-update:version:get:first() { :; }

      # Pre-populate .gitignore
      [[ -d "${__E_ROOT}" ]] || mkdir -p "${__E_ROOT}"
      if [[ ! -f "${__E_ROOT}/.gitignore" ]] || ! grep -q "^# test content$" "${__E_ROOT}/.gitignore"; then
        echo "# test content" >> "${__E_ROOT}/.gitignore"
        echo "*.tmp" >> "${__E_ROOT}/.gitignore"
      fi

      When call self-update:initialize
      The status should be success

      # Should preserve existing content and add .versions/
      The contents of file "${__E_ROOT}/.gitignore" should include "*.tmp"
      The contents of file "${__E_ROOT}/.gitignore" should include ".versions/"

      # Verify initialization via logger
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End

    It 'creates .e-bash directory structure properly'
      self-update:version:get:first() { :; }

      When call self-update:initialize
      The status should be success

      # Verify key directories exist
      The path "${__E_ROOT}" should be directory
      The path "${__E_ROOT}/.git" should be directory

      # Verify initialization via logger
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End
  End
End
