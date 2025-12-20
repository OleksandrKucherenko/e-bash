#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154,SC2155,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-19
## Version: 0.11.6
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

Describe 'Self-Update Rollback and Cleanup /'
  # Note: We include the script which defines readonly variables
  # Do not try to override them in setup
  Include .scripts/_self-update.sh

  cleanup() {
    # Clean up test artifacts
    __REPO_VERSIONS=()
    declare -g -A __REPO_MAPPING=()
  }

  AfterEach 'cleanup'

  Describe 'self-update:rollback:backup /'
    setup_rollback_backup_test() {
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/rollback_backup.XXXXXX")
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"

      # Create original file
      echo "original content" > "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_rollback_backup_test() {
      rm -rf "$TEMP_PROJECT_DIR"
    }

    BeforeEach 'setup_rollback_backup_test'
    AfterEach 'cleanup_rollback_backup_test'

    It 'restores file from latest backup'
      # Create backup files (simulating previous ln --backup operations)
      echo "backup 1" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~"
      echo "backup 2" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~2~"
      echo "backup 3" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~3~"

      # Modify current file
      echo "modified" > "$TEMP_PROJECT_DIR/.scripts/test.sh"

      When call self-update:rollback:backup "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Should restore from latest backup (.~3~)
      The contents of file "$TEMP_PROJECT_DIR/.scripts/test.sh" should equal "backup 3"
      # Verify logger output
      The result of function no_colors_stderr should include "Found backup file:"
    End

    It 'outputs backup file path found'
      echo "backup 1" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~"

      When call self-update:rollback:backup "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The result of function no_colors_stderr should include "Found backup file:"
      The result of function no_colors_stderr should include "test.sh.~1~"
    End

    It 'handles no backup files gracefully'
      When call self-update:rollback:backup "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The result of function no_colors_stderr should include "Found backup file: <none>"
      # Original file should remain unchanged
      The contents of file "$TEMP_PROJECT_DIR/.scripts/test.sh" should equal "original content"
    End

    It 'selects highest numbered backup file'
      # Create multiple backups
      echo "backup 1" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~"
      echo "backup 5" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~5~"
      echo "backup 10" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~10~"
      echo "backup 2" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~2~"

      When call self-update:rollback:backup "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Should select .~10~ (highest number)
      The contents of file "$TEMP_PROJECT_DIR/.scripts/test.sh" should equal "backup 10"
      # Verify logger output
      The result of function no_colors_stderr should include "Found backup file:"
    End

    It 'removes backup file after restoration'
      echo "backup content" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~"

      When call self-update:rollback:backup "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Backup file should be removed (moved to replace current file)
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~" should not be exist
      # Verify logger output
      The result of function no_colors_stderr should include "Found backup file:"
    End
  End

  Describe 'self-update:rollback:version /'
    setup_rollback_version_test() {
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/rollback_project.XXXXXX")
      TEST_ROLLBACK_VERSION="test-rollback-v1.0.0"

      # Setup version directory with test script at __E_ROOT
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_ROLLBACK_VERSION}/.scripts"
      echo "#!/bin/bash" > "${__E_ROOT}/${__WORKTREES}/${TEST_ROLLBACK_VERSION}/.scripts/test.sh"
      echo "echo 'v1.0.0'" >> "${__E_ROOT}/${__WORKTREES}/${TEST_ROLLBACK_VERSION}/.scripts/test.sh"

      # Setup project directory
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/.scripts/test.sh"
      echo "echo 'current'" >> "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_rollback_version_test() {
      rm -rf "$TEMP_PROJECT_DIR"
      rm -rf "${__E_ROOT}/${__WORKTREES}/${TEST_ROLLBACK_VERSION}"
    }

    BeforeEach 'setup_rollback_version_test'
    AfterEach 'cleanup_rollback_version_test'

    It 'rolls back to specified version'
      # Mock version:has to say version doesn't exist, then version:get will be called
      self-update:version:has() { return 0; }  # Pretend it exists

      When call self-update:rollback:version "$TEST_ROLLBACK_VERSION" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should be symlink
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash binding: test.sh ~>"
      # Link should point to version
      link_target=$(readlink "$TEMP_PROJECT_DIR/.scripts/test.sh")
      The variable link_target should include "$TEST_ROLLBACK_VERSION"
    End

    It 'uses default version v1.0.0 if not specified'
      # Mock version operations
      self-update:version:has() { return 0; }

      # Create the default v1.0.0 version directory
      mkdir -p "${__E_ROOT}/${__WORKTREES}/v1.0.0/.scripts"
      echo "#!/bin/bash" > "${__E_ROOT}/${__WORKTREES}/v1.0.0/.scripts/test.sh"

      When call self-update:rollback:version "" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash binding:"
      # Check link target
      link_target=$(readlink "$TEMP_PROJECT_DIR/.scripts/test.sh")
      The variable link_target should include "v1.0.0"

      # Cleanup
      rm -rf "${__E_ROOT}/${__WORKTREES}/v1.0.0"
    End

    It 'creates backup of current file during rollback'
      self-update:version:has() { return 0; }

      When call self-update:rollback:version "$TEST_ROLLBACK_VERSION" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Should create backup with numbered pattern
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~" should be file
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash binding:"
    End
  End

  Describe 'self-update:unlink /'
    setup_unlink_test() {
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/unlink_project.XXXXXX")
      TEST_UNLINK_VERSION="test-unlink-v1.0.0"

      # Setup source file at __E_ROOT
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/.scripts"
      echo "#!/bin/bash" > "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/.scripts/test.sh"
      echo "# version file content" >> "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/.scripts/test.sh"

      # Setup project with symlink
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      ln -s "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/.scripts/test.sh" "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_unlink_test() {
      rm -rf "$TEMP_PROJECT_DIR"
      rm -rf "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}"
    }

    BeforeEach 'setup_unlink_test'
    AfterEach 'cleanup_unlink_test'

    It 'converts symlink to regular file'
      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The stdout should equal "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should be file
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should not be symlink
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash unlink:"
    End

    It 'preserves file content after unlinking'
      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The stdout should equal "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The contents of file "$TEMP_PROJECT_DIR/.scripts/test.sh" should include "# version file content"
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash unlink:"
    End

    It 'outputs unlink message'
      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The result of function no_colors_stderr should include "e-bash unlink: test.sh <~"
      The result of function no_colors_stderr should include ".versions/${TEST_UNLINK_VERSION}/.scripts/test.sh"
    End

    It 'handles non-symlink file gracefully'
      # Replace symlink with regular file
      rm "$TEMP_PROJECT_DIR/.scripts/test.sh"
      echo "regular file" > "$TEMP_PROJECT_DIR/.scripts/test.sh"

      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The result of function no_colors_stderr should include "e-bash unlink: test.sh - NOT A LINK"
    End

    It 'handles directory symlinks'
      # Create directory symlink
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/mydir"
      echo "content" > "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/mydir/file.txt"

      ln -s "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/mydir" "$TEMP_PROJECT_DIR/mydir"

      When call self-update:unlink "$TEMP_PROJECT_DIR/mydir"
      The status should be success
      The stdout should equal "$TEMP_PROJECT_DIR/mydir"
      The path "$TEMP_PROJECT_DIR/mydir" should be directory
      The path "$TEMP_PROJECT_DIR/mydir" should not be symlink
      The path "$TEMP_PROJECT_DIR/mydir/file.txt" should be file
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash unlink:"
    End

    It 'preserves directory content after unlinking'
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/mydir"
      echo "test content" > "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/mydir/file.txt"

      ln -s "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_VERSION}/mydir" "$TEMP_PROJECT_DIR/mydir"

      When call self-update:unlink "$TEMP_PROJECT_DIR/mydir"
      The status should be success
      The stdout should equal "$TEMP_PROJECT_DIR/mydir"
      The contents of file "$TEMP_PROJECT_DIR/mydir/file.txt" should equal "test content"
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash unlink:"
    End

    It 'handles broken symlinks'
      # Create symlink to non-existent target
      ln -s "/nonexistent/path/file.sh" "$TEMP_PROJECT_DIR/.scripts/broken.sh"

      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/broken.sh"
      # Should fail because the target doesn't exist
      The status should be failure
      The result of function no_colors_stderr should include "WARNING: Problem running"
    End
  End

  Describe 'self-update:unlink edge cases /'
    setup_unlink_edge_test() {
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/unlink_edge.XXXXXX")
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      TEST_UNLINK_EDGE_VERSION="test-unlink-edge-v1.0.0"
    }

    cleanup_unlink_edge_test() {
      rm -rf "$TEMP_PROJECT_DIR"
      rm -rf "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_EDGE_VERSION}"
    }

    BeforeEach 'setup_unlink_edge_test'
    AfterEach 'cleanup_unlink_edge_test'

    It 'handles files with spaces in name'
      mkdir -p "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_EDGE_VERSION}/.scripts"
      echo "content" > "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_EDGE_VERSION}/.scripts/file with spaces.sh"

      ln -s "${__E_ROOT}/${__WORKTREES}/${TEST_UNLINK_EDGE_VERSION}/.scripts/file with spaces.sh" "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh"

      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh"
      The status should be success
      The stdout should equal "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh"
      The path "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh" should be file
      The path "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh" should not be symlink
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash unlink:"
    End

    It 'handles relative symlinks'
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/unlink_repo_rel.XXXXXX")

      mkdir -p "$TEMP_REPO_DIR/source"
      echo "relative content" > "$TEMP_REPO_DIR/source/file.sh"

      cd "$TEMP_PROJECT_DIR/.scripts" || exit 1
      ln -s "../../$(basename "$TEMP_REPO_DIR")/source/file.sh" "relative.sh"
      cd - >/dev/null || exit 1

      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/relative.sh"
      The status should be success
      The stdout should equal "$TEMP_PROJECT_DIR/.scripts/relative.sh"
      The path "$TEMP_PROJECT_DIR/.scripts/relative.sh" should be file
      The contents of file "$TEMP_PROJECT_DIR/.scripts/relative.sh" should include "relative content"
      # Verify logger output
      The result of function no_colors_stderr should include "e-bash unlink:"

      rm -rf "$TEMP_REPO_DIR"
    End
  End
End
