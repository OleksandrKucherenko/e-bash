#!/usr/bin/env bash
# shellcheck disable=SC2034

# shellcheck disable=SC1090 source=./_commons.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_commons.sh"
# shellcheck disable=SC1090 source=./_logger.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_logger.sh"
logger dependencies "$@" # register own debug tag & logger functions

#set -x # Uncomment to DEBUG

# shellcheck disable=SC2001,SC2155,SC2046,SC2116
function isDebug() {
	local args=("$@")
	if [[ "${args[*]}" =~ "--debug" ]]; then echo true; else echo false; fi
}

function isExec() {
	local args=("$@")
	if [[ "${args[*]}" =~ "--exec" ]]; then echo true; else echo false; fi
}

function isOptional() {
	local args=("$@")
	if [[ "${args[*]}" =~ "--optional" ]]; then echo true; else echo false; fi
}

function isSilent() {
	local args=("$@")
	if [[ "${args[*]}" =~ "--silent" ]]; then echo true; else echo false; fi
}

# shellcheck disable=SC2001,SC2155,SC2086
function dependency() {
	local tool_name=$1
	local tool_version_pattern=$2
	local tool_fallback=${3:-"No details. Please google it."}
	local tool_version_flag=${4:-"--version"}
	local is_exec=$(isExec "$@")
	local is_optional=$(isOptional "$@")

	configDebugDependencies "$@" # refresh debug flags

	# escape symbols: & / . { }, remove end of line, replace * by expectation from 1 to 4 digits
	local tool_version=$(sed -e 's#[&\\/\.{}]#\\&#g; s#$#\\#' -e '$s#\\$##' -e 's#*#[0-9]\\{1,4\\}#g' <<<$tool_version_pattern)

	# try to find tool
	local WHICH_TOOL=$(command -v $tool_name)

	if [ -z "$WHICH_TOOL" ]; then
		printfDependencies "which  : %s\npattern: %s, sed: \"s#.*\(%s\).*#\1#g\"\n-------\n" \
			"${WHICH_TOOL:-"command -v $tool_name"}" "$tool_version_pattern" "$tool_version"

		if $is_optional; then
			# shellcheck disable=SC2154
			echo "Optional   [${cl_red}NO${cl_reset}]: \`$tool_name\` - ${cl_red}not found${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}"
			return 0
		else
			echo "${cl_red}Error: dependency \`$tool_name\` not found."
			echo "${cl_reset} Hint. To install tool use the command below: "
			echo " $>  $tool_fallback"
			exit 1
		fi
	fi

	local VERSION_MSG=$($tool_name $tool_version_flag 2>&1)
	local VERSION_CLEAN=$(echo "'$VERSION_MSG'" | sed -n "s#.*\($tool_version\).*#\1#p" | head -1)

	printfDependencies "which  : %s\nversion: %s\npattern: %s, sed: \"s#.*\(%s\).*#\1#g\"\nver.   : %s\n-------\n" \
		"$WHICH_TOOL" "$VERSION_MSG" "$tool_version_pattern" "$tool_version" "$VERSION_CLEAN"

	if [ "$VERSION_CLEAN" == "" ]; then
		if $is_optional; then
			echo "Optional   [${cl_red}NO${cl_reset}]: \`$tool_name\` - ${cl_red}wrong version${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}"
			return 0
		else
			echo "${cl_red}Error: dependency version \`$tool_name\` is wrong."
			echo " Extracted: \`$VERSION_CLEAN\`"
			echo " Expected : \`$tool_version_pattern\`${cl_reset}"

			if $is_exec; then
				# shellcheck disable=SC2006,SC2154
				echo " Executing: ${cl_yellow}$($tool_fallback)${cl_reset}"
				echo ""
				eval $tool_fallback
			else
				echo ""
				echo " Hint. To install tool use the command below: "
				echo " $>  $tool_fallback"
				exit 1
			fi
		fi
	else
		if $is_optional; then echo -n "Optional   "; else echo -n "Dependency "; fi
		# shellcheck disable=SC2154
		echo "[${cl_green}OK${cl_reset}]: \`$tool_name\` - version: $VERSION_CLEAN"
	fi
}

function optional() {
	local args=("$@")

	# remove all flags from call
	local del=("--debug" "--exec" "--silent" "--optional")
	for value in "${del[@]}"; do
		for i in "${!args[@]}"; do
			if [[ ${args[i]} == "${value}" ]]; then unset 'args[i]'; fi
		done
	done

	# inject default parameters
	if [ "${#args[@]}" == "2" ]; then
		args+=("No details. Please google it." "--version")
	elif [ "${#args[@]}" == "3" ]; then
		args+=("--version")
	fi

	# recover flags
	if [ "$(isExec "$@")" == "true" ]; then args+=("--exec"); fi
	if [ "$(isSilent "$@")" == "true" ]; then args+=("--silent"); fi
	if [ "$(isDebug "$@")" == "true" ]; then args+=("--debug"); fi
	args+=("--optional")

	# we should expand any number of input arguments to required 4 + extra flags
	dependency "${args[@]}"
}

# Tests:
#dependency bash "5.0.18(1)-release" "brew install bash" "--version"
#dependency bash "5.0.[0-9]{2}(1)-release" "brew install bash" "--version"
#dependency bash "5.0.*(1)-release" "brew install bash" "--version"
#dependency bash "5.*.*(1)-release" "brew install bash" "--version"
#dependency bash "5.*.*" "brew install bash" "--version" --debug # print debug info
#dependency bash "5.*.*" "brew install bash" "--version" 0 # ignore $5 parameter
#dependency git "2.*.*" "brew install git" "--version"
#dependency bazelisk "4.*.*" "brew install bazel" "--version"
#dependency yq "4.13.2" "brew install yq" "-V"
#dependency jq "1.6" "brew install jq"
#dependency bash "[45].*.*" "brew install bash" # allow 4.xx and 5.xx versions
#dependency go "1.17.*" "brew install go" "version"
#dependency buildozer "redacted" "go get github.com/bazelbuild/buildtools/buildozer" "-version" 1
#dependency buildozer "redacted" "go get github.com/bazelbuild/buildtools/buildozer"
#dependency go "1.17.*" "brew install go && (echo 'export GOPATH=\$HOME/go; export PATH=\$GOPATH/bin:\$PATH;' >> ~/.zshrc)" "version"
#dependency go "2.17.*" "echo 'export GOPATH=\$HOME/go; export PATH=\$GOPATH/bin:\$PATH;'" "version" --exec
#dependency go "2.17.*" "echo 'export GOPATH=\$HOME/go; export PATH=\$GOPATH/bin:\$PATH;' >> ~/.zshrc" "version" --debug

# ref:
#  https://docs.gradle.org/current/userguide/single_versions.html
#  https://github.com/qzb/sh-semver
#  https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
