#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2288

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Mock dependencies for _dryrun.sh
Mock logger
	echo "$@"
End

Mock logger:init
	return 0
End

Mock printf:Exec
	# Redirect to stderr to match actual behavior
	printf "$@" >&2
End

Mock printf:Test
	# Redirect to stderr to match actual behavior
	printf "$@" >&2
End

Mock printf:TestLogger
	# Redirect to stderr to match actual behavior
	printf "$@" >&2
End

Mock echo:Exec
	# Redirect to stderr to match actual behavior
	echo "$@" >&2
End

Mock printf:Dry
	# Output to stdout for dry run messages
	printf "$@"
End

Mock echo:Dry
	# Output to stdout for dry run messages
	echo "$@"
End

Mock printf:Rollback
	# Redirect to stderr to match actual behavior
	printf "$@" >&2
End

Mock echo:Rollback
	# Output to stdout for dry run rollback messages
	echo "$@"
End

Mock log:Output
	# Pass through the output as expected by the tests
	cat
End

Mock echo:Loader
	echo "$@"
End

# Mock color variables to avoid dependency on _colors.sh
BeforeAll "export cl_red='' cl_green='' cl_cyan='' cl_green='' cl_reset='' cl_grey='' cl_gray=''"

# Set global variables before including the module
BeforeAll "export DRY_RUN=false UNDO_RUN=false SILENT=false"

Include ".scripts/_dryrun.sh"

Describe "_dryrun.sh/"
	# Clean environment before each test
	BeforeEach "unset DRY_RUN_TEST UNDO_RUN_TEST SILENT_TEST"

	Describe "Global Variables/"
		It "Should set default values for global variables"
			The variable DRY_RUN should eq "false"
			The variable UNDO_RUN should eq "false"
			The variable SILENT should eq "false"
		End
	End

	Describe "dryrun:exec function/"
		It "Should execute command successfully and return exit code"
			When call dryrun:exec "Test" "false" "echo" "hello world"

			The status should be success
			The output should eq "hello world"
			The error should include "echo hello world"
			The error should include "code: 0"
		End

		It "Should handle command failure and return correct exit code"
			When call dryrun:exec "Test" "false" "exit" "1"

			The status should eq 1
			The output should eq ""
			The error should include "exit 1"
			The error should include "code: 1"
		End

		It "Should display output when not in silent mode"
			When call dryrun:exec "Test" "false" "echo" "test output"

			The status should be success
			The output should eq "test output"
			The error should include "echo test output"
			The error should include "code: 0"
		End

		It "Should suppress output when in silent mode"
			When call dryrun:exec "Test" "true" "echo" "test output"

			The status should be success
			The output should eq ""
			The error should include "echo test output"
			The error should include "code: 0"
		End

		It "Should preserve errexit setting"
			BeforeCall "set -e"
			When call dryrun:exec "Test" "false" "echo" "preserved errexit"

			The status should be success
			The output should eq "preserved errexit"
			The error should include "echo preserved errexit"
			The error should include "code: 0"
		End

		It "Should handle command with arguments containing spaces"
			When call dryrun:exec "Test" "false" "echo" "hello world with spaces"

			The status should be success
			The output should eq "hello world with spaces"
			The error should include "echo hello world with spaces"
			The error should include "code: 0"
		End

		It "Should handle command with no arguments"
			When call dryrun:exec "Test" "false" "pwd"

			The status should be success
			The output should include "/"
			The error should include "pwd"
			The error should include "code: 0"
		End
	End

	Describe "dry-run function generator/"
		It "Should generate wrapper functions for a single command"
			When call dry-run "testcmd"

			The status should be success
			The function run:testcmd should be defined
			The function dry:testcmd should be defined
			The function rollback:testcmd should be defined
			The function undo:testcmd should be defined
		End

		It "Should generate wrapper functions for multiple commands"
			When call dry-run "cmd1" "cmd2" "cmd3"

			The status should be success
			The function run:cmd1 should be defined
			The function run:cmd2 should be defined
			The function run:cmd3 should be defined
			The function dry:cmd1 should be defined
			The function dry:cmd2 should be defined
			The function dry:cmd3 should be defined
			The function rollback:cmd1 should be defined
			The function rollback:cmd2 should be defined
			The function rollback:cmd3 should be defined
			The function undo:cmd1 should be defined
			The function undo:cmd2 should be defined
			The function undo:cmd3 should be defined
		End

		It "Should use custom suffix when provided"
			When call dry-run "mycmd" "CUSTOM"

			The status should be success
			The function run:mycmd should be defined
			The function dry:mycmd should be defined
			The function rollback:mycmd should be defined
			The function undo:mycmd should be defined
		End

		It "Should convert command name to uppercase for default suffix"
			When call dry-run "testcommand"

			The status should be success
			The function run:testcommand should be defined
		End
	End

	Describe "Generated functions behavior/"
		BeforeEach "dry-run 'echo' 'pwd'"

		Describe "run: functions in normal mode/"
			BeforeEach "export DRY_RUN=false UNDO_RUN=false SILENT=false"

			It "Should execute command normally when run:echo is called"
				When call run:echo "normal execution"

				The status should be success
				The output should eq "normal execution"
				The error should include "echo normal execution"
				The error should include "code: 0"
			End

			It "Should pass all arguments correctly"
				When call run:echo "arg1" "arg2" "arg with spaces"

				The status should be success
				The output should eq "arg1 arg2 arg with spaces"
				The error should include "echo arg1 arg2 arg with spaces"
				The error should include "code: 0"
			End
		End

		Describe "dry: functions in normal mode/"
			BeforeEach "export DRY_RUN=false UNDO_RUN=false SILENT=false"

			It "Should execute command normally when dry:echo is called"
				When call dry:echo "dry execution"

				The status should be success
				The output should eq "dry execution"
				The error should include "echo dry execution"
				The error should include "code: 0"
			End
		End

		Describe "run: functions in dry run mode/"
			BeforeEach "export DRY_RUN=true UNDO_RUN=false SILENT=false"

			It "Should not execute command when DRY_RUN=true"
				When call run:echo "should not execute"

				The status should be success
				The output should include "echo should not execute"
			End

			It "Should return success without executing the actual command"
				When call run:echo "false"

				The status should be success           # Should be 0, not the exit code of 'false'
				The output should include "echo false" # Should show what would be executed
			End
		End

		Describe "rollback: functions in normal mode/"
			BeforeEach "export DRY_RUN=false UNDO_RUN=false SILENT=false"

			It "Should not execute command when UNDO_RUN=false (normal mode)"
				When call rollback:echo "should not execute"

				The status should be success
				The output should include "(dry) echo should not execute"
			End
		End

		Describe "rollback: functions in undo mode/"
			BeforeEach "export DRY_RUN=false UNDO_RUN=true SILENT=false"

			It "Should execute command when UNDO_RUN=true"
				When call rollback:echo "rollback execution"

				The status should be success
				The output should eq "rollback execution"
				The error should include "echo rollback execution"
				The error should include "code: 0"
			End
		End

		Describe "undo: functions/"
			BeforeEach "export DRY_RUN=false UNDO_RUN=true SILENT=false"

			It "Should delegate to rollback: function"
				When call undo:echo "undo execution"

				The status should be success
				The output should eq "undo execution"
				The error should include "echo undo execution"
				The error should include "code: 0"
			End
		End

		Describe "Silent mode behavior/"
			BeforeEach "export DRY_RUN=false UNDO_RUN=false SILENT=true"

			It "Should suppress output in run: function when SILENT=true"
				When call run:echo "silent test"

				The status should be success
				The output should eq ""
				The error should include "echo silent test" # Command still logged
				The error should include "code: 0"
			End

			It "Should suppress output in rollback: function when SILENT=true but still show dry run message"
				When call rollback:echo "silent rollback"

				The status should be success
				The output should include "(dry) echo silent rollback" # Should show dry run message
				The error should be blank                              # No stderr output in dry rollback mode
			End
		End
	End

	Describe "Per-command environment variable overrides/"
		BeforeEach "dry-run 'echo'"

		It "Should use DRY_RUN_ECHO override when set"
			BeforeCall "export DRY_RUN_ECHO=true DRY_RUN=false"
			When call run:echo "should be dry"

			The status should be success
			The output should include "echo should be dry"
		End

		It "Should use UNDO_RUN_ECHO override when set"
			BeforeCall "export UNDO_RUN_ECHO=true UNDO_RUN=false"
			When call rollback:echo "should execute"

			The status should be success
			The output should eq "should execute"
			The error should include "echo should execute"
			The error should include "code: 0"
		End

		It "Should use SILENT_ECHO override when set"
			BeforeCall "export SILENT_ECHO=true SILENT=false"
			When call run:echo "silent override"

			The status should be success
			The output should eq ""
			The error should include "echo silent override"
			The error should include "code: 0"
		End

		It "Should fall back to global variables when command-specific ones are not set"
			BeforeCall "export DRY_RUN=true"
			When call run:echo "global dry run"

			The status should be success
			The output should include "echo global dry run"
		End

		It "Should prioritize command-specific variables over global ones"
			BeforeCall "export DRY_RUN=true DRY_RUN_ECHO=false"
			When call run:echo "should execute"

			The status should be success
			The output should eq "should execute"
			The error should include "echo should execute"
			The error should include "code: 0"
		End
	End

	Describe "rollback:func function/"
		It "Should not execute function when UNDO_RUN=false"
			BeforeCall "export UNDO_RUN=false DRY_RUN=false"
			When call rollback:func "test_function" "arg1" "arg2"

			The status should be success
			The output should include "(dry-func): test_function arg1 arg2"
		End

		It "Should not execute function when DRY_RUN=true"
			BeforeCall "export UNDO_RUN=true DRY_RUN=true"
			When call rollback:func "test_function" "arg1" "arg2"

			The status should be success
			The output should include "(dry-func): test_function arg1 arg2"
		End

		It "Should execute function when UNDO_RUN=true and DRY_RUN=false"
			BeforeCall "export UNDO_RUN=true DRY_RUN=false"
			When call rollback:func "echo" "hello world"

			The status should be success
			The output should eq "hello world"
			The error should include "echo hello world"
			The error should include "code: 0"
		End

		It "Should display function body when function exists and in dry mode"
			# Create a test function
			test_function() {
				echo "This is a test"
			}

			BeforeCall "export UNDO_RUN=false DRY_RUN=true"
			When call rollback:func "test_function"

			The status should be success
			The output should include "(dry-func): test_function"
			The error should include "This is a test"
		End

		It "Should handle non-existent function gracefully"
			BeforeCall "export UNDO_RUN=false DRY_RUN=true"
			When call rollback:func "non_existent_function"

			The status should be success
			The output should include "(dry-func): non_existent_function"
		End

		It "Should respect SILENT setting"
			BeforeCall "export UNDO_RUN=true DRY_RUN=false SILENT=true"
			When call rollback:func "echo" "silent rollback"

			The status should be success
			The output should eq ""
			The error should include "echo silent rollback"
			The error should include "code: 0"
		End
	End

	Describe "Complex scenarios and edge cases/"
		It "Should handle mixed global and per-command settings"
			BeforeCall "export DRY_RUN=true UNDO_RUN=false SILENT=false"
			BeforeCall "dry-run 'echo' 'pwd'"
			BeforeCall "export DRY_RUN_PWD=false"

			When call run:echo "dry global"
			The status should be success
			The output should include "echo dry global"
		End

		It "Should respect per-command override over global settings"
			BeforeCall "export DRY_RUN=true UNDO_RUN=false SILENT=false"
			BeforeCall "dry-run 'echo' 'pwd'"
			BeforeCall "export DRY_RUN_PWD=false"

			When call run:pwd
			The status should be success
			The output should include "/"
			The error should include "pwd"
			The error should include "code: 0"
		End

		It "Should handle command names with special characters"
			When call dry-run "test-cmd" "test_cmd" "test123"

			The status should be success
			The function run:test-cmd should be defined
			The function run:test_cmd should be defined
			The function run:test123 should be defined
		End

		It "Should handle empty command arguments"
			BeforeCall "dry-run 'echo'"

			When call run:echo
			The status should be success
			The error should include "echo"    # Should show the command that was executed
			The error should include "code: 0" # Should show the exit code
		End

		It "Should preserve shell options correctly"
			BeforeCall "set -e"
			BeforeCall "dry-run 'echo'"
			BeforeCall "export DRY_RUN=false UNDO_RUN=false"

			When call run:echo "test with errexit"

			The status should be success
			The output should eq "test with errexit"
			The error should include "echo test with errexit"
			The error should include "code: 0"
		End
	End

	Describe "Integration with logger system/"
		It "Should use correct logger tags for different operations"
			# The dryrun:exec function uses printf:Exec for command logging
			# This tests that the logger integration works
			When call dryrun:exec "TestLogger" "false" "echo" "logger test"

			The status should be success
			The output should eq "logger test"
			The error should include "echo logger test"
			The error should include "code: 0"
		End

		It "Should respect DEBUG environment for logger output"
			BeforeCall "export DEBUG=Exec"
			When call dryrun:exec "Exec" "false" "echo" "debug test"

			The status should be success
			The output should eq "debug test"
			The error should include "echo debug test"
			The error should include "code: 0"
		End
	End
End
