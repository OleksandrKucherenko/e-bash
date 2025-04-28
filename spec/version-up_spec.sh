#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-28
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
fDescribe 'version-up.v2.sh'
  # Define a helper function to strip ANSI escape sequences
  # $1 = stdout, $2 = stderr, $3 = exit status of the command
  no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }
  no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }

  mk_repo() {
    mkdir -p "$TEST_DIR" || true
    cd "$TEST_DIR"
  }
  git_init() { git init -q; }
  git_config_user() { git config --local user.name "Test User"; }
  git_config_email() { git config --local user.email "test@example.com"; }
  git_config() { git_config_user && git_config_email; }
  ln_script() { ln -s "$ROOT_SCRIPT" "$VERSION_UP_SCRIPT"; }
  rm_repo() { rm -rf "$TEST_DIR"; }

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

    #Dump
  End
End
