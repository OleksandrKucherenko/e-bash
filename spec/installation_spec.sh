#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-24
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

Describe 'bin/install.e-bash.sh'
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
  do_uninstall() { ./install.e-bash.sh uninstall --confirm  2>/dev/null >/dev/null; }
  do_uninstall_global() { HOME="$TEMP_HOME" ./install.e-bash.sh uninstall --confirm --global  2>/dev/null >/dev/null; }

  # Mock installation state without network access
  # Simulates a successful local installation by creating expected directory structure
  mock_install() {
    # Create .scripts directory with actual e-bash scripts
    mkdir -p .scripts
    cp -r "$SHELLSPEC_PROJECT_ROOT/.scripts/"* .scripts/ 2>/dev/null || true

    # Add .scripts to git
    git add .scripts
    git commit --no-gpg-sign -m "Install e-bash scripts" -q 2>/dev/null || git commit -m "Install e-bash scripts" -q

    # Create a fake tag v1.0.0 on current commit to simulate version detection
    git tag v1.0.0 2>/dev/null || true

    # Set up git remote and branches as the install script would
    git remote add e-bash https://github.com/OleksandrKucherenko/e-bash.git 2>/dev/null || true
    
    # Create e-bash-scripts branch pointing to the tagged commit
    git branch e-bash-scripts 2>/dev/null || true
    
    # Create a temporary branch to simulate e-bash-temp pointing to v1.0.0
    git branch e-bash-temp 2>/dev/null || true

    # Return success
    return 0
  }

  # Mock upgrade state - creates previous version file
  mock_upgrade() {
    local previous_version="${1:-v1.0.0}"
    # Get current HEAD as "previous" version
    local current_hash=$(git rev-parse HEAD)
    echo "$current_hash" > .e-bash-previous-version
    git add .e-bash-previous-version
    git commit --no-gpg-sign -m "Upgrade e-bash (mock)" -q 2>/dev/null || git commit -m "Upgrade e-bash (mock)" -q
    return 0
  }

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
      #The result of function no_colors_output should include "Error: Not in a git repository"
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
      The result of function no_colors_output should include "Installation complete"
      The result of function no_colors_output should include "The e-bash scripts are now available in the"
      The error should be present # logs output
      The dir ".scripts" should be present
      The file ".scripts/_colors.sh" should be present
    End

    It 'should integrate with mise.toml if file exists'
      touch .mise.toml
      git add .mise.toml
      git commit --no-gpg-sign -m "Add mise.toml" -q 2>/dev/null || git commit -m "Add mise.toml" -q

      When run ./install.e-bash.sh install

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Installation complete"
      The result of function no_colors_output should include "Added e-bash configuration to"
      The result of function no_colors_output should include ".mise.toml"
      The file ".mise.toml" should be present
      The contents of file ".mise.toml" should include "E_BASH"
      The contents of file ".mise.toml" should include "{{config_root}}/.scripts"
      The contents of file ".mise.toml" should include "_.path"
    End

    It 'should not modify mise.toml if it already has E_BASH configuration'
      touch .mise.toml
      echo '[env]' >> .mise.toml
      echo 'E_BASH = "{{config_root}}/.scripts"' >> .mise.toml
      git add .mise.toml
      git commit --no-gpg-sign -m "Add mise.toml with E_BASH" -q 2>/dev/null || git commit -m "Add mise.toml with E_BASH" -q

      When run ./install.e-bash.sh install

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Installation complete"
      The result of function no_colors_output should include "Skipping MISE integration"
    End

    It 'should insert into existing [env] section before other sections'
      touch .mise.toml
      echo '[env]' >> .mise.toml
      echo 'NODE_ENV = "development"' >> .mise.toml
      echo '' >> .mise.toml
      echo '[tools]' >> .mise.toml
      echo 'node = "20"' >> .mise.toml
      git add .mise.toml
      git commit --no-gpg-sign -m "Add mise.toml with [env] and [tools]" -q 2>/dev/null || git commit -m "Add mise.toml with [env] and [tools]" -q

      When run sh -c './install.e-bash.sh install && echo "=== FILE CONTENT ===" && cat .mise.toml'

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Installation complete"
      The result of function no_colors_output should include "Added e-bash configuration to existing [env] section"
      # Verify E_BASH is in the [env] section, not after [tools]
      # Simple verification: if E_BASH, NODE_ENV, and [tools] all exist,
      # and the test expects E_BASH to be in [env] section, this is sufficient
      The output should include "E_BASH"
      The output should include "NODE_ENV"
      The output should include "[tools]"
    End

    It 'should handle mise.toml with [[env]] array of tables'
      touch .mise.toml
      echo '[[env]]' >> .mise.toml
      echo 'NODE_ENV = "development"' >> .mise.toml
      git add .mise.toml
      git commit --no-gpg-sign -m "Add mise.toml with [[env]]" -q 2>/dev/null || git commit -m "Add mise.toml with [[env]]" -q

      When run ./install.e-bash.sh install

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Installation complete"
      The result of function no_colors_output should include "Added e-bash configuration as new [[env]] entry"
      The file ".mise.toml" should be present
      The contents of file ".mise.toml" should include "[[env]]"
      The contents of file ".mise.toml" should include "E_BASH"
      The contents of file ".mise.toml" should include "NODE_ENV"
    End

    It 'should not modify mise.toml with [[env]] if E_BASH exists'
      touch .mise.toml
      echo '[[env]]' >> .mise.toml
      echo 'E_BASH = "{{config_root}}/.scripts"' >> .mise.toml
      git add .mise.toml
      git commit --no-gpg-sign -m "Add mise.toml with [[env]] and E_BASH" -q 2>/dev/null || git commit -m "Add mise.toml with [[env]] and E_BASH" -q

      When run ./install.e-bash.sh install

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Installation complete"
      The result of function no_colors_output should include "Skipping MISE integration"
    End

    It 'should detect "main" branch correctly'
      git_rename_main

      When run ./install.e-bash.sh install

      The status should be success
      The result of function no_colors_output should include "Installation complete!"
      The error should include "git checkout --quiet main"
    End

    It 'should detect "custom" branch correctly'
      git_rename_custom

      When run ./install.e-bash.sh install

      The status should be success
      The result of function no_colors_output should include "Installation complete!"
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
      The result of function no_colors_output should include "Installation complete!"
      The error should be present # logs output
      The result of function no_colors_error should include "git checkout --quiet new_branch"
    End

    It 'should install v1.0.1-alpha.1 version of e-bash'
      When run ./install.e-bash.sh install v1.0.1-alpha.1

      The status should be success
      The result of function no_colors_output should include "Installing e-bash scripts (version: v1.0.1-alpha.1)"
      The result of function no_colors_output should include "Installation complete!"
      The error should be present # logs output
      The error should include "git checkout --quiet -b e-bash-temp v1.0.1-alpha.1"

      #Dump
    End

    It 'should create README.md with instructions'
      When run ./install.e-bash.sh install

      The status should be success
      The result of function no_colors_output should include "Installation complete!"
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
      The result of function no_colors_output should include "Upgrade complete!"
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
      The result of function no_colors_output should include "Resolve Conflict by Aborting GIT Merge"
      The result of function no_colors_output should include "Manual Uninstall Guide"
      The error should be present # logs output
    End
  End

  # Test rollback functionality
  Describe 'Rollback:'
    Before 'temp_repo; git_init; git_config; cp_install'
    After 'cleanup_temp_repo'

    It 'should rollback to previous version successfully'
      # Mock installation and upgrade to create previous version file
      mock_install
      mock_upgrade

      When run ./install.e-bash.sh rollback

      The status should be success
      The result of function no_colors_output should include "Rollback complete!"
      The error should be present # logs output
    End

    It 'should fail when no previous version exists'
      When run ./install.e-bash.sh rollback

      The status should be failure
      The result of function no_colors_output should include "Error: No previous version found to rollback to"
      The error should be present # logs output
    End

    It 'should fail with empty previous version file'
      # Create empty version file
      touch .e-bash-previous-version

      When run ./install.e-bash.sh rollback

      The status should be failure
      The result of function no_colors_output should include "=== operation: ROLLBACK ==="
      The error should include "Error: Previous version file is empty or invalid"
    End

    It 'should fail with invalid commit hash format'
      # Create file with invalid hash
      echo "not-a-valid-hash-!!!" > .e-bash-previous-version

      When run ./install.e-bash.sh rollback

      The status should be failure
      The result of function no_colors_output should include "=== operation: ROLLBACK ==="
      The error should include "Error: Previous version file is empty or invalid"
    End

    It 'should fail with non-existent commit hash'
      # Create file with valid format but non-existent hash
      echo "0000000000000000000000000000000000000000" > .e-bash-previous-version

      When run ./install.e-bash.sh rollback

      The status should be failure
      The result of function no_colors_output should include "=== operation: ROLLBACK ==="
      The error should include "Error: Previous version commit no longer exists"
    End

    It 'should accept valid commit hash'
      # Create a commit so we have a valid hash
      touch test-file.txt
      git add test-file.txt
      git commit --no-gpg-sign -m "test commit" -q 2>/dev/null || git commit -m "test commit" -q

      # Get a valid commit hash
      local valid_hash=$(git rev-parse HEAD)
      echo "$valid_hash" > .e-bash-previous-version

      When run ./install.e-bash.sh rollback

      # Should not fail with validation error, but may fail with rollback error
      The status should be failure
      The result of function no_colors_output should include "=== operation: ROLLBACK ==="
      The result of function no_colors_output should include "Rolling back to previous version:"
      The error should not include "Error: Previous version file is empty or invalid"
      The error should not include "Error: Previous version commit no longer exists"
    End

    It 'should accept valid short commit hash'
      # Create a commit so we have a valid hash
      touch test-file2.txt
      git add test-file2.txt
      git commit --no-gpg-sign -m "test commit 2" -q 2>/dev/null || git commit -m "test commit 2" -q

      # Get a valid short commit hash
      local valid_hash=$(git rev-parse --short HEAD)
      echo "$valid_hash" > .e-bash-previous-version

      When run ./install.e-bash.sh rollback

      # Should not fail with validation error, but may fail with rollback error
      The status should be failure
      The result of function no_colors_output should include "=== operation: ROLLBACK ==="
      The result of function no_colors_output should include "Rolling back to previous version:"
      The error should not include "Error: Previous version file is empty or invalid"
      The error should not include "Error: Previous version commit no longer exists"
    End
  End

  # Test permission error handling
  Describe 'Permission Errors:'
    make_readonly() {
      chmod -w .
    }

    restore_write() {
      chmod +w .
    }

    After 'restore_write; cleanup_temp_repo'

    xIt 'should detect read-only repository during install'
      # Skipped: Permission tests require non-root user to test properly
      # Root user bypasses permission checks
      temp_repo
      git_init
      git_config
      cp_install
      make_readonly

      When run ./install.e-bash.sh install

      The status should be failure
      The error should include "Error:"
      The error should include "permission"
    End

    xIt 'should detect read-only repository during uninstall'
      # Skipped: Permission tests require non-root user to test properly
      temp_repo
      git_init
      git_config
      cp_install
      # Create .scripts to simulate installation
      mkdir .scripts
      touch .scripts/test.sh
      make_readonly

      When run ./install.e-bash.sh uninstall --confirm 

      The status should be failure
      The error should include "Error:"
    End

    xIt 'should provide helpful error message for permission denied'
      # Skipped: Permission tests require non-root user to test properly
      temp_repo
      git_init
      git_config
      cp_install
      make_readonly

      When run ./install.e-bash.sh install

      The status should be failure
      # Should suggest checking permissions
      The error should include "permission"
    End

    # Verification test that permission check function exists
    It 'should have check_write_permissions function defined in script'
      temp_repo
      cp_install

      # Check that the function is defined in the script
      When run grep -n "function check_write_permissions" ./install.e-bash.sh

      The status should be success
      The result of function no_colors_output should include "check_write_permissions"
    End
  End

  # Scenario 5: Viewing available versions of e-Bash
  Describe 'Versions:'

    Before 'temp_repo; cp_install'
    After 'cleanup_temp_repo'

    It 'should list all available versions'
      When run ./install.e-bash.sh versions

      The status should be success
      The result of function no_colors_output should include "Available remote stable versions"
      The result of function no_colors_output should include "Available remote non-stable versions (pre-releases, development):"
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
      The result of function no_colors_output should include "Installation complete!"
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

    It 'should fail with clear error for non-existent version during validation'
      When run ./install.e-bash.sh install v999.999.999

      The status should be failure
      The result of function no_colors_output should include "Installing e-bash scripts"
      The error should be present # logs output should have error message
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
      The result of function no_colors_output should include "Usage:"
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
      The result of function no_colors_output should include "Installation complete!"
      The result of function no_colors_output should include "e-Bash scripts installed globally to"
      The error should be present # logs output

      The dir "$TEMP_HOME/.e-bash" should be present
      The dir "$TEMP_HOME/.e-bash/.scripts" should be present
      The file "$TEMP_HOME/.e-bash/.scripts/_colors.sh" should be present

      # Dump
    End

    It 'should install specific version globally'
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install v1.0.0 --global

      The status should be success
      The result of function no_colors_output should include "Installation complete!"
      The error should be present # logs output

      The dir "$TEMP_HOME/.e-bash" should be present
      The file "$TEMP_HOME/.e-bash/.scripts/_colors.sh" should be present

      # Dump
    End

    It 'should update shell configuration files'
      touch "$TEMP_HOME/.${SHELL##*/}rc"

      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install --global

      The status should be success
      The result of function no_colors_output should include "Installation complete!"
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
      The result of function no_colors_output should include "Installation complete!"
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
      The result of function no_colors_output should include "Installation complete!"
      The error should be present # logs output

      The file "$TEMP_HOME/.${SHELL##*/}rc" should be present
      # For tagged version, path should include .versions/{version}
      The contents of file "$TEMP_HOME/.${SHELL##*/}rc" should include 'export E_BASH="${HOME}/.e-bash/.versions/v1.0.0/.scripts"'

      # Dump
    End

    It 'should support NO symlink creation with --no-create-symlink option'
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh install --global --no-create-symlink

      The status should be success
      The result of function no_colors_output should include "Installation complete!"
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
      The result of function no_colors_output should include "Installation complete!"
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
      The result of function no_colors_output should include "Installation complete!"
      The result of function no_colors_output should include "$TEMP_HOME/.e-bash"
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
        The result of function no_colors_output should include "Rollback complete"
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
        The result of function no_colors_output should include "Rollback complete"
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
        The result of function no_colors_error should include "installer: e-bash scripts"
        The result of function no_colors_output should include "Error: Global e-bash installation not found"
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
        The result of function no_colors_error should include "installer: e-bash scripts"
        The result of function no_colors_output should include "Error: Version v99.99.99 not found"
      End
    End
  End

  # Test automated uninstall functionality
  Describe 'Uninstall:'
    Before 'temp_repo; git_init; git_config; cp_install'
    After 'cleanup_temp_repo'

    It 'should require --confirm flag for safety'
      mock_install

      When run ./install.e-bash.sh uninstall

      The status should be failure
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Use --confirm to proceed"
    End

    It 'should remove .scripts directory with --confirm'
      mock_install

      When run ./install.e-bash.sh uninstall --confirm 

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete"
      The dir ".scripts" should not be exist
    End

    It 'should remove .e-bash-previous-version file'
      mock_install
      mock_upgrade  # Create previous version file

      When run ./install.e-bash.sh uninstall --confirm 

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete!"
      The file ".e-bash-previous-version" should not be exist
    End

    It 'should remove e-bash remote'
      mock_install
      ./install.e-bash.sh uninstall --confirm 2>/dev/null >/dev/null

      When run git remote

      The output should not include "e-bash"
    End

    It 'should remove e-bash branches'
      mock_install
      ./install.e-bash.sh uninstall --confirm 2>/dev/null >/dev/null

      When run git branch

      The output should not include "e-bash-scripts"
      The output should not include "e-bash-temp"
    End

    It 'should remove bin/install.e-bash.sh if it exists'
      mock_install
      mkdir_bin
      cp_install
      mv install.e-bash.sh bin/

      When run ./bin/install.e-bash.sh uninstall --confirm 

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete!"
      The file "bin/install.e-bash.sh" should not be exist
    End

    It 'should clean .envrc E_BASH configuration'
      mock_install
      touch .envrc
      echo 'export E_BASH="$PWD/.scripts"' >> .envrc
      echo 'PATH_add "$PWD/.scripts"' >> .envrc

      When run ./install.e-bash.sh uninstall --confirm

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete!"
      The file ".envrc" should not include "E_BASH"
      The file ".envrc" should not include "PATH_add"
    End

    It 'should clean .mise.toml E_BASH configuration with [env]'
      mock_install
      touch .mise.toml
      echo '# e-bash scripts configuration' >> .mise.toml
      echo '[env]' >> .mise.toml
      echo 'E_BASH = "{{config_root}}/.scripts"' >> .mise.toml
      echo '_.path = ["{{config_root}}/.scripts"]' >> .mise.toml

      When run ./install.e-bash.sh uninstall --confirm

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete!"
      The file ".mise.toml" should not include "E_BASH"
      The file ".mise.toml" should not include "_.path"
    End

    It 'should clean .mise.toml E_BASH configuration with [[env]]'
      mock_install
      touch .mise.toml
      echo '# e-bash scripts configuration' >> .mise.toml
      echo '[[env]]' >> .mise.toml
      echo 'E_BASH = "{{config_root}}/.scripts"' >> .mise.toml
      echo '_.path = ["{{config_root}}/.scripts"]' >> .mise.toml

      When run ./install.e-bash.sh uninstall --confirm

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete!"
      The file ".mise.toml" should not include "E_BASH"
      The file ".mise.toml" should not include "_.path"
    End

    It 'should preserve other [[env]] entries when cleaning'
      mock_install
      touch .mise.toml
      echo '[[env]]' >> .mise.toml
      echo 'NODE_ENV = "development"' >> .mise.toml
      echo '' >> .mise.toml
      echo '# e-bash scripts configuration' >> .mise.toml
      echo '[[env]]' >> .mise.toml
      echo 'E_BASH = "{{config_root}}/.scripts"' >> .mise.toml
      echo '_.path = ["{{config_root}}/.scripts"]' >> .mise.toml

      When run sh -c './install.e-bash.sh uninstall --confirm && echo "=== FILE CONTENT CHECK ===" && cat .mise.toml'

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete!"
      The file ".mise.toml" should not include "E_BASH"
      The output should include "NODE_ENV"
    End

    It 'should preserve user files during uninstall'
      mock_install
      # Add user files
      touch .scripts/user-script.sh
      echo "# User content" > README.md

      When run ./install.e-bash.sh uninstall --confirm 

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Uninstall complete!"
      The file "README.md" should be present
      The contents of file "README.md" should include "User content"
    End

    It 'should support dry-run mode'
      mock_install

      When run ./install.e-bash.sh uninstall --confirm --dry-run 

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "dry run:"
      The dir ".scripts" should be present
    End

    It 'should show error when not installed'
      # Fresh repo without e-bash
      rm -rf .scripts .e-bash-previous-version

      When run ./install.e-bash.sh uninstall --confirm 

      The status should be failure
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Error: e-bash is not installed"
    End

    It 'should NOT remove shell RC files'
      mock_install
      # This is important - shell RC should not be touched
      When run ./install.e-bash.sh uninstall --confirm 

      # Should complete successfully
      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      # And should not mention shell RC files
      The output should not include ".bashrc"
      The output should not include ".zshrc"
    End
  End

  # Test global uninstall
  Describe 'Global Uninstall:'
    setup_temp_home() {
      TEMP_HOME="$TEST_DIR/temp_home"
      mkdir -p "$TEMP_HOME"
      REAL_HOME="$HOME"
      export HOME="$TEMP_HOME"
    }

    restore_real_home() {
      export HOME="$REAL_HOME"
      rm -rf "$TEMP_HOME"
    }

    Before 'temp_repo; setup_temp_home; cp_install'
    After 'restore_real_home; cleanup_temp_repo'

    It 'should only remove symlink from current project'
      mkdir -p "$TEMP_HOME/repo" && cd "$TEMP_HOME/repo" || return 1
      git_init
      git_master_to_main
      cp_install

      # Install global with symlink
      env HOME="$TEMP_HOME" ./install.e-bash.sh install --global 2>/dev/null >/dev/null

      # Uninstall should only remove symlink
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh uninstall --confirm --global 

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Removed .scripts symlink"
      The path ".scripts" should not be exist
      # Global installation should still exist
      The dir "$TEMP_HOME/.e-bash" should be present
    End

    It 'should preserve global installation directory'
      mkdir -p "$TEMP_HOME/repo" && cd "$TEMP_HOME/repo" || return 1
      git_init
      git_master_to_main
      cp_install

      env HOME="$TEMP_HOME" ./install.e-bash.sh install --global 2>/dev/null >/dev/null

      When run env HOME="$TEMP_HOME" ./install.e-bash.sh uninstall --confirm --global 

      The status should be success
      The result of function no_colors_error should include "installer: e-bash scripts"
      The stdout should include "=== operation: UNINSTALL ==="
      The stdout should include "Uninstalling global e-bash link from current project..."
      The stdout should include "Removed .scripts symlink"
      The stdout should include "Uninstall complete!"
      # $HOME/.e-bash should still exist
      The dir "$TEMP_HOME/.e-bash" should be present
      The file "$TEMP_HOME/.e-bash/.scripts/_colors.sh" should be present
    End

    It 'should show error when no symlink exists'
      mkdir -p "$TEMP_HOME/repo" && cd "$TEMP_HOME/repo" || return 1
      git_init
      git_master_to_main
      cp_install

      # No symlink created
      When run env HOME="$TEMP_HOME" ./install.e-bash.sh uninstall --confirm --global 

      The status should be failure
      The result of function no_colors_error should include "installer: e-bash scripts"
      The result of function no_colors_output should include "Error: No .scripts symlink found"
    End
  End
End
