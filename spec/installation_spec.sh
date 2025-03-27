#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-27
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# shellcheck disable=SC2288
% TEST_DIR: "$SHELLSPEC_TMPBASE/tmprepo"

#
# TDD:
#  watchman-make -p 'spec/installation_spec.sh' 'bin/*.sh' --run "clear && shellspec --no-kcov --focus spec/installation_spec.sh -- "
#

# Path to the installation script
INSTALL_SCRIPT="bin/install.e-bash.sh"

fDescribe 'install.e-bash.sh /'
  temp_repo() {
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR" || return 1
  }
  cleanup_temp_repo() { rm -rf "$TEST_DIR"; }
  cp_install() { cp "$SHELLSPEC_PROJECT_ROOT/$INSTALL_SCRIPT" ./; }
  git_init() { git init -q; }
  git_config_user() { git config --local user.name "Test User"; }
  git_config_email() { git config --local user.email "test@example.com"; }
  git_config() { git_config_user && git_config_email; }
  git_commit() { git commit -q -m "Initial commit"; }
  git_amend() { git commit --amend -q --no-edit; }
  git_ignore() { echo "install.e-bash.sh" >.gitignore; }
  git_add_all() { git add .; }
  mkdir_bin() { mkdir -p bin; }
  git_keep_bin() { touch bin/.gitkeep && git add bin/.gitkeep; }
  git_add_bindir() { mkdir_bin && git_keep_bin && git_amend; }
  install_latest() { ./install.e-bash.sh install 2>/dev/null >/dev/null; }
  install_alpha() { ./install.e-bash.sh install v1.0.1-alpha.1 2>/dev/null >/dev/null; }
  install_stable() { ./install.e-bash.sh install v1.0.0 2>/dev/null >/dev/null; }
  upgrade_latest() { ./install.e-bash.sh upgrade 2>/dev/null >/dev/null; }
  upgrade_alpha() { ./install.e-bash.sh upgrade v1.0.1-alpha.1 2>/dev/null >/dev/null; }
  upgrade_stable() { ./install.e-bash.sh upgrade v1.0.0 2>/dev/null >/dev/null; }
  do_rollback() { ./install.e-bash.sh rollback 2>/dev/null >/dev/null; }
  do_versions() { ./install.e-bash.sh versions 2>/dev/null >/dev/null; }

  # Define a helper function to strip ANSI escape sequences
  # $1 = stdout, $2 = stderr, $3 = exit status of the command
  no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }
  no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }

  Describe 'check_prerequisites /'
    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    # Scenario 9
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

  # Test installation of e-bash scripts
  Describe 'install_scripts /'
    git_rename_custom() { git branch -m custom; }
    git_rename_main() { git branch -m main; }
    git_new_branch() { git checkout -b new_branch 1>/dev/null 2>&1; }

    Before 'temp_repo; git_init; git_config; cp_install'
    After 'cleanup_temp_repo'

    # Scenario 1
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

    # Scenario 2
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

    It 'should create README.md with instructions'
      When run ./install.e-bash.sh install

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output
      The file "README.md" should be present
    End
  End

  # Test upgrading e-bash
  Describe 'upgrade_scripts /'
    Before 'temp_repo; git_init; git_config; cp_install; install_stable'
    After 'cleanup_temp_repo'

    It 'should upgrade to the latest version successfully'
      When run ./install.e-bash.sh upgrade

      The status should be success
      The output should include "Upgrade complete!"
      The error should be present # logs output
      The file .e-bash-previous-version should be present
    End

    It 'should print uninstall instructions on merge conflict'
      # user has repo with e-bash script installed manually...

      # I mean something in .scripts folder
      mkdir -p .scripts                        # create out destination folder
      echo "fake content" >.scripts/_colors.sh # is_installed() == true
      git_add_all
      git_amend

      When run ./install.e-bash.sh

      The status should be failure
      The output should include "Resolve Conflict by Aborting GIT Merge"
      The output should include "Manual Uninstall Guide"
      The error should be present # logs output
    End
  End

  # Test rollback functionality
  Describe 'repo_rollback /'
    Before 'temp_repo; git_init; git_config; cp_install; install_stable'
    After 'cleanup_temp_repo'

    It 'should rollback to previous version successfully'
      upgrade_alpha

      When run ./install.e-bash.sh rollback

      The status should be success
      The output should include "Rollback complete!"
      The error should be present # logs output
      The file .e-bash-previous-version should not be empty file
    End

    It 'should fail when no previous version exists'
      When run ./install.e-bash.sh rollback

      The status should be failure
      The output should include "Error: No previous version found to rollback to"
      The error should be present # logs output
    End
  End

  # Scenario 5: Viewing available versions of e-Bash
  Describe 'repo_versions /'

    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    It 'should list all available versions'
      When run ./install.e-bash.sh versions

      The status should be success
      The output should include "Available stable versions:"
      The output should include "Non-stable versions (pre-releases, development versions)"
      The error should be present # logs output
    End

    Describe 'on top of existing repo /'
      Before 'temp_repo; git_init; git_config; cp_install'

      It 'should mark current alpha installed version'
        install_alpha

        When run ./install.e-bash.sh versions

        The status should be success
        The result of function no_colors_stdout should include "v1.1.0 [LATEST]"
        The result of function no_colors_stdout should include "v1.0.1-alpha.1 [CURRENT]"
        The error should be present # logs output
      End

      It 'should mark current stable installed version'
        install_stable

        When run ./install.e-bash.sh versions

        The status should be success
        The result of function no_colors_stdout should include "v1.0.0 [CURRENT]"
        The result of function no_colors_stdout should include "v1.1.0 [LATEST]"
        The error should be present # logs output
      End

      It 'should mark latest stable installed version'
        install_latest
        cp_install

        When run ./install.e-bash.sh versions

        The status should be success
        The result of function no_colors_stdout should include "master - Development version (alias to: latest) [CURRENT]"
        The error should be present # logs output
      End

    End
  End

  # Test specific version installation
  Describe 'install with specific version:'
    Before 'temp_repo; git_init; git_config; cp_install'
    After 'cleanup_temp_repo'

    It 'should install the specified version'
      When run ./install.e-bash.sh install v1.0.0

      The status should be success
      The output should include "Installing e-bash scripts (version: v1.0.0)"
      The output should include "Installation complete!"
      The error should be present # logs output
    End

    It 'should not install not-existing version of e-bash'
      When run ./install.e-bash.sh install v0.0.0-alpha

      The status should be failure
      The output should include "Installing e-bash scripts (version: v0.0.0-alpha)"
      The error should be present # logs output
      The error should include "fatal: 'v0.0.0-alpha' is not a commit and a branch 'e-bash-temp' cannot be created from it"

      # FIXME: should we rollback to the initial state of repo? Uncomment Dump to preview.
      # Dump
    End
  End

  # Test helper functions
  Describe 'help functions /'
    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    It 'should correctly show --help message'
      When run ./install.e-bash.sh --help

      The status should be success
      The output should include "Usage:"
      The error should include "Regular folder detected"
    End

    It 'should correctly show help message'
      When run ./install.e-bash.sh help

      The status should be success
      The output should include "Usage:"
      The error should include "Regular folder detected"
    End
  End
End
