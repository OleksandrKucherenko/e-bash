#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-05-27
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# shellcheck disable=SC2288
% TEST_DIR: "$SHELLSPEC_TMPBASE/tmprepo"

#
# TDD:
#  watchman-make -p 'spec/version-up_spec.sh' 'bin/*.sh' --run "clear && shellspec --no-kcov --focus spec/version-up_spec.sh -- "
#

# Path to the version-up script
VERSION_UP_SCRIPT="./version-up.v2.sh"
ROOT_SCRIPT="$SHELLSPEC_PROJECT_ROOT/bin/version-up.v2.sh"

# keep it in focus mode `fDescribe` or `fIt` for TDD
Describe 'bin/version-up.v2.sh /'
  #region Helper Functions
  # Define a helper function to strip ANSI escape sequences
  # $1 = stdout, $2 = stderr, $3 = exit status of the command
  no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
  no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

  mk_repo() {
    mkdir -p "$TEST_DIR" || true
    cd "$TEST_DIR" || exit 1
  }
  git_init() { git init -q; }
  git_config_user() { git config --local user.name "Test User"; }
  git_config_email() { git config --local user.email "test@example.com"; }
  git_config() { git_config_user && git_config_email; }
  ln_script() { ln -s "$ROOT_SCRIPT" "$VERSION_UP_SCRIPT"; }
  rm_repo() { rm -rf "$TEST_DIR"; }
  git_first_commit() { (git add . && git commit -m "Initial commit"); }
  git_next_commit() { (git add . && git commit -m "Next commit${1:-" $(date)"}"); }
  git_create_tag() { git tag "$1"; }
  random_change() { date >>random.txt; }
  #endregion

  Before 'mk_repo; git_init; git_config; ln_script'
  After 'rm_repo'

  # test-000
  It 'test-000: displays usage/help information and exits with 0'
    BeforeRun 'export DEBUG="ver"'
    When run bash "$VERSION_UP_SCRIPT" --help

    The status should be success
    The stderr should be present

    The result of function no_colors_stdout should include "Usage:"
    The result of function no_colors_stdout should include "Notes:"
    The result of function no_colors_stdout should include "Version: [PREFIX]MAJOR.MINOR.PATCH[-STAGE][+REVISION]"
    The result of function no_colors_stdout should include "Reference:"
    The result of function no_colors_stdout should include "Versions priority:"

    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # test-001
  It 'test-001: displays script version and exits with 0'
    BeforeRun 'export DEBUG="ver"'
    When run bash "$VERSION_UP_SCRIPT" --version

    The status should be success
    The stdout should be present

    The result of function no_colors_stdout should include "version: 2.0.0"
    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # test-002
  It 'test-002: should detect empty git repository'
    BeforeRun 'export DEBUG="ver"; unset TRACE'
    # We're already in a fresh git repo thanks to the Before hook
    # which runs: mk_repo; git_init; git_config; ln_script
    When run bash "$VERSION_UP_SCRIPT"

    The status should be success
    The stdout should be present

    The result of function no_colors_stdout should include "Empty repository without commits. Nothing to do."
    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # test-002-1
  It 'test-002: proposes version 0.0.1-alpha in a fresh git repository'
    # CI mode, prevent user input asking
    BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

    # And one commit exists
    git_first_commit >/dev/null 2>&1

    When run bash "$VERSION_UP_SCRIPT"

    The status should be success
    The stdout should be present

    The result of function no_colors_stdout should include "git tag 0.1.0-alpha"
    The result of function no_colors_stdout should include "git push origin 0.1.0-alpha"
    The result of function no_colors_stderr should include "Selected versioning strategy: increment MINOR of the latest 0.0.1-alpha"
    The result of function no_colors_stderr should include "Proposed Next Version TAG: 0.1.0-alpha"
    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # test-003: Propose next release version tag
  # Gherkin Scenario Outline: Propose next release version tag
  Describe "test-003: version scenarios /"
    Parameters
      # id | init_tag | flag | expected_version
      "#0" "v1.2.3" "" "v1.3.0"
      "#1" "v1.2.3" "--default" "v1.2.4"
      "#2" "v1.2.3" "--major" "v2.0.0"
      "#3" "v1.2.3" "--minor" "v1.3.0"
      "#4" "v1.2.3" "--patch" "v1.2.4"
      "#5" "v1.2.3" "--alpha" "v1.2.3-alpha"
      "#6" "v1.2.3" "--beta" "v1.2.3-beta"
      "#7" "v1.2.3" "--rc" "v1.2.3-rc"
      "#8" "v1.2.3" "--revision" "v1.2.3+1"
      # "#9" "v1.2.3" "--stay" "v1.2.3"
    End

    It "should be proposed '$4' from tag '$2' after '$3' flag"
      # CI mode to prevent interactive prompts
      BeforeRun "export DEBUG=\"ver\"; export CI=1; unset TRACE"

      # Create an initial commit and tag
      git_first_commit >/dev/null 2>&1
      git_create_tag "$2"
      random_change
      git_next_commit >/dev/null 2>&1

      # Run the script with the provided flag
      When run bash "$VERSION_UP_SCRIPT" "$3"

      The status should be success
      The stdout should be present

      # Verify the correct version is proposed
      The result of function no_colors_stdout should include "git tag $4"
      The result of function no_colors_stdout should include "git push origin $4"
      The result of function no_colors_stderr should include "Selected versioning strategy: "
      The result of function no_colors_stderr should include "Proposed Next Version TAG: $4"

      # Verify prefix detection
      The result of function no_colors_stderr should include "Auto-detected prefix: v from tags: $2"
      The result of function no_colors_stderr should include "Prefix detected: v"

      # Exit code should be 0
      The result of function no_colors_stderr should include "exit code: 0"

      # cat version.properties
      # Dump
    End
  End

  Describe "forced stay on the same version tag /"
    # test-003: --stay part
    It "test-003: should reuse version when on a MASTER branch"
      # CI mode, prevent user input asking
      BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

      # Create initial commit and tag
      git_first_commit >/dev/null 2>&1
      git_create_tag "v2.0.0"

      When run bash "$VERSION_UP_SCRIPT"

      The status should be success
      The stdout should be present

      # Verify it suggests reusing the same version
      The result of function no_colors_stdout should include "Tag v2.0.0 and HEAD are aligned. We will stay on the TAG version."

      # Exit code should be 0
      The result of function no_colors_stderr should include "exit code: 0"

      # Dump
    End

    It "test-003: forced stay strategy on a MASTER branch"
      # CI mode, prevent user input asking
      BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

      # Create initial commit and tag
      git_first_commit >/dev/null 2>&1
      git_create_tag "v2.0.0"
      random_change
      git_next_commit >/dev/null 2>&1

      When run bash "$VERSION_UP_SCRIPT" --stay

      The status should be success
      The stdout should be present

      The result of function no_colors_stdout should include "File version.properties is successfully created."
      The result of function no_colors_stderr should include "Selected versioning strategy: stay on the same version"
      The result of function no_colors_stderr should include "Version tags detected: v2.0.0"
      The result of function no_colors_stderr should include "Proposed Next Version TAG: v2.0.0"

      # Exit code should be 0
      The result of function no_colors_stderr should include "exit code: 0"

      # Dump
    End

    # test-004: Re-publish existing version tag
    It 'test-004: should reuse version when on a branch named after that version tag'
      # CI mode, prevent user input asking
      BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

      # Create initial commit and tag
      git_first_commit >/dev/null 2>&1
      git_create_tag "v2.0.0"

      # Create and checkout a branch with the same name as the tag
      git checkout -b "v2.0.0-hotfix" v2.0.0 >/dev/null 2>&1

      When run bash "$VERSION_UP_SCRIPT"

      The status should be success
      The stdout should be present

      # Verify it suggests reusing the same version
      The result of function no_colors_stdout should include "Tag v2.0.0 and HEAD are aligned. We will stay on the TAG version."

      # Check detection messages
      The result of function no_colors_stderr should include "Latest repo tag: v2.0.0"
      The result of function no_colors_stderr should include "Auto-detected prefix: v from tags: v2.0.0"
      The result of function no_colors_stderr should include "Selected versioning strategy: stay on the same version"

      # Exit code should be 0
      The result of function no_colors_stderr should include "exit code: 0"

      # Dump
    End
  End

  # test-005: Propose revision segment increase on branched version tag
  It 'test-005: should propose REVISION segment increase when on a branch from a version tag'
    # CI mode, prevent user input asking
    BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

    # Create two tags v1.1.0+10 and v1.2.0
    {
      git_first_commit
      git_create_tag "v1.1.0+10"
      random_change
      git_next_commit
      git_create_tag "v1.2.0"

      # Create and checkout a branch from v1.1.0
      git checkout -b "hotfix-v1.1.0" "v1.1.0+10"

      # Add a commit to the branch
      random_change
      git_next_commit ": hotfix applied"
    } >/dev/null 2>&1

    When run bash "$VERSION_UP_SCRIPT"

    The status should be success
    The stdout should be present

    # Verify the correct version is proposed
    The result of function no_colors_stdout should include "git tag v1.1.0+11"
    The result of function no_colors_stdout should include "git push origin v1.1.0+11"

    # Check detection messages
    The result of function no_colors_stderr should include "Selected versioning strategy: increment last version PART of hotfix-v1.1.0"
    The result of function no_colors_stderr should include "Selected versioning strategy: forced REVISION increment."
    The result of function no_colors_stderr should include "Proposed Next Version TAG: v1.1.0+11"
    The result of function no_colors_stderr should include "Auto-detected prefix: v from tags: v1.1.0+10"

    # Exit code should be 0
    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # test-005-1: Propose patch segment increase on branched version tag
  It 'test-005: should propose PATCH segment increase when on a branch from a version tag'
    # CI mode, prevent user input asking
    BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

    # Create two tags v1.1.1 and v1.2.0
    {
      git_first_commit
      git_create_tag "v1.1.1" # important: last segment should not be zero
      random_change
      git_next_commit
      git_create_tag "v1.2.0"

      # Create and checkout a branch from v1.1.1
      git checkout -b "hotfix-v1.1.1" "v1.1.1"

      # Add a commit to the branch
      random_change
      git_next_commit ": hotfix applied"
    } >/dev/null 2>&1

    When run bash "$VERSION_UP_SCRIPT"

    The status should be success
    The stdout should be present

    # Verify the correct version is proposed
    The result of function no_colors_stdout should include "git tag v1.1.2"
    The result of function no_colors_stdout should include "git push origin v1.1.2"

    # Check detection messages - using robust ANSI escape sequence handling
    The result of function no_colors_stderr should include "Starting './version-up.v2.sh ' process"
    The result of function no_colors_stderr should include "Selected versioning strategy: forced PATCH increment"
    The result of function no_colors_stderr should include "Proposed Next Version TAG: v1.1.2"
    The result of function no_colors_stderr should include "Auto-detected prefix: v from tags"

    # Exit code should be 0
    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # test-005-2: Propose last segment increase on branched version tag
  It 'test-005: should propose PATCH increase with stage keeping'
    # CI mode, prevent user input asking
    BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

    # Create two tags v1.1.1-rc.1 and v1.2.0
    {
      git_first_commit
      git_create_tag "v1.1.1-rc.1" # important: last segment should not be zero
      random_change
      git_next_commit
      git_create_tag "v1.2.0"

      # Create and checkout a branch from v1.1.0
      git checkout -b "hotfix-v1.1.1-rc.1" "v1.1.1-rc.1"

      # Add a commit to the branch
      random_change
      git_next_commit ": hotfix applied"
    } >/dev/null 2>&1

    When run bash "$VERSION_UP_SCRIPT"

    The status should be success
    The stdout should be present

    # Verify the correct version is proposed
    The result of function no_colors_stdout should include "git tag v1.1.2-rc.1"
    The result of function no_colors_stdout should include "git push origin v1.1.2-rc.1"

    # Check detection messages
    The result of function no_colors_stderr should include "Selected versioning strategy: increment last version PART of hotfix-v1.1.1-rc.1"
    The result of function no_colors_stderr should include "Proposed Next Version TAG: v1.1.2-rc.1"
    # Check that both tags are detected (order may vary by platform)
    The result of function no_colors_stderr should include "Auto-detected prefix: v from tags:"
    The result of function no_colors_stderr should include "v1.1.1-rc.1"
    The result of function no_colors_stderr should include "v1.2.0"

    # Exit code should be 0
    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # Monorepo test scenarios
  Describe "monorepo version detection /"
    #region Helper functions for monorepo tests
    package_commit() {
      local package="$1"
      local comment="$2"

      mkdir -p "packages/$package"
      (cd "packages/$package" && touch file.txt && date >>file.txt)
      git add "packages/$package"
      git commit -m "packages/$package: $comment" >/dev/null 2>&1
    }

    package_versioned_change() {
      local package="$1"
      local comment="$2"
      local tag="$3"

      package_commit "$package" "$comment"
      git tag "packages/$package/$tag"
    }

    setup_monorepo() {
      # Create subdirectories for packages
      mkdir -p packages/foo packages/bar

      # Initialize git in the monorepo
      git_init
      git_config

      # Create initial commit
      git_first_commit

      # Add commits to packages/foo
      package_versioned_change "foo" "initial commit" "v1.0.0"

      # Add commits to packages/bar
      package_versioned_change "bar" "initial commit" "v1.1.0"
    }

    git_foo_commit() { package_commit "foo" "new commit"; }
    git_bar_commit() { package_commit "bar" "new commit"; }
    #endregion

    # test-020: Monorepo default prefix detection
    It "test-020: should auto-detect prefix in monorepo structure"
      # CI mode, prevent user input asking
      BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

      # Set up monorepo with packages/foo and packages/bar
      # with tags packages/foo/v1.0.0 and packages/bar/v1.1.0
      {
        setup_monorepo

        # make a change to the code for a new version proposal
        git_foo_commit
      } >/dev/null 2>&1

      # Set working directory to packages/foo
      cd packages/foo || return 1

      When run bash "../../version-up.v2.sh"

      The status should be success
      The stdout should be present

      # Verify prefix detection and version proposal
      The result of function no_colors_stderr should include "Auto-detected prefix: packages/foo/v from tags: packages/bar/v1.1.0, packages/foo/v1.0.0"
      The result of function no_colors_stderr should include "Prefix detected: packages/foo/v"
      The result of function no_colors_stderr should include "Selected versioning strategy: increment MINOR of the latest packages/foo/v1.0.0"
      The result of function no_colors_stderr should include "Proposed Next Version TAG: packages/foo/v1.1.0"
      The result of function no_colors_stdout should include "git tag packages/foo/v1.1.0"
      The result of function no_colors_stdout should include "git push origin packages/foo/v1.1.0"

      # Exit code should be 0
      The result of function no_colors_stderr should include "exit code: 0"

      # Dump
    End

    # test-021: Monorepo root prefix strategy
    It "test-021: should use root prefix strategy in monorepo structure"
      # CI mode, prevent user input asking
      BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

      # Set up a monorepo with tags v1.0.0 at root and packages/foo/v2.0.0
      {
        # Initialize git repo
        git_init
        git_config

        # Create initial commit at root level
        git_first_commit
        git tag "v1.0.0"

        # Create packages/foo directory and add commits
        package_versioned_change "foo" "initial commit" "v2.0.0"

        # make a change to the code for a new version proposal
        random_change
        git add .
        git commit -m "Root level change" >/dev/null 2>&1
      } >/dev/null 2>&1

      # Set working directory to packages/foo
      cd packages/foo || return 1

      When run bash "../../version-up.v2.sh" --prefix root

      The status should be success
      The stdout should be present

      # Verify root prefix detection and version proposal
      The result of function no_colors_stderr should include "Auto-detected prefix: v from tags: packages/foo/v2.0.0, v1.0.0"
      The result of function no_colors_stderr should include "Prefix detected: v"
      The result of function no_colors_stderr should include "Selected versioning strategy: forced MINOR increment."
      The result of function no_colors_stderr should include "Proposed Next Version TAG: v1.1.0"
      The result of function no_colors_stdout should include "git tag v1.1.0"
      The result of function no_colors_stdout should include "git push origin v1.1.0"

      # Exit code should be 0
      The result of function no_colors_stderr should include "exit code: 0"

      # Dump
    End

    # test-022: Monorepo sub-folder prefix strategy
    It "test-022: should use sub-folder prefix strategy in monorepo structure"
      BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'

      # Set up monorepo with tag packages/foo/v1.2.3
      {
        git_init
        git_config

        package_versioned_change "foo" "initial commit" "v1.2.3"

        random_change
        git add .
        git commit -m "New commit"
      } >/dev/null 2>&1

      cd packages/foo || return 1

      When run bash "../../version-up.v2.sh" --prefix sub-folder

      The status should be success
      The stdout should be present

      The result of function no_colors_stderr should include "Current prefix strategy: sub-folder:'packages/foo/'"
      The result of function no_colors_stderr should include "Prefix detected: packages/foo/v"
      The result of function no_colors_stderr should include "Selected versioning strategy: forced MINOR increment."
      The result of function no_colors_stderr should include "Proposed Next Version TAG: packages/foo/v1.3.0"
      The result of function no_colors_stderr should include "exit code: 0"

      # Dump
    End

    # Monorepo custom prefix string
    It "test-023: should use custom prefix string in monorepo structure"
      BeforeRun 'export DEBUG="ver"; export CI=1; unset TRACE'
      # Set up monorepo with tag custom/v0.9.0
      {
        git_init
        git_config

        mkdir -p somefolder
        (cd somefolder && touch file.txt && echo "content" >file.txt)
        git add somefolder
        git commit -m "initial commit" >/dev/null 2>&1
        git tag "custom/v0.9.0"

        random_change
        git add .
        git commit -m "New commit" >/dev/null 2>&1
      } >/dev/null 2>&1

      When run bash "./version-up.v2.sh" --prefix custom

      The status should be success
      The stdout should be present

      The result of function no_colors_stderr should include "Current prefix strategy: custom:'custom'"
      The result of function no_colors_stderr should include "Prefix detected: custom/v"
      The result of function no_colors_stderr should include "Selected versioning strategy: forced MINOR increment."
      The result of function no_colors_stderr should include "Proposed Next Version TAG: custom/v0.10.0"
      The result of function no_colors_stderr should include "exit code: 0"

      # Dump
    End
  End
End
