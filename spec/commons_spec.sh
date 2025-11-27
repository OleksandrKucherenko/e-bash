#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2288

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-27
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

% TEST_DIR: "$SHELLSPEC_TMPBASE/.secrets"

Mock logger
	echo "$@"
End

Mock echo:Common
	echo "$@"
End

Include ".scripts/_commons.sh"

Describe "_commons.sh /"
	# remove colors in output
	BeforeCall "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset"
	BeforeCall 'export DEBUG="*"'

	It "args:isHelp returns true when --help flag is provided"
		When call args:isHelp --help

		The status should be success
		The output should eq true
		The error should eq ''
		# Dump
	End

	Describe "env:variable:or:secret:file /"
		It "No variable or secret file provided error"
			When call env:variable:or:secret:file "new_value" \
				"GITLAB_CI_INTEGRATION_TEST" \
				".secrets/gitlab_ci_integration_test"

			The status should be failure
			The output should include "ERROR: bash env variable '\$GITLAB_CI_INTEGRATION_TEST' or file '.secrets/gitlab_ci_integration_test' should be provided"
			The error should eq ''

			# Dump
		End

		It "Profided environment variable GITLAB_CI_INTEGRATION_TEST"
			preserve() { %preserve new_value:VALUE; }
			AfterCall preserve
			BeforeCall "export GITLAB_CI_INTEGRATION_TEST='<secret>'"
			When call env:variable:or:secret:file "new_value" \
				"GITLAB_CI_INTEGRATION_TEST" \
				".secrets/gitlab_ci_integration_test"

			The status should be success

			# DISABLED: eval does not publish new_value during test, due to test isolation
			# The variable VALUE should eq '<secret>'

			The output should include "Using var : \$GITLAB_CI_INTEGRATION_TEST ~> new_value"
			The error should eq ''
		End

		Describe "With provided secret file /"
			folder() { mkdir -p "$TEST_DIR"; }
			file() { touch "$TEST_DIR/gitlab_ci_integration_test"; }
			content() { echo "<secret>" >"$TEST_DIR/gitlab_ci_integration_test"; }
			destroy() { rm "$TEST_DIR/gitlab_ci_integration_test"; }

			Before 'folder; file; content'
			After 'destroy'

			It "Extract value from profided secret file gitlab_ci_integration_test"
				preserve() { %preserve new_value:VALUE; }
				AfterCall preserve

				When call env:variable:or:secret:file "new_value" \
					"GITLAB_CI_INTEGRATION_TEST" \
					"$TEST_DIR/gitlab_ci_integration_test"

				The status should be success
				The variable VALUE should eq '<secret>'

				The output should include "Using file: $TEST_DIR/gitlab_ci_integration_test ~> new_value"
				The error should eq ''

				# Dump
			End

			It "If provided environment variable and secret file, value selected from env variable"
				preserve() { %preserve new_value:VALUE; }
				AfterCall preserve
				BeforeCall "export GITLAB_CI_INTEGRATION_TEST='<secret2>'"

				When call env:variable:or:secret:file "new_value" \
					"GITLAB_CI_INTEGRATION_TEST" \
					"$TEST_DIR/gitlab_ci_integration_test"

				The status should be success
				The variable VALUE should eq '<secret2>'

				The output should include "Using var : \$GITLAB_CI_INTEGRATION_TEST ~> new_value"
				The error should eq ''
			End
		End
	End

	Describe "env:variable:or:secret:file:optional /"
		It "No variable or secret file provided error"
			When call env:variable:or:secret:file:optional "new_value" \
				"GITLAB_CI_INTEGRATION_TEST" \
				".secrets/gitlab_ci_integration_test"

			The status should be success
			The output should include "Note: bash env variable '\$GITLAB_CI_INTEGRATION_TEST' or file '.secrets/gitlab_ci_integration_test' can be provided."
			The error should eq ''

			# Dump
		End

		It "Profided environment variable GITLAB_CI_INTEGRATION_TEST"
			preserve() { %preserve new_value:VALUE; }
			AfterCall preserve
			BeforeCall "export GITLAB_CI_INTEGRATION_TEST='<secret>'"
			When call env:variable:or:secret:file:optional "new_value" \
				"GITLAB_CI_INTEGRATION_TEST" \
				".secrets/gitlab_ci_integration_test"

			# Dump

			The status should be success # return: 1
			The variable VALUE should eq '<secret>'

			The output should include "Using var : \$GITLAB_CI_INTEGRATION_TEST ~> new_value"
			The error should eq ''
		End

		Describe "With provided secret file /"
			folder() { mkdir -p "$TEST_DIR"; }
			file() { touch "$TEST_DIR/gitlab_ci_integration_test"; }
			content() { echo "<secret>" >"$TEST_DIR/gitlab_ci_integration_test"; }
			destroy() { rm "$TEST_DIR/gitlab_ci_integration_test"; }

			Before 'folder; file; content'
			After 'destroy'

			It "Extract value from profided secret file gitlab_ci_integration_test"
				preserve() { %preserve new_value:VALUE; }
				AfterCall preserve

				When call env:variable:or:secret:file:optional "new_value" \
					"GITLAB_CI_INTEGRATION_TEST" \
					"$TEST_DIR/gitlab_ci_integration_test"

				# Dump

				The status should be success # return: 2
				The variable VALUE should eq '<secret>'

				The output should include "Using file: $TEST_DIR/gitlab_ci_integration_test ~> new_value"
				The error should eq ''
			End
		End
	End
End
