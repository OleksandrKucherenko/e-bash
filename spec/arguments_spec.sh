#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

eval "$(shellspec - -c) exit 1"

export line_1="133"
export line_2="144"
export line_3="159"
export line_4="172"

xDescribe '_arguments.sh'
	BeforeRun 'export DEBUG="*"'
	Include ".scripts/_arguments.sh"

	It 'On no ARGS_DEFINITION provided, expected fallback to predefined flags'
		# preserve() { %preserve version:VERSION; }
		# AfterRun preserve
		# When run source .scritps/_arguments.sh --help --version --debug --something
		When call parse_arguments --help --version --debug --something

		The status should be success
		The variable VERSION should eq '1.0.0'

		# debug output is printed
		The stdout should include "[$line_2] export help=\"1\""
		The stdout should include "[$line_2] export version=\"1.0.0\""
		The stdout should include "[$line_2] export DEBUG=\"*\""
		The stdout should include 'definition to output index:'
		The stdout should include "'index', 'output variable name', 'args quantity', 'defaults':"

		The stderr should include 'Definition: -h,--help -v,--version=:1.0.0 --debug=DEBUG:*'
		The stderr should include 'ignored: --something'

		Dump
	End
End

xDescribe "next"
	xIt 'ARGS_DEFINITION set to "-h,--help" produce help env variable with value 1'
		preserve() { %preserve help:HELP; }
		BeforeRun 'export ARGS_DEFINITION="-h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --help

		The status should be success
		The variable HELP should eq '1'

		The stdout should include "[$line_2] export help=\"1\""
		The stdout should include 'extracted: help=1'

		The stderr should include 'Definition: -h,--help'

		# Dump
	End

	xIt 'Extract argument after --id flag into args_pno variable'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno::1 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --id "test" --help

		The status should be success
		The variable ID should eq 'test'

		The stdout should include "[$line_1] export args_pno=\"test\""
		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno::1 -h,--help'

		# Dump
	End

	xIt 'Extract value into args_pno variable from key=value argument'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno::1 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --id="test" --help

		The status should be success
		The variable ID should eq 'test'

		The stdout should include "[$line_1] export args_pno=\"test\""
		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno::1 -h,--help'

		# Dump
	End

	xIt 'Force <empty> value into args_pno variable from key=value argument'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno::1 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --id="" --help

		The status should be success
		The variable ID should eq '<empty>'

		The stdout should include "[$line_1] export args_pno=\"<empty>\""
		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno::1 -h,--help'

		# Dump
	End

	xIt 'Force overwrite of default "dummy" value by <empty> from key=value argument'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:1 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --id="" --help

		The stdout should include "[$line_1] export args_pno=\"<empty>\""
		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:1 -h,--help'
		The status should be success
		The variable ID should eq '<empty>'

		# Dump
	End

	xIt 'Extract multiple arguments into args_pno variable, space separated array'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:2 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --id "first" "second" --help

		The status should be success
		The variable ID should eq 'first second'

		The stdout should include "[$line_1] export args_pno=\"first second\""
		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:2 -h,--help'

		# Dump
	End

	xIt 'Missed argument for --id flag raise error message'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:2 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --help --id "first"

		The status should be failure
		The variable ID should be undefined
		The stdout should include 'Error. Too little arguments provided'

		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:2 -h,--help'

		# Dump
	End

	xIt 'Ignore undefined flag arguments and print warning message to stderr'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:2 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --help --key1="first" --key2 "second"

		The status should be success
		The stderr should include 'ignored: --key1 (first)'
		The stderr should include 'ignored: --key2'
		The stderr should include "ignored: second [\$1]"
		The variable ID should be undefined

		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:2 -h,--help'

		# Dump
	End

	xIt 'Override default value of the definition by key=value argument'
		preserve() { %preserve DEBUG; }
		BeforeRun 'export ARGS_DEFINITION="--debug=DEBUG:*"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --debug='*,-common'

		The status should be success
		The variable DEBUG should eq '*,-common'

		The stdout should include "[$line_2] export DEBUG=\"*\""
		The stdout should include "[$line_3] export DEBUG=\"*,-common\""
		The stderr should include 'Definition: --debug=DEBUG:*'

		# Dump
	End

	#
	# TODO: fix the code, raise error instead of warning
	#
	xIt 'Print warning on multiple arguments definition for indexed arguments'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="\$1,-i,--id,--pno=args_pno:dummy:2 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --help "first" "second"

		The status should be success
		The stderr should include "Warning. Indexed variable '\$1' should not be used for multiple arguments."
		The variable ID should eq 'first'

		# The stdout should include 'Too little arguments provided'
		The stdout should include "[$line_2] export help=\"1\""
		The stdout should include "[$line_4] export args_pno=\"first\""
		The stderr should include "Definition: \$1,-i,--id,--pno=args_pno:dummy:2 -h,--help"

		# Dump
	End

End

xDescribe "In Progress:"
	BeforeRun 'export DEBUG="*"'

	#
	# TODO: fix the code, args_pno should have "dummy" value
	#
	It 'Expect default "dummy" value for ID for --id flag'
		preserve() { %preserve args_pno:ID; }
		BeforeRun 'export ARGS_DEFINITION="-i,--id,--pno=args_pno:dummy:1 -h,--help"'
		AfterRun preserve

		When run source .scritps/_arguments.sh --id --help

		The status should be success
		The variable ID should eq 'dummy'

		The stdout should include "[$line_2] export args_pno=\"dummy\""
		The stdout should include "[$line_2] export help=\"1\""
		The stderr should include 'Definition: -i,--id,--pno=args_pno:dummy:1 -h,--help'

		Dump
	End

End

xDescribe 'Utility functions:'
	# BeforeRun 'export DEBUG="*"'
	Include .scripts/_logger.sh
	Include .scritps/_arguments.sh

	It 'Extract output definition for parse_arguments function' tags:inner
		When call __extract_output_definition --cookies --cookies=first:default:1

		The stderr should include '~> cookies|default|1'
		The stdout should include 'cookies|default|1'

		Dump
	End

End
