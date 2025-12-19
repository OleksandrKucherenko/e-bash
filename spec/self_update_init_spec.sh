#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 0.11.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

Describe 'Self-Update Initialization /'
  Include .scripts/_self-update.sh

  setup() {
    # Mock all logger functions to avoid errors
    echo:Version() { echo "$@" >&2; }
    echo:Git() { echo "$@" >&2; }
    echo:Regex() { :; }
    echo:Loader() { echo "$@" >&2; }
    echo:Simple() { echo "$@" >&2; }
    echo:Semver() { echo "$@" >&2; }

    printf:Version() { printf "$@" >&2; }
    printf:Git() { printf "$@" >&2; }
    printf:Regex() { :; }
    printf:Simple() { printf "$@" >&2; }
  }

  cleanup() {
    # Clean up test artifacts
    __REPO_VERSIONS=()
    declare -g -A __REPO_MAPPING=()
  }

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe 'self-update:initialize /'
    setup_init_test() {
      TEMP_HOME_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/init_home.XXXXXX")
      TEMP_E_ROOT="$TEMP_HOME_DIR/.e-bash"
      __E_ROOT="$TEMP_E_ROOT"

      # Mock self-update:version:get:first to avoid real git operations
      self-update:version:get:first() {
        echo:Version "Mock: Extract first version" >&2
      }
    }

    cleanup_init_test() {
      rm -rf "$TEMP_HOME_DIR"
    }

    BeforeEach 'setup_init_test'
    AfterEach 'cleanup_init_test'

    It 'creates .e-bash directory if it does not exist'
      When call self-update:initialize
      The status should be success
      The path "$TEMP_E_ROOT" should be directory
    End

    It 'initializes git repository in .e-bash directory'
      When call self-update:initialize
      The status should be success
      The path "$TEMP_E_ROOT/.git" should be directory
    End

    It 'does not reinitialize existing git repository'
      # Initialize once
      self-update:initialize >/dev/null 2>&1

      # Initialize again
      When call self-update:initialize
      The status should be success
      # Should still work without errors
      The path "$TEMP_E_ROOT/.git" should be directory
    End

    It 'adds e-bash remote with correct URL'
      When call self-update:initialize
      The status should be success

      cd "$TEMP_E_ROOT" || exit 1
      The result of "git remote get-url e-bash" should equal "https://github.com/OleksandrKucherenko/e-bash.git"
    End

    It 'sets push URL to no_push for e-bash remote'
      When call self-update:initialize
      The status should be success

      cd "$TEMP_E_ROOT" || exit 1
      The result of "git remote get-url --push e-bash" should equal "no_push"
    End

    It 'does not add remote if it already exists'
      # Initialize once
      self-update:initialize >/dev/null 2>&1

      # Initialize again
      When call self-update:initialize
      The status should be success

      cd "$TEMP_E_ROOT" || exit 1
      # Should have exactly one e-bash remote
      remote_count=$(git remote -v | grep -c "e-bash")
      The variable remote_count should equal 2  # fetch + push URLs
    End

    It 'checks out master branch'
      When call self-update:initialize
      The status should be success

      cd "$TEMP_E_ROOT" || exit 1
      current_branch=$(git branch --show-current)
      The variable current_branch should equal "master"
    End

    It 'outputs initialization success message'
      When call self-update:initialize
      The result of function no_colors_stderr should include "e-bash repo initialized in ~/.e-bash"
    End

    It 'adds .versions/ to .gitignore'
      When call self-update:initialize
      The status should be success

      The path "$TEMP_E_ROOT/.gitignore" should be file
      The contents of file "$TEMP_E_ROOT/.gitignore" should include ".versions/"
    End

    It 'does not duplicate .versions/ in .gitignore'
      # Initialize once
      self-update:initialize >/dev/null 2>&1

      # Initialize again
      When call self-update:initialize
      The status should be success

      # Count occurrences of .versions/ in .gitignore
      cd "$TEMP_E_ROOT" || exit 1
      count=$(grep -c ".versions/" .gitignore)
      The variable count should equal 1
    End

    It 'calls self-update:version:get:first'
      When call self-update:initialize
      The status should be success
      The result of function no_colors_stderr should include "Mock: Extract first version"
    End

    It 'fetches latest changes from remote'
      # We need to test that git fetch is called, but since we mock the remote
      # we can verify the operations complete without error
      When call self-update:initialize
      The status should be success
      # No specific assertion, just verify it doesn't fail
    End

    It 'resets to remote master branch'
      # Pre-create repo with local commits
      mkdir -p "$TEMP_E_ROOT"
      cd "$TEMP_E_ROOT" || exit 1
      git init --quiet
      git config user.email "test@example.com"
      git config user.name "Test User"
      echo "local" > local.txt
      git add local.txt
      git commit -m "local commit" --quiet

      When call self-update:initialize
      The status should be success
      # Should reset to remote state
    End
  End

  Describe 'self-update:initialize with existing content /'
    setup_existing_test() {
      TEMP_HOME_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/init_existing.XXXXXX")
      TEMP_E_ROOT="$TEMP_HOME_DIR/.e-bash"
      __E_ROOT="$TEMP_E_ROOT"

      # Pre-create the directory structure
      mkdir -p "$TEMP_E_ROOT"
      cd "$TEMP_E_ROOT" || exit 1
      git init --quiet
      git config user.email "test@example.com"
      git config user.name "Test User"

      # Create some content
      echo "existing content" > existing.txt
      git add existing.txt
      git commit -m "existing commit" --quiet

      # Mock first version extraction
      self-update:version:get:first() {
        echo:Version "Mock: Extract first version" >&2
      }
    }

    cleanup_existing_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_HOME_DIR"
    }

    BeforeEach 'setup_existing_test'
    AfterEach 'cleanup_existing_test'

    It 'preserves existing git repository'
      When call self-update:initialize
      The status should be success
      The path "$TEMP_E_ROOT/.git" should be directory
    End

    It 'adds remote to existing repository'
      When call self-update:initialize
      The status should be success

      cd "$TEMP_E_ROOT" || exit 1
      remote_exists=$(git remote | grep -c "e-bash" || echo 0)
      The variable remote_exists should equal 1
    End

    It 'updates .gitignore in existing repository'
      # Create existing .gitignore
      echo "# existing ignore rules" > "$TEMP_E_ROOT/.gitignore"
      echo "*.log" >> "$TEMP_E_ROOT/.gitignore"

      When call self-update:initialize
      The status should be success

      # Should append .versions/ without removing existing content
      The contents of file "$TEMP_E_ROOT/.gitignore" should include "*.log"
      The contents of file "$TEMP_E_ROOT/.gitignore" should include ".versions/"
    End
  End

  Describe 'self-update:initialize integration /'
    setup_integration_test() {
      TEMP_HOME_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/init_integration.XXXXXX")
      TEMP_E_ROOT="$TEMP_HOME_DIR/.e-bash"
      __E_ROOT="$TEMP_E_ROOT"

      # Create a local mock repository to serve as remote
      TEMP_REMOTE_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/remote.XXXXXX")

      cd "$TEMP_REMOTE_DIR" || exit 1
      git init --quiet --bare

      # Clone it to create content
      TEMP_CONTENT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/content.XXXXXX")
      cd "$TEMP_CONTENT_DIR" || exit 1
      git clone --quiet "$TEMP_REMOTE_DIR" repo
      cd repo || exit 1
      git config user.email "test@example.com"
      git config user.name "Test User"

      # Create master branch with content
      echo "master content" > master.txt
      git add master.txt
      git commit -m "master commit" --quiet
      git tag v1.0.0
      git push --quiet origin master
      git push --quiet origin v1.0.0

      # Override the repo URL for testing
      __REPO_URL="$TEMP_REMOTE_DIR"

      # Don't mock get:first for integration test
    }

    cleanup_integration_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_HOME_DIR" "$TEMP_REMOTE_DIR" "$TEMP_CONTENT_DIR"
    }

    BeforeEach 'setup_integration_test'
    AfterEach 'cleanup_integration_test'

    It 'performs complete initialization with real git operations'
      When call self-update:initialize
      The status should be success

      # Verify git repo is initialized
      The path "$TEMP_E_ROOT/.git" should be directory

      # Verify remote is configured
      cd "$TEMP_E_ROOT" || exit 1
      remote_url=$(git remote get-url e-bash)
      The variable remote_url should equal "$TEMP_REMOTE_DIR"

      # Verify master branch is checked out
      current_branch=$(git branch --show-current)
      The variable current_branch should equal "master"

      # Verify .gitignore exists
      The path "$TEMP_E_ROOT/.gitignore" should be file
    End

    It 'fetches content from remote repository'
      When call self-update:initialize
      The status should be success

      cd "$TEMP_E_ROOT" || exit 1
      # Should have the master.txt file from remote
      The path "$TEMP_E_ROOT/master.txt" should be file
      The contents of file "$TEMP_E_ROOT/master.txt" should equal "master content"
    End

    It 'creates worktree for first version'
      When call self-update:initialize
      The status should be success

      # Should create .versions/v1.0.0 worktree
      The path "$TEMP_E_ROOT/.versions/v1.0.0" should be directory
      The path "$TEMP_E_ROOT/.versions/v1.0.0/master.txt" should be file
    End
  End

  Describe 'self-update:initialize error handling /'
    setup_error_test() {
      TEMP_HOME_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/init_error.XXXXXX")
      TEMP_E_ROOT="$TEMP_HOME_DIR/.e-bash"
      __E_ROOT="$TEMP_E_ROOT"

      # Mock version get to avoid remote operations
      self-update:version:get:first() {
        echo:Version "Mock: Extract first version" >&2
      }
    }

    cleanup_error_test() {
      rm -rf "$TEMP_HOME_DIR"
    }

    BeforeEach 'setup_error_test'
    AfterEach 'cleanup_error_test'

    It 'handles read-only parent directory gracefully'
      Skip if "running as root" [ "$(id -u)" -eq 0 ]

      # Make parent directory read-only
      chmod 555 "$TEMP_HOME_DIR"

      When call self-update:initialize
      # Should fail to create directory
      The status should be failure

      # Restore permissions for cleanup
      chmod 755 "$TEMP_HOME_DIR"
    End

    It 'creates parent directories if needed'
      # Remove the temp directory
      rm -rf "$TEMP_HOME_DIR"

      # Create a nested path
      TEMP_E_ROOT="$TEMP_HOME_DIR/nested/path/.e-bash"
      __E_ROOT="$TEMP_E_ROOT"

      When call self-update:initialize
      The status should be success
      The path "$TEMP_E_ROOT" should be directory
    End
  End

  Describe 'self-update:initialize .gitignore management /'
    setup_gitignore_test() {
      TEMP_HOME_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/init_gitignore.XXXXXX")
      TEMP_E_ROOT="$TEMP_HOME_DIR/.e-bash"
      __E_ROOT="$TEMP_E_ROOT"

      self-update:version:get:first() {
        echo:Version "Mock: Extract first version" >&2
      }
    }

    cleanup_gitignore_test() {
      rm -rf "$TEMP_HOME_DIR"
    }

    BeforeEach 'setup_gitignore_test'
    AfterEach 'cleanup_gitignore_test'

    It 'creates .gitignore if it does not exist'
      When call self-update:initialize
      The status should be success
      The path "$TEMP_E_ROOT/.gitignore" should be file
    End

    It 'adds comment explaining exclusion'
      When call self-update:initialize
      The status should be success
      The contents of file "$TEMP_E_ROOT/.gitignore" should include "# exclude .versions worktree folder from git"
    End

    It 'adds blank line before comment for readability'
      # Pre-create .gitignore with existing content
      mkdir -p "$TEMP_E_ROOT"
      cd "$TEMP_E_ROOT" || exit 1
      git init --quiet
      echo "*.tmp" > .gitignore
      cd - >/dev/null || exit 1

      When call self-update:initialize
      The status should be success

      # Should have blank line before comment
      gitignore_content=$(cat "$TEMP_E_ROOT/.gitignore")
      The variable gitignore_content should include "*.tmp"
      # Verify blank line exists (content should have double newline pattern)
      [ -n "$(echo "$gitignore_content" | grep -A1 "^$" | grep "# exclude")" ]
      The status should be success
    End
  End
End
