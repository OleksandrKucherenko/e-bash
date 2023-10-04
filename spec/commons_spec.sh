#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

eval "$(shellspec - -c) exit 1"

Include ".scripts/_commons.sh"

Describe "_commons.sh"
    BeforeRun 'export DEBUG="*"'

    It "isHelp returns false"
        When call isHelp

        The status should be success
        The output should eq false
        Dump
    End
End
