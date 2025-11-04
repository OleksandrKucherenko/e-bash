#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-07-06
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

fDescribe 'bin/install.e-bash.sh'
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
  git_master_to_main() { git branch -m main; }
  mkdir_bin() { mkdir -p bin; }
  git_keep_bin() { touch bin/.gitkeep && git add bin/.gitkeep; }
  git_add_bindir() { mkdir_bin && git_keep_bin && git_amend; }
  install_latest() { ./install.e-bash.sh install 2>/dev/null >/dev/null; }
  install_alpha() { ./install.e-bash.sh install v1.0.1-alpha.1 2>/dev/null >/dev/null; }
  install_stable() { ./install.e-bash.sh install v1.0.0 2>/dev/null >/dev/null; }
  # Global installation functions need environment variable forwarding to work with temp_home
  install_global() { HOME="$TEMP_HOME" ./install.e-bash.sh install --global 2>/dev/null >/dev/null; }
  install_global_version() { HOME="$TEMP_HOME" ./install.e-bash.sh install v1.0.0 --global 2>/dev/null >/dev/null; }
  install_global_symlink() { HOME="$TEMP_HOME" ./install.e-bash.sh install --global --create-symlink 2>/dev/null >/dev/null; }
  upgrade_latest() { ./install.e-bash.sh upgrade 2>/dev/null >/dev/null; }
  upgrade_alpha() { ./install.e-bash.sh upgrade v1.0.1-alpha.1 2>/dev/null >/dev/null; }
  upgrade_stable() { ./install.e-bash.sh upgrade v1.0.0 2>/dev/null >/dev/null; }
  upgrade_global() { HOME="$TEMP_HOME" ./install.e-bash.sh upgrade --global 2>/dev/null >/dev/null; }
  upgrade_global_version() { HOME="$TEMP_HOME" ./install.e-bash.sh upgrade v1.0.1-alpha.1 --global 2>/dev/null >/dev/null; }
  do_rollback() { ./install.e-bash.sh rollback 2>/dev/null >/dev/null; }
  do_rollback_global() { HOME="$TEMP_HOME" ./install.e-bash.sh rollback --global 2>/dev/null >/dev/null; }
  do_versions() { ./install.e-bash.sh versions 2>/dev/null >/dev/null; }

  # Define a helper function to strip ANSI escape sequences
  # $1 = stdout, $2 = stderr, $3 = exit status of the command
  no_colors_error() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
  no_colors_output() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

  Describe 'Check Prerequisites:'
    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    # Scenario 9
    It 'should detect when not in a git repository'
      # Run the script, should fail since it's not a git repository
      When run ./install.e-bash.sh

      The status should be failure
      #The output should include "Error: Not in a git repository"
      The result of function no_colors_error should include "detected: we are in a regular folder."

      # We don't need to verify the exact stderr output,
      # but we can check that stderr is not empty
      The stderr should be present

      # Dump
    End
  End

  Describe 'Check Unstaged Changes:'
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
  Describe 'Install:'
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
      The file ".scripts/_colors.sh" should be present
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
      The result of function no_colors_error should include "git checkout --quiet new_branch"
    End

    It 'should install v1.0.1-alpha.1 version of e-bash'
      When run ./install.e-bash.sh install v1.0.1-alpha.1

      The status should be success
      The result of function no_colors_output should include "Installing e-bash scripts (version: v1.0.1-alpha.1)"
      The output should include "Installation complete!"
      The error should be present # logs output
      The error should include "git checkout --quiet -b e-bash-temp v1.0.1-alpha.1"

      #Dump
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
  Describe 'Upgrade:'
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
  Describe 'Rollback:'
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
  Describe 'Versions:'

    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    It 'should list all available versions'
      When run ./install.e-bash.sh versions

      The status should be success
      The output should include "Available remote stable versions"
      The output should include "Available remote non-stable versions (pre-releases, development):"
      The error should be present # logs output
    End

    Describe 'on top of existing repo /'
      Before 'temp_repo; git_init; git_config; cp_install'

      It 'should mark current alpha installed version'
        install_alpha

        When run ./install.e-bash.sh versions

        The status should be success
        The result of function no_colors_output should include "v1.1.0 [LAST]"
        The result of function no_colors_output should include "v1.0.1-alpha.1 [CURRENT]"
        The error should be present # logs output
      End

      It 'should mark current stable installed version'
        install_stable

        When run ./install.e-bash.sh versions

        The status should be success
        The result of function no_colors_output should include "v1.0.0 [CURRENT]"
        The result of function no_colors_output should include "v1.1.0 [LAST]"
        The error should be present # logs output
      End

      It 'should mark latest stable installed version'
        install_latest
        cp_install

        When run ./install.e-bash.sh versions

        The status should be success
        The result of function no_colors_output should include "master - Development version (alias: latest) [CURRENT]"
        The error should be present # logs output
      End

    End
  End

  # Test specific version installation
  Describe 'Install Version:'
    Before 'temp_repo; git_init; git_config; cp_install'
    After 'cleanup_temp_repo'

    It 'should install the specified version'
      When run ./install.e-bash.sh install v1.0.0

      The status should be success
      The result of function no_colors_output should include "Installing e-bash scripts (version: v1.0.0)"
      The output should include "Installation complete!"
      The error should be present # logs output
    End

    It 'should not install not-existing version of e-bash'
      When run ./install.e-bash.sh install v0.0.0-alpha

      The status should be failure
      The result of function no_colors_output should include "Installing e-bash scripts (version: v0.0.0-alpha)"
      The error should be present # logs output
      The error should include "fatal: 'v0.0.0-alpha' is not a commit and a branch 'e-bash-temp' cannot be created from it"

      # FIXME: should we rollback to the initial state of repo? Uncomment Dump to preview.
      # Dump
    End
  End

  # Test helper functions
  Describe 'Help:'
    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    It 'should correctly show --help message'
      When run ./install.e-bash.sh --help

      The status should be success
      The result of function no_colors_output should include "install.e-bash.sh [options] [command] [version]"
      The result of function no_colors_error should include "exit code: 0"
    End

    It 'should correctly show help message'
      When run ./install.e-bash.sh help

      The status should be success
      The output should include "Usage:"
      The result of function no_colors_error should include "detected: we are in a regular folder."
    End
  End

  # Test global installation of e-bash scripts
  Describe 'Global Install:'
    setup_temp_home() {
      # Create a temporary directory to act as HOME
      TEMP_HOME="$TEST_DIR/temp_home"
      mkdir -p "$TEMP_HOME"

      # Backup the real HOME
      REAL_HOME="$HOME"

      # Override HOME for testing
      export HOME="$TEMP_HOME"
    }

    restore_real_home() {
      # Restore the real HOME
      export HOME="$REAL_HOME"

      # Clean up temporary home
      rm -rf "$TEMP_HOME"
    }

    Before 'temp_repo; setup_temp_home; cp_install'
    After 'restore_real_home; cleanup_temp_repo'

    It 'should install e-bash scripts globally to HOME directory'
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install --global

      The status should be success
      The output should include "Installation complete!"
      The output should include "e-Bash scripts installed globally to"
      The error should be present # logs output

      The dir "$TEMP_HOME/.e-bash" should be present
      The dir "$TEMP_HOME/.e-bash/.scripts" should be present
      The file "$TEMP_HOME/.e-bash/.scripts/_colors.sh" should be present

      # Dump
    End

    It 'should install specific version globally'
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install v1.0.0 --global

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output

      The dir "$TEMP_HOME/.e-bash" should be present
      The file "$TEMP_HOME/.e-bash/.scripts/_colors.sh" should be present

      # Dump
    End

    It 'should update shell configuration files'
      touch "$TEMP_HOME/.${SHELL##*/}rc"

      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install --global

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output

      The file "$TEMP_HOME/.${SHELL##*/}rc" should be present
      The contents of file "$TEMP_HOME/.${SHELL##*/}rc" should include "export E_BASH"

      # Dump
    End

    It 'should export correct E_BASH path for master version in shell rc'
      touch "$TEMP_HOME/.${SHELL##*/}rc"

      # Install master (default version)
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install --global

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output

      The file "$TEMP_HOME/.${SHELL##*/}rc" should be present
      # For master version, path should be ${HOME}/.e-bash/.scripts
      The contents of file "$TEMP_HOME/.${SHELL##*/}rc" should include 'export E_BASH="${HOME}/.e-bash/.scripts"'
      # Should NOT include .versions/master in the path
      The contents of file "$TEMP_HOME/.${SHELL##*/}rc" should not include '.versions/master'

      # Dump
    End

    It 'should export versioned E_BASH path for tagged version in shell rc'
      touch "$TEMP_HOME/.${SHELL##*/}rc"

      # Install specific version
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install v1.0.0 --global

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output

      The file "$TEMP_HOME/.${SHELL##*/}rc" should be present
      # For tagged version, path should include .versions/{version}
      The contents of file "$TEMP_HOME/.${SHELL##*/}rc" should include 'export E_BASH="${HOME}/.e-bash/.versions/v1.0.0/.scripts"'

      # Dump
    End

    It 'should support NO symlink creation with --no-create-symlink option'
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install --global --no-create-symlink

      The status should be success
      The output should include "Installation complete!"
      The error should be present # logs output

      The dir "$TEMP_HOME/.e-bash" should be present

      The path "$TEST_DIR/.scripts" should not be exist

      # Dump
    End

    It 'should detect broken .scripts symlink'
      # Create a broken symlink
      rm -rf "$TEST_DIR/.scripts"
      ln -s "$TEST_DIR/.scripts-broken" "$TEST_DIR/.scripts"

      # Run the script, should fail since the .scripts symlink is broken
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh --global

      The status should be success
      The output should include "Installation complete!"
      The result of function no_colors_error should include "detected: broken symlink: .scripts ->"
      The stderr should be present

      # Dump
    End

    It 'should install globally and bind to current repo'
      # First install
      mkdir -p "$TEMP_HOME/repo" && cd "$TEMP_HOME/repo" || return 1
      git_init
      git_master_to_main
      cp_install

      # run from REPO directory
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh --global upgrade v1.0.1-alpha.1

      The status should be success
      The result of function no_colors_output should include "e-bash scripts not installed. Installing instead."
      The output should include "Installation complete!"
      The output should include "$TEMP_HOME/.e-bash"
      The result of function no_colors_output should include "Symlink created: .scripts ->"
      The result of function no_colors_output should include "tmprepo/temp_home/.e-bash/.versions/v1.0.1-alpha.1/.scripts"

      # Dump
    End

    It 'should upgrade repo binding to the latest version'
      # First install
      mkdir -p "$TEMP_HOME/repo" && cd "$TEMP_HOME/repo" || return 1
      git_init
      git_master_to_main
      cp_install
      upgrade_global_version

      # upgrade from v1.0.1-alpha.1 to master
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh upgrade --global

      The status should be success
      The result of function no_colors_output should include "Skipping worktree creation for master branch"
      The result of function no_colors_output should include "Global e-bash upgrade complete!"
      The result of function no_colors_output should include "The e-bash scripts have been upgraded to version master"
      The result of function no_colors_output should include "Symlink created: .scripts ->"
      The result of function no_colors_output should include "tmprepo/temp_home/.e-bash/.scripts"

      # Dump
    End

    It 'should downgrade repo to another version'
      # First install
      mkdir -p "$TEMP_HOME/repo" && cd "$TEMP_HOME/repo" || return 1
      git_init
      git_master_to_main
      cp_install
      # install latest/master
      upgrade_global

      # version 1.0.0
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh upgrade v1.0.0 --global

      The status should be success
      The result of function no_colors_output should include "Global e-bash upgrade complete!"
      The result of function no_colors_output should include "tmprepo/temp_home/.e-bash/.versions/v1.0.0/.scripts"
      The result of function no_colors_output should include "The e-bash scripts have been upgraded to version v1.0.0"

      # Dump
    End

    Describe 'Global Rollback:'
      It 'should rollback from master to previous version'
        # Setup: Install v1.0.0, then upgrade to master
        mkdir -p "$TEMP_HOME/repo" && cd "$TEMP_HOME/repo" || return 1
        git_init
        git_master_to_main
        cp_install

        # Install v1.0.0 with symlink
        env HOME="$TEMP_HOME" ./install.e-bash.sh install v1.0.0 --global 2>/dev/null >/dev/null

        # Upgrade to master
        env HOME="$TEMP_HOME" ./install.e-bash.sh upgrade master --global 2>/dev/null >/dev/null

        # Rollback should go back to v1.0.0
        When run env HOME="$TEMP_HOME" ./install.e-bash.sh rollback v1.0.0 --global

        The status should be success
        The output should include "Rollback complete"
        # Symlink should point back to v1.0.0
        The result of function no_colors_output should include ".versions/v1.0.0/.scripts"
      End

      It 'should rollback from versioned to master'
        # Setup: Install master, then upgrade to v1.0.0
        mkdir -p "$TEMP_HOME/repo2" && cd "$TEMP_HOME/repo2" || return 1
        git_init
        git_master_to_main
        cp_install

        env HOME="$TEMP_HOME" ./install.e-bash.sh install master --global 2>/dev/null >/dev/null
        env HOME="$TEMP_HOME" ./install.e-bash.sh upgrade v1.0.0 --global 2>/dev/null >/dev/null

        # Rollback to master
        When run env HOME="$TEMP_HOME" ./install.e-bash.sh rollback master --global

        The status should be success
        The output should include "Rollback complete"
        # Symlink should point to master
        The result of function no_colors_output should include "/.e-bash/.scripts"
        The result of function no_colors_output should not include ".versions"
      End

      It 'should show error when global installation not found'
        mkdir -p "$TEMP_HOME/repo3" && cd "$TEMP_HOME/repo3" || return 1
        git_init
        git_master_to_main
        cp_install

        # Try rollback without global installation
        When run env HOME="$TEMP_HOME" ./install.e-bash.sh rollback master --global

        The status should be failure
        The output should include "Error: Global e-bash installation not found"
      End

      It 'should show error when version not available'
        mkdir -p "$TEMP_HOME/repo4" && cd "$TEMP_HOME/repo4" || return 1
        git_init
        git_master_to_main
        cp_install

        env HOME="$TEMP_HOME" ./install.e-bash.sh install master --global 2>/dev/null >/dev/null

        # Try to rollback to non-existent version
        When run env HOME="$TEMP_HOME" ./install.e-bash.sh rollback v99.99.99 --global

        The status should be failure
        The output should include "Error: Version v99.99.99 not found"
      End
    End
  End
End
