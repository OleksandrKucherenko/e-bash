#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-16
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

export line_1="147"
export line_2="158"
export line_3="173"
export line_4="186"

Describe '_arguments.sh'
BeforeRun 'export DEBUG="*"'
Include ".scripts/_arguments.sh"

Mock echo:Common
echo "$@"
End

Mock printf:Common
printf "$@" # dummy
End

It 'On no ARGS_DEFINITION provided, expected fallback to predefined flags'
preserve() { %preserve version:VERSION; }
AfterCall preserve
When call parse:arguments --help --version --debug --something

The status should be success
The variable VERSION should eq '1.0.0'

# debug output is printed
The stdout should include "[$line_2] export help='1'"
The stdout should include "[$line_2] export version='1.0.0'"
The stdout should include "[$line_2] export DEBUG='*'"
The stdout should include 'definition to output index:'
The stdout should include "'index', 'output variable name', 'args quantity', 'defaults':"

The stderr should include 'Definition: -h,--help -v,--version=:1.0.0 --debug=DEBUG:*'
The stderr should include 'ignored: --something'

# Dump
End

It 'ARGS_DEFINITION set to "-h,--help" produce help env variable with value 1'
preserve() { %preserve help:HELP; }
BeforeCall 'export ARGS_DEFINITION="-h,--help"'
AfterCall preserve

When call parse:arguments --help

The status should be success
The variable HELP should eq '1'

The stdout should include "[$line_2] export help='1'"
The stdout should include 'extracted: help=1'

The stderr should include 'Definition: -h,--help'

# Dump
End

It 'Extract argument after --id flag into args_pno variable'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno::1 -h,--help"'
AfterCall preserve

When call parse:arguments --id "test" --help

The status should be success
The variable ID should eq 'test'

The stdout should include "[$line_1] export args_pno='test'"
The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno::1 -h,--help'

# Dump
End

It 'Extract value into args_pno variable from key=value argument'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno::1 -h,--help"'
AfterCall preserve

When call parse:arguments --id="test" --help

The status should be success
The variable ID should eq 'test'

The stdout should include "[$line_1] export args_pno='test'"
The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno::1 -h,--help'

# Dump
End

It 'Force <empty> value into args_pno variable from key=value argument'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno::1 -h,--help"'
AfterCall preserve

When call parse:arguments --id="" --help

The status should be success
The variable ID should eq '<empty>'

The stdout should include "[$line_1] export args_pno='<empty>'"
The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno::1 -h,--help'

# Dump
End

It 'Force overwrite of default "dummy" value by <empty> from key=value argument'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:1 -h,--help"'
AfterCall preserve

When call parse:arguments --id="" --help

The stdout should include "[$line_1] export args_pno='<empty>'"
The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:1 -h,--help'
The status should be success
The variable ID should eq '<empty>'

# Dump
End

It 'Extract multiple arguments into args_pno variable, space separated array'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:2 -h,--help"'
AfterCall preserve

When call parse:arguments --id "first" "second" --help

The status should be success
The variable ID should eq 'first second'

The stdout should include "[$line_1] export args_pno='first second'"
The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:2 -h,--help'

# Dump
End

xIt 'Missed argument for --id flag raise error message'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:2 -h,--help"'
AfterCall preserve

When call parse:arguments --help --id "first"

The status should be failure
The variable ID should be undefined
The stdout should include 'Error. Too little arguments provided'

The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:2 -h,--help'

# Dump
End

It 'Ignore undefined flag arguments and print warning message to stderr'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:2 -h,--help"'
AfterCall preserve

When call parse:arguments --help --key1="first" --key2 "second"

The status should be success
The stderr should include 'ignored: --key1 (first)'
The stderr should include 'ignored: --key2'
The stderr should include "ignored: second [\$1]"
The variable ID should be undefined

The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:2 -h,--help'

# Dump
End

It 'Override default value of the definition by key=value argument'
preserve() { %preserve DEBUG; }
BeforeCall 'export ARGS_DEFINITION="--debug=DEBUG:*"'
AfterCall preserve

When call parse:arguments --debug='*,-common'

The status should be success
The variable DEBUG should eq '*,-common'

The stdout should include "[$line_2] export DEBUG='*'"
The stdout should include "[$line_3] export DEBUG='*,-common'"
The stderr should include 'Definition: --debug=DEBUG:*'

# Dump
End

#
# TODO: fix the code, raise error instead of warning
#
It 'Print warning on multiple arguments definition for indexed arguments'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="\$1,-i,--id,--pno=args_pno:dummy:2 -h,--help"'
AfterCall preserve

When call parse:arguments --help "first" "second"

The status should be success
The stderr should include "Warning. Indexed variable '\$1' should not be used for multiple arguments."
The variable ID should eq 'first'

# The stdout should include 'Too little arguments provided'
The stdout should include "[$line_2] export help='1'"
The stdout should include "[$line_4] export args_pno='first'"
The stderr should include "Definition: \$1,-i,--id,--pno=args_pno:dummy:2 -h,--help"

# Dump
End

#
# TODO: fix the code, args_pno should have "dummy" value
#
xIt 'Expect default "dummy" value for ID for --id flag'
preserve() { %preserve args_pno:ID; }
BeforeCall 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:1 -h,--help"'
AfterCall preserve

When call parse:arguments --id --help

The status should be success
The variable ID should eq 'dummy'

The stdout should include "[$line_2] export args_pno='dummy'"
The stdout should include "[$line_2] export help='1'"
The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:1 -h,--help'

Dump
End

Describe 'function parse:extract_output_definition():'
Describe "Parameters Matrix:"
Parameters
"#00" --cookies --cookies "cookies|1|0"
"#01" --cookies --cookies= "cookies|1|0"
"#02" --cookies --cookies=: "cookies||0"
"#03" --cookies --cookies=::1 "cookies||1"
"#04" --cookies --cookies=:default:1 "cookies|default|1"
"#05" --cookies --cookies=first "first|1|0"
"#06" --cookies --cookies=first: "first||0"
"#07" --cookies --cookies=first::1 "first||1"
"#08" --cookies --cookies=first:default "first|default|0"
"#09" --cookies --cookies=first:default:1 "first|default|1"
"#10" --cookies "\$1,-c,--cookies=first:default:1" "first|default|1"
"#11" "\$1" "\$1,-c,--cookies=first:default:1" "first|default|1"
"#12" "-c" "\$1,-c,--cookies=first:default:1" "first|default|1"
"#13" "-cookies=first:default:1" "\$1,-c,--cookies=first:default:1" "first|default|1"
End

It "parse:extract_output_definition for parse:arguments function $1" tags:inner
When call parse:extract_output_definition "$2" "$3"

The stdout should include "$4"
The stderr should include "~> $4"

# Dump
End
End

It "Expected Waring when Indexed parameters has reservation for more than one argument" tags:inner
When call parse:extract_output_definition "\$1" "\$1,-c,--cookies=first:default:2"

The stdout should include "first|default|2"
The stderr should include "Warning. Indexed variable '\$1' should not be used for multiple arguments."
The stderr should include "~> first|default|2"

# Dump
End
End
End
