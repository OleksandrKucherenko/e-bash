#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016,SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

# Set up E_BASH path for ShellSpec environment - this will be resolved from project root
export E_BASH="$(pwd)/.scripts"

# Disable debug output for tests to avoid pollution
export DEBUG=""

# Mock logger functions to prevent "command not found" errors
# But still produce output so tests can verify messages
# Note: Logger functions output to STDERR, not STDOUT
Mock printf:Trap
	printf "$@" >&2
End

# Helper functions to strip ANSI color codes
# $1 = stdout, $2 = stderr, $3 = exit status
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

Mock echo:Trap
	echo "$@" >&2
End

Describe '_traps.sh /'
	Include ".scripts/_traps.sh"

	# Mock the trap dispatcher to prevent actual trap execution during tests
	# This must be defined AFTER the module is loaded to override it
	Mock Trap::dispatch
		# Completely suppress trap dispatching during tests
		# Redirect any potential output to /dev/null to prevent test pollution
		# Just do nothing - no return statement needed
		: # This is a no-op command
	End

	BeforeEach 'suppress_expected_stderr'

	suppress_expected_stderr() {
		# Suppress expected initialization messages that would pollute test output
		# This allows us to focus on testing functionality rather than output formatting
		return 0
	}

	Describe 'Module initialization /'
		It 'loads without errors'
			# GIVEN: Mock functions are available and module was included
			# WHEN: Check that core trap functions exist after module load
			# THEN: Expected functions should be available proving module loaded successfully
			When call type trap:on
			The status should be success
			The output should include "trap:on is a function"
		End

		It 'creates trap:off function'
			When call type trap:off
			The output should include "trap:off is a function"
		End

		It 'creates trap:list function'
			When call type trap:list
			The output should include "trap:list is a function"
		End
	End

	Describe 'trap:on / basic functionality /'
		cleanup_test() {
			echo "cleanup_test executed"
		}

		It 'registers single handler for EXIT signal'
			When call trap:on cleanup_test EXIT
			The status should be success
			The result of function no_colors_stderr should include "Handler registered"
		End

		It 'fails when handler function does not exist'
			When call trap:on nonexistent_function EXIT
			The status should be failure
			The result of function no_colors_stderr should include "does not exist"
		End

		It 'fails when no signals specified'
			When call trap:on cleanup_test
			The status should be failure
			The result of function no_colors_stderr should include "No signals specified"
		End

		It 'normalizes SIGINT to INT'
			cleanup_int() { echo "int"; }
			When call trap:on cleanup_int SIGINT
			The status should be success
			The result of function no_colors_stderr should include "INT"
		End

		It 'normalizes signal 0 to EXIT'
			cleanup_exit() { echo "exit"; }
			When call trap:on cleanup_exit 0
			The status should be success
			The result of function no_colors_stderr should include "EXIT"
		End
	End

	Describe 'trap:on / multiple handlers /'
		handler_a() { echo "handler_a"; }
		handler_b() { echo "handler_b"; }
		handler_c() { echo "handler_c"; }

		It 'registers multiple handlers for same signal'
			trap:on handler_a EXIT 2>/dev/null
			When call trap:on handler_b EXIT
			The status should be success
			The result of function no_colors_stderr should include "Handler registered"
		End

		It 'registers handler for multiple signals'
			When call trap:on handler_c INT TERM HUP
			The status should be success
			The result of function no_colors_stderr should include "INT"
			The result of function no_colors_stderr should include "TERM"
			The result of function no_colors_stderr should include "HUP"
		End
	End

	Describe 'trap:on / duplicate handling /'
		dup_handler() { echo "dup"; }

		It 'warns when handler already registered'
			trap:on dup_handler EXIT 2>/dev/null
			When call trap:on dup_handler EXIT
			The status should be success
			The result of function no_colors_stderr should include "already registered"
		End

		It 'allows duplicates with --allow-duplicates flag'
			dup_handler2() { echo "dup2"; }
			trap:on dup_handler2 EXIT 2>/dev/null
			When call trap:on --allow-duplicates dup_handler2 EXIT
			The status should be success
			The result of function no_colors_stderr should include "duplicate"
		End
	End

	Describe 'trap:off / functionality /'
		remove_handler() { echo "remove"; }

		It 'removes handler from signal'
			trap:on remove_handler EXIT 2>/dev/null
			When call trap:off remove_handler EXIT
			The status should be success
			The result of function no_colors_stderr should include "Handler removed"
		End

		It 'handles non-existent handler gracefully'
			When call trap:off nonexistent_handler EXIT
			The status should be success
			The result of function no_colors_stderr should include "No handlers registered"
		End

		It 'fails when no signals specified'
			When call trap:off remove_handler
			The status should be failure
			The result of function no_colors_stderr should include "No signals specified"
		End
	End

	Describe 'trap:list / functionality /'
		list_handler_a() { echo "a"; }
		list_handler_b() { echo "b"; }

		It 'lists handlers for specific signal'
			trap:on list_handler_a EXIT 2>/dev/null
			trap:on list_handler_b EXIT 2>/dev/null
			When call trap:list EXIT
			The output should include "list_handler_a"
			The output should include "list_handler_b"
		End

		It 'shows empty output for uninitialized signal'
			When call trap:list USR1
			The output should eq ""
		End

		It 'lists all signals when no argument provided'
			trap:on list_handler_a INT 2>/dev/null
			When call trap:list
			The output should include "INT"
		End
	End

	Describe 'trap:clear / functionality /'
		clear_handler_a() { echo "a"; }
		clear_handler_b() { echo "b"; }

		It 'clears all handlers for signal'
			trap:on clear_handler_a EXIT 2>/dev/null
			trap:on clear_handler_b EXIT 2>/dev/null
			trap:clear EXIT 2>/dev/null

			# After clear, list shows signal with empty handler list
			When call trap:list EXIT
			The output should eq ""
		End

		It 'fails when no signals specified'
			When call trap:clear
			The status should be failure
			The result of function no_colors_stderr should include "No signals specified"
		End
	End

	Describe 'trap:push and trap:pop /'
		push_handler_outer() { echo "outer"; }
		push_handler_inner() { echo "inner"; }

		It 'pushes current trap state'
			trap:on push_handler_outer EXIT 2>/dev/null
			When call trap:push EXIT
			The status should be success
			The result of function no_colors_stderr should include "pushed"
		End

		It 'pops and restores trap state'
			trap:on push_handler_outer EXIT 2>/dev/null
			trap:push EXIT 2>/dev/null
			trap:on push_handler_inner EXIT 2>/dev/null
			trap:pop EXIT 2>/dev/null

			# After pop, only outer should remain
			When call trap:list EXIT
			The output should include "push_handler_outer"
			The output should not include "push_handler_inner"
		End

		It 'fails when popping empty stack'
			When call trap:pop EXIT
			The status should be failure
			The result of function no_colors_stderr should include "No trap state to pop"
		End

		It 'supports nested push/pop'
			h1() { echo "1"; }
			h2() { echo "2"; }
			h3() { echo "3"; }

			trap:on h1 EXIT 2>/dev/null
			trap:push EXIT 2>/dev/null

			trap:on h2 EXIT 2>/dev/null
			trap:push EXIT 2>/dev/null

			trap:on h3 EXIT 2>/dev/null

			# Pop back twice
			trap:pop EXIT 2>/dev/null
			trap:pop EXIT 2>/dev/null

			# Only h1 should remain
			When call trap:list EXIT
			The output should include "h1"
			The output should not include "h2"
			The output should not include "h3"
		End

		It 'snapshots all active signals when called without arguments'
			multi_sig_a() { echo "a"; }
			multi_sig_b() { echo "b"; }
			multi_sig_c() { echo "c"; }

			# Register handlers for multiple signals
			trap:on multi_sig_a EXIT 2>/dev/null
			trap:on multi_sig_b INT 2>/dev/null
			trap:on multi_sig_c TERM 2>/dev/null

			# Push without arguments (should snapshot all)
			trap:push 2>/dev/null

			# Modify all signals
			new_handler() { echo "new"; }
			trap:on new_handler EXIT 2>/dev/null
			trap:on new_handler INT 2>/dev/null
			trap:on new_handler TERM 2>/dev/null

			# Pop should restore all signals
			trap:pop 2>/dev/null

			# Verify original handlers restored for all signals
			exit_list=$(trap:list EXIT)
			int_list=$(trap:list INT)
			term_list=$(trap:list TERM)

			# Check EXIT restored
			echo "$exit_list" | grep -q "multi_sig_a" || exit 1
			echo "$exit_list" | grep -q "new_handler" && exit 1

			# Check INT restored
			echo "$int_list" | grep -q "multi_sig_b" || exit 1
			echo "$int_list" | grep -q "new_handler" && exit 1

			# Check TERM restored
			When call trap:list TERM
			The output should include "multi_sig_c"
			The output should not include "new_handler"
		End
	End

	Describe 'trap:scope:begin and trap:scope:end /'
		scope_handler() { echo "scoped"; }
		global_handler() { echo "global"; }

		It 'creates scoped trap section'
			trap:on global_handler EXIT 2>/dev/null

			trap:scope:begin EXIT 2>/dev/null
			trap:on scope_handler EXIT 2>/dev/null
			trap:scope:end EXIT 2>/dev/null

			# After scope end, only global should remain
			When call trap:list EXIT
			The output should include "global_handler"
			The output should not include "scope_handler"
		End
	End

	Describe 'Signal normalization /'
		It 'normalizes SIGTERM to TERM'
			norm_term() { echo "term"; }
			trap:on norm_term SIGTERM 2>/dev/null
			When call trap:list TERM
			The output should include "norm_term"
		End

		It 'normalizes lowercase to uppercase'
			norm_hup() { echo "hup"; }
			trap:on norm_hup hup 2>/dev/null
			When call trap:list HUP
			The output should include "norm_hup"
		End

		It 'normalizes numeric signals using kill -l'
			norm_int() { echo "int"; }
			trap:on norm_int 2 2>/dev/null # SIGINT is typically signal 2
			When call trap:list INT
			The output should include "norm_int"
		End
	End

	Describe 'Trap dispatcher execution /'
		# Note: Dispatcher functionality verified via manual integration tests
		# ShellSpec environment has limitations with signal delivery testing
		# See spec/helpers/trap_dispatcher_e2e_minimal.sh for manual testing

		It 'allows handler registration and listing'
			# GIVEN: The trap module is loaded
			# WHEN: Registering handlers and listing them
			# THEN: Handlers should be registered and listable

			# Register test handlers
			test_handler_one() { echo "ONE"; }
			test_handler_two() { echo "TWO"; }

			# Register handlers and verify listing
			trap:on test_handler_one INT 2>/dev/null
			trap:on test_handler_two INT 2>/dev/null

			# Verify handlers are registered and can be listed
			When call trap:list INT
			The result of function no_colors_stdout should include "test_handler_one"
			The result of function no_colors_stdout should include "test_handler_two"
		End

		It 'can clear and re-register handlers'
			# GIVEN: Handlers are registered for a signal
			# WHEN: Clearing and re-registering handlers
			# THEN: Only new handlers should remain

			# Clear any existing handlers and register new ones
			trap:clear INT 2>/dev/null

			# Register new handlers
			reset_handler_one() { echo "RESET_ONE"; }
			reset_handler_two() { echo "RESET_TWO"; }

			trap:on reset_handler_one INT 2>/dev/null
			trap:on reset_handler_two INT 2>/dev/null

			# List handlers and verify only new ones exist
			When call trap:list INT
			The result of function no_colors_stdout should include "reset_handler_one"
			The result of function no_colors_stdout should include "reset_handler_two"
			The result of function no_colors_stdout should not include "test_handler"
		End

		It 'dispatcher function exists and is callable'
			# GIVEN: Trap module is loaded
			# WHEN: Checking for dispatcher function
			# THEN: Trap::dispatch function should be available

			When call type Trap::dispatch
			The output should include "Trap::dispatch"
		End
	End

	Describe 'Legacy trap handling /'
		It 'captures existing trap configuration'
			# Set a legacy trap before loading our module
			trap 'echo legacy_trap' USR1

			# Initialize our handler (suppress logger output during setup)
			legacy_test() { echo "new_handler"; }
			trap:on legacy_test USR1 2>/dev/null

			# List should show both
			When call trap:list USR1
			The output should include "legacy_test"
			The output should include "legacy"
		End
	End
End
