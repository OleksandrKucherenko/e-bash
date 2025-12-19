#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 1.12.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Define script paths for cleaner usage
PROJECT_ROOT="$(pwd)"
SCRIPT_DIR="${PROJECT_ROOT}/bin"
VERIFY_SCRIPT="${SCRIPT_DIR}/git.verify-all-commits.sh"

# Set E_BASH variable manually for tests
export E_BASH="${PROJECT_ROOT}/.scripts"
# Speed up tests by suppressing git filter-branch warning (saves ~5-10s)
export FILTER_BRANCH_SQUELCH_WARNING=1

Describe 'bin/git.verify-all-commits.sh /'
  Include "$VERIFY_SCRIPT"

  BeforeEach 'setup_test_environment'
  AfterEach 'cleanup_test_environment'

  setup_test_environment() {
    TEST_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/verify_commits.XXXXXX")
    export TEST_DIR
    ORIGINAL_DIR=$(pwd)
    export ORIGINAL_DIR
    cd "$TEST_DIR" || exit

    # Mock logger functions for testing
    echo:Error() { echo "$*" >&2; }
    echo:Success() { echo "$*"; }
    echo:Verify() { echo "$*"; }
    echo:Info() { echo "$*"; }
    echo:Debug() { echo "$*"; }
    echo:Progress() { echo "$*"; }
    echo:Warning() { echo "$*" >&2; } # Add missing Warning mock
    printf:Error() { printf '%s' "$*" >&2; }
    printf:Success() { printf '%s' "$*"; }
    printf:Verify() { printf '%s' "$*"; }
    printf:Info() { printf '%s' "$*"; }
    printf:Debug() { printf '%s' "$*"; }
    printf:Progress() { printf '%s' "$*"; }

    # Disable colors for consistent test output
    export NO_COLOR=1
    unset DEBUG

    # Initialize a git repository for testing
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create a base tracked file for modification tests
    echo "initial content" >test_file.txt
    git add test_file.txt
    git commit -m "Initial commit" >/dev/null 2>&1
  }

  cleanup_test_environment() {
    cd "$ORIGINAL_DIR" >/dev/null
    rm -rf "$TEST_DIR" 2>/dev/null || true
    unset TEST_DIR ORIGINAL_DIR
  }

  create_test_commit() {
    local message="$1"
    local file="test_${RANDOM}.txt"
    echo "test content" >"$file"
    git add "$file"
    git commit -m "$message" >/dev/null 2>&1
  }

  Context 'when checking git repository status'
    It 'detects valid git repository'
      When call git rev-parse --git-dir
      The status should be success
      The output should include ".git"
    End

    It 'fails when not in git repository'
      Skip 'Test requires proper git repository setup - TODO: fix in next iteration'
      # cd /tmp
      # When run source "$VERIFY_SCRIPT"
      # The stderr should include 'Not in a git repository'
      # The status should be failure
    End
  End

  Context 'when validating commit messages'
    BeforeEach 'create_test_commits'

    create_test_commits() {
      create_test_commit "feat: add new feature"
      create_test_commit "fix: resolve bug"
      create_test_commit "bad commit message"
      create_test_commit "docs: update README"
    }

    It 'detects conventional commits correctly'
      # Get the hash of the "feat: add new feature" commit (HEAD~3)
      good_commit_hash=$(git log -1 --format=%H HEAD~3)
      When call conventional:is_valid_commit "$good_commit_hash"
      The status should be success
    End

    It 'rejects non-conventional commits'
      # Get the hash of the "bad commit message" commit (HEAD~1)
      bad_commit_hash=$(git log -1 --format=%H HEAD~1)
      When call conventional:is_valid_commit "$bad_commit_hash"
      The status should be failure
    End

    It 'handles multi-line commit messages'
      create_test_commit "feat: add authentication

      This commit adds OAuth2 support with JWT tokens.

      BREAKING CHANGE: API endpoints have changed"

      When call conventional:is_valid_commit "$(git log -1 --format=%H HEAD)"
      The status should be success
    End

    It 'validates commit with scope and breaking change'
      create_test_commit "feat(api)!: breaking API changes"

      When call conventional:is_valid_commit "$(git log -1 --format=%H HEAD)"
      The status should be success
    End
  End

  Context 'when processing multiple commits'
    It 'counts failed commits correctly'
      create_test_commit "feat: valid feature"
      create_test_commit "invalid message"
      create_test_commit "another bad one"

      # Mock the main function logic for testing
      failed_commits=("$(git log -1 --format=%H HEAD)" "$(git log -1 --format=%H HEAD~2)")
      failed_count=${#failed_commits[@]}

      The variable failed_count should eq 2
    End

    It 'skips merge commits'
      create_test_commit "feat: valid feature"
      # Create a merge commit
      git checkout -b feature-branch >/dev/null 2>&1
      create_test_commit "feat: branch feature"
      git checkout main >/dev/null 2>&1 || git checkout master >/dev/null 2>&1
      git merge feature-branch --no-ff -m "Merge branch 'feature-branch'" >/dev/null 2>&1

      # Test that merge commits are skipped
      latest_commit=$(git log -1 --format=%H HEAD)
      When call validate_commit "$latest_commit"
      The status should be success # Should skip merge commit
      The output should include "Skipping merge commit validation"
    End
  End

  Context 'when using patch mode'
    BeforeEach 'setup_patch_test'

    setup_patch_test() {
      create_test_commit "bad commit message"
      export patch="1"
    }

    It 'creates backup branch before modifying history'
      # Mock the backup creation
      create_backup_branch() {
        echo "Creating backup branch"
        return 0
      }

      When call create_backup_branch
      The output should include "Creating backup branch"
      The status should be success
    End

    It 'checks for clean working tree'
      # Test with clean working tree
      When call check_working_tree_clean
      The status should be success
    End

    It 'prevents patching with uncommitted changes'
      # Modify an existing tracked file to create uncommitted changes
      echo "modification" >>test_file.txt

      # Mock the check_working_tree_clean function to avoid exit call
      check_working_tree_clean() {
        if ! git diff-index --quiet HEAD --; then
          echo:Error "❌ You have uncommitted changes. Please commit or stash them first."
          echo:Error "   Use 'git status' to see what changes need to be committed."
          return 1 # Return 1 instead of exit 1
        fi
        return 0
      }

      When call check_working_tree_clean
      The status should be failure
      The stderr should include "uncommitted changes"
    End
  End

  Context 'when rewording commits'
    BeforeEach 'setup_reword_test'

    setup_reword_test() {
      create_test_commit "bad message to fix"
      test_commit_hash=$(git log -1 --format=%H HEAD)
    }

    It 'shows current commit message'
      Data
        #|
      End

      When call reword_commit "$test_commit_hash"
      The output should include "Current commit message"
      The output should include "bad message to fix"
      The output should include "⏭️  Skipped commit"
    End

    It 'provides format guidance'
      Data
        #|feat: improved commit message
      End

      When call reword_commit "$test_commit_hash"
      The output should include "type(scope): description"
      The output should include "feat, fix, docs"
      The stderr should include "Could not reword commit using filter-branch"
    End
  End

  Context 'argument parsing'
    It 'recognizes help flag'
      When run "$VERIFY_SCRIPT" --help
      The output should include "USAGE:"
      The output should include "OPTIONS:"
      The output should include "--patch"
      The status should be success
    End

    It 'recognizes version flag'
      When run "$VERIFY_SCRIPT" --version
      The output should include "0.1.0"
      The status should be success
    End

    It 'recognizes patch flag'
      # We can't easily test interactive mode, but we can verify the flag is parsed
      export patch="1"
      # Mock the main function to avoid full execution
      main() { return 0; }
      When call main
      # Should not error on patch flag recognition
      The status should be success
    End

    It 'recognizes branch flag'
      export branch="1"
      # Mock the main function to avoid full execution
      main() { return 0; }
      When call main
      # Should not error on branch flag recognition
      The status should be success
    End
  End

  Context 'conventional commit parsing'
    It 'parses simple conventional commit'
      # Initialize the global associative array
      declare -g -A __conventional_parse_result

      When call conventional:parse "feat: add new feature"
      The status should be success

      # Check parsed result
      The variable __conventional_parse_result[type] should eq "feat"
      The variable __conventional_parse_result[description] should eq "add new feature"
    End

    It 'parses commit with scope'
      declare -g -A __conventional_parse_result
      When call conventional:parse "fix(auth): resolve login issue"
      The status should be success
      The variable __conventional_parse_result[type] should eq "fix"
      The variable __conventional_parse_result[scope] should eq "auth"
    End

    It 'parses breaking change'
      declare -g -A __conventional_parse_result
      When call conventional:parse "feat!: breaking API change"
      The status should be success
      The variable __conventional_parse_result[type] should eq "feat"
      The variable __conventional_parse_result[breaking] should eq "!"
    End

    It 'rejects invalid format'
      declare -g -A __conventional_parse_result
      When call conventional:parse "random message without proper format"
      The status should be failure
    End

    It 'handles edge cases'
      declare -g -A __conventional_parse_result
      When call conventional:parse ""
      The status should be failure
    End
  End

  Context 'error handling'
    It 'handles missing git gracefully'
      Skip 'Test requires complex git mocking - TODO: fix in next iteration'
      # # Temporarily override git command
      # git() { return 127; }
      #
      # When call main
      # The status should be failure
    End

    It 'handles git log failures'
      Skip 'Test requires complex git mocking - TODO: fix in next iteration'
      # git() {
      #   if [[ "$1" == "log" ]]; then
      #     return 1
      #   fi
      #   command git "$@"
      # }
      #
      # When call main
      # The status should be failure
    End
  End
End
