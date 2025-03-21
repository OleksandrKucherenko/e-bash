#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-21
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

% TEST_DIR: "$SHELLSPEC_TMPBASE/tmprepo"

#
# TDD:
#  watchman-make -p 'spec/installation_spec.sh' 'bin/*.sh' --run \
#    "clear && shellspec --no-kcov --focus spec/installation_spec.sh -- "
#

# Path to the installation script
INSTALL_SCRIPT="bin/install.e-bash.sh"

Describe 'install.e-bash.sh /'
  temp_repo() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || return 1
  }
  cleanup_temp_repo() { rm -rf "$TEST_DIR"; }
  cp_install() { cp "$SHELLSPEC_PROJECT_ROOT/$INSTALL_SCRIPT" ./; }
  git_init() { git init -q; }
  git_config() {
    git config --local user.email "test@example.com"
    git config --local user.name "Test User"
  }
  git_commit() { git commit -q -m "Initial commit"; }
  git_ignore() { echo "install.e-bash.sh" >.gitignore; }
  git_add_all() { git add .; }

  # Define a helper function to strip ANSI escape sequences
  # $1 = stdout, $2 = stderr, $3 = exit status of the command
  no_colors_stderr() { echo -n "$2" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'; }
  no_colors_stdout() { echo -n "$1" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g'; }

  Describe 'check_prerequisites /'
    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    It 'should detect when not in a git repository'
      # Run the script, should fail since it's not a git repository
      When run ./install.e-bash.sh

      The status should be failure
      The output should include "Error: Not in a git repository"

      # We don't need to verify the exact stderr output,
      # but we can check that stderr is not empty
      The stderr should be present

      # Dump
    End
  End

  Describe 'check_unstaged_changes /'
    git_stage_touch() {
      touch file.txt
      git add file.txt
    }
    git_stage_content() {
      echo "test" >file.txt
      git add file.txt
    }
    git_untracked_dir() { mkdir -p untracked/nested; }

    Before 'temp_repo; git_init; git_config; cp_install'
    After 'cleanup_temp_repo'

    It 'should detect unstaged or uncommited changes for empty files'
      git_stage_touch

      # Run the script, should fail since there are unstaged changes
      When run ./install.e-bash.sh

      The status should eq 1
      The stdout should include "Error: Unstaged or uncommited changes detected"
      The stderr should be present
    End

    It 'should detect unstaged or uncommited changes for non-empty files'
      git_stage_content

      # Run the script, should fail since there are unstaged changes
      When run ./install.e-bash.sh

      The status should eq 1
      The stdout should include "Error: Unstaged or uncommited changes detected"
      The stderr should be present
    End

    It 'should detect untracked directories'
      git_untracked_dir

      # Run the script, should fail since there are untracked directories
      When run ./install.e-bash.sh

      The status should eq 1
      The stdout should include "Error: Detected untracked directories that would be lost during install operations"
      The stdout should include "untracked/"
      The stderr should be present
    End
  End

  Describe 'install_scripts /'
    git_rename_custom() { git branch -m custom; }
    git_rename_main() { git branch -m main; }
    git_new_branch() { git checkout -b new_branch 1>/dev/null 2>&1; }

    Before 'temp_repo; git_init; git_config; cp_install'
    After 'cleanup_temp_repo'

    It 'should install e-bash scripts successfully'
      When run ./install.e-bash.sh install

      The status should be success
      The output should include "Installation complete"
      The output should include "The e-bash scripts are now available in the"
      The error should be present # logs output
      The dir ".scripts" should be present
    End

    It 'should detect "main" branch correctly'
      git_rename_main

      When run ./install.e-bash.sh install

      The status should be success
      The output should include "Installation complete!"
      The error should include "git checkout --quiet main"
    End

    It 'should detect "custom" branch correctly'
      git_rename_custom

      When run ./install.e-bash.sh install

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output
      The error should include "git checkout --quiet custom"
    End

    It 'should work on "new_branch" branch correctly'
      git_ignore
      git_add_all
      git_commit
      git_new_branch

      When run ./install.e-bash.sh install

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output
      The result of function no_colors_stderr should include "git checkout --quiet new_branch"
    End

    It 'should install v1.0.1-alpha.1 version of e-bash'
      When run ./install.e-bash.sh install v1.0.1-alpha.1

      The status should be success
      The output should include "Installing e-bash scripts (version: v1.0.1-alpha.1)"
      The output should include "Installation complete!"
      The error should be present # logs output
      The error should include "git checkout --quiet -b e-bash-temp v1.0.1-alpha.1"
    End

    It 'should not install not-existing version of e-bash'
      When run ./install.e-bash.sh install v0.0.0-alpha

      The status should be failure
      The output should include "Installing e-bash scripts (version: v0.0.0-alpha)"
      The error should be present # logs output
      The error should include "fatal: 'v0.0.0-alpha' is not a commit and a branch 'e-bash-temp' cannot be created from it"

      # FIXME: should we rollback to the initial state of repo?

      # Dump
    End

    It 'should create README.md with instructions'
      When run ./install.e-bash.sh install

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output
      The file "README.md" should be present
    End
  End

  # Test upgrading e-bash
  Describe 'upgrade_scripts():'
    It 'should upgrade to the latest version successfully'
      Skip # To be implemented
    End

    It 'should save current version before upgrading'
      Skip # To be implemented
    End

    It 'should report the version change'
      Skip # To be implemented
    End
  End

  # Test rollback functionality
  Describe 'repo_rollback():'
    It 'should rollback to previous version successfully'
      Skip # To be implemented
    End

    It 'should fail when no previous version exists'
      Skip # To be implemented
    End
  End

  # Test version management
  Describe 'repo_versions():'
    It 'should list all available versions'
      Skip # To be implemented
    End

    It 'should mark current installed version'
      Skip # To be implemented
    End
  End

  # Test specific version installation
  Describe 'install with specific version:'
    It 'should install the specified version'
      Skip # To be implemented
    End

    It 'should fail with invalid version'
      Skip # To be implemented
    End
  End

  # Test error scenarios
  Describe 'error handling:'
    It 'should handle installation with insufficient permissions'
      Skip # To be implemented
    End

    It 'should handle network failures gracefully'
      Skip # To be implemented
    End
  End

  # Test helper functions
  Describe 'helper functions:'
    It 'should correctly determine current branch'
      Skip # To be implemented
    End

    It 'should correctly detect if e-bash is installed'
      Skip # To be implemented
    End

    It 'should correctly get the installed version'
      Skip # To be implemented
    End
  End
End
