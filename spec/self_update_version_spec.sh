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

is_sha1() { grep -Eq '^[a-f0-9]{40}$'; }
is_hash_log() { grep -Eq '^hash: [a-f0-9]{40} of '; }

Describe 'Self-Update Version Management /'
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

  Describe 'self-update:version:has /'
    setup_has_test() {
      # Create a temporary directory to simulate version directory
      TEMP_VERSION_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/version_has.XXXXXX")

      # Mock __E_ROOT to use our temp directory
      __E_ROOT="$TEMP_VERSION_DIR"

      # Create a mock version directory
      mkdir -p "$TEMP_VERSION_DIR/$__WORKTREES/v1.0.0"
    }

    cleanup_has_test() {
      rm -rf "$TEMP_VERSION_DIR"
    }

    BeforeEach 'setup_has_test'
    AfterEach 'cleanup_has_test'

    It 'returns success when version directory exists'
      When call self-update:version:has "v1.0.0"
      The status should be success
    End

    It 'returns failure when version directory does not exist'
      When call self-update:version:has "v2.0.0"
      The status should be failure
    End

    It 'checks correct path structure'
      # Create another version
      mkdir -p "$TEMP_VERSION_DIR/$__WORKTREES/v1.1.0"

      When call self-update:version:has "v1.1.0"
      The status should be success
    End
  End

  Describe 'self-update:version:get /'
    setup_get_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/version_get.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      # Initialize a mock git repo
      cd "$TEMP_REPO_DIR" || exit 1
      git init --quiet
      git config user.email "test@example.com"
      git config user.name "Test User"

      # Create initial commit
      echo "test" > test.txt
      git add test.txt
      git commit -m "initial" --quiet

      # Create a tag
      git tag v1.0.0

      # Create worktrees directory
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES"
    }

    cleanup_get_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_REPO_DIR"
    }

    BeforeEach 'setup_get_test'
    AfterEach 'cleanup_get_test'

    It 'creates worktree for specified version'
      When call self-update:version:get "v1.0.0"
      The status should be success
      The path "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0" should be directory
      The result of function no_colors_stderr should include "e-bash version v1.0.0"
    End

    It 'outputs correct message with version path'
      When call self-update:version:get "v1.0.0"
      The result of function no_colors_stderr should include "e-bash version v1.0.0 ~ ~/.e-bash/.versions/v1.0.0"
    End
  End

  Describe 'self-update:version:get:first /'
    setup_first_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/version_first.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      # Initialize mock git repo
      cd "$TEMP_REPO_DIR" || exit 1
      git init --quiet
      git config user.email "test@example.com"
      git config user.name "Test User"

      echo "test" > test.txt
      git add test.txt
      git commit -m "initial" --quiet
      git tag v1.0.0

      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES"
    }

    cleanup_first_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_REPO_DIR"
    }

    BeforeEach 'setup_first_test'
    AfterEach 'cleanup_first_test'

    It 'extracts the first/rollback version (v1.0.0)'
      When call self-update:version:get:first
      The status should be success
      The result of function no_colors_stderr should include "Extract first version: v1.0.0"
      The path "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0" should be directory
    End

    It 'does not extract if version already exists'
      # Pre-create the worktree
      git worktree add --quiet "$__WORKTREES/v1.0.0" v1.0.0

      When call self-update:version:get:first
      The status should be success
      The result of function no_colors_stderr should include "Extract first version: v1.0.0"
    End
  End

  Describe 'self-update:version:get:latest /'
    setup_latest_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/version_latest.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      cd "$TEMP_REPO_DIR" || exit 1
      git init --quiet
      git config user.email "test@example.com"
      git config user.name "Test User"

      echo "v1" > test.txt
      git add test.txt
      git commit -m "v1" --quiet
      git tag v1.0.0

      echo "v2" > test.txt
      git add test.txt
      git commit -m "v2" --quiet
      git tag v2.0.0

      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES"

      # Setup version arrays
      __REPO_VERSIONS=("1.0.0" "2.0.0")
      declare -g -A __REPO_MAPPING=(
        ["1.0.0"]="v1.0.0"
        ["2.0.0"]="v2.0.0"
      )
    }

    cleanup_latest_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_REPO_DIR"
    }

    BeforeEach 'setup_latest_test'
    AfterEach 'cleanup_latest_test'

    It 'extracts the latest/highest version'
      When call self-update:version:get:latest
      The status should be success
      The result of function no_colors_stderr should include "Extract latest version: v2.0.0"
      The path "$TEMP_REPO_DIR/$__WORKTREES/v2.0.0" should be directory
    End
  End

  Describe 'self-update:version:remove /'
    setup_remove_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/version_remove.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      cd "$TEMP_REPO_DIR" || exit 1
      git init --quiet
      git config user.email "test@example.com"
      git config user.name "Test User"

      echo "test" > test.txt
      git add test.txt
      git commit -m "initial" --quiet
      git tag v1.0.0

      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES"
      git worktree add --quiet "$__WORKTREES/v1.0.0" v1.0.0
    }

    cleanup_remove_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_REPO_DIR"
    }

    BeforeEach 'setup_remove_test'
    AfterEach 'cleanup_remove_test'

    It 'removes version worktree from disk'
      When call self-update:version:remove "v1.0.0"
      The status should be success
      The path "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0" should not be exist
      The result of function no_colors_stderr should include "e-bash version v1.0.0 - REMOVED"
    End

    It 'handles removing non-existent version gracefully'
      When call self-update:version:remove "v2.0.0"
      The status should be success
      The result of function no_colors_stderr should include "e-bash version v2.0.0 - REMOVED"
    End
  End

  Describe 'self-update:version:bind /'
    setup_bind_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/version_bind.XXXXXX")
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/project.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      # Setup version directory with test script
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts"
      echo "#!/bin/bash" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"
      echo "echo 'v1.0.0'" >> "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"

      # Setup project directory with target file
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/.scripts/test.sh"
      echo "echo 'original'" >> "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_bind_test() {
      rm -rf "$TEMP_REPO_DIR" "$TEMP_PROJECT_DIR"
    }

    BeforeEach 'setup_bind_test'
    AfterEach 'cleanup_bind_test'

    It 'creates symbolic link from project file to version file'
      When call self-update:version:bind "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should be symlink
      The result of function no_colors_stderr should include "e-bash binding: test.sh ~>"
    End

    It 'creates backup of existing file when binding'
      When call self-update:version:bind "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Should create a backup file with pattern test.sh.~1~
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~" should be file
    End

    It 'skips binding if already bound to same version'
      # First bind
      self-update:version:bind "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/test.sh" >/dev/null 2>&1

      # Try to bind again
      When call self-update:version:bind "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The result of function no_colors_stderr should include "e-bash binding: skip test.sh same version"
    End

    It 'skips binding if file does not exist in version directory'
      When call self-update:version:bind "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/nonexistent.sh"
      The status should be success
      The result of function no_colors_stderr should include "e-bash binding: skip nonexistent.sh not found in"
    End

    It 'handles bin/ subdirectory files'
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/bin"
      echo "#!/bin/bash" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/bin/tool.sh"

      mkdir -p "$TEMP_PROJECT_DIR/bin"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/bin/tool.sh"

      When call self-update:version:bind "v1.0.0" "$TEMP_PROJECT_DIR/bin/tool.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/bin/tool.sh" should be symlink
    End
  End

  Describe 'self-update:version:hash /'
    setup_version_hash_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/version_hash.XXXXXX")
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/project_hash.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      # Setup version directory with test script
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts"
      echo "#!/bin/bash" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"
      echo "# version 1.0.0 content" >> "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"

      # Setup project directory
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_version_hash_test() {
      rm -rf "$TEMP_REPO_DIR" "$TEMP_PROJECT_DIR"
    }

    BeforeEach 'setup_version_hash_test'
    AfterEach 'cleanup_version_hash_test'

    It 'calculates hash of version file'
      When call self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "v1.0.0"
      The status should be success
      The stdout should satisfy is_sha1
      The result of function no_colors_stderr should include "hash versioned file:"
    End

    It 'creates .sha1 cache file for version file'
      When call self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "v1.0.0"
      The status should be success
      The path "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh.sha1" should be file
    End

    It 'returns different hash for different versions'
      # Create v2.0.0 with different content
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v2.0.0/.scripts"
      echo "#!/bin/bash" > "$TEMP_REPO_DIR/$__WORKTREES/v2.0.0/.scripts/test.sh"
      echo "# version 2.0.0 content - different" >> "$TEMP_REPO_DIR/$__WORKTREES/v2.0.0/.scripts/test.sh"

      hash1=$(self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "v1.0.0")

      When call self-update:version:hash "$TEMP_PROJECT_DIR/.scripts/test.sh" "v2.0.0"
      The status should be success
      The stdout should not equal "$hash1"
    End

    It 'resolves file path correctly for bin/ directory'
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/bin"
      echo "#!/bin/bash" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/bin/tool.sh"
      echo "# tool content" >> "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/bin/tool.sh"

      mkdir -p "$TEMP_PROJECT_DIR/bin"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/bin/tool.sh"

      When call self-update:version:hash "$TEMP_PROJECT_DIR/bin/tool.sh" "v1.0.0"
      The status should be success
      The stdout should satisfy is_sha1
    End
  End

  Describe 'self-update:version:tags integration /'
    setup_tags_integration_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/tags_integration.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      cd "$TEMP_REPO_DIR" || exit 1
      git init --quiet
      git config user.email "test@example.com"
      git config user.name "Test User"

      echo "v1" > test.txt
      git add test.txt
      git commit -m "v1" --quiet
      git tag v1.0.0

      echo "v1.0.1" > test.txt
      git add test.txt
      git commit -m "v1.0.1" --quiet
      git tag v1.0.1

      echo "v1.1.0" > test.txt
      git add test.txt
      git commit -m "v1.1.0" --quiet
      git tag v1.1.0

      echo "v2.0.0-beta" > test.txt
      git add test.txt
      git commit -m "v2.0.0-beta" --quiet
      git tag v2.0.0-beta

      echo "v2.0.0" > test.txt
      git add test.txt
      git commit -m "v2.0.0" --quiet
      git tag v2.0.0
    }

    cleanup_tags_integration_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_REPO_DIR"
    }

    BeforeEach 'setup_tags_integration_test'
    AfterEach 'cleanup_tags_integration_test'

    It 'extracts and sorts version tags from real git repo'
      When call self-update:version:tags
      The status should be success
      # Should populate arrays
      The variable __REPO_VERSIONS[@] should not be blank
      The value "${#__REPO_VERSIONS[@]}" should equal 5
    End

    It 'sorts versions in ascending order'
      self-update:version:tags

      # Check array is sorted
      The value "${__REPO_VERSIONS[0]}" should equal "1.0.0"
      The value "${__REPO_VERSIONS[1]}" should equal "1.0.1"
      The value "${__REPO_VERSIONS[2]}" should equal "1.1.0"
      The value "${__REPO_VERSIONS[3]}" should equal "2.0.0-beta"
      The value "${__REPO_VERSIONS[4]}" should equal "2.0.0"
    End

    It 'creates correct version-to-tag mapping'
      self-update:version:tags

      # Check mapping preserves 'v' prefix
      The value "${__REPO_MAPPING[1.0.0]}" should equal "v1.0.0"
      The value "${__REPO_MAPPING[2.0.0]}" should equal "v2.0.0"
      The value "${__REPO_MAPPING[2.0.0-beta]}" should equal "v2.0.0-beta"
    End

    It 'handles tags with and without v prefix'
      # Add tag without 'v' prefix
      git tag 3.0.0

      When call self-update:version:tags
      The status should be success
      The value "${__REPO_MAPPING[3.0.0]}" should equal "3.0.0"
    End
  End
End
