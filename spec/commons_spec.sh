#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

eval "$(shellspec - -c) exit 1"

Mock logger
    echo "$@"
End

Include ".scripts/_commons.sh"

Describe "_commons.sh"
    BeforeRun 'export DEBUG="*"'

    It "args:isHelp returns true when --help flag is provided"
        When call args:isHelp --help

        The status should be success
        The output should eq true
        The error should eq ''
        # Dump
    End
End
