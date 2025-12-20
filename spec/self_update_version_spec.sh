#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-20
## Version: 0.11.18
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Enable DEBUG for logger verification
export DEBUG="version,git,loader,semver"

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

is_sha1() { grep -Eq '^[a-f0-9]{40}$'; }
is_hash_log() { grep -Eq '^hash: [a-f0-9]{40} of '; }

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

Describe 'Self-Update Version Management /'
  # Note: We include the script which defines readonly variables
  # Do not try to override them in setup
  Include .scripts/_self-update.sh

  cleanup() {
    # Clean up test artifacts
    __REPO_VERSIONS=()
    declare -g -A __REPO_MAPPING=()
  }

  AfterEach 'cleanup'

  Describe 'Constants and default values /'
    It 'verifies __WORKTREES constant value'
      # This test ensures the hardcoded regex in self-update:version:bind
      # stays in sync with the __WORKTREES constant value
      The variable __WORKTREES should equal ".versions"
    End
  End

  Describe 'self-update:version:has /'
    It 'returns success when version directory exists'
      # Create test structure at actual __E_ROOT
      mkdir -p "${__E_ROOT}/${__WORKTREES}/test-v1.0.0" || Skip "Cannot create test directory"

      When call self-update:version:has "test-v1.0.0"
      The status should be success

      # Cleanup
      rm -rf "${__E_ROOT}/${__WORKTREES}/test-v1.0.0"
    End

    It 'returns failure when version directory does not exist'
      When call self-update:version:has "nonexistent-version-xyz"
      The status should be failure
    End

    It 'checks correct path structure'
      # Create multiple test versions
      mkdir -p "${__E_ROOT}/${__WORKTREES}/test-v1.1.0" || Skip "Cannot create test directory"

      When call self-update:version:has "test-v1.1.0"
      The status should be success

      # Cleanup
      rm -rf "${__E_ROOT}/${__WORKTREES}/test-v1.1.0"
    End
  End

  Describe 'self-update:version:get /'
    setup_get_test() {
      # Setup a minimal git repo at __E_ROOT for testing
      if [[ ! -d "${__E_ROOT}/.git" ]]; then
        Skip "Git repo not initialized at __E_ROOT"
      fi

      ORIGINAL_DIR="$PWD"
    }

    cleanup_get_test() {
      cd "$ORIGINAL_DIR" || true
      # Clean up any test worktrees
      rm -rf "${__E_ROOT}/${__WORKTREES}/test-tag-"* 2>/dev/null || true
    }

    BeforeEach 'setup_get_test'
    AfterEach 'cleanup_get_test'

    It 'outputs correct message with version path'
      # Mock the actual git worktree command to avoid real operations
      git() {
        if [[ "$1" == "worktree" && "$2" == "add" ]]; then
          # Simulate worktree creation
          local worktree_path="$3"
          local tag="$4"
          mkdir -p "${__E_ROOT}/${worktree_path}"
          echo "Mocked git worktree add for $tag" >&2
          return 0
        fi
        command git "$@"
      }

      When call self-update:version:get "test-tag-get"
      The status should be success
      The result of function no_colors_stderr should include "e-bash version test-tag-get ~ ~/.e-bash/.versions/test-tag-get"

      # Cleanup mock
      unset -f git
    End
  End

  Describe 'self-update:version:get:first /'
    It 'calls get with v1.0.0 version'
      # Mock the dependency functions
      self-update:version:has() { return 1; }  # Pretend it doesn't exist
      self-update:version:get() {
        echo:Version "Mock get called with: $1" >&2
        [[ "$1" == "v1.0.0" ]]
      }

      When call self-update:version:get:first
      The status should be success
      The result of function no_colors_stderr should include "Extract first version: v1.0.0"
      The result of function no_colors_stderr should include "Mock get called with: v1.0.0"
    End

    It 'skips extraction if version already exists'
      self-update:version:has() { return 0; }  # Pretend it exists
      self-update:version:get() {
        echo "Should not be called" >&2
        return 1
      }

      When call self-update:version:get:first
      The status should be success
      The result of function no_colors_stderr should include "Extract first version: v1.0.0"
      The result of function no_colors_stderr should not include "Should not be called"
    End
  End

  Describe 'self-update:version:get:latest /'
    It 'calls find:highest_tag and get'
      # Mock dependencies
      self-update:version:find:highest_tag() {
        echo "v2.5.0"
      }
      self-update:version:has() { return 1; }
      self-update:version:get() {
        echo:Version "Mock get called with: $1" >&2
        [[ "$1" == "v2.5.0" ]]
      }

      When call self-update:version:get:latest
      The status should be success
      The result of function no_colors_stderr should include "Extract latest version: v2.5.0"
      The result of function no_colors_stderr should include "Mock get called with: v2.5.0"
    End

    It 'skips extraction if latest already exists'
      self-update:version:find:highest_tag() { echo "v2.5.0"; }
      self-update:version:has() { return 0; }
      self-update:version:get() {
        echo "Should not be called" >&2
        return 1
      }

      When call self-update:version:get:latest
      The status should be success
      The result of function no_colors_stderr should not include "Should not be called"
    End
  End

  Describe 'self-update:version:remove /'
    It 'calls git worktree remove and rm -rf'
      TEST_REMOVE_VERSION="test-remove-v1.0.0"

      # Create a test directory to remove
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_REMOVE_VERSION}"

      # Mock git command
      git() {
        if [[ "$1" == "worktree" && "$2" == "remove" ]]; then
          echo "Mock git worktree remove: $3" >&2
          return 0
        fi
        command git "$@"
      }

      When call self-update:version:remove "$TEST_REMOVE_VERSION"
      The status should be success
      The result of function no_colors_stderr should include "e-bash version $TEST_REMOVE_VERSION - REMOVED"
      The path "${__E_ROOT}/${__WORKTREES}/${TEST_REMOVE_VERSION}" should not be exist

      unset -f git
    End
  End

  Describe 'self-update:version:bind /'
    setup_bind_test() {
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/project.XXXXXX")
      TEST_BIND_VERSION="test-bind-v1.0.0"

      # Setup version directory with test script at __E_ROOT
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_BIND_VERSION}/.scripts"
      echo "#!/bin/bash" > "${__E_ROOT}/${__WORKTREES}/${TEST_BIND_VERSION}/.scripts/test.sh"
      echo "echo 'version content'" >> "${__E_ROOT}/${__WORKTREES}/${TEST_BIND_VERSION}/.scripts/test.sh"

      # Setup project directory with target file
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/.scripts/test.sh"
      echo "echo 'original'" >> "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_bind_test() {
      rm -rf "$TEMP_PROJECT_DIR"
      rm -rf "${__E_ROOT}/${__WORKTREES}/${TEST_BIND_VERSION}"
    }

    BeforeEach 'setup_bind_test'
    AfterEach 'cleanup_bind_test'

    It 'creates symbolic link from project file to version file'
      When call self-update:version:bind "$TEST_BIND_VERSION" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should be symlink
      The result of function no_colors_stderr should include "e-bash binding: test.sh ~>"
    End

    It 'creates backup of existing file when binding'
      When call self-update:version:bind "$TEST_BIND_VERSION" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Should create a backup file with pattern test.sh.~1~
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~" should be file
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash binding: test.sh ~>"
    End

    It 'skips binding if already bound to same version'
      # First bind
      self-update:version:bind "$TEST_BIND_VERSION" "$TEMP_PROJECT_DIR/.scripts/test.sh" >/dev/null 2>&1

      # Try to bind again
      When call self-update:version:bind "$TEST_BIND_VERSION" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The result of function no_colors_stderr should include "e-bash binding: skip test.sh same version"
    End

    It 'skips binding if file does not exist in version directory'
      When call self-update:version:bind "$TEST_BIND_VERSION" "$TEMP_PROJECT_DIR/.scripts/nonexistent.sh"
      The status should be success
      The result of function no_colors_stderr should include "e-bash binding: skip nonexistent.sh not found in"
    End
  End

  Describe 'self-update:version:hash /'
    setup_version_hash_test() {
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/project_hash.XXXXXX")
      TEST_HASH_VERSION="test-hash-v1.0.0"

      # Setup version directory with test script
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION}/.scripts"
      echo "#!/bin/bash" > "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION}/.scripts/test.sh"
      echo "# version 1.0.0 content" >> "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION}/.scripts/test.sh"

      # Setup project directory
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_version_hash_test() {
      rm -rf "$TEMP_PROJECT_DIR"
      rm -rf "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION}"
    }

    BeforeEach 'setup_version_hash_test'
    AfterEach 'cleanup_version_hash_test'

    It 'calculates hash of version file'
      When call self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "$TEST_HASH_VERSION"
      The status should be success
      The stdout should satisfy is_sha1
      The result of function no_colors_stderr should include "hash versioned file:"
    End

    It 'creates .sha1 cache file for version file'
      When call self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "$TEST_HASH_VERSION"
      The status should be success
      The stdout should satisfy is_sha1
      The path "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION}/.scripts/test.sh.sha1" should be file
      # Verify logger output
      The result of function no_colors_stderr should include "hash versioned file:"
    End

    It 'returns different hash for different content'
      # Create another version with different content
      TEST_HASH_VERSION2="test-hash-v2.0.0"
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION2}/.scripts"
      echo "#!/bin/bash" > "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION2}/.scripts/test.sh"
      echo "# version 2.0.0 content - different" >> "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION2}/.scripts/test.sh"

      hash1=$(self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "$TEST_HASH_VERSION" 2>/dev/null)
      hash2=$(self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "$TEST_HASH_VERSION2" 2>/dev/null)

      The variable hash1 should not equal "$hash2"

      rm -rf "${__E_ROOT}/${__WORKTREES}/${TEST_HASH_VERSION2}"
    End
  End

  Describe 'self-update:version:tags integration /'
    setup_tags_integration_test() {
      ORIGINAL_DIR="$PWD"

      # Create a test git repo at __E_ROOT if it doesn't exist
      if [ ! -d "${__E_ROOT}/.git" ]; then
        mkdir -p "${__E_ROOT}"
        cd "${__E_ROOT}" || return 1

        # Initialize git repo
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"

        # Create initial commit
        echo "test" > README.md
        git add README.md
        git commit -q -m "Initial commit"

        # Create some version tags for testing
        git tag v1.0.0
        git tag v1.1.0
        git tag v1.2.0
        git tag v2.0.0

        cd "$ORIGINAL_DIR" || return 1
      fi
    }

    cleanup_tags_integration_test() {
      cd "$ORIGINAL_DIR" || true
      # Clean up test repo if we created it
      if [ -d "${__E_ROOT}/.git" ]; then
        # Only remove if it's our test repo (has our test tags)
        cd "${__E_ROOT}" || true
        if git tag | grep -q "^v1.0.0$"; then
          cd "$ORIGINAL_DIR" || true
          rm -rf "${__E_ROOT}"
        fi
      fi
    }

    BeforeEach 'setup_tags_integration_test'
    AfterEach 'cleanup_tags_integration_test'

    It 'extracts version tags from git repo'
      When call self-update:version:tags
      The status should be success
      # Should populate arrays with our test tags
      The variable __REPO_VERSIONS[@] should not be blank
    End

    It 'creates version-to-tag mapping'
      self-update:version:tags

      # Should have our test versions
      [ "${#__REPO_VERSIONS[@]}" -gt 0 ] || Skip "No version tags found"

      # Check that mapping exists for first version
      first_version="${__REPO_VERSIONS[0]}"
      The variable __REPO_MAPPING[$first_version] should not be blank
    End

    It 'sorts versions in ascending order'
      self-update:version:tags

      # Should have at least 2 versions from our test tags
      [ "${#__REPO_VERSIONS[@]}" -ge 2 ] || Skip "Need at least 2 versions"

      # Compare first two versions - first should be less than second
      v1="${__REPO_VERSIONS[0]}"
      v2="${__REPO_VERSIONS[1]}"

      When call compare:versions "$v1" "$v2"
      The status should be success
    End
  End
End
