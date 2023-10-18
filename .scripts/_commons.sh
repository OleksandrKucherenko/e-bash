#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2023-10-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# is allowed to use macOS extensions (script can be executed in *nix environment)
use_macos_extensions=false
if [[ "$OSTYPE" == "darwin"* ]]; then use_macos_extensions=true; fi

# shellcheck disable=SC1090  source=_colors.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_colors.sh"

# shellcheck disable=SC1090 source=_logger.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_logger.sh"

function time:now() {
	echo "$EPOCHREALTIME" # <~ bash 5.0
	#python -c 'import datetime; print datetime.datetime.now().strftime("%s.%f")'
}

# shellcheck disable=SC2155,SC2086
function time:diff() {
	local diff="$(time:now) - $1"
	bc <<<$diff
}

# shellcheck disable=SC2086
function validate:input() {
	local variable=$1
	local default=${2:-""}
	local prompt=${3:-""}
	local user_in=""

	# Ctrl+C during read operation force error exit
	trap 'exit 1' SIGINT

	# execute at least once
	while :; do
		# allow macOs read command extension usage (default value -i)
		if $use_macos_extensions; then
			[[ -z "${prompt// /}" ]] || read -e -i "${default}" -p "${cl_purple}? ${cl_reset}${prompt}${cl_blue}" -r user_in
			[[ -n "${prompt// /}" ]] || read -e -i "${default}" -r user_in
		else
			[[ -z "${prompt// /}" ]] || echo "${cl_purple}? ${cl_reset}${prompt}${cl_blue}"
			read -r user_in
		fi
		printf "${cl_reset}"
		[[ -z "${user_in// /}" ]] || break
	done

	local __resultvar=$variable
	eval $__resultvar="'$user_in'"
}

# shellcheck disable=SC2086,SC2059
function validate:input:yn() {
	local variable=$1
	local default=${2:-""}
	local prompt=${3:-""}
	local user_in=false

	while true; do
		if $use_macos_extensions; then
			[[ -z "${prompt// /}" ]] || read -e -i "${default}" -p "${cl_purple}? ${cl_reset}${prompt}${cl_blue}" -r yn
			[[ -n "${prompt// /}" ]] || read -e -i "${default}" -r yn
		else
			[[ -z "${prompt// /}" ]] || echo "${cl_purple}? ${cl_reset}${prompt}${cl_blue}"
			read -r yn
		fi
		printf "${cl_reset}"
		case $yn in
		[Yy]*)
			user_in=true
			break
			;;
		[Nn]*)
			user_in=false
			break
			;;
		*)
			user_in=false
			break
			;;
		esac
	done
	local __resultvar=$variable
	eval $__resultvar="$user_in"
}

# shellcheck disable=SC2086
function env:variable:or:secret:file() {
	#
	# Usage:
	#     env:variable:or:secret:file "new_value" \
	#       "GITLAB_CI_INTEGRATION_TEST" \
	#       ".secrets/gitlab_ci_integration_test" \
	#       "{user friendly message}"
	#
	local name=$1
	local variable=$2
	local file=$3
	local fallback=${4:-"No hints, check the documentation"}
	local __result=$name

	if [[ -z "${!variable}" ]]; then
		if [[ ! -f "$file" ]]; then
			echo ""
			echo "${cl_red}ERROR:${cl_reset} shell environment variable '\$$variable' or file '$file' should be provided"
			echo ""
			echo "Hint:"
			echo "  $fallback"
			echo ""
			echo:Common "Working Dir: $(pwd)"
			return 1
		else
			echo "Using file: ${cl_green}$file${cl_reset} ~> $name"
			eval $__result="'$(cat $file)'"
		fi
	else
		echo "Using var : ${cl_green}\$$variable${cl_reset} ~> $name"
		eval $__result="'${!variable}'"
	fi
}

# shellcheck disable=SC2086
function env:variable:or:secret:file:optional() {
	#
	# Usage:
	#     env:variable:or:secret:file:optional "new_value" \
	#       "GITLAB_CI_INTEGRATION_TEST" \
	#       ".secrets/gitlab_ci_integration_test"
	#
	local name=$1
	local variable=$2
	local file=$3
	local __result=$name

	if [[ -z "${!variable}" ]]; then
		if [[ ! -f "$file" ]]; then
			# NO variable, NO file
			echo "${cl_yellow}Note:${cl_reset} shell environment variable '\$$variable' or file '$file' can be provided."
			return 0
		else
			echo "Using file: ${cl_green}$file${cl_reset} ~> $name"
			eval $__result="'$(cat $file)'"
			return 2
		fi
	else
		echo "Using var : ${cl_green}\$$variable${cl_reset} ~> $name"
		eval $__result="'${!variable}'"
		return 1
	fi
}

function args:isHelp() {
	local args=("$@")
	if [[ "${args[*]}" =~ "--help" ]]; then echo true; else echo false; fi
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger common "$@" # register own logger

# old version of function names
alias now=time:now
alias print_time_diff=time:diff
alias validate_input=validate:input
alias validate_yn_input=validate:input:yn
alias env_variable_or_secret_file=env:variable:or:secret:file
alias optional_env_variable_or_secret_file=env:variable:or:secret:file:optional
alias isHelp=args:isHelp
