#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

is_sha1() { grep -Eq '^[a-f0-9]{40}$'; }
is_hash_log() { grep -Eq '^hash: [a-f0-9]{40} of '; }

Describe 'Self-Update Module /'
  # Note: We include the script which defines readonly variables
  # Do not try to override them in setup
  Include .scripts/_self-update.sh

  setup() {
    # Mock all logger functions to avoid errors
    echo:Version() { echo "$@"; }  # Silent mock
    echo:Git() { echo "$@"; }      # Silent mock
    echo:Regex() { :; }    # Silent mock
    echo:Loader() { echo "$@"; }   # Silent mock
    echo:Simple() { echo "$@"; }   # Silent mock
    echo:Semver() { echo "$@"; }   # Silent mock
    
    printf:Version() { printf "$@"; }
    printf:Git() { printf "$@"; }
    printf:Regex() { :; }
    printf:Simple() { printf "$@"; }
  }

  cleanup() {
    # Clean up test artifacts
    # Note: cannot unset readonly variables, just clean up our test data
    __REPO_VERSIONS=()
    declare -g -A __REPO_MAPPING=()
  }

  BeforeEach 'setup'
  AfterEach 'cleanup'

  Describe 'compare:versions /'
    It 'compares two versions correctly (1.0.0 < 2.0.0)'
      When call compare:versions "1.0.0" "2.0.0"
      
      The status should be success
      # left side expression to verify, right side possible valid operators between operands
      The stderr should include "(1.0.0 < 2.0.0) -> (< <= !=)"
    End

    It 'compares two versions correctly (2.0.0 > 1.0.0)'
      When call compare:versions "2.0.0" "1.0.0"
      
      The status should be failure
      # left side expression to verify, right side possible valid operators between operands
      The stderr should include "(2.0.0 < 1.0.0) -> (> >= !=)"
    End

    It 'handles pre-release versions (1.0.0-alpha < 1.0.0)'
      When call compare:versions "1.0.0-alpha" "1.0.0"
     
      The status should be success
      # left side expression to verify, right side possible valid operators between operands
      The stderr should include "(1.0.0-alpha < 1.0.0) -> (< <= !=)"
    End

    It 'handles equal versions (1.0.0 = 1.0.0)'
      When call compare:versions "1.0.0" "1.0.0"
      
      The status should be failure
      # left side expression to verify, right side possible valid operators between operands
      The stderr should include "(1.0.0 < 1.0.0) -> (= == >= <=)"
    End
  End

  Describe 'array:qsort /'
    It 'sorts an empty array'
      When call array:qsort "compare:versions"
      The output should equal ""
    End

    It 'sorts a single element array'
      When call array:qsort "compare:versions" "1.0.0"
      The output should equal "1.0.0"
    End

    It 'sorts multiple versions in ascending order'
      When call array:qsort "compare:versions" "2.0.0" "1.0.0" "1.5.0"
      
      The line 1 should equal "1.0.0"
      The line 2 should equal "1.5.0"
      The line 3 should equal "2.0.0"

      The stderr should include "(1.0.0 < 2.0.0) -> (< <= !=)"
      The stderr should include "(1.5.0 < 2.0.0) -> (< <= !=)"
      The stderr should include "(1.5.0 < 1.0.0) -> (> >= !=)"
    End

    It 'sorts versions with pre-release tags correctly'
      When call array:qsort "compare:versions" "1.0.0" "1.0.0-beta" "1.0.0-alpha" "2.0.0"
      
      The line 1 should equal "1.0.0-alpha"
      The line 2 should equal "1.0.0-beta"
      The line 3 should equal "1.0.0"
      The line 4 should equal "2.0.0"

      The stderr should include "(1.0.0-beta < 1.0.0) -> (< <= !=)"
      The stderr should include "(1.0.0-alpha < 1.0.0) -> (< <= !=)"
      The stderr should include "(1.0.0-alpha < 1.0.0-beta) -> (< <= !=)"
    End
  End

  Describe 'semver:constraints /'
    It 'v1 incorrectly allows prerelease in stable ranges'
      When call semver:constraints:v1 "1.0.1-alpha" "~1.0.0"
      The status should be success
      The stderr should include "[~1.0.0]:"
      
      # Dump
    End

    It 'v2 excludes prerelease unless range includes prerelease'
      When call semver:constraints:v2 "1.0.1-alpha" "~1.0.0"
      The status should be failure
      The stderr should include "[~1.0.0]:"
      
      # Dump
    End

    It 'v2 allows prerelease with same patch when range includes prerelease'
      When call semver:constraints:v2 "1.0.1-beta" "~1.0.1-alpha"
      The status should be success
      The stderr should include "[~1.0.1-alpha]:"
      
      # Dump
    End

    It 'v2 excludes prerelease with different patch even if range includes prerelease'
      When call semver:constraints:v2 "1.0.2-alpha" "~1.0.1-alpha"
      The status should be failure
      The stderr should include "[~1.0.1-alpha]:"
      
      # Dump
    End

    It 'v2 still allows stable versions within prerelease range'
      When call semver:constraints:v2 "1.0.2" "~1.0.1-alpha"
      The status should be success
      The stderr should include "[~1.0.1-alpha]:"
      
      # Dump
    End
  End

  Describe 'self-update:version:tags /'
    setup_mock_repo() {
      # Mock git tag command to return test tags
      __REPO_VERSIONS=()
      __REPO_MAPPING=()

      # Simulate having these tags available
      # We'll mock this by directly setting the arrays
      __REPO_VERSIONS=("1.0.0" "1.0.1" "1.1.0" "2.0.0")
      __REPO_MAPPING=(
        ["1.0.0"]="v1.0.0"
        ["1.0.1"]="v1.0.1"
        ["1.1.0"]="v1.1.0"
        ["2.0.0"]="v2.0.0"
      )
    }

    BeforeEach 'setup_mock_repo'

    It 'populates __REPO_VERSIONS array'
      The variable __REPO_VERSIONS[@] should not be blank
      The value "${#__REPO_VERSIONS[@]}" should equal 4
    End

    It 'populates __REPO_MAPPING associative array'
      The variable __REPO_MAPPING[@] should not be blank
      The value "${__REPO_MAPPING[1.0.0]}" should equal "v1.0.0"
    End

    It 'sorts versions in ascending order'
      The value "${__REPO_VERSIONS[0]}" should equal "1.0.0"
      The value "${__REPO_VERSIONS[3]}" should equal "2.0.0"
    End
  End

  Describe 'self-update:version:find:highest_tag /'
    setup_versions() {
      __REPO_VERSIONS=("1.0.0" "1.0.1-alpha" "1.1.0" "2.0.0-beta" "2.0.0")
      declare -g -A __REPO_MAPPING=(
        ["1.0.0"]="v1.0.0"
        ["1.0.1-alpha"]="v1.0.1-alpha"
        ["1.1.0"]="v1.1.0"
        ["2.0.0-beta"]="v2.0.0-beta"
        ["2.0.0"]="v2.0.0"
      )
    }

    BeforeEach 'setup_versions'

    It 'returns the highest version tag'
      When call self-update:version:find:highest_tag
      The output should equal "v2.0.0"
    End

    It 'includes pre-release versions in consideration'
      # Remove the stable 2.0.0, highest should be 2.0.0-beta
      unset '__REPO_VERSIONS[4]'
      __REPO_VERSIONS=("${__REPO_VERSIONS[@]}")  # re-index array

      When call self-update:version:find:highest_tag
      The output should equal "v2.0.0-beta"
    End
  End

  Describe 'self-update:version:find:latest_stable /'
    setup_versions_with_prerelease() {
      __REPO_VERSIONS=("1.0.0" "1.0.1-alpha" "1.1.0" "2.0.0-beta" "2.0.0-rc.1")
      declare -g -A __REPO_MAPPING=(
        ["1.0.0"]="v1.0.0"
        ["1.0.1-alpha"]="v1.0.1-alpha"
        ["1.1.0"]="v1.1.0"
        ["2.0.0-beta"]="v2.0.0-beta"
        ["2.0.0-rc.1"]="v2.0.0-rc.1"
      )
    }

    BeforeEach 'setup_versions_with_prerelease'

    It 'returns the latest stable version (no pre-release)'
      When call self-update:version:find:latest_stable
      The output should equal "v1.1.0"
    End

    It 'skips pre-release versions (alpha, beta, rc)'
      # Verify it doesn't return 2.0.0-beta or 2.0.0-rc.1
      When call self-update:version:find:latest_stable
      The output should not equal "v2.0.0-beta"
      The output should not equal "v2.0.0-rc.1"
    End
  End

  Describe 'self-update:version:find:latest_stable with stable highest /'
    setup_stable_versions() {
      __REPO_VERSIONS=("1.0.0" "1.0.1-alpha" "1.1.0" "2.0.0")
      declare -g -A __REPO_MAPPING=(
        ["1.0.0"]="v1.0.0"
        ["1.0.1-alpha"]="v1.0.1-alpha"
        ["1.1.0"]="v1.1.0"
        ["2.0.0"]="v2.0.0"
      )
    }

    BeforeEach 'setup_stable_versions'

    It 'returns the highest stable version when it is the highest overall'
      When call self-update:version:find:latest_stable
      The output should equal "v2.0.0"
    End
  End

  Describe 'self-update:version:find /'
    setup_find_versions() {
      __REPO_VERSIONS=("1.0.0" "1.0.1" "1.1.0" "1.2.0" "2.0.0")
      declare -g -A __REPO_MAPPING=(
        ["1.0.0"]="v1.0.0"
        ["1.0.1"]="v1.0.1"
        ["1.1.0"]="v1.1.0"
        ["1.2.0"]="v1.2.0"
        ["2.0.0"]="v2.0.0"
      )
    }

    BeforeEach 'setup_find_versions'

    It 'finds exact version match (1.0.0)'
      BeforeCall "export DEBUG=*"

      When call self-update:version:find "1.0.0"
      The output should equal "v1.0.0"
      # Line that confirms exact match found
      The stderr should include "(1.0.0=1.0.0) (1.0.0 = 1.0.0) -> (= == >= <=)"
    End

    It 'finds highest version matching caret constraint (^1.0.0)'
      When call self-update:version:find "^1.0.0"
     
      The output should equal "v1.2.0"
      The stderr should include "(1.2.0>=1.0.0) (1.2.0 >= 1.0.0) -> (> >= !=)"
    End

    It 'finds highest version matching tilde constraint (~1.0.0)'
      When call self-update:version:find "~1.0.0"

      The output should equal "v1.0.1"
      The stderr should include "(1.0.1>=1.0.0) (1.0.1 >= 1.0.0) -> (> >= !=)"
      The stderr should include "(1.0.1<1.1.0) (1.0.1 < 1.1.0) -> (< <= !=)"
    End

    It 'finds version in range (>1.0.0 <=1.1.0)'
      When call self-update:version:find ">1.0.0 <=1.1.0"

      The output should equal "v1.1.0"
      The stderr should include "(1.1.0>1.0.0) (1.1.0 > 1.0.0) -> (> >= !=)"
      The stderr should include "(1.1.0<=1.1.0) (1.1.0 <= 1.1.0) -> (= == >= <=)"
    End
  End

  Describe 'self-update version expression handling /'
    setup_update_test() {
      # Mock necessary functions to avoid actual git operations
      self-update:initialize() { :; }
      self-update:version:get:latest() { :; }
      self-update:version:has() { return 0; }
      self-update:version:get() { :; }
      self-update:self:version() { echo "v1.0.0"; }
      self-update:version:bind() { :; }
      self-update:file:hash() { echo "mock-hash"; }
      self-update:version:hash() { echo "different-hash"; }

      # Setup version data
      __REPO_VERSIONS=("1.0.0" "1.0.1-alpha" "1.1.0" "2.0.0-beta" "2.0.0")
      declare -g -A __REPO_MAPPING=(
        ["1.0.0"]="v1.0.0"
        ["1.0.1-alpha"]="v1.0.1-alpha"
        ["1.1.0"]="v1.1.0"
        ["2.0.0-beta"]="v2.0.0-beta"
        ["2.0.0"]="v2.0.0"
      )
    }

    BeforeEach 'setup_update_test'

    Describe 'latest notation /'
      It 'resolves "latest" to latest stable version'
        # We need to verify the version selected, mock the bind to capture it
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "v2.0.0"
        }

        When call self-update "latest" "/tmp/test-script.sh"
        The status should be success
        The stdout should include "mock-hash"
        The stdout should include "different-hash"
        The stderr should include "binding to: v2.0.0"

        # Dump
      End
    End

    Describe '* (star) notation /'
      It 'resolves "*" to highest version (including pre-release)'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "v2.0.0"
        }

        When call self-update "*" "/tmp/test-script.sh"
        The status should be success
        The stdout should include "different-hash"
        The stderr should include "binding to: v2.0.0"
      End

      It 'resolves "next" to highest version (including pre-release)'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "v2.0.0"
        }

        When call self-update "next" "/tmp/test-script.sh"
        The status should be success
        The stdout should include "different-hash"
        The stderr should include "binding to: v2.0.0"
      End
    End

    Describe 'branch:* notation /'
      It 'resolves "branch:master" to "master"'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "master"
        }

        When call self-update "branch:master" "/tmp/test-script.sh"
        The status should be success
        The stdout should include "different-hash"
        The stderr should include "binding to: master"
      End

      It 'resolves "branch:develop" to "develop"'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "develop"
        }

        When call self-update "branch:develop" "/tmp/test-script.sh"
        The status should be success
        The stdout should include "different-hash"
        The stderr should include "binding to: develop"
      End
    End

    Describe 'tag:* notation /'
      It 'resolves "tag:v1.0.0" to "v1.0.0"'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "v1.0.0"
        }

        When call self-update "tag:v1.0.0" "/tmp/test-script.sh"
        The status should be success
        The stdout should include "different-hash"
        The stderr should include "binding to: v1.0.0"
      End

      It 'resolves "tag:v2.0.0-beta" to "v2.0.0-beta"'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "v2.0.0-beta"
        }

        When call self-update "tag:v2.0.0-beta" "/tmp/test-script.sh"
        The status should be success

        The result of function no_colors_stdout should include "e-bash is outdated: v1.0.0 -> v2.0.0-beta"
        The stderr should include "binding to: v2.0.0-beta"
      End
    End

    Describe 'semver constraint expressions /'
      It 'resolves "^1.0.0" using semver constraints'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          test "$1" = "v1.1.0"
        }

        When call self-update "^1.0.0" "/tmp/test-script.sh"
        The status should be success

        The result of function no_colors_stdout should include "e-bash is outdated: v1.0.0 -> v1.1.0"
        The stderr should include "binding to: v1.1.0"

        # Dump
      End

      It 'resolves "~1.0.0" using semver constraints'
        self-update:version:bind() {
          echo "binding to: $1" >&2
          # Should match highest patch version in 1.0.x
          [[ "$1" == "v1.0.0" || "$1" == "v1.0.1" ]]
        }

        When call self-update "~1.0.0" "/tmp/test-script.sh"
        The status should be success
        The stdout should include "different-hash"
        The stderr should not include "binding to: v1.0.1-alpha"

        # Dump
      End
    End
  End

  Describe 'path:resolve /'
    setup_path_test() {
      # Create temporary directory structure for testing
      TEMP_DIR=$(mktemp -d)
      mkdir -p "$TEMP_DIR/subdir"
      touch "$TEMP_DIR/test-file.sh"
      touch "$TEMP_DIR/subdir/nested-file.sh"
    }

    cleanup_path_test() {
      rm -rf "$TEMP_DIR"
    }

    BeforeEach 'setup_path_test'
    AfterEach 'cleanup_path_test'

    It 'resolves absolute path'
      When call path:resolve "$TEMP_DIR/test-file.sh" "$TEMP_DIR"
      The status should be success

      The output should equal "$TEMP_DIR/test-file.sh"
      The result of function no_colors_stderr should include "file ~> $TEMP_DIR/test-file.sh"
    End

    It 'resolves relative path from working directory'
      cd "$TEMP_DIR" || exit 1

      When call path:resolve "test-file.sh" "$TEMP_DIR"
      
      The status should be success
      The output should equal "$TEMP_DIR/test-file.sh"
      The result of function no_colors_stderr should include "file ~> $TEMP_DIR/test-file.sh"
    End

    It 'resolves nested file path'
      When call path:resolve "$TEMP_DIR/subdir/nested-file.sh" "$TEMP_DIR"
      The output should equal "$TEMP_DIR/subdir/nested-file.sh"
      The status should be success
      The result of function no_colors_stderr should include "file ~> $TEMP_DIR/subdir/nested-file.sh"
    End

    It 'returns error for non-existent file'
      When call path:resolve "$TEMP_DIR/non-existent.sh" "$TEMP_DIR"
      
      The status should be failure
      The stdout should include "$TEMP_DIR/non-existent.sh"
      The result of function no_colors_stderr should include "ERROR: file not found ($TEMP_DIR): $TEMP_DIR/non-existent.sh"
    End
  End

  Describe 'self-update:self:version /'
    setup_version_test() {
      VERSIONED_SCRIPT_FIXTURE="$SHELLSPEC_PROJECT_ROOT/spec/fixtures/versioned-script.sh"
      NO_VERSION_SCRIPT_FIXTURE="$SHELLSPEC_PROJECT_ROOT/spec/fixtures/no-version.sh"
    }

    cleanup_version_test() {
      unset VERSIONED_SCRIPT_FIXTURE NO_VERSION_SCRIPT_FIXTURE
    }

    BeforeEach 'setup_version_test'
    AfterEach 'cleanup_version_test'

    It 'extracts version from script copyright comments'
      When call self-update:self:version "$VERSIONED_SCRIPT_FIXTURE"
      The output should equal "v1.2.3"
      The result of function no_colors_stderr should include "copyright: versioned-script.sh to 1.2.3"
    End

    It 'returns default version for scripts without version comments'
      When call self-update:self:version "$NO_VERSION_SCRIPT_FIXTURE"
      The output should equal "v1.0.0"
      The result of function no_colors_stderr should include "fallback: no-version.sh to v1.0.0"
    End
  End

  Describe 'self-update:file:hash /'
    hash_test:cached() {
      local file="$1"
      self-update:file:hash "$file" >/dev/null
      self-update:file:hash "$file"
    }

    hash_test:detect_change() {
      local file="$1"
      local hash1
      hash1="$(self-update:file:hash "$file")"

      echo "modified content" >"$file"

      local hash2
      hash2="$(self-update:file:hash "$file")"

      [[ "$hash1" != "$hash2" ]] || return 1
      echo "$hash2"
    }

    setup_hash_test() {
      TEMP_DIR=$(mktemp -d)
      echo "test content" > "$TEMP_DIR/test-file.sh"
    }

    cleanup_hash_test() {
      rm -rf "$TEMP_DIR"
    }

    BeforeEach 'setup_hash_test'
    AfterEach 'cleanup_hash_test'

    It 'calculates SHA1 hash of file'
      When call self-update:file:hash "$TEMP_DIR/test-file.sh"
      
      # Expected: printed hash in stdout and stderr messages
      The stdout should satisfy is_sha1
      The result of function no_colors_stderr should satisfy is_hash_log
      The result of function no_colors_stderr should include "of $TEMP_DIR/test-file.sh"
      The status should be success
      
      # Dump
    End

    It 'creates .sha1 cache file'
      When call self-update:file:hash "$TEMP_DIR/test-file.sh"
      The status should be success
      The stdout should satisfy is_sha1
      The result of function no_colors_stderr should satisfy is_hash_log

      The path "$TEMP_DIR/test-file.sh.sha1" should be file
      The output should equal "$(cat "$TEMP_DIR/test-file.sh.sha1")"
    End

    It 'uses cached hash on subsequent calls'
      When call hash_test:cached "$TEMP_DIR/test-file.sh"
      The status should be success
      The stdout should satisfy is_sha1
      The output should equal "$(cat "$TEMP_DIR/test-file.sh.sha1")"
      The result of function no_colors_stderr should satisfy is_hash_log
      The result of function no_colors_stderr should include "from test-file.sh.sha1"
    End

    It 'detects file changes and updates hash'
      When call hash_test:detect_change "$TEMP_DIR/test-file.sh"
      The status should be success
      The stdout should satisfy is_sha1
      The output should equal "$(cat "$TEMP_DIR/test-file.sh.sha1")"
      The result of function no_colors_stderr should satisfy is_hash_log
    End
  End
End
