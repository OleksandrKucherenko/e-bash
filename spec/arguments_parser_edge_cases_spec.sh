#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-04-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Describe 'parse:arguments edge cases /'
  BeforeRun 'export DEBUG="*"'
  Include ".scripts/_arguments.sh"

  # Suppress logger output - tests verify behavior, not logs
  Mock echo:Common
    :
  End

  Mock echo:Parser
    :
  End

  Mock printf:Common
    :
  End

  Mock printf:Parser
    :
  End

  Describe 'key=value parsing /'

    Context 'when value contains equals sign (--key=val=ue)'
      It 'preserves the full value after first equals'
        preserve() { %preserve output:OUTPUT; }
        BeforeCall 'export ARGS_DEFINITION="-o,--output=output::1"'
        AfterCall preserve

        When call parse:arguments --output="path/to/file=backup"

        The status should be success
        The variable OUTPUT should eq 'path/to/file=backup'
      End
    End

    Context 'when value contains spaces via equals syntax'
      # Note: --flag="value with spaces" is already handled by shell quoting
      # The parser receives the full string as one argument
      It 'preserves spaces in quoted value'
        preserve() { %preserve output:OUTPUT; }
        BeforeCall 'export ARGS_DEFINITION="-o,--output=output::1"'
        AfterCall preserve

        When call parse:arguments --output="hello world"

        The status should be success
        The variable OUTPUT should eq 'hello world'
      End
    End

    Context 'when value is a URL with protocol'
      It 'preserves URL with colon in --flag=URL syntax'
        preserve() { %preserve registry:REGISTRY; }
        BeforeCall 'export ARGS_DEFINITION="--registry=registry::1"'
        AfterCall preserve

        When call parse:arguments --registry="https://registry.npmjs.org"

        The status should be success
        The variable REGISTRY should eq 'https://registry.npmjs.org'
      End
    End

    Context 'when value is empty via --flag=""'
      It 'sets value to <empty> marker'
        preserve() { %preserve output:OUTPUT; }
        BeforeCall 'export ARGS_DEFINITION="-o,--output=output::1"'
        AfterCall preserve

        When call parse:arguments --output=""

        The status should be success
        The variable OUTPUT should eq '<empty>'
      End
    End
  End

  Describe 'positional arguments /'

    Context 'when mixing positional and flag arguments'
      It 'assigns positional args correctly alongside flags'
        preserve() { %preserve cmd:CMD help:HELP; }
        BeforeCall 'export ARGS_DEFINITION="\$1,<command>=cmd::1 -h,--help"'
        AfterCall preserve

        When call parse:arguments "deploy" --help

        The status should be success
        The variable CMD should eq 'deploy'
        The variable HELP should eq '1'
      End
    End

    Context 'when positional argument comes after flag with value'
      It 'correctly separates flag value from positional'
        preserve() { %preserve cmd:CMD output:OUTPUT; }
        BeforeCall 'export ARGS_DEFINITION="\$1,<command>=cmd::1 -o,--output=output::1"'
        AfterCall preserve

        When call parse:arguments -o "result.txt" "deploy"

        The status should be success
        The variable OUTPUT should eq 'result.txt'
        The variable CMD should eq 'deploy'
      End
    End

    Context 'when more positional args than defined'
      It 'ignores extra positional arguments'
        preserve() { %preserve cmd:CMD; }
        BeforeCall 'export ARGS_DEFINITION="\$1,<command>=cmd::1"'
        AfterCall preserve

        When call parse:arguments "deploy" "extra1" "extra2"

        The status should be success
        The variable CMD should eq 'deploy'
      End
    End
  End

  Describe 'flag with multi-arg value (args_qt > 1) /'

    Context 'when flag expects 2 arguments'
      It 'aggregates two following arguments space-separated'
        preserve() { %preserve range:RANGE; }
        BeforeCall 'export ARGS_DEFINITION="--range=range::2"'
        AfterCall preserve

        When call parse:arguments --range "1" "10"

        The status should be success
        The variable RANGE should eq '1 10'
      End
    End

    Context 'when flag expects 2 args but only 1 provided'
      It 'returns error for too few arguments'
        BeforeCall 'export ARGS_DEFINITION="--range=range::2 -h,--help"'

        When call parse:arguments --help --range "1"

        The status should be failure
        The stderr should include "too few arguments"
      End
    End

    Context 'when flag expects args and next arg looks like a flag'
      It 'consumes the flag-like arg as value (not as separate flag)'
        preserve() { %preserve data:DATA; }
        BeforeCall 'export ARGS_DEFINITION="--data=data::1 -v,--verbose"'
        AfterCall preserve

        When call parse:arguments --data "--verbose"

        The status should be success
        # --verbose is consumed as value of --data, not as a flag
        The variable DATA should eq '--verbose'
      End
    End
  End

  Describe 'default values /'

    Context 'when flag is not provided'
      It 'pre-fills with default value'
        preserve() { %preserve output:OUTPUT; }
        BeforeCall 'export ARGS_DEFINITION="-o,--output=output:default.txt:1"'
        AfterCall preserve

        When call parse:arguments

        The status should be success
        # Defaults are pre-filled for value flags (args_qt > 0)
        The variable OUTPUT should eq 'default.txt'
      End
    End

    Context 'when boolean flag has default value'
      It 'assigns default when flag is present'
        preserve() { %preserve verbose:VERBOSE; }
        BeforeCall 'export ARGS_DEFINITION="--verbose=verbose:true"'
        AfterCall preserve

        When call parse:arguments --verbose

        The status should be success
        The variable VERBOSE should eq 'true'
      End
    End

    Context 'when flag default contains URL with colon'
      It 'preserves full URL as default when value provided'
        preserve() { %preserve registry:REGISTRY; }
        BeforeCall 'export ARGS_DEFINITION="--registry=registry:https://registry.npmjs.org:1"'
        AfterCall preserve

        When call parse:arguments --registry "https://custom.registry.io"

        The status should be success
        The variable REGISTRY should eq 'https://custom.registry.io'
      End
    End

    Context 'when flag with args_qt=1 is last arg without value'
      It 'returns error for missing required value'
        BeforeCall 'export ARGS_DEFINITION="--registry=registry:https://registry.npmjs.org:1"'

        When call parse:arguments --registry

        The status should be failure
        The stderr should include "too few arguments"
      End
    End
  End

  Describe 'parse:exclude_flags_from_args /'

    Context 'when input contains long flags'
      It 'removes --flag style arguments'
        helper() { parse:exclude_flags_from_args "$@"; echo "${ARGS_NO_FLAGS[*]}"; }

        When call helper "arg1" "--flag" "arg2" "--verbose"

        The status should be success
        The stdout should eq 'arg1 arg2'
      End
    End

    Context 'when input contains short flags'
      It 'keeps -x short flags (only removes -- long flags)'
        helper() { parse:exclude_flags_from_args "$@"; echo "${ARGS_NO_FLAGS[*]}"; }

        When call helper "arg1" "-v" "arg2"

        The status should be success
        # Current behavior: short flags are NOT removed
        The stdout should eq 'arg1 -v arg2'
      End
    End

    Context 'when input contains --flag=value'
      It 'removes the entire --flag=value argument'
        helper() { parse:exclude_flags_from_args "$@"; echo "${ARGS_NO_FLAGS[*]}"; }

        When call helper "arg1" "--output=file.txt" "arg2"

        The status should be success
        The stdout should eq 'arg1 arg2'
      End
    End
  End

  Describe 'multiple alias flags /'

    Context 'when flag has 3 aliases'
      It 'accepts any alias for the same variable'
        preserve() { %preserve id:ID1 id:ID2 id:ID3; }
        BeforeCall 'export ARGS_DEFINITION="-i,--id,--identifier=id::1"'

        p1() { %preserve id:ID1; }
        AfterCall p1
        When call parse:arguments -i "val1"
        The status should be success
        The variable ID1 should eq 'val1'
      End
    End
  End

  Describe 'parse:extract_output_definition edge cases /'

    Context 'when definition has pipe char in default'
      # The return value uses | as separator, so pipe in default would break parsing
      It 'breaks on pipe character in default value'
        When call parse:extract_output_definition "--sep" "--sep=sep:a|b:1"

        The stdout should include "sep|a|b|1"
        # Note: IFS='|' read would parse this as: var=sep default=a extra=b args_qt=1
        # This is a known limitation
      End
    End

    Context 'when definition has no output variable specified'
      It 'derives variable name from flag by stripping dashes'
        When call parse:extract_output_definition "--dry-run" "--dry-run"

        The stdout should include "dryrun|1|0"
      End
    End

    Context 'when definition uses indexed positional'
      It 'parses $1 positional correctly'
        When call parse:extract_output_definition '$1' '$1,<cmd>=cmd:default:1'

        The stdout should include "cmd|default|1"
      End
    End
  End
End
