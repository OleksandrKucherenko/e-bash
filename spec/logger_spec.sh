#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2023-10-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

export SCRIPT_DIR=".scripts"

Describe '_logger.sh:'
    Include ".scripts/_logger.sh"

    Mock echo:Common
        echo "$@"
    End

    It 'Expected empty output when registered pre-defined common logger'
        BeforeCall 'export DEBUG="*"'
        When call logger "common"

        The status should be success
        The output should eq ''
        The error should eq ''

        # Dump
    End

    It 'Expected TAGS dump when register token after common loggers'
        BeforeCall 'export DEBUG="*" && logger common && logger token'
        When call echo:Token "test token echo command"

        The status should be success
        The output should include 'test token echo command'
        The error should include 'Logger tags  : common token | 1 1'

        # Dump
    End

    It 'Expected echo with custom prefix when register token after common loggers'
        BeforeCall 'export DEBUG="*" && logger common && logger token && TAGS_PREFIX[token]="[token] "'
        When call echo:Token "test token echo command"

        The status should be success
        The output should include '[token] test token echo command'
        The error should include 'Logger tags  : common token | 1 1'

        # Dump
    End

    It 'Expected printf with custom prefix when register token after common loggers'
        BeforeCall 'export DEBUG="*" && logger common && logger token && TAGS_PREFIX[token]="[token] "'
        When call printf:Token "%s" "test token echo command"

        The status should be success
        The output should include '[token] test token echo command'
        The error should include 'Logger tags  : common token | 1 1'

        # Dump
    End
End
