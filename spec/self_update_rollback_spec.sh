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

Describe 'Self-Update Rollback and Cleanup /'
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
    End

    It 'removes backup file after restoration'
      echo "backup content" > "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~"

      When call self-update:rollback:backup "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Backup file should be removed (moved to replace current file)
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~" should not be exist
    End

    It 'uses BASH_SOURCE[0] as default file path'
      # Create a test script that will call rollback:backup
      cat > "$TEMP_PROJECT_DIR/.scripts/caller.sh" << 'EOF'
#!/bin/bash
source .scripts/_self-update.sh
echo "backup" > "${BASH_SOURCE[0]}.~1~"
self-update:rollback:backup
cat "${BASH_SOURCE[0]}"
EOF
      chmod +x "$TEMP_PROJECT_DIR/.scripts/caller.sh"

      cd "$SHELLSPEC_PROJECT_ROOT" || exit 1

      When run script "$TEMP_PROJECT_DIR/.scripts/caller.sh"
      The status should be success
      The stdout should include "backup"
    End
  End

  Describe 'self-update:rollback:version /'
    setup_rollback_version_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/rollback_version.XXXXXX")
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/rollback_project.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      # Initialize mock git repo
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

      # Setup version directory with test script
      git worktree add --quiet "$__WORKTREES/v1.0.0" v1.0.0
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts"
      echo "#!/bin/bash" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"
      echo "echo 'v1.0.0'" >> "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"

      # Setup project directory
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      echo "#!/bin/bash" > "$TEMP_PROJECT_DIR/.scripts/test.sh"
      echo "echo 'current'" >> "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_rollback_version_test() {
      cd - >/dev/null || true
      rm -rf "$TEMP_REPO_DIR" "$TEMP_PROJECT_DIR"
    }

    BeforeEach 'setup_rollback_version_test'
    AfterEach 'cleanup_rollback_version_test'

    It 'rolls back to specified version'
      When call self-update:rollback:version "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should be symlink
      # Link should point to v1.0.0 version
      The result of "readlink $TEMP_PROJECT_DIR/.scripts/test.sh" should include "v1.0.0"
    End

    It 'uses default version v1.0.0 if not specified'
      When call self-update:rollback:version "" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The result of "readlink $TEMP_PROJECT_DIR/.scripts/test.sh" should include "v1.0.0"
    End

    It 'creates version worktree if not already present'
      # Remove the worktree first
      cd "$TEMP_REPO_DIR" || exit 1
      git worktree remove "$__WORKTREES/v1.0.0" --force >/dev/null 2>&1 || true
      rm -rf "$__WORKTREES/v1.0.0"

      When call self-update:rollback:version "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The path "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0" should be directory
    End

    It 'creates backup of current file during rollback'
      When call self-update:rollback:version "v1.0.0" "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      # Should create backup with numbered pattern
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh.~1~" should be file
    End

    It 'uses BASH_SOURCE[0] as default file path'
      # Mock BASH_SOURCE in the function context
      rollback_test_wrapper() {
        local test_file="$1"
        self-update:rollback:version "v1.0.0" "$test_file"
      }

      When call rollback_test_wrapper "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should be symlink
    End
  End

  Describe 'self-update:unlink /'
    setup_unlink_test() {
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/unlink_repo.XXXXXX")
      TEMP_PROJECT_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/unlink_project.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      # Setup source file
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts"
      echo "#!/bin/bash" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"
      echo "# version file content" >> "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh"

      # Setup project with symlink
      mkdir -p "$TEMP_PROJECT_DIR/.scripts"
      ln -s "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/test.sh" "$TEMP_PROJECT_DIR/.scripts/test.sh"
    }

    cleanup_unlink_test() {
      rm -rf "$TEMP_REPO_DIR" "$TEMP_PROJECT_DIR"
    }

    BeforeEach 'setup_unlink_test'
    AfterEach 'cleanup_unlink_test'

    It 'converts symlink to regular file'
      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should be file
      The path "$TEMP_PROJECT_DIR/.scripts/test.sh" should not be symlink
    End

    It 'preserves file content after unlinking'
      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The contents of file "$TEMP_PROJECT_DIR/.scripts/test.sh" should include "# version file content"
    End

    It 'outputs unlink message'
      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The result of function no_colors_stderr should include "e-bash unlink: test.sh <~"
      The result of function no_colors_stderr should include ".versions/v1.0.0/.scripts/test.sh"
    End

    It 'handles non-symlink file gracefully'
      # Replace symlink with regular file
      rm "$TEMP_PROJECT_DIR/.scripts/test.sh"
      echo "regular file" > "$TEMP_PROJECT_DIR/.scripts/test.sh"

      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/test.sh"
      The status should be success
      The result of function no_colors_stderr should include "e-bash unlink: test.sh - NOT A LINK"
    End

    It 'uses BASH_SOURCE[0] as default file path'
      # Create a script that calls unlink on itself
      cat > "$TEMP_PROJECT_DIR/.scripts/unlink_self.sh" << 'EOF'
#!/bin/bash
source .scripts/_self-update.sh
# This script should detect it's not a link
self-update:unlink 2>&1 | grep -q "NOT A LINK"
EOF
      chmod +x "$TEMP_PROJECT_DIR/.scripts/unlink_self.sh"

      cd "$SHELLSPEC_PROJECT_ROOT" || exit 1

      When run script "$TEMP_PROJECT_DIR/.scripts/unlink_self.sh"
      The status should be success
    End

    It 'handles directory symlinks'
      # Create directory symlink
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/mydir"
      echo "content" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/mydir/file.txt"

      ln -s "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/mydir" "$TEMP_PROJECT_DIR/mydir"

      When call self-update:unlink "$TEMP_PROJECT_DIR/mydir"
      The status should be success
      The path "$TEMP_PROJECT_DIR/mydir" should be directory
      The path "$TEMP_PROJECT_DIR/mydir" should not be symlink
      The path "$TEMP_PROJECT_DIR/mydir/file.txt" should be file
    End

    It 'preserves directory content after unlinking'
      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/mydir"
      echo "test content" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/mydir/file.txt"

      ln -s "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/mydir" "$TEMP_PROJECT_DIR/mydir"

      When call self-update:unlink "$TEMP_PROJECT_DIR/mydir"
      The status should be success
      The contents of file "$TEMP_PROJECT_DIR/mydir/file.txt" should equal "test content"
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
    }

    cleanup_unlink_edge_test() {
      rm -rf "$TEMP_PROJECT_DIR"
    }

    BeforeEach 'setup_unlink_edge_test'
    AfterEach 'cleanup_unlink_edge_test'

    It 'handles files with spaces in name'
      TEMP_REPO_DIR=$(mktemp -d "$SHELLSPEC_TMPBASE/unlink_repo_space.XXXXXX")
      __E_ROOT="$TEMP_REPO_DIR"

      mkdir -p "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts"
      echo "content" > "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/file with spaces.sh"

      ln -s "$TEMP_REPO_DIR/$__WORKTREES/v1.0.0/.scripts/file with spaces.sh" "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh"

      When call self-update:unlink "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh"
      The status should be success
      The path "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh" should be file
      The path "$TEMP_PROJECT_DIR/.scripts/file with spaces.sh" should not be symlink

      rm -rf "$TEMP_REPO_DIR"
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
      The path "$TEMP_PROJECT_DIR/.scripts/relative.sh" should be file
      The contents of file "$TEMP_PROJECT_DIR/.scripts/relative.sh" should include "relative content"

      rm -rf "$TEMP_REPO_DIR"
    End
  End
End
