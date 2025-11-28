#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2329,SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


eval "$(shellspec - -c) exit 1"

Describe 'bin/git.conventional-commits.sh /'
  # Include the script using relative path from project root
  Include bin/git.conventional-commits.sh

  BeforeEach 'setup_test_environment'
  AfterEach 'cleanup_test_environment'

  setup_test_environment() {
    export TEST_DIR=$(mktemp -d)
    export ORIGINAL_DIR=$(pwd)
    export CONVENTIONAL_SCRIPT="${ORIGINAL_DIR}/bin/git.conventional-commits.sh"
    cd "$TEST_DIR"

    # Mock logger functions for testing
    echo:Error() { echo "$*" >&2; }
    echo:Success() { echo "$*"; }
    echo:Verify() { echo "$*"; }
    echo:Info() { echo "$*"; }
    echo:Debug() { echo "$*"; }
    echo:Progress() { echo "$*"; }
    printf:Error() { printf "%s" "$*" >&2; }
    printf:Success() { printf "%s" "$*"; }
    printf:Verify() { printf "%s" "$*"; }
    printf:Info() { printf "%s" "$*"; }
    printf:Debug() { printf "%s" "$*"; }
    printf:Progress() { printf "%s" "$*"; }

    # Disable colors for consistent test output
    export NO_COLOR=1
    unset DEBUG

    # Initialize a git repository for testing
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Initialize associative array for conventional commit parsing results
    declare -g -A __conventional_parse_result
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

  Context 'conventional commit type validation /'
    Parameters
      "feat"
      "fix"
      "docs"
      "style"
      "refactor"
      "perf"
      "test"
      "build"
      "ci"
      "chore"
      "revert"
      "wip"
    End

    It "recognizes $1 as valid commit type"
      When call conventional:parse "$1: test message"
      The status should be success
    End
  End

  Context 'invalid commit type validation /'
    Parameters
      "bad"
      "invalid"
      "random"
      "custom"
      "update"
    End

    It "rejects $1 as invalid commit type"
      When call conventional:parse "$1: test message"
      The status should be failure
    End
  End

  Context 'conventional commit format parsing /'
    It 'parses simple format: type: description'
      When call conventional:parse "feat: add new feature"
      The status should be success

      # The result should be stored in __conventional_parse_result
      The variable __conventional_parse_result[type] should eq "feat"
      The variable __conventional_parse_result[scope] should eq ""
      The variable __conventional_parse_result[breaking] should eq ""
      The variable __conventional_parse_result[description] should eq "add new feature"
    End

    It 'parses format with scope: type(scope): description'
      When call conventional:parse "fix(auth): resolve login issue"
      The status should be success

      The variable __conventional_parse_result[type] should eq "fix"
      The variable __conventional_parse_result[scope] should eq "auth"
      The variable __conventional_parse_result[description] should eq "resolve login issue"
    End

    It 'parses breaking change indicator'
      When call conventional:parse "feat!: breaking API changes"
      The status should be success

      The variable __conventional_parse_result[type] should eq "feat"
      The variable __conventional_parse_result[breaking] should eq "!"
      The variable __conventional_parse_result[description] should eq "breaking API changes"
    End

    It 'parses scope with breaking change'
      When call conventional:parse "feat(api)!: breaking API changes"
      The status should be success

      The variable __conventional_parse_result[type] should eq "feat"
      The variable __conventional_parse_result[scope] should eq "api"
      The variable __conventional_parse_result[breaking] should eq "!"
      The variable __conventional_parse_result[description] should eq "breaking API changes"
    End

    It 'handles multi-line commit messages'
      # Read multi-line data and parse it
      multi_line="feat: add authentication

Implement OAuth 2.0 authentication flow with support for:
- Google OAuth
- GitHub OAuth
- Email/password fallback

BREAKING CHANGE: Old authentication method is no longer supported"

      When call conventional:parse "$multi_line"
      The status should be success

      The variable __conventional_parse_result[type] should eq "feat"
      The variable __conventional_parse_result[description] should eq "add authentication"
      The variable __conventional_parse_result[footer] should include "BREAKING CHANGE"
    End

    It 'detects breaking change in footer'
      # Read multi-line data and parse it
      oauth_content="feat!: implement OAuth authentication

Complete rewrite of authentication system using OAuth 2.0.

BREAKING CHANGE: Sessions from v1 are incompatible with v2"

      When call conventional:parse "$oauth_content"
      The status should be success

      The variable __conventional_parse_result[breaking] should eq "!"
      The variable __conventional_parse_result[footer] should include "BREAKING CHANGE"
    End
  End

  Context 'edge cases and malformed input /'
    It 'rejects empty message'
      When call conventional:parse ""
      The status should be failure
    End

    It 'rejects message without type'
      When call conventional:parse "random message without proper format"
      The status should be failure
    End

    It 'rejects message without description'
      When call conventional:parse "feat:"
      The status should be failure
    End

    It 'rejects message with invalid scope format'
      When call conventional:parse "featinvalid): bad scope"
      The status should be failure
    End

    It 'handles messages with special characters'
      When call conventional:parse "fix: resolve issue with #123 and @mentions"
      The status should be success
    End

    It 'handles very long descriptions'
      local long_description="feat: $(printf 'a %.0s' {1..200})"
      When call conventional:parse "$long_description"
      The status should be success
    End
  End

  Context 'conventional:grep function /'
    It 'generates valid regex pattern'
      When call conventional:grep
      The output should include "feat"
      The output should include "fix"
      The output should include "docs"
      The output should include "(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|wip)"
    End

    Context 'pattern validation /'
      Parameters
        "feat"
        "fix"
        "docs"
        "style"
        "refactor"
        "perf"
        "test"
        "build"
        "ci"
        "chore"
        "revert"
        "wip"
      End

      It "pattern includes $1 type"
        When call conventional:grep
        The output should include "$1"
      End
    End

    Context 'conventional:recompose function /'
      It 'recomposes simple commit correctly'
        # Set up a parsed result
        __conventional_parse_result[message]="feat: add feature"
        __conventional_parse_result[type]="feat"
        __conventional_parse_result[scope]=""
        __conventional_parse_result[breaking]=""
        __conventional_parse_result[description]="add feature"
        __conventional_parse_result[body]=""
        __conventional_parse_result[footer]=""

        When call conventional:recompose
        The output should eq "feat: add feature"
      End

      It 'recomposes commit with scope'
        __conventional_parse_result[type]="fix"
        __conventional_parse_result[scope]="api"
        __conventional_parse_result[breaking]=""
        __conventional_parse_result[description]="fix endpoint"
        __conventional_parse_result[body]=""
        __conventional_parse_result[footer]=""

        When call conventional:recompose
        The output should eq "fix(api): fix endpoint"
      End

      It 'recomposes breaking change'
        __conventional_parse_result[type]="feat"
        __conventional_parse_result[scope]=""
        __conventional_parse_result[breaking]="!"
        __conventional_parse_result[description]="breaking change"
        __conventional_parse_result[body]=""
        __conventional_parse_result[footer]=""

        When call conventional:recompose
        The output should eq "feat!: breaking change"
      End

      It 'recomposes multi-line commit'
        __conventional_parse_result[type]="feat"
        __conventional_parse_result[scope]=""
        __conventional_parse_result[breaking]="!"
        __conventional_parse_result[description]="add auth"
        __conventional_parse_result[body]="This adds OAuth2 support."
        __conventional_parse_result[footer]="BREAKING CHANGE: API endpoints changed."

        When call conventional:recompose
        The output should include "feat!: add auth"
        The output should include "This adds OAuth2 support."
        The output should include "BREAKING CHANGE: API endpoints changed."
      End
    End

    Context 'version commit detection /'
      It 'identifies version commits correctly'
        create_test_commit "feat: add new feature"
        local commit_hash
        commit_hash=$(git log -1 --format=%H HEAD)

        When call conventional:is_version_commit "$commit_hash"
        The status should be success
      End

      It 'handles change commits'
        create_test_commit "chore: update dependencies"
        local commit_hash
        commit_hash=$(git log -1 --format=%H HEAD)

        When call conventional:is_change_commit "$commit_hash"
        The status should be success
      End
    End

    Context 'script execution modes /'
      It 'works when sourced'
        When run source "$CONVENTIONAL_SCRIPT"
        The status should be success
      End
    End

    Context 'error handling /'
      It 'handles git log failures gracefully'
        # Mock git to fail
        git() {
          if [[ "$1" == "log" ]]; then
            return 1
          fi
          command git "$@"
        }

        When call conventional:is_valid_commit "fakehash"
        The status should be failure
      End

      It 'handles invalid commit hashes'
        When call conventional:is_valid_commit "invalid_hash"
        The status should be failure
      End
    End
  End

End
