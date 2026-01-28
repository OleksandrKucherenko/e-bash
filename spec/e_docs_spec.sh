#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-27
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Describe 'e-docs /'
  # Make e-docs executable before tests
  setup() {
    chmod +x bin/e-docs.sh 2>/dev/null || true
  }
  BeforeAll 'setup'

  # Helper to run e-docs on fixture (--stdout for stdout output, filter dependency message)
  edocs() { bin/e-docs.sh --stdout "$1" 2>/dev/null | grep -v 'Dependency \[OK\]'; }

  Context 'Basic functionality /'
    It 'shows help with --help flag'
      When call bin/e-docs.sh --help
      The status should be success
      The output should include 'Usage:'
      The output should include 'Generate documentation'
    End

    It 'exits with error for unknown option'
      When call bin/e-docs.sh --unknown-option
      The status should be failure
      The error should include 'Unknown option'
    End
  End

  Context 'Documentation block detection /'
    It 'parses simple function with description'
      When call edocs "spec/fixtures/e-docs/simple_function.sh"
      The status should be success
      The output should include 'simple_func'
      The output should include 'simple function that does one thing'
    End

    It 'generates header from filename'
      When call edocs "spec/fixtures/e-docs/simple_function.sh"
      The status should be success
      The output should include '# simple_function.sh'
    End
  End

  Context 'Full documentation parsing /'
    It 'extracts Parameters section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Parameters'
      The output should include 'arg1'
      The output should include 'arg2'
    End

    It 'extracts Globals section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Globals'
    End

    It 'extracts Returns section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Returns'
    End

    It 'extracts Usage section as code block'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Usage'
      The output should include 'full_func'
    End

    It 'extracts Side Effects section'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Side Effects'
    End
  End

  Context 'Undocumented functions /'
    It 'handles functions without documentation'
      When call edocs "spec/fixtures/e-docs/no_docs.sh"
      The status should be success
      The output should include 'undocumented_func'
      The output should include 'No documentation available'
    End
  End

  Context 'Namespaced functions /'
    It 'detects functions with colons in name'
      When call edocs "spec/fixtures/e-docs/namespaced.sh"
      The status should be success
      The output should include 'logger:init'
      The output should include 'logger:prefix'
    End
  End

  Context 'Module Summary parsing /'
    It 'extracts module title from end of file'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Test Module'
    End

    It 'extracts References from module summary'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'demo'
    End
  End

  Context 'Table of Contents /'
    It 'generates TOC with function links'
      When call edocs "spec/fixtures/e-docs/full_function.sh"
      The output should include 'Index'
      The output should include '[`full_func`]'
    End

    It 'can disable TOC with --no-toc flag'
      When call bin/e-docs.sh --stdout --no-toc "spec/fixtures/e-docs/simple_function.sh"
      The output should not include '## Index'
    End
  End
End
