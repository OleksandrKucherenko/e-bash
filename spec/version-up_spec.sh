#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-29
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

# keep it in focus mode `fDescribe` for TDD
fDescribe 'bin/version-up.v2.sh'
  # Define a helper function to strip ANSI escape sequences
  # $1 = stdout, $2 = stderr, $3 = exit status of the command
  no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }
  no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }

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
  git_next_commit() { (git add . && git commit -m "Next commit"); }
  git_create_tag() { git tag "$1"; }
  random_change() { date >>random.txt; }

  Before 'mk_repo; git_init; git_config; ln_script'
  After 'rm_repo'

  # test-000
  It 'displays usage/help information and exits with 0'
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
  It 'displays script version and exits with 0'
    BeforeRun 'export DEBUG="ver"'
    When run bash "$VERSION_UP_SCRIPT" --version

    The status should be success
    The stdout should be present

    The result of function no_colors_stdout should include "version: 2.0.0"
    The result of function no_colors_stderr should include "exit code: 0"

    # Dump
  End

  # test-002
  It 'should detect empty git repository'
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
  It 'proposes version 0.0.1-alpha in a fresh git repository'
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
  Describe "version tag proposal scenarios"
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

    It "proposes the next version from tag '$2' after '$3' flag, expected '$4'"
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

  # test-004: Re-publish existing version tag
  It 'should reuse version when on a branch named after that version tag'
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
