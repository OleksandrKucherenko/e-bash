#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Mock logger
    echo "$@"
End

Mock config:logger:Dependencies
    echo "$@"
End

Mock printf:Dependencies
    printf "$@"
End

Mock echo:Dependencies
    echo "$@"
End

Include ".scripts/_dependencies.sh"

Describe "_dependencies.sh"
    # remove colors in output
    BeforeCall "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset"

    Describe "Dependency:"
        It "Dependency OK on \`dependency bash \"5.*.*\" \"brew install bash\" --version\`"
            When call dependency bash "5.*.*" "brew install bash" --version

            The status should be success
            The output should include "Dependency [OK]: \`bash\` - version: 5."
            The error should include ""

            # Dump
        End

        It "Custom version request flag on \`dependency bash \"5.*.*\" \"brew install bash\" --version\`"
            When call dependency bash "5.*.*" "brew install bash" --help

            The status should be success
            The output should include "Dependency [OK]: \`bash\` - version: 5."
            The output should include 'bash home page: <http://www.gnu.org/software/bash>'
            The error should include ""

            # Dump
        End

        It "Range of version on \`dependency bash \"[45].*.*\" \"brew install bash\" --version\`"
            When call dependency bash "[45].*.*" "brew install bash" --version

            The status should be success
            The output should include "Dependency [OK]: \`bash\` - version:"
            The error should include ""

            # Dump
        End

        It "Customized version pattern on \`dependency bash \"[1-5].*.*(1)-release\" \"brew install bash\" --version\`"
            When call dependency bash "[1-5].*.*(1)-release" "brew install bash" --version

            The status should be success
            The output should include "Dependency [OK]: \`bash\` - version: 5."
            The error should include ""

            # Dump
        End

        It "Wrong Version on \`dependency bash \"99.*.*\" \"brew install bash\"\`"
            When call dependency bash "99.*.*" "brew install bash"

            The status should be failure
            The output should include "Error: dependency version \`bash\` is wrong."
            The output should include "Hint. To install tool use the command below:"
            The output should include "\$>  brew install bash"
            The error should include ""

            # Dump
        End

        It "Do Exec on wrong version on \`dependency bash \"99.*.*\" \"echo 'executted'\" --version --exec\`"
            # Note: --exec can be only after $4 parameter
            When call dependency bash "99.*.*" "echo 'executed' >&2;" --version --exec

            The status should be success
            The output should include "Error: dependency version \`bash\` is wrong."
            The output should include "Expected : \`99.*.*\`"
            The output should include "Executing: echo 'executed' >&2;"
            The error should include "executed"

            # Dump
        End

        It "Not Found on \`dependency not_exist_tool \"1.0.0\"\`"
            When call dependency not_exist_tool "1.*.*"

            The status should eq 1
            The output should include "Error: dependency \`not_exist_tool\` not found."
            The output should include "No details. Please google it."
            The error should include ""

            # Dump
        End
    End

    Describe "Optional:"
        It "Optional OK on \`optional bash \"5.*.*\" \"brew install bash\" --version --debug\`"
            When call optional bash "5.*.*" "brew install bash" --version --debug

            The status should be success
            The output should include "Optional   [OK]: \`bash\` - version: 5."
            The error should include ""

            # Dump
        End

        It "Wrong Version on \`optional bash \"99.*.*\" \"brew install bash\" --version\`"
            When call optional bash "99.*.*" "brew install bash" --version

            The status should be success
            The output should include "Optional   [NO]: \`bash\` - wrong version! Try: brew install bash"
            The error should include ""

            # Dump
        End

        It "Not Found on \`optional not_exist_tool \"1.0.0\"\`"
            When call optional not_exist_tool "1.*.*"

            The status should eq 0
            The output should include "Optional   [NO]: \`not_exist_tool\` - not found! Try: No details. Please google it."
            The error should include ""

            # Dump
        End

    End

    Describe "Utilities:"
        It "isDebug returns true when --debug flag is provided"
            When call isDebug --debug
            The status should be success
            The output should eq true
            The error should eq ''
            # Dump
        End

        It "isExec returns true when --exec flag is provided"
            When call isExec --exec
            The status should be success
            The output should eq true
            The error should eq ''
            # Dump
        End

        It "isOptional returns true when --optional flag is provided"
            When call isOptional --optional
            The status should be success
            The output should eq true
            The error should eq ''
            # Dump
        End

        It "isSilent returns true when --silent flag is provided"
            When call isSilent --silent
            The status should be success
            The output should eq true
            The error should eq ''
            # Dump
        End
    End
End
