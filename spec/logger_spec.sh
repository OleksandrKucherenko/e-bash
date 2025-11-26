#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

export SCRIPT_DIR=".scripts"

Describe '_logger.sh /'
	Include ".scripts/_logger.sh"

	# Cleanup mechanism
	AfterAll 'logger:cleanup'

	Context 'Basic logger registration/'
		It 'returns empty output when registering pre-defined common logger'
			BeforeCall 'export DEBUG="*"'
			When call logger "common"

			The status should be success
			The output should eq ''
			The error should eq ''
		End

		It 'outputs TAGS dump when registering token after common loggers'
			BeforeCall 'export DEBUG="*" && logger common && logger token'
			When call echo:Token "test token echo command"

			The status should be success
			The output should include 'test token echo command'
			The error should include 'Logger tags  : common token | 1 1'
		End
	End

	Context 'Logger with custom prefixes/'
		It 'echo:Tag outputs with custom prefix'
			BeforeCall 'export DEBUG="*" && logger common && logger token && TAGS_PREFIX[token]="[token] "'
			When call echo:Token "test token echo command"

			The status should be success
			The output should include '[token] test token echo command'
			The error should include 'Logger tags  : common token | 1 1'
		End

		It 'printf:Tag outputs with custom prefix (macOS compatibility test)'
			BeforeCall 'export DEBUG="*" && logger common && logger token && TAGS_PREFIX[token]="[token] "'
			When call printf:Token "%s" "test token echo command"

			The status should be success
			The output should include '[token] test token echo command'
			The error should include 'Logger tags  : common token | 1 1'
		End

		It 'printf:Tag with custom prefix and format specifiers'
			setup() {
				export DEBUG="*"
				logger "test"
				logger:prefix "test" "[TEST] "
			}
			BeforeCall 'setup'

			When call printf:Test "Value: %s" "123"

			The status should be success
			The output should eq '[TEST] Value: 123'
		End

		It 'echo:Tag with custom prefix using logger:prefix helper'
			setup() {
				export DEBUG="*"
				logger "test"
				logger:prefix "test" ">> "
			}
			BeforeCall 'setup'

			When call echo:Test "Hello"

			The status should be success
			The output should eq '>> Hello'
		End

		It 'echo:Tag with multiple arguments'
			setup() {
				export DEBUG="*"
				logger "test"
				logger:prefix "test" ""
			}
			BeforeCall 'setup'

			When call echo:Test "Part1" "Part2"

			The status should be success
			The output should eq 'Part1 Part2'
		End
	End

	Context 'DEBUG filtering logic/'
		It 'enables logger when tag explicitly listed'
			setup() {
				export DEBUG="test"
				logger "test"
			}
			BeforeCall 'setup'

			When call echo:Test "Visible"
			The output should eq 'Visible'
		End

		It 'enables logger via wildcard'
			setup() {
				export DEBUG="*"
				logger "test"
			}
			BeforeCall 'setup'

			When call echo:Test "Visible"
			The output should eq 'Visible'
		End

		It 'disables logger via negation pattern'
			setup() {
				export DEBUG="*,-test"
				logger "test"
			}
			BeforeCall 'setup'

			When call echo:Test "Hidden"
			The status should be failure
			The output should eq ''
		End

		It 'disables logger by default when DEBUG is empty'
			setup() {
				export DEBUG=""
				logger "test"
			}
			BeforeCall 'setup'

			When call echo:Test "Hidden"
			The status should be failure
			The output should eq ''
		End

		It 'enables logger in complex DEBUG list'
			setup() {
				export DEBUG="other,test,another"
				logger "test"
			}
			BeforeCall 'setup'

			When call echo:Test "Visible"
			The output should eq 'Visible'
		End

		It 'isolates multiple loggers (disabled logger fails)'
			setup() {
				export DEBUG="logA"
				logger "logA"
				logger "logB"
			}
			BeforeCall 'setup'

			When call echo:LogB "Hidden"
			The status should be failure
			The output should eq ''
		End
	End

	Context 'Advanced features/'
		It 'handles printf:Tag with special characters (\n \t)'
			setup() {
				export DEBUG="*"
				logger "test"
			}
			BeforeCall 'setup'

			When call printf:Test "Line1\nLine2\tTab"
			The output should eq "$(printf "Line1\nLine2\tTab")"
		End

		It 'handles printf:Tag with % in arguments'
			setup() {
				export DEBUG="*"
				logger "test"
			}
			BeforeCall 'setup'

			When call printf:Test "Val: %s" "100%"
			The output should eq 'Val: 100%'
		End

		It 'initializes logger with logger:init helper'
			setup() {
				export DEBUG="*"
				# Redirect to stdout (>&1) for capture
				logger:init "test" "[T] " ">&1"
			}
			BeforeCall 'setup'

			When call echo:Test "Init"
			The output should eq '[T] Init'
		End

		It 'redirects logger output to /dev/null'
			setup() {
				export DEBUG="*"
				logger:init "test" "" ">/dev/null"
			}
			BeforeCall 'setup'

			When call echo:Test "Gone"
			The output should eq ''
		End

		It 'preserves and restores state with logger:push/pop'
			setup() {
				export DEBUG="*"
				logger "test"
				TAGS[test]=1
				logger:push
				TAGS[test]=0
				logger:pop
			}
			BeforeCall 'setup'

			When call echo:Test "Restored"
			The output should eq 'Restored'
		End

		It 'handles empty message with prefix'
			setup() {
				export DEBUG="*"
				logger "test"
				logger:prefix "test" "PRE"
			}
			BeforeCall 'setup'

			When call echo:Test ""
			The output should eq 'PRE'
		End
	End

	Context 'Edge cases/'
		It 'printf:Tag with plain text (no format specifiers)'
			setup() {
				export DEBUG="*"
				logger "test"
				logger:prefix "test" "[X] "
			}
			BeforeCall 'setup'

			# Using plain text as first arg (not a format string)
			When call printf:Test "hello world"

			# This works correctly on both platforms
			The output should eq '[X] hello world'
		End

		It 'printf:Tag with multiple plain arguments demonstrates edge case'
			setup() {
				export DEBUG="*"
				logger "bug"
				logger:prefix "bug" "[BUG] "
			}
			BeforeCall 'setup'

			# This edge case produces garbled output (known limitation)
			# printf:Tag expects first argument to be a format string
			When call printf:Bug "plain" "text" "here"

			# Mark as pending - demonstrates current behavior limitation
			# Users should use echo:Tag for plain text, printf:Tag for formatting
			Skip "printf:Tag requires format string as first argument - use echo:Tag for plain text"
		End
	End
End
