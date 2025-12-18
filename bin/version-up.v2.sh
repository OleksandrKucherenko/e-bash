#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2155,SC1090,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-17
## Version: 3.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Set TERM if not defined (required for tput commands)
if [[ -z $TERM ]]; then export TERM=xterm-256color; fi

# For help:
#   ./version-up.v2.sh --help

# For developer / references:
#  https://ryanstutorials.net/bash-scripting-tutorial/bash-functions.php
#  http://tldp.org/LDP/abs/html/comparison-ops.html
#  https://misc.flogisoft.com/bash/tip_colors_and_formatting

shopt -s extdebug # enable extended debugging

DEBUG=${DEBUG:-"ver,-dbg,-loader,-parser,-common"}
export SKIP_ARGS_PARSING=1 # skip arguments parsing during script loading
readonly VERSION_FILE=version.properties

#region Helper scripts attaching
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && cd .. && pwd)/.scripts"

# Import all required modules
# shellcheck source=../.scripts/_colors.sh
# shellcheck source=../.scripts/_commons.sh
# shellcheck source=../.scripts/_logger.sh
# shellcheck source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"
# shellcheck source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"
# shellcheck source=../.scripts/_semver.sh
source "$E_BASH/_semver.sh" # connect advanced version parser
#endregion

# create custom logger echo:Ver, printf:Ver
logger:init ver "${cl_green}[ver]${cl_reset} " # no prefix, to stderr
logger:init dbg "${cl_gray}[dbg]${cl_reset} "  # no prefix, to stderr

#region Arguments
declare help version \
	args_release args_alpha args_beta args_rc args_stage \
	args_major args_minor args_patch \
	args_revision args_git_revision args_meta \
	args_stay args_default args_apply args_prefix

# pattern: "{\$argument_index}[,-{short},--{alias}-]=[output]:[init_value]:[args_quantity]"
export ARGS_DEFINITION=""
export COMPOSER="
	$(args:i help -a "-h,--help" -h "Show help and exit." -g global)
	$(args:i version -a "--version" -d "2.0.0" -h "Show version and exit." -g global)
	$(args:i DEBUG -a "--debug" -d "*" -h "Enable debug mode." -g global)
	$(args:i DRY_RUN -a "--dry-run" -d "false" -h "Run in dry-run mode without making actual changes." -g global)
	$(args:i args_release -a "-r,--release" -h "Switch stage to release, no suffix." -g stage)
	$(args:i args_alpha -a "-a,--alpha" -h "Switch stage to alpha. Set: ${cl_purple}'-alpha'${cl_reset}" -g stage)
	$(args:i args_beta -a "-b,--beta" -h "Switch stage to beta. Set: ${cl_purple}'-beta'${cl_reset}" -g stage)
	$(args:i args_rc -a "-c,--rc,--release-candidate" -h "Switch stage to release candidate. Set: ${cl_purple}'-rc'${cl_reset}" -g stage)
	$(args:i args_stage -a "--pre-release" -q 1 -h "Custom stage/pre-release. Usage: ${cl_purple}'--pre-release=rc.12'${cl_reset} will set: ${cl_purple}'-rc.12'${cl_reset}" -g special)
	$(args:i args_meta -a "--build" -q 1 -h "Custom meta/build/revision part. Usage: ${cl_grey}'--build=snapshot.12'${cl_reset} will set: ${cl_grey}'+snapshot.12'${cl_reset}" -g special)
	$(args:i args_major -a "-m,--major" -d "*" -h "Increment ${cl_red}MAJOR${cl_reset} version part.")
	$(args:i args_minor -a "-i,--minor" -d "*" -h "Increment ${cl_green}MINOR${cl_reset} version part.")
	$(args:i args_patch -a "-p,--patch" -d "*" -h "Increment ${cl_blue}PATCH${cl_reset} version part.")
	$(args:i args_revision -a "-e,--revision" -d "*" -h "Increment ${cl_grey}REVISION${cl_reset} version part.")
	$(args:i args_git_revision -a "-g,--git,--git-revision" -h "Use git revision number as a revision part." -g special)
	$(args:i args_prefix -a "--prefix" -d "sub-folder" -q 1 -h "Provide tag prefix or use on of the strategies: ${cl_cyan}root${cl_reset}, ${cl_cyan}sub-folder${cl_reset} (default), ${cl_lcyan}any_string${cl_reset}" -g special)
	$(args:i args_stay -a "--stay" -h "Compose ${cl_yellow}version.properties${cl_white} but do not do any increments." -g action)
	$(args:i args_default -a "--default" -h "Increment last found part of version, keeping the stage. Increment applied up to MINOR part." -g action)
	$(args:i args_apply -a "--apply" -h "Run GIT command(s) to apply version upgrade." -g action)
"
eval "$COMPOSER" >/dev/null
parse:arguments "$@"
#endregion

#region Interrupt and Exit Handlers
readonly EXIT_OK=0
readonly EXIT_NO=1
readonly TMP_FILE_CACHE=$(mktemp -u version-up.v2.cache.XXXX.tmp)

# Trap to capture exit/interrupt and print exit code
function on_exit() {
	local exit_code=$?

	# Cleanup temporary files
	[ -f "$TMP_FILE_CACHE" ] && rm -f "$TMP_FILE_CACHE"

	local CLR="${cl_green}"
	[ $exit_code -ne 0 ] && CLR="${cl_red}"

	echo -e "\n${cl_gray}exit code: ${CLR}$exit_code${cl_reset}" >&2
	return $exit_code
}

function on_interrupt() {
	# TODO (olku): reserve for rollback on interrupt

	echo -e "\n${cl_gray}Script interrupted!${cl_reset}" >&2
	exit "${EXIT_NO}"
}

# Register trap for normal exit and interrupt
trap on_exit EXIT
trap on_interrupt INT TERM
#endregion

#region Tracing/CallStack
__FUNC_STACK="" # CSV list of functions

function on_entry() {
	local current_func="${FUNCNAME[1]}"
	local last_on_stack="${__FUNC_STACK##*,}"
	local indent_level=$(echo "$__FUNC_STACK" | tr -cd ',' | wc -c)
	local indent=$(printf '%*s' "$indent_level" '' | tr ' ' '  ')

	# if we got "<<" exit from nested function, then print current new level
	if [[ "$last_on_stack" == "<<" ]]; then
		__FUNC_STACK=${__FUNC_STACK%,*}
		#indent=$(printf '%*s' "$((indent_level - 1))" '' | tr ' ' '  ')
		#echo -e "${indent}${GRAY}-- ${BLUE}$current_func${NC}" >&2
	elif [[ "$current_func" != "on_entry" &&
		"$current_func" != "on_return" &&
		"$current_func" != "$last_on_stack" ]]; then
		echo -e "${indent}${cl_gray}>> ${cl_blue}$current_func${cl_reset}" >&2
		__FUNC_STACK="$__FUNC_STACK,$current_func"
	fi
}

function on_return() {
	local current_func="${FUNCNAME[1]}"

	__FUNC_STACK=${__FUNC_STACK%,*}
	local indent_level=$(echo "$__FUNC_STACK" | tr -cd ',' | wc -c)
	local indent=$(printf '%*s' "$indent_level" '' | tr ' ' '  ')
	echo -e "${indent}${cl_gray}<< ${cl_blue}$current_func${cl_reset}" >&2

	__FUNC_STACK="${__FUNC_STACK},<<"
}

[ -n "$TRACE" ] && trap on_entry DEBUG && trap on_return RETURN
#endregion

# display help
function help() {
	echo "Usage:"
	echo "  ${cl_yellow}$0${cl_reset} [-r|--release] [-a|--alpha] [-b|--beta] [-c|--release-candidate]"
	echo '                       [-m|--major] [-i|--minor] [-p|--patch] [-e|--revision] [-g|--git|--git-revision]'
	echo '                       [--prefix root|sub-folder|<prefix>] [--build <revision>] [--pre-release <stage>]'
	echo '                       [--stay] [--default] [--apply] [--version] [--dry-run] [--debug] [--help]'
	echo ''
	print:help
	echo "${cl_gray}Notes:"
	echo '  1. when used --build option, --revision flag will be ignored.'
	echo '  2. when used --pre-release option, --alpha, --beta, --rc flags will be ignored.'
	echo '  3. root and sub-folder are reserved keywords, do not use them.'
	echo '  4. REVISION part does not participate in version comparison according to SEMVER spec.'
	echo "${cl_reset}"
	echo "Version: [${cl_cyan}PREFIX${cl_reset}]${cl_red}MAJOR${cl_reset}.${cl_green}MINOR${cl_reset}.${cl_blue}PATCH${cl_reset}[${cl_purple}-STAGE${cl_reset}][${cl_grey}+REVISION${cl_reset}]"
	echo ''
	echo 'Reference:'
	echo ' https://semver.org/'
	echo ''
	echo 'Versions priority:'
	echo ' 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0'
}

# Cross-platform sed function - uses gsed on macOS, sed on Linux
function xsed() {
	if command -v gsed >/dev/null 2>&1; then
		gsed "$@"
	else
		sed "$@"
	fi
}

## slagify, convert input string to valid bash variable name
function slagify() {
	local input="$1"
	# Replace non-alphanumeric characters with underscores
	local slag=$(echo "$input" | xsed 's/[^a-zA-Z0-9]/_/g')
	# Ensure it doesn't start with a number
	slag=$(echo "$slag" | xsed 's/^[0-9]/_&/g')
	echo "$slag"
}

# find the monorepo root folder, print it to STDOUT
function monorepo_root() {
	# Navigate up from the script directory until we find the .git sub-folder to determine the monorepo root
	local monorepoRootDir=$(
		dir="$(dirname "${BASH_SOURCE[0]}")"
		[ "$dir" = "." ] && dir="$(pwd)"
		while [[ "$dir" != '/' && ! -d "$dir/.git" ]]; do dir="$(dirname "$dir")"; done
		echo "$dir"
	)

	echo "$monorepoRootDir"
}

# https://stackoverflow.com/a/67449155
function get_relative_path() {
	local targetFilename=$(basename "$1")
	# Use realpath to resolve symbolic links in both paths
	local targetFolder=$(realpath "$(dirname "$1")")
	local currentFolder=$(realpath "$2")
	local result=.

	while [ "$currentFolder" != "$targetFolder" ]; do
		if [[ "$targetFolder" =~ "$currentFolder"* ]]; then
			local pointSegment=${targetFolder#${currentFolder}}
			result=$result/${pointSegment#/}
			break
		fi
		result="$result"/..
		currentFolder=$(dirname "$currentFolder")
	done

	result=$result/$targetFilename
	echo "${result#./}"
}

# resolve args_prefix into default value, after parsing it may have empty value
function args_prefix_or_default() {
	echo "${args_prefix:-"sub-folder"}"
}

# get monorepo sub-folder, print it to STDOUT
function prefix_sub_folder() {
	local tmpFileName="temp.file"
	local repoDir=$(realpath "$(monorepo_root)")
	local relativePath=$(get_relative_path "$(pwd)/$tmpFileName" "$repoDir")

	# expected / at the end
	echo "${relativePath/$tmpFileName/}"
}

# resolve prefix income parameter into prefix calue, and print it to STDOUT
# strategy: root|sub-folder|{any-string}
function prefix_strategy() {
	local strategy=${1:-"$(args_prefix_or_default)"}
	local resolution=""

	if [[ "$strategy" == "root" ]]; then
		resolution=""
	elif [[ "$strategy" == "sub-folder" ]]; then
		resolution=$(prefix_sub_folder)
	else
		resolution="$strategy"
	fi

	echo "$resolution"
}

# calculate the prefix based on the strategy. Modifies PREFIX variable.
function use_prefix() {
	PREFIX=$(prefix_strategy "$1")
}

# get the highest version tag for all branches, print it to STDOUT
function highest_tag() {
	local gitTag=$(git tag --list 2>/dev/null | sort -V | tail -n1 2>/dev/null)
	echo "$gitTag"
}

# extract current branch name, print it to STDOUT
function current_branch() {
	# expected: heads/{branch_name} OR {branch_name}
	# fallback: master
	local gitBranch="master"

	if git rev-parse --quiet --verify HEAD &>/dev/null; then
		gitBranch=$(git rev-parse --abbrev-ref HEAD | cut -d"/" -f2)
	else
		# newly created git repo without commits

		# Check if there's a default branch configured
		if git config init.defaultBranch >/dev/null 2>&1; then
			gitBranch=$(git config init.defaultBranch)
		fi
	fi

	echo "$gitBranch"
}

# get latest/head commit hash number, print it to STDOUT
function head_hash() {
	local commitHash=""

	if git rev-parse --quiet --verify HEAD &>/dev/null; then
		commitHash=$(git rev-parse --verify HEAD)
	else
		# newly created git repo without commits
		: # no-op
	fi

	echo "$commitHash"
}

# extract tag commit hash code, tag name provided by argument, print it to STDOUT.
function tag_hash() {
	local tagHash=$(git log -1 --format=format:"%H" "$1" 2>/dev/null | tail -n1)
	echo "$tagHash"
}

# resolve prefix argument before the actual processing is done. result print to STDOUT.
function resolve_prefix_to_value() {
	local resolved_prefix=$(prefix_strategy) # extract default strategy first

	# if --prefix provided, then required re-evaluation of the prefix
	if [[ -n "$args_prefix" ]]; then
		resolved_prefix=$(prefix_strategy "$args_prefix")
	fi

	echo "$resolved_prefix"
}

# auto-detect tag prefix from existing tags in repository
# shellcheck disable=SC2155,SC2001
function auto_detect_prefix_from_tags() {
	# TODO (olku): Limit analysis to 25 most recent tags for performance (| head -n 25)
	local all_tags=$(git tag --sort=-creatordate -l)

	# If no tags found, return empty prefix
	if [[ -z "$all_tags" ]]; then
		echo:Ver "Auto-detected prefix: No tags found in the repository."
		echo ""
		return
	fi

	# Get semver regex pattern and prefix strategy
	local semver_pattern=$(semver:grep) _prefix=$(args_prefix_or_default)

	# Key-value storage for prefixes
	declare -A prefixes

	# Process each tag and extract a prefix in front of SEMVER, ignore suffix
	while read -r tag; do
		# Use semver regex to extract the prefix
		# Expected pattern: {prefix}{semver}{suffix}
		local semver_part=$(echo "$tag" | grep -oE "$semver_pattern")

		# If we found a semver part in the tag
		if [[ -n "$semver_part" ]]; then
			# Extract prefix by removing semver part (and anything after) from the tag
			local prefix=$(echo "$tag" | xsed "s/${semver_part}.*//")

			# Count occurrences of this prefix
			if [[ -n "${prefixes[$prefix]}" ]]; then
				prefixes[$prefix]=$((prefixes[$prefix] + 1))
			else
				prefixes[$prefix]=1
			fi
		fi
	done <<<"$all_tags"

	# TODO: depends on the strategy we may select another prefix from the list.
	# sub-folder - means that we have a sub-folder path as a prefix, even if tags with
	#   such pattern are not very often.
	echo:Ver "Current prefix strategy: ${cl_gray}${_prefix}:${cl_purple}'${PREFIX}'${cl_reset}"

	# Find the most common prefix
	local mostUsed="" high=$((1 << 16))
	local max=0 # most used prefix

	for prefix in "${!prefixes[@]}"; do
		# give the priority to the resolved sub-folder prefix $PREFIX if our strategy is sub-folder $_prefix
		if [[ "${_prefix}" == "sub-folder" && "${prefix}" == "${PREFIX}"* ]]; then
			prefixes[$prefix]=$((prefixes[$prefix] + high))
		fi

		if [[ ${prefixes[$prefix]} -gt $max ]]; then
			mostUsed="$prefix"
			max=${prefixes[$prefix]}
		fi
	done

	# print detected patterns top-5, if we have more than 1
	if [[ ${#prefixes[@]} -gt 1 ]]; then
		for prefix in "${!prefixes[@]}"; do
			local count=${prefixes[$prefix]}
			echo:Ver "Auto-detected prefix: ${cl_yellow}${prefix}${cl_reset}, Count: $((count & ~high)), Priority: $((count & high))"
		done # | head -n 5
	fi

	# Format tags as comma-separated list
	local csvTags=$(echo "$all_tags" | tr '\n' ',' | xsed 's/,$//; s/,/, /g')
	echo:Ver "Auto-detected prefix: ${cl_yellow}${mostUsed}${cl_reset} from tags: ${cl_gray}${csvTags}${cl_reset}"

	echo "${mostUsed}"
}

# Use temporary file for caching the results of the function, to prevent
# repeated calculations and time expensive calls.
function cached:auto_detect_prefix_from_tags() {
	if [ ! -f "$TMP_FILE_CACHE" ]; then
		auto_detect_prefix_from_tags >"$TMP_FILE_CACHE"
	fi

	cat "$TMP_FILE_CACHE"
}

# get latest tag in specified branch. result to STDOUT.
function latest_tag() {
	local resolved_prefix=$(resolve_prefix_to_value)

	# TODO (olku): fetch remote tags first before extraction, they can be changed by another PR

	# extract from git latest tag that started from number (OR from prefix and number)
	local tag=$(git describe --tags --abbrev=0 --match="${resolved_prefix}[0-9]*" 2>/dev/null)

	# if tag is empty then try to autodetect the prefix and try extaction again
	if [[ -z "$tag" ]]; then
		echo:Ver "${cl_gray}No tags found with default prefix strategy (${resolved_prefix}[0-9]*), fallback to auto-detected prefix...${cl_reset}"
		resolved_prefix=$(cached:auto_detect_prefix_from_tags)
		tag=$(git describe --tags --abbrev=0 --match="${resolved_prefix}[0-9]*" 2>/dev/null)
	fi

	echo:Ver "Latest repo tag: ${cl_blue}${tag:-"<none>"}${cl_reset}"
	echo "$tag"
}

# get latest revision number, print it to STDOUT
function latest_revision() {
	local gitRevision=$(git rev-list --count HEAD 2>/dev/null)
	echo "$gitRevision"
}

# increment MAJOR part, reset all others lower PARTS, don't touch STAGE
function increment_major() {
	local override=${args_major:-"*"}

	if [[ "$override" != "*" ]]; then
		PARTS["major"]=$((override))
	else
		PARTS["major"]=$((PARTS["major"] + 1))
	fi

	PARTS["minor"]=0
	PARTS["patch"]=0
	PARTS["build"]=""
	IS_DIRTY=1

	echo:Ver "Selected versioning strategy: ${cl_green}forced MAJOR increment${cl_reset}."
	echo:Ver "Incrementing MAJOR: ${cl_green}${PARTS["major"]}${cl_reset}"
}

# increment MINOR part, reset all others lower PARTS, don't touch STAGE
function increment_minor() {
	local override=${args_minor:-"*"}

	if [[ "$override" != "*" ]]; then
		PARTS["minor"]=$((override))
	else
		PARTS["minor"]=$((PARTS["minor"] + 1))
	fi

	PARTS["patch"]=0
	PARTS["build"]=""
	IS_DIRTY=1

	echo:Ver "Selected versioning strategy: ${cl_green}forced MINOR increment${cl_reset}."
	echo:Ver "Incrementing MINOR: ${cl_green}${PARTS["minor"]}${cl_reset}"
}

# increment PATCH part, reset all others lower PARTS, don't touch STAGE
function increment_patch() {
	local override=${args_patch:-"*"}

	if [[ "$override" != "*" ]]; then
		PARTS["patch"]=$((override))
	else
		PARTS["patch"]=$((PARTS["patch"] + 1))
	fi

	PARTS["build"]=""
	IS_DIRTY=1

	echo:Ver "Selected versioning strategy: ${cl_green}forced PATCH increment${cl_reset}."
	echo:Ver "Incrementing PATCH: ${cl_green}${PARTS["patch"]}${cl_reset}"
}

# increment REVISION part, don't touch STAGE
function increment_revision() {
	local override=${args_revision:-"*"}
	local build=${PARTS["build"]//+/} # we force `+NNN` format
	build=${build:-"0"}               # fallback to 0 if empty

	if [[ "$override" != "*" ]]; then
		build=${override//+/}
	else
		build=$((build + 1))
	fi

	PARTS["build"]="+${build}"
	IS_DIRTY=1

	echo:Ver "Selected versioning strategy: ${cl_green}forced REVISION increment${cl_reset}."
	echo:Ver "Incrementing REVISION: ${cl_green}${PARTS["build"]}${cl_reset}"
}

# set revision part to a revision counter based on total amount of commits in repository
function set_revision_number() {
	local number="$1"

	PARTS["build"]="+$((number))"
	IS_DIRTY=1
	echo:Ver "Setting REVISION: ${cl_green}${PARTS["build"]}${cl_reset}"
}

# increment the number only of last found PART: REVISION --> PATCH --> MINOR. don't touch STAGE
function increment_last_found() {
	echo:Ver "Selected versioning strategy: ${cl_green}increment last found non-zero version part${cl_reset}."

	if [[ "${#PARTS["build"]}" == 0 || "${PARTS["build"]}" == "0" ]]; then  # build is empty or 0
		if [[ "${#PARTS["patch"]}" == 0 || "${PARTS["patch"]}" == "0" ]]; then # patch is empty or 0
			increment_minor
		else
			increment_patch
		fi
	else
		increment_revision
	fi

	# stage part is not EMPTY
	if [[ "${#PARTS["pre-release"]}" != 0 ]]; then
		IS_SHIFT=1
	fi
}

# do not do any increments, just stay on the same version
function stay_on_the_same_version() {
	IS_DIRTY=1
	NO_APPLY_MSG=1

	echo:Ver "Selected versioning strategy: ${cl_green}stay on the same version${cl_reset}."
}

# assign stage to the future version
function set_stage() {
	local stage="$1"

	PARTS["pre-release"]="$stage"
	IS_DIRTY=1

	echo:Ver "Selected versioning strategy: ${cl_green}forced stage '$stage'${cl_reset}."
	echo:Ver "Setting stage: ${cl_green}${stage}${cl_reset}"
}

# compose version from PARTS and output it to STDOUT
function compose() {
    local i=0 # make $i local to avoid conflicts
	for i in "${!PARTS[@]}"; do echo:Dbg "$i: ${PARTS[$i]}"; done
	declare -A V=(
		["major"]="${PARTS["major"]}"
		["minor"]="${PARTS["minor"]}"
		["patch"]="${PARTS["patch"]}"
		["pre-release"]="${PARTS["pre-release"]}" # started from "-"
		["build"]="${PARTS["build"]}"             # started from "+"
	)

	for i in "${!V[@]}"; do echo:Dbg "$i: ${V[$i]}"; done

	# "${major}.${minor}.${patch}${pre_release}${build}"
	echo "${PREFIX}$(semver:recompose "V")"
	echo:Dbg "${PREFIX}$(semver:recompose "V")"

	unset V
}

# print error message about conflict with existing tag and proposed tag
function error_conflict_tag() {
	local red=$(tput setaf 1 2>/dev/null || echo "")
	local end=$(tput sgr0 2>/dev/null || echo "")
	local yellow=$(tput setaf 3 2>/dev/null || echo "")

	echo -e "${red}ERROR:${end} "
	echo -e "${red}ERROR:${end} Found conflict with existing tag ${yellow}$(compose)${end} / $PROPOSED_HASH"
	echo -e "${red}ERROR:${end} Only manual resolving is possible now."
	echo -e "${red}ERROR:${end} "
	echo -e "${red}ERROR:${end} To Resolve try to add --revision or --patch modifier."
	echo -e "${red}ERROR:${end} "
	echo ""
}

# print help message how to apply changes manually
function help_manual_apply() {
	echo 'To apply changes manually execute the command(s):'
	echo -e "\033[90m"
	echo "  git tag $(compose)"
	echo "  git push origin $(compose)"
	echo -e "\033[0m"
}

# save all support information into version.properties file
function publish_version_file() {
	local publish_path="${VERSION_FILE}"

	# Determine where to publish version.properties file
	# If we're using a subfolder prefix and we're in that subfolder, publish there
	if [[ -n "${SUB_FOLDER_PREFIX}" && "${SUB_FOLDER_PREFIX}" == "$(prefix_sub_folder)" ]]; then
		publish_path="${VERSION_FILE}"
		echo "Publishing version file to subfolder: $(pwd)/${VERSION_FILE}"
	else
		# Use existing version.properties location if found
		if [[ -n "${VERSION_PROPS_PATH}" ]]; then
			publish_path="${VERSION_PROPS_PATH}"
			echo "Updating existing version file: ${VERSION_PROPS_PATH}"
		fi
		# Default behavior remains the same - current directory
	fi

	echo "# $(date)" >"${publish_path}"
	{
		echo "## Version: 2.0.0"
		echo "snapshot.version=$(compose)"
		echo "snapshot.lasttag=$TAG"
		echo "snapshot.revision=$REVISION"
		echo "snapshot.hightag=$TOP_TAG"
		echo "snapshot.branch=$BRANCH"
		echo "snapshot.prefix=$PREFIX"
		echo '# end of file'
	} >>"${publish_path}"

	echo ""
	echo "File ${cl_yellow}${publish_path}${cl_reset} is successfully created."
}

# apply changes to GIT repository, local changes only
function apply_git_changes() {
	echo ''
	echo "Applying git repository version up... no push, only local tag assignment!"
	echo ''

	# Check for tag conflicts before applying
	local proposed_tag="$(compose)"
	local proposed_hash=$(tag_hash "$proposed_tag")
	local current_head=$(head_hash)
	
	if [[ -n "$proposed_hash" && "$proposed_hash" != "$current_head" ]]; then
		error_conflict_tag
		exit 1
	fi

	git tag "$proposed_tag"

	# confirm that tag applied
	git --no-pager log \
		--pretty=format:"%h%x09%Cblue%cr%Cgreen%x09%an%Creset%x09%s%Cred%d%Creset" \
		-n 2 --date=short | nl -w2 -s"  "

	echo ''
	echo ''
}

# print current state of the repository
function report_current_state() {
	# do we have any GIT tag for parsing?!
	echo ""
	if [[ -z "${TAG// /}" ]]; then
		TAG=$INIT_VERSION
		echo "No tags found."
	else
		echo "Found tag        : ${cl_blue}$TAG${cl_reset} in branch ${cl_yellow}$BRANCH${cl_reset}"
	fi

	# print current revision number based on number of commits
	echo "Current Revision : ${cl_green}$REVISION${cl_reset}"
	echo "Current Branch   : ${cl_yellow}$BRANCH${cl_reset}"
	echo "Repository Dir   : ${cl_yellow}$(realpath "$(monorepo_root)")${cl_reset}"
	echo "Current Folder   : \"$(prefix_sub_folder)\""
	echo ""

}

# stage == "pre-release" in terms of SEMVER
function handle_stage_shift() {
	stage=${PARTS["pre-release"]}
	PARTS["pre-release"]='.'

	# detect first run on repository, INIT_VERSION was used
	if [[ "$(compose)" == "0.0" ]]; then
		increment_minor
	fi

	PARTS["pre-release"]=$stage
}

# Verify arguments that allows quick exit from the script: help, version.
function parse_quick_arguments() {
	local args=("$@")

	# parse input parameters
	if [[ "$help" == "1" ]]; then
		help
		# shellcheck disable=SC2086
		exit $EX_OK
	elif [[ -n "$version" ]]; then
		echo "version: ${version}"
		# shellcheck disable=SC2086
		exit $EX_OK
	fi
}

# Based on passed argument evaluate and configure versioning strategy
function configure_strategy() {
	echo:Ver "Configuring versioning strategy..."
	local args=("$@")

	local isNoArgs=false
	[ "${#args[@]}" -eq 0 ] && isNoArgs=true

	if $isNoArgs; then
		echo:Dbg "Testing latest tag hash: ${cl_blue}${TAG_HASH:0:7}${cl_reset} vs HEAD hash: ${cl_blue}${HEAD_HASH:0:7}${cl_reset}"

		if [[ -z "${HEAD_HASH}" ]]; then
			echo "Empty repository without commits. Nothing to do."
			exit 0
		elif [[ "$TAG_HASH" == "$HEAD_HASH" ]]; then
			echo "Tag ${cl_blue}${TAG:-"<none>"}${cl_reset} and ${cl_yellow}HEAD${cl_reset} are aligned. We will stay on the TAG version."
			echo:Ver "Selected versioning strategy: ${cl_green}stay on the same version${cl_reset}."
			# TODO (olku): should we re-create the version.properties file?
			exit 0
		else
			echo:Ver "Tag ${cl_blue}${TAG:-"<none>"}${cl_reset} and ${cl_yellow}HEAD${cl_reset} are not aligned. Continue with versioning..."
		fi

		# are we in the branch that has version tag or name that matches the pattern?
		local semver_grep=$(semver:grep)
		local semver_part=$(echo "$BRANCH" | grep -oE "$semver_grep")

		if [[ -n "$semver_part" ]]; then
			echo:Ver "Detected branch name ${cl_yellow}$BRANCH${cl_reset} and it matches SEMVER pattern."
			echo:Ver "Selected versioning strategy: ${cl_green}increment last version PART of ${cl_yellow}$BRANCH${cl_reset}"
			args_default=1
		else
			echo:Ver "Detected branch name ${cl_yellow}$BRANCH${cl_reset} and it does not match SEMVER pattern."
			echo:Ver "Selected versioning strategy: ${cl_green}increment MINOR of the latest ${cl_blue}${TAG:-"$INIT_VERSION"}${cl_reset}"
			args_minor='*' # use default increment
		fi
	fi

	echo:Dbg "alpha: $args_alpha, beta: $args_beta, rc: $args_rc, release: $args_release"
	echo:Dbg "patch: $args_patch, revision: $args_revision, git_revision: $args_git_revision, minor: $args_minor"
	echo:Dbg "default: $args_default, major: $args_major, stay: $args_stay, apply: $args_apply"
	echo:Dbg "overrides / stage: $args_stage, revision: $args_meta"
	echo:Dbg "prefix: $args_prefix"

	[[ "$args_alpha" == "1" ]] && set_stage "-alpha"
	[[ "$args_beta" == "1" ]] && set_stage "-beta"
	[[ "$args_rc" == "1" ]] && set_stage "-rc"
	[[ "$args_release" == "1" ]] && set_stage ""
	[[ -n "$args_stage" ]] && set_stage "-${args_stage}"

	# DONE: support --major=2 --minor=1 --patch=0 --revision=1000 overrides
	[[ -n "$args_major" ]] && increment_major
	[[ -n "$args_minor" ]] && increment_minor
	[[ -n "$args_patch" ]] && increment_patch
	[[ -n "$args_revision" ]] && increment_revision
	[[ "$args_git_revision" == "1" ]] && set_revision_number "${REVISION}"
	[[ -n "$args_meta" ]] && PARTS["build"]="+${args_meta}" && IS_DIRTY=1

	[[ "$args_default" == "1" ]] && increment_last_found
	[[ "$args_stay" == "1" ]] && stay_on_the_same_version
	[[ "$args_apply" == "1" ]] && DO_APPLY=1

	[[ -n "$args_prefix" ]] && use_prefix "$args_prefix"

}

# Check if version.properties exists and process it
# Inputs: none
# Outputs: STDOUT - logs about version properties status
# Side effects: sets VERSION_PROPS_EXISTS global variable, sources properties file
function check_version_properties() {
	local version_props_exists=0

	if [[ -n "${VERSION_PROPS_PATH}" ]]; then
		echo:Ver "Found ${cl_blue}version.properties${cl_reset} file: ${cl_yellow}${VERSION_PROPS_PATH}${cl_reset}"
		process_version_properties "${VERSION_PROPS_PATH}"
		version_props_exists=1
	else
		echo:Ver "No ${cl_yellow}version.properties${cl_reset} found. Using script defaults for versioning..."
		version_props_exists=0
	fi

	# Return for main function to use
	return ${version_props_exists}
}

# Check if we can detect version tags
# Inputs: TAG - current tag, INIT_VERSION - initial version placeholder
# Outputs: STDOUT - logs about version tag detection
# Returns: 0 if version tags detected, 1 otherwise
# Side effects: none
function has_version_tags() {
	local result=1

	if [[ -n "${TAG}" && "${TAG}" != "${INIT_VERSION}" ]]; then
		echo:Ver "Version tags detected: ${cl_green}${TAG}${cl_reset}"
		result=0
	fi

	return ${result}
}

# Handle multiple prefix detection
# Inputs: AUTO_DETECTED_PREFIX - comma-separated list of detected prefixes
# Outputs: STDOUT - logs about prefix handling
# Side effects: sets SUB_FOLDER_PREFIX and PREFIX global variables
function handle_multiple_prefixes() {
	local sub_folder_prefix=""
	local sub_folder=""
	local -a prefixes=() # Initialize as empty array

	# Split comma-separated prefixes into array
	IFS=',' read -ra prefixes <<<"${AUTO_DETECTED_PREFIX}"

	echo:Ver "Multiple prefixes detected: ${AUTO_DETECTED_PREFIX}"

	# Check if any prefix matches current subfolder
	for prefix in "${prefixes[@]}"; do
		if is_prefix_matching_current_folder "${prefix}"; then
			echo:Ver "Matched prefix is a sub-folder path: ${prefix}"
			sub_folder_prefix="${prefix}"
			break
		fi
	done

	# Set global for later use
	SUB_FOLDER_PREFIX="${sub_folder_prefix}"

	if [[ -n "${SUB_FOLDER_PREFIX}" ]]; then
		echo:Ver "STRONG: Using subfolder prefix: ${SUB_FOLDER_PREFIX}"
		PREFIX="${SUB_FOLDER_PREFIX}"
	else
		# Check if we're in a sub-folder
		sub_folder=$(prefix_sub_folder)
		if [[ -n "${sub_folder}" && "${sub_folder}" != "/" ]]; then
			echo:Ver "WEAK: Using current folder path as prefix: ${sub_folder}"
			PREFIX="${sub_folder}"
			echo:Ver "Detected release of sub-project with own version numbering."
		fi
	fi
}

# Handle single prefix detection
# Inputs: AUTO_DETECTED_PREFIX - detected prefix string
# Outputs: STDOUT - logs about prefix handling
# Side effects: sets PREFIX global variable
function handle_single_prefix() {
	local prefix="$1"
	local sub_folder=""

	if [[ "${prefix}" == "v" ]]; then
		echo:Ver "Known prefix ${cl_yellow}v${cl_reset} detected."
		PREFIX="v"
	else
		# Check if it's a subfolder path
		sub_folder=$(prefix_sub_folder)
		if [[ "${prefix}" == "${sub_folder}" ]]; then
			echo:Ver "Prefix matches current subfolder: ${cl_yellow}${sub_folder}${cl_reset}"
			PREFIX="${sub_folder}"
		else
			echo:Ver "Using detected prefix: ${cl_yellow}${prefix}${cl_reset}"
			PREFIX="${prefix}"
		fi
	fi
}

# Handle prefix detection and processing
# Inputs: AUTO_DETECTED_PREFIX - detected prefix or comma-separated prefixes
# Outputs: STDOUT - logs about prefix handling
# Side effects: sets PREFIX and potentially SUB_FOLDER_PREFIX global variables
function handle_prefix_detection() {
	local prefixes=()

	if [[ -n "${AUTO_DETECTED_PREFIX}" ]]; then
		echo:Ver "Prefix detected: ${cl_yellow}${AUTO_DETECTED_PREFIX}${cl_reset}"

		# Check if we have multiple prefixes
		IFS=',' read -ra prefixes <<<"${AUTO_DETECTED_PREFIX}"
		if [[ "${#prefixes[@]}" -gt 1 ]]; then
			handle_multiple_prefixes "${prefixes[@]}"
		else
			handle_single_prefix "${AUTO_DETECTED_PREFIX}"
		fi
	else
		echo:Ver "No prefix detected. Using empty prefix."
		PREFIX=""
	fi
}

# Handle the case when no version tags are detected
# Inputs: none
# Outputs: STDOUT - logs about subfolder strategy
# Side effects: may set PREFIX global variable after user confirmation
function handle_no_version_tags() {
	local sub_folder=""

	echo:Ver "No version tags detected."

	# Propose using subfolder strategy
	sub_folder=$(prefix_sub_folder)
	if [[ -n "${sub_folder}" && "${sub_folder}" != "/" ]]; then
		if ask_user_confirmation "Use subfolder '${sub_folder}' as prefix?" "Y"; then
			PREFIX="${sub_folder}"
			echo:Ver "Using subfolder as prefix: ${cl_yellow}${PREFIX}${cl_reset}"
		fi
	fi
}

# Process tag detection and handling
# Inputs: none
# Outputs: STDOUT - logs about tag detection and handling
# Side effects: may set PREFIX, SUB_FOLDER_PREFIX global variables
function process_tag_detection() {
	# Check if we have any git tags
	if [[ -z "$(git tag --list 2>/dev/null)" ]]; then
		echo:Ver "No tags found in the repository."
		handle_no_version_tags
	else
		echo:Ver "Repository has Tags. Lets check them for SEMVER compatibility."

		# Check if we can detect version tags
		if has_version_tags; then
			handle_prefix_detection
		else
			handle_no_version_tags
		fi
	fi
}

# Process the proposed version and apply changes if needed
# Inputs: $@ - command line arguments
# Outputs: STDOUT - various logs about version processing
# Side effects: may modify TAG, trigger version application
function process_version() {
	# Print current state of the repository on screen
	report_current_state

	# Detected shift between stages, but no increment applied
	[[ "$IS_SHIFT" == "1" ]] && handle_stage_shift

	# No increment applied yet and no shift of state, do minor increase
	[[ "$IS_DIRTY$IS_SHIFT" == "" ]] && increment_minor

	# Instruct user how to apply new TAG
	echo:Ver "Proposed Next Version TAG: ${cl_green}$(compose)${cl_reset}"
	echo ''

	# Is proposed tag in conflict with any other TAG
	PROPOSED_HASH=$(tag_hash "$(compose)")
	if [[ "${#PROPOSED_HASH}" -gt 0 && "$NO_APPLY_MSG" == "" ]]; then
		error_conflict_tag
	fi
}

# Handle confirmation and apply version if needed
# Inputs: none
# Outputs: STDOUT - logs about applying version
# Side effects: may set DO_APPLY, output version file, apply git changes
function handle_version_apply() {
	# Ask for confirmation if not in CI
	if [[ "$NO_APPLY_MSG" == "" ]]; then
		if ! is_ci_environment && ask_user_confirmation "Apply this version?" "Y"; then
			DO_APPLY=1
		fi
		help_manual_apply
	fi

	# Compose version override file
	if [[ "$TAG" == "$INIT_VERSION" ]]; then
		TAG='0.0'
	fi

	publish_version_file

	# Should we apply the changes
	if [[ "$DO_APPLY" == "1" ]]; then
		apply_git_changes
	fi
}

# Check if we're running in a CI environment
function is_ci_environment() {
	[[ -n "${CI}" || -n "${GITHUB_ACTIONS}" || -n "${GITLAB_CI}" || -n "${JENKINS_URL}" ]] && return 0 || return 1
}

# Check if version.properties exists in the current directory or parent directories
function find_version_properties() {
	local current_dir="$(pwd)"
	local root_dir="$(monorepo_root)"
	local found_file=""

	# Check in current directory first
	if [[ -f "${current_dir}/version.properties" ]]; then
		found_file="${current_dir}/version.properties"
		echo "${found_file}"
		return 0
	fi

	# Find upwards until repository root
	while [[ "${current_dir}" != "${root_dir}" && "${current_dir}" != "/" ]]; do
		if [[ -f "${current_dir}/version.properties" ]]; then
			found_file="${current_dir}/version.properties"
			echo "${found_file}"
			return 0
		fi
		current_dir="$(dirname "${current_dir}")"
	done

	# Check repository root as last resort
	if [[ -f "${root_dir}/version.properties" ]]; then
		found_file="${root_dir}/version.properties"
		echo "${found_file}"
		return 0
	fi

	echo ""
	return 1
}

# Process version.properties file if it exists
function process_version_properties() {
	local properties_file="$1"
	if [[ -f "${properties_file}" ]]; then
		echo:Ver "Using version definitions from: ${cl_yellow}${properties_file}${cl_reset}"
		# Source the properties file to get variables.
		# extract non comments lines for processing
		grep -v '^#' "${properties_file}" | while read -r line; do
			local variable="${line/=*/}"
			local var_name="$(slagify "${variable}")"
			local var_value="${line#*=}"

			printf:Dbg "${cl_green}%-20s${cl_reset}= ${cl_yellow}%-30s ${cl_grey}# %s${cl_reset}\n" "${var_name}" "\"${var_value}\"" "${line}"
			eval "export ${var_name}=\"${var_value}\""
		done

		return 0
	fi
	return 1
}

# Ask user for confirmation
function ask_user_confirmation() {
	local message="$1"
	local default_answer="$2"

	if is_ci_environment; then
		# In CI, always proceed with default
		echo "CI environment detected, proceeding with default action."
		return 0
	fi

	read -r -p "${message} [Y/n] " answer
	answer=${answer:-${default_answer}}

	if [[ "${answer}" =~ ^[Yy]$ ]]; then
		return 0
	else
		echo "Operation canceled by user."
		return 1
	fi
}

# Verify if prefix matches current folder path
function is_prefix_matching_current_folder() {
	local prefix="$1"
	local folder_path=$(prefix_sub_folder)

	# Normalize paths for comparison
	local norm_prefix=${prefix%/}
	local norm_folder=${folder_path%/}

	[[ "${norm_prefix}" == "${norm_folder}" ]] && return 0 || return 1
}

# Prepare global variables for versioning process
# Inputs: $@ - command line arguments
# Global variables:
# - PREFIX, AUTO_DETECTED_PREFIX, INIT_VERSION, TAG,
# - REVISION, BRANCH, TOP_TAG, TAG_HASH, HEAD_HASH,
# - PROPOSED_HASH, VERSION_PROPS_PATH
function prepare_globals() {
	echo:Ver "Recovering versioning strategy from repository state..."

	# try to detect the prefix in versioning tags/branches names. expected pattern: {PREFIX}{SEMVER}{SUFFIX}
	# PREFIX in this case can be:
	#   - '{any-string}' - something defined by user;
	#   - '{sub-folder}' - sub-folder path used as a prefix;
	#   - '{root}' - empty string;
	export PREFIX=$(resolve_prefix_to_value)
	export AUTO_DETECTED_PREFIX=$(cached:auto_detect_prefix_from_tags)

	# initial version used for repository without tags
	export INIT_VERSION="${PREFIX}0.0.1-alpha"

	# do GIT data extracting into globals
	export TAG=$(latest_tag "$@")
	export REVISION=$(latest_revision)
	export BRANCH=$(current_branch)
	export TOP_TAG=$(highest_tag)
	export TAG_HASH=$(tag_hash "$TAG")
	export HEAD_HASH=$(head_hash)
	export PROPOSED_HASH=""

	# Find version.properties if it exists
	export VERSION_PROPS_PATH=$(find_version_properties)

	# parse the tag into parts
	# shellcheck disable=SC2015
	semver:parse "${TAG:-"$INIT_VERSION"}" "PARTS" &&
		(for i in "${!PARTS[@]}"; do echo:Dbg "$i: ${PARTS[$i]}"; done) ||
		echo:Dbg "$? - FAIL parsing '${TAG}'!"
}

# Main function that orchestrates the versioning process
# Inputs: $@ - command line arguments
# Outputs: STDOUT - logs about version processing
# Side effects: various, handled by subfunctions
function main() {
	# check arguments for quick exit flags
	parse_quick_arguments "$@"

	# shellcheck disable=SC2178,SC2124
	local args=" $@"
	echo:Ver "Starting '$0${args[*]}' process..."

	# Prepare global variables for processing, based on arguments and disk/repo state
	prepare_globals "$@"

	# parse arguments after we initialize global state
	configure_strategy "$@"

	# Check if version.properties exists and process it
	check_version_properties

	# Process version tag detection and handling
	process_tag_detection

	# Process version calculation and potential conflicts
	process_version "$@"

	# Handle version application
	handle_version_apply
}

main "$@"

#region Afterwords
# Major logic of the script - "on each run script propose future version of the product".
#  - if no tags on project --> propose '0.1-alpha'
#  - do multiple build iterations until you become satisfied with result
#  - run 'version-up.v2.sh --apply' to save result in GIT
#
# Enhanced version logic based on Excalidraw diagram:
# 1. Check if we have tags in the repository
#    - NO: Use default versioning strategy
#    - YES: Continue to step 2
#
# 2. Check if we can detect version tags
#    - NO: Propose using subfolder as prefix (with user confirmation)
#    - YES: Continue to step 3
#
# 3. Check if we can detect a prefix
#    - NO: Use empty prefix (root strategy)
#    - YES: Continue to step 4
#
# 4. Check if multiple prefixes are detected
#    - NO: Check if it's a known prefix (v{SEMVER}) or custom prefix
#    - YES: Continue to step 5
#
# 5. Check if it's a sub-folder prefix
#    - NO: Use WEAK strategy - use current subfolder path as prefix
#    - YES: Use STRONG strategy - use the detected prefix
#
# 6. Check for version.properties file
#    - Find in current folder or navigate up to root
#    - Use definitions from file if found
#
# 7. Apply versioning with pattern: {prefix}{SEMVER}
#
# 8. Ask for user confirmation if not in CI environment
#
# 9. Apply version and generate version.properties file
#
# Priority for version configuration:
# 1. Global environment variables
# 2. Script arguments
# 3. Local version.properties file
# 4. Default values
#endregion
