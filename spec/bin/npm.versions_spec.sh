#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2155,SC2317,SC2016,SC2329

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Define script paths for cleaner usage
readonly PROJECT_ROOT="$(pwd)"
readonly SCRIPT_DIR="${PROJECT_ROOT}/bin"
readonly UNDER_TEST="${SCRIPT_DIR}/npm.versions.sh"

# Set E_BASH before sourcing the script
export E_BASH="${PROJECT_ROOT}/.scripts"

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

# Mock logger functions that will be used by the functions under test
# This means logger:init and dry-run calls are never executed, and our mocks work perfectly
Mock echo:Npmv
  echo "$*" >&2
End

Mock printf:Npmv
  printf '%s' "$@" >&2
End

Mock echo:Npm
  echo "$*" >&2
End

Mock printf:Npm
  printf '%s' "$@" >&2
End

Mock echo:Versions
  echo "$*" >&2
End

Mock printf:Versions
  printf '%s' "$@" >&2
End

Mock echo:Registry
  echo "$*" >&2
End

Mock printf:Registry
  printf '%s' "$@" >&2
End

Mock echo:Dump
  echo "$*" >&2
End

Mock printf:Dump
  printf '%s' "$@" >&2
End

Mock log:Npmv
  cat
End

Mock log:Npm
  cat
End

Mock log:Versions
  cat
End

Mock log:Registry
  cat
End

Mock log:Dump
  cat
End

# Mock logger functions used by _arguments.sh and _commons.sh
Mock echo:Common
  :
End

Mock printf:Common
  :
End

Mock echo:Parser
  :
End

Mock printf:Parser
  :
End

# Helper mocks used when exercising main() and entrypoint flows
function mock_dry_npm_success() {
  dry:npm() {
    echo "dry:npm $*" >&2
    return 0
  }
}

function mock_run_npm_versions() {
  MOCK_NPM_VERSIONS_JSON=$1
  MOCK_NPM_VERIFY_STATUS=${2:-1}
  run:npm() {
    if [[ $1 == view && $3 == versions ]]; then
      echo "$MOCK_NPM_VERSIONS_JSON"
      return 0
    elif [[ $1 == view && $3 == version ]]; then
      return "$MOCK_NPM_VERIFY_STATUS"
    fi
    return 0
  }
}

Describe 'bin/npm.versions.sh /'
  # Source the script to test its functions
  # ShellSpec's Include sets __SOURCED__ automatically, stopping execution at ${__SOURCED__:+return}
  Include "$UNDER_TEST"
  BeforeAll 'cl:unset'

  Context 'Script sourcing and initialization /'
    It 'should define print_usage function'
      The function print_usage should be defined
    End

    It 'should define fetch_versions function'
      The function fetch_versions should be defined
    End

    It 'should define display_versions function'
      The function display_versions should be defined
    End

    It 'should define parse_range function'
      The function parse_range should be defined
    End

    It 'should define confirm_unpublish function'
      The function confirm_unpublish should be defined
    End

    It 'should define unpublish_version function'
      The function unpublish_version should be defined
    End

    It 'should define verify_unpublish function'
      The function verify_unpublish should be defined
    End

    It 'should define main function'
      The function main should be defined
    End
  End

  Context 'parse_range function /'
    # Create test versions array
    setup_test_versions() {
      TEST_VERSIONS=("1.0.0" "1.0.1" "1.0.2" "1.1.0" "1.1.1" "2.0.0" "2.0.1" "2.1.0" "3.0.0" "3.0.1")
    }

    BeforeEach 'setup_test_versions'

    It 'should parse single index'
      When call parse_range "1" "${TEST_VERSIONS[@]}"
      The status should be success
      The output should eq "0"
    End

    It 'should parse multiple comma-separated indexes'
      When call parse_range "1,3,5" "${TEST_VERSIONS[@]}"
      The status should be success
      The line 1 of output should eq "0"
      The line 2 of output should eq "2"
      The line 3 of output should eq "4"
    End

    It 'should parse range with dash'
      When call parse_range "2-4" "${TEST_VERSIONS[@]}"
      The status should be success
      The line 1 of output should eq "1"
      The line 2 of output should eq "2"
      The line 3 of output should eq "3"
    End

    It 'should parse mixed ranges and indexes'
      When call parse_range "1,3-5,8" "${TEST_VERSIONS[@]}"
      The status should be success
      The line 1 of output should eq "0"
      The line 2 of output should eq "2"
      The line 3 of output should eq "3"
      The line 4 of output should eq "4"
      The line 5 of output should eq "7"
    End

    It 'should handle input with spaces'
      When call parse_range "1, 3 - 5, 8" "${TEST_VERSIONS[@]}"
      The status should be success
      The line 1 of output should eq "0"
      The line 2 of output should eq "2"
      The line 3 of output should eq "3"
      The line 4 of output should eq "4"
      The line 5 of output should eq "7"
    End

    It 'should reject invalid index format'
      When call parse_range "abc" "${TEST_VERSIONS[@]}"
      The status should be failure
      The result of function no_colors_stderr should include "Invalid index"
    End

    It 'should reject out of range index (too high)'
      When call parse_range "100" "${TEST_VERSIONS[@]}"
      The status should be failure
      The result of function no_colors_stderr should include "Index out of range"
    End

    It 'should reject invalid range format'
      When call parse_range "2-abc" "${TEST_VERSIONS[@]}"
      The status should be failure
      The result of function no_colors_stderr should include "Invalid range"
    End

    It 'should reject out of range in range expression'
      When call parse_range "8-20" "${TEST_VERSIONS[@]}"
      The status should be failure
      The result of function no_colors_stderr should include "Index out of range"
    End
  End

  Context 'fetch_versions function /'
    setup_fetch_mocks() {
      dry:npm() {
        echo "dry:npm $*" >&2
        return 0
      }

      run:npm() {
        echo '["1.0.0"]'
        return 0
      }
    }

    BeforeEach 'setup_fetch_mocks'

    It 'should configure npm registry before fetching'
      When call fetch_versions "test-pkg" "https://mirror.registry"
      The status should be success
      The result of function no_colors_stderr should include "dry:npm config set registry https://mirror.registry"
      The output should include "1.0.0"
    End

    It 'should return sorted newline separated versions'
      run:npm() {
        echo '["2.0.0","1.0.1","1.0.0"]'
        return 0
      }
      When call fetch_versions "test-pkg"
      The status should be success
      The line 1 of output should eq "1.0.0"
      The line 2 of output should eq "1.0.1"
      The line 3 of output should eq "2.0.0"
      The result of function no_colors_stderr should include "Fetching versions"
    End

    It 'should return failure when npm view fails'
      run:npm() { return 1; }
      When call fetch_versions "missing"
      The status should be failure
      The result of function no_colors_stderr should include "Failed to fetch versions"
    End
  End

  Context 'display_versions function /'
    setup_term_width() {
      export TERM_WIDTH=80
    }

    BeforeEach 'setup_term_width'

    It 'should display versions when versions array is not empty'
      When call display_versions "1.0.0" "1.0.1" "1.0.2"
      The status should be success
      The output should include "Found"
      The output should include "version"
      The output should include "1.0.0"
      The output should include "1.0.1"
      The output should include "1.0.2"
    End

    It 'should fail when no versions provided'
      When call display_versions
      The status should be failure
      The result of function no_colors_stderr should include "No versions found"
    End

    It 'should display version count'
      When call display_versions "1.0.0" "1.0.1" "1.0.2"
      The status should be success
      The output should include "3 versions"
    End

    It 'should include index numbers for each version'
      When call display_versions "1.0.0" "1.0.1"
      The status should be success
      The output should include "1)"
      The output should include "2)"
    End

    It 'should handle single version'
      When call display_versions "1.0.0"
      The status should be success
      The output should include "Found"
      The output should include "1 version"
      The output should include "1)"
      The output should include "1.0.0"
    End
  End

  Context 'print_usage function /'
    It 'should display usage information'
      When call print_usage
      The status should be success
      The output should include "Usage"
      The output should include "npm.versions.sh"
    End

    It 'should display arguments help'
      When call print_usage
      The output should include "package-name"
      The output should include "help"
      The output should include "registry"
    End

    It 'should display examples'
      When call print_usage
      The output should include "Examples"
    End
  End

  Context 'confirm_unpublish function /'
    It 'should return success when user types yes'
      Data
        #|yes
      End
      When call confirm_unpublish "test-package" "1.0.0" "1.0.1"
      The status should be success
      The result of function no_colors_stderr should include "about to unpublish"
      The result of function no_colors_stderr should include "test-package"
      The result of function no_colors_stderr should include "1.0.0"
      The result of function no_colors_stderr should include "1.0.1"
      The result of function no_colors_stderr should include "CANNOT"
    End

    It 'should return failure when user types no'
      Data
        #|no
      End
      When call confirm_unpublish "test-package" "1.0.0"
      The status should be failure
      The result of function no_colors_stderr should include "cancelled"
    End

    It 'should return failure when user types anything else'
      Data
        #|maybe
      End
      When call confirm_unpublish "test-package" "1.0.0"
      The status should be failure
      The result of function no_colors_stderr should include "cancelled"
    End

    It 'should display warning about irreversible action'
      Data
        #|no
      End
      When call confirm_unpublish "pkg" "1.0.0"
      The status should be failure
      The result of function no_colors_stderr should include "CANNOT"
      The result of function no_colors_stderr should include "undone"
    End

    It 'should list all versions to be unpublished'
      Data
        #|yes
      End
      When call confirm_unpublish "pkg" "1.0.0" "2.0.0" "3.0.0"
      The status should be success
      The result of function no_colors_stderr should include "1.0.0"
      The result of function no_colors_stderr should include "2.0.0"
      The result of function no_colors_stderr should include "3.0.0"
    End
  End

  Context 'unpublish_version function /'
    setup_unpublish_mocks() {
      # Mock dry:npm for unpublish tests
      dry:npm() {
        case "$1" in
        unpublish)
          echo "Mocked unpublish: $*" >&2
          return 0
          ;;
        *)
          echo "Unexpected dry:npm: $*" >&2
          return 1
          ;;
        esac
      }
    }

    BeforeEach 'setup_unpublish_mocks'

    It 'should call npm unpublish with correct arguments'
      export REGISTRY="https://test-registry.com"
      When call unpublish_version "test-pkg" "1.0.0"
      The status should be success
      The result of function no_colors_stderr should include "Unpublishing"
      The result of function no_colors_stderr should include "test-pkg@1.0.0"
    End

    It 'should return failure when npm unpublish fails'
      # Override the BeforeEach mock for this specific test
      dry:npm() { return 1; }
      When call unpublish_version "test-pkg" "1.0.0"
      The status should be failure
      The result of function no_colors_stderr should include "Failed to unpublish"
    End

    It 'should use configured registry'
      # Override the BeforeEach mock to capture arguments
      dry:npm() {
        echo "Args: $*" >&2
        return 0
      }
      export REGISTRY="https://custom.registry"
      When call unpublish_version "pkg" "1.0.0"
      The result of function no_colors_stderr should include "--registry=https://custom.registry"
    End
  End

  Context 'verify_unpublish function /'
    setup_verify_mocks() {
      # Default mock: version not found (return 1)
      run:npm() {
        return 1
      }
    }

    BeforeEach 'setup_verify_mocks'

    It 'should return success when version is not found'
      When call verify_unpublish "test-pkg" "1.0.0"
      The status should be success
      The result of function no_colors_stderr should include "Verified"
      The result of function no_colors_stderr should include "removed"
    End

    It 'should return failure when version still exists'
      # Override to return 0 (version exists)
      run:npm() { return 0; }
      When call verify_unpublish "test-pkg" "1.0.0"
      The status should be failure
      The result of function no_colors_stderr should include "Failed"
      The result of function no_colors_stderr should include "still exists"
    End

    It 'should use configured registry for verification'
      # We can't check the exact args because run:npm output is redirected to /dev/null
      # Just verify the function succeeds with the registry set
      export REGISTRY="https://verify-registry.com"
      When call verify_unpublish "pkg" "2.0.0"
      The status should be success
      The result of function no_colors_stderr should include "Verified"
    End
  End

  Context 'Script entrypoint /'
    It 'displays usage when called with --help'
      export TERM=dumb
      When run script "$UNDER_TEST" --help
      The status should be success
      The result of function no_colors_stdout should include "Usage"
      The result of function no_colors_stdout should include "Examples"
    End
  End

  Context 'main function /'
    It 'returns failure when no versions are available'
      mock_dry_npm_success
      run:npm() { return 1; }
      Data
        #|
      End
      When call main
      The status should be failure
      The result of function no_colors_stderr should include "No versions found"
    End

    It 'exits with success when user selects nothing'
      mock_dry_npm_success
      mock_run_npm_versions '["1.0.0","2.0.0"]'
      Data
        #|
      End
      When call main
      The status should be success
      The result of function no_colors_stderr should include "No versions selected"
    End

    It 'fails when selection input is invalid'
      mock_dry_npm_success
      mock_run_npm_versions '["1.0.0"]'
      Data
        #|abc
      End
      When call main
      The status should be failure
      The result of function no_colors_stderr should include "No valid versions selected"
    End

    It 'unpublishes selected versions when confirmed'
      mock_dry_npm_success
      mock_run_npm_versions '["1.0.0","2.0.0"]'
      Data
        #|1
        #|yes
      End
      When call main
      The status should be success
      The result of function no_colors_stderr should include "Operation completed"
    End

    It 'cancels operation when confirmation is denied'
      mock_dry_npm_success
      mock_run_npm_versions '["1.0.0","2.0.0"]'
      Data
        #|1
        #|no
      End
      When call main
      The status should be success
      The result of function no_colors_stderr should include "Operation cancelled"
    End
  End
End
