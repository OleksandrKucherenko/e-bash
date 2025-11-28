#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2034,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-27
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Describe 'bin/npm.versions.sh /'
  # Include the script using relative path from project root
  Include bin/npm.versions.sh

  BeforeEach 'setup_test_environment'
  AfterEach 'cleanup_test_environment'

  setup_test_environment() {
    # Ensure E_BASH is set to project root
    export E_BASH="${SHELLSPEC_PROJECT_ROOT}/.scripts"

    # Disable colors for cleaner test output
    export NO_COLOR=1
    export TERM=dumb

    # Set DEBUG to minimal to avoid logger noise
    export DEBUG="-*"

    # Create temp directory for test artifacts
    export TEST_TMP_DIR=$(mktemp -d)

    # Mock logger functions used by _arguments module
    echo:Common() { : ; }  # Silent in tests
    echo:Parser() { : ; }  # Silent in tests
    echo:Loader() { : ; }  # Silent in tests
    printf:Common() { : ; }  # Silent in tests
    printf:Parser() { : ; }  # Silent in tests
    printf:Loader() { : ; }  # Silent in tests
    log:Common() { : ; }  # Silent in tests
    log:Parser() { : ; }  # Silent in tests
    log:Loader() { : ; }  # Silent in tests

    # Mock logger functions used by npm.versions.sh
    echo:Npmv() { echo "$*"; }
    echo:Npm() { : ; }  # Silent in tests
    echo:Versions() { : ; }  # Silent in tests
    echo:Registry() { : ; }  # Silent in tests
    echo:Dump() { : ; }  # Silent in tests
    printf:Npmv() { printf "%s" "$*"; }
    printf:Npm() { : ; }  # Silent in tests
    printf:Versions() { : ; }  # Silent in tests
    printf:Registry() { : ; }  # Silent in tests
    printf:Dump() { : ; }  # Silent in tests

    # Reset global variables to known state
    export DRY_RUN=false
    export SILENT_NPM=false
    export REGISTRY="https://registry.npmjs.org"
    export PACKAGE_NAME="test-package"
  }

  cleanup_test_environment() {
    rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
    unset TEST_TMP_DIR DRY_RUN SILENT_NPM REGISTRY PACKAGE_NAME
  }

  Context 'parse_range() - single version numbers /'
    Parameters
      "1" 0
      "5" 4
      "10" 9
    End

    It "converts 1-based index '$1' to 0-based index '$2'"
      # Setup test versions array
      versions=("0.0.1" "0.0.2" "0.0.3" "1.0.0" "1.0.1" "1.1.0" "2.0.0" "2.1.0" "3.0.0" "3.1.0")

      When call parse_range "$1" "${versions[@]}"
      The output should eq "$2"
      The status should be success
    End
  End

  Context 'parse_range() - comma-separated indices /'
    It 'handles multiple single indices: 1,3,5'
      versions=("v1" "v2" "v3" "v4" "v5" "v6")

      When call parse_range "1,3,5" "${versions[@]}"
      The line 1 of output should eq "0"
      The line 2 of output should eq "2"
      The line 3 of output should eq "4"
      The status should be success
    End

    It 'handles indices with spaces: "1, 3, 5"'
      versions=("v1" "v2" "v3" "v4" "v5" "v6")

      When call parse_range "1, 3, 5" "${versions[@]}"
      The line 1 of output should eq "0"
      The line 2 of output should eq "2"
      The line 3 of output should eq "4"
      The status should be success
    End
  End

  Context 'parse_range() - range notation /'
    It 'handles simple range: 1-3'
      versions=("v1" "v2" "v3" "v4" "v5")

      When call parse_range "1-3" "${versions[@]}"
      The line 1 of output should eq "0"
      The line 2 of output should eq "1"
      The line 3 of output should eq "2"
      The status should be success
    End

    It 'handles range at end of list: 3-5'
      versions=("v1" "v2" "v3" "v4" "v5")

      When call parse_range "3-5" "${versions[@]}"
      The line 1 of output should eq "2"
      The line 2 of output should eq "3"
      The line 3 of output should eq "4"
      The status should be success
    End

    It 'handles single element range: 2-2'
      versions=("v1" "v2" "v3" "v4" "v5")

      When call parse_range "2-2" "${versions[@]}"
      The output should eq "1"
      The status should be success
    End
  End

  Context 'parse_range() - complex mixed notation /'
    It 'handles combination: 1,3-5,7'
      versions=("v1" "v2" "v3" "v4" "v5" "v6" "v7" "v8")

      When call parse_range "1,3-5,7" "${versions[@]}"
      The line 1 of output should eq "0"
      The line 2 of output should eq "2"
      The line 3 of output should eq "3"
      The line 4 of output should eq "4"
      The line 5 of output should eq "6"
      The status should be success
    End
  End

  Context 'parse_range() - invalid input handling /'
    It 'rejects non-numeric input'
      versions=("v1" "v2" "v3")

      When call parse_range "abc" "${versions[@]}"
      The status should be failure
      The error should include "Invalid index"
    End

    It 'rejects out-of-range index (too high)'
      versions=("v1" "v2" "v3")

      When call parse_range "10" "${versions[@]}"
      The status should be failure
      The error should include "Index out of range"
    End

    It 'rejects zero index'
      versions=("v1" "v2" "v3")

      When call parse_range "0" "${versions[@]}"
      The status should be failure
      The error should include "Index out of range"
    End

    It 'rejects invalid range with non-numeric boundaries'
      versions=("v1" "v2" "v3")

      When call parse_range "a-b" "${versions[@]}"
      The status should be failure
      The error should include "Invalid range"
    End

    It 'rejects range exceeding array bounds'
      versions=("v1" "v2" "v3")

      When call parse_range "1-10" "${versions[@]}"
      The status should be failure
      The error should include "Index out of range"
    End
  End

  Context 'run:npm() - actual execution mode /'
    BeforeEach 'setup_npm_mock'

    setup_npm_mock() {
      export DRY_RUN=false
      export SILENT_NPM=false

      # Mock npm command
      npm() {
        case "$1" in
          "config")
            echo "npm config $*" >&2
            return 0
            ;;
          "view")
            if [[ "$2" == "test-package" && "$3" == "versions" && "$4" == "--json" ]]; then
              echo '["1.0.0","1.0.1","2.0.0"]'
              return 0
            fi
            return 1
            ;;
          "unpublish")
            echo "npm unpublish $*" >&2
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }
    }

    It 'executes npm config command via run:npm'
      When call run:npm config set registry "https://registry.npmjs.org"
      The error should include "npm config set registry"
      The status should be success
    End

    It 'executes npm view and returns JSON output via run:npm'
      When call run:npm view "test-package" versions --json
      The output should include "1.0.0"
      The output should include "2.0.0"
      The status should be success
    End
  End

  Context 'dry:npm() - destructive operations /'
    BeforeEach 'setup_npm_mock'

    setup_npm_mock() {
      export DRY_RUN=false
      export SILENT_NPM=false

      # Mock npm command
      npm() {
        case "$1" in
          "unpublish")
            echo "npm unpublish $*" >&2
            return 0
            ;;
          *)
            return 1
            ;;
        esac
      }
    }

    It 'executes npm unpublish command via dry:npm'
      When call dry:npm unpublish "test-package@1.0.0"
      The error should include "npm unpublish"
      The status should be success
    End
  End

  Context 'dry:npm() - dry run mode /'
    BeforeEach 'enable_dry_run'

    enable_dry_run() {
      export DRY_RUN=true
      export SILENT_NPM=false
    }

    It 'simulates npm unpublish without execution'
      When call dry:npm unpublish "test-package@1.0.0"
      The error should include "npm unpublish"
      The status should be success
    End
  End

  Context 'run:npm() - dry run mode for readonly operations /'
    BeforeEach 'enable_dry_run'

    enable_dry_run() {
      export DRY_RUN=true
      export SILENT_NPM=false
    }

    It 'simulates npm config without execution'
      When call run:npm config set registry "https://test.com"
      The error should include "npm config set registry"
      The status should be success
    End

    It 'simulates npm view without execution'
      When call run:npm view "test-package" versions --json
      The error should include "npm view"
      The status should be success
    End
  End

  Context 'fetch_versions() /'
    BeforeEach 'setup_fetch_versions_test'

    setup_fetch_versions_test() {
      export DRY_RUN=false
      export SILENT_NPM=true

      # Mock npm command
      npm() {
        case "$1" in
          "config")
            return 0
            ;;
          "view")
            if [[ "$3" == "versions" && "$4" == "--json" ]]; then
              # Return mock JSON array of versions
              echo '["0.1.0","0.2.0","1.0.0","1.1.0","2.0.0"]'
              return 0
            fi
            return 1
            ;;
          *)
            return 1
            ;;
        esac
      }
    }

    It 'fetches and sorts versions correctly'
      When call fetch_versions "test-package" "https://registry.npmjs.org"
      The line 1 of output should eq "0.1.0"
      The line 2 of output should eq "0.2.0"
      The line 3 of output should eq "1.0.0"
      The line 4 of output should eq "1.1.0"
      The line 5 of output should eq "2.0.0"
      The status should be success
    End

    It 'returns error for non-existent package'
      # Override npm mock to return error
      npm() {
        if [[ "$1" == "view" ]]; then
          return 1
        fi
        return 0
      }

      When call fetch_versions "non-existent-package"
      The status should be failure
    End
  End

  Context 'display_versions() /'
    BeforeEach 'setup_display_test'

    setup_display_test() {
      # Set predictable terminal width
      TERM_WIDTH=80
    }

    It 'displays versions in formatted output'
      versions=("1.0.0" "1.0.1" "1.1.0" "2.0.0")

      When call display_versions "${versions[@]}"
      The output should include "Found"
      The output should include "4"
      The output should include "version(s)"
      The output should include "1.0.0"
      The output should include "2.0.0"
      The status should be success
    End

    It 'handles single version'
      versions=("1.0.0")

      When call display_versions "${versions[@]}"
      The output should include "Found"
      The output should include "1"
      The output should include "version(s)"
      The status should be success
    End

    It 'returns error for empty version list'
      When call display_versions
      The status should be failure
      The error should include "No versions found"
    End

    It 'formats canary versions with gray color'
      versions=("1.0.0" "1.1.0-canary.1" "2.0.0")

      When call display_versions "${versions[@]}"
      The output should include "canary"
      The status should be success
    End
  End

  Context 'parse:arguments() - argument parsing /'
    setup_args_definition() {
      export ARGS_DEFINITION=""
      ARGS_DEFINITION+=" \$1,<package-name>=PACKAGE_NAME:@oleksandrkucherenko/mcp-obsidian"
      ARGS_DEFINITION+=" -h,--help=help"
      ARGS_DEFINITION+=" -r,--registry=REGISTRY:https://registry.npmjs.org:1"
      ARGS_DEFINITION+=" --dry-run=DRY_RUN:true"
      ARGS_DEFINITION+=" --silent=SILENT_NPM:true"
    }

    BeforeEach 'setup_args_definition'

    It 'parses --registry option'
      When call parse:arguments "--registry" "https://custom.registry.com"
      The variable REGISTRY should eq "https://custom.registry.com"
      The status should be success
    End

    It 'parses --dry-run flag'
      When call parse:arguments "--dry-run"
      The variable DRY_RUN should eq "true"
      The status should be success
    End

    It 'parses --silent flag'
      When call parse:arguments "--silent"
      The variable SILENT_NPM should eq "true"
      The status should be success
    End

    It 'parses package name from positional argument'
      When call parse:arguments "my-package"
      The variable PACKAGE_NAME should eq "my-package"
      The status should be success
    End
  End

  Context 'print_usage() /'
    It 'displays usage information'
      When call print_usage
      The output should include "Usage:"
      The output should include "npm.versions.sh"
      The output should include "Options:"
      The output should include "--help"
      The output should include "--registry"
      The output should include "--dry-run"
      The output should include "Examples:"
    End
  End

  Context 'unpublish_version() /'
    BeforeEach 'setup_unpublish_test'

    setup_unpublish_test() {
      export DRY_RUN=false
      export REGISTRY="https://test.registry.com"

      npm() {
        if [[ "$1" == "unpublish" ]]; then
          echo "Unpublished $2" >&2
          return 0
        fi
        return 1
      }
    }

    It 'successfully unpublishes a version'
      When call unpublish_version "test-package" "1.0.0"
      The status should be success
      The error should include "Successfully unpublished"
    End

    It 'returns failure when npm unpublish fails'
      npm() {
        if [[ "$1" == "unpublish" ]]; then
          return 1
        fi
        return 0
      }

      When call unpublish_version "test-package" "1.0.0"
      The status should be failure
      The error should include "Failed to unpublish"
    End
  End

  Context 'verify_unpublish() /'
    It 'verifies version no longer exists'
      npm() {
        if [[ "$1" == "view" ]]; then
          return 1  # Version not found
        fi
        return 0
      }

      When call verify_unpublish "test-package" "1.0.0"
      The status should be success
      The error should include "Verified"
      The error should include "removed from registry"
    End

    It 'returns failure if version still exists after unpublish'
      npm() {
        if [[ "$1" == "view" ]]; then
          return 0  # Version still found
        fi
        return 0
      }

      When call verify_unpublish "test-package" "1.0.0"
      The status should be failure
      The error should include "Failed"
      The error should include "still exists"
    End
  End
End
