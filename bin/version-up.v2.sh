#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2155,SC1090,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-05
## Version: 3.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# For help:
#   ./version-up.v2.sh --help

# For developer / references:
#  https://ryanstutorials.net/bash-scripting-tutorial/bash-functions.php
#  http://tldp.org/LDP/abs/html/comparison-ops.html
#  https://misc.flogisoft.com/bash/tip_colors_and_formatting

DEBUG=${DEBUG:-"-loader,ver,-parser"}

#region Arguments
declare help version \
	args_release args_alpha args_beta args_rc \
	args_major args_minor args_patch args_revision \
	args_git_revision args_stay args_default args_apply args_prefix

# pattern: "{\$argument_index}[,-{short},--{alias}-]=[output]:[init_value]:[args_quantity]"
ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" --version=version:1.0.0"
ARGS_DEFINITION+=" -r,--release=args_release"
ARGS_DEFINITION+=" -a,--alpha=args_alpha"
ARGS_DEFINITION+=" -b,--beta=args_beta"
ARGS_DEFINITION+=" -c,--release-candidate=args_rc"
ARGS_DEFINITION+=" -m,--major=args_major"
ARGS_DEFINITION+=" -i,--minor=args_minor"
ARGS_DEFINITION+=" -p,--patch=args_patch"
ARGS_DEFINITION+=" -e,--revision=args_revision"
ARGS_DEFINITION+=" -g,--git-revision=args_git_revision"
ARGS_DEFINITION+=" --stay=args_stay"
ARGS_DEFINITION+=" --default=args_default"
ARGS_DEFINITION+=" --apply=args_apply"
ARGS_DEFINITION+=" --prefix=args_prefix:sub-folder:1" # sub-folder|root|{any_string}
#endregion

#region Helper scripts attaching
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

# Import all required modules
# shellcheck source=../.scripts/_colors.sh
source /dev/null # trick to make shellcheck happy

# shellcheck source=../.scripts/_commons.sh
source /dev/null # trick to make shellcheck happy

# shellcheck source=../.scripts/_logger.sh
source /dev/null # trick to make shellcheck happy

# shellcheck source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

# shellcheck source=../.scripts/_semver.sh
source "$E_BASH/_semver.sh" # connect advanced version parser
#endregion

# create custom logger echo:Ver, printf:Ver
logger ver "$@" && logger:redirect ver ">&2"

# display help
function help() {
	args:d '-h' 'Show help and exit.' 'global'                # --help
	args:d '--version' 'Show version and exit.' 'global'      # version
	args:d '-r' 'switch stage to release, no suffix.'         # --release
	args:d '-a' 'switch stage to alpha.'                      # --alpha
	args:d '-b' 'switch stage to beta.'                       # --beta
	args:d '-c' 'switch stage to release-candidate.'          # --release-candidate
	args:d '-m' 'Increment MAJOR version part.'               # --major
	args:d '-i' 'Increment MINOR version part.'               # --minor
	args:d '-p' 'Increment PATCH version part.'               # --patch
	args:d '-e' 'Increment REVISION version part.'            # --revision
	args:d '-g' 'Use git revision number as a revision part.' # --git-revision

	args:d '--stay' "Compose ${cl_yellow}version.properties${cl_white} but do not do any increments."
	args:d '--default' 'Increment last found part of version, keeping the stage. Increment applied up to MINOR part.'
	args:d '--apply' 'Run GIT command to apply version upgrade.'
	args:d '--prefix' 'Provide tag prefix or use on of the strategies: root, sub-folder (default), any_string'

	echo 'usage: ./version-up.sh [-r|--release] [-a|--alpha] [-b|--beta] [-c|--release-candidate]'
	echo '                      [-m|--major] [-i|--minor] [-p|--patch] [-e|--revision] [-g|--git-revision]'
	echo '                      [--prefix root|sub-folder|any] [--stay] [--default] [--help]'
	echo ''
	echo 'Switches:'
	print:help
	echo ''
	echo 'Version: [PREFIX]MAJOR.MINOR[.PATCH[.REVISION]][-STAGE]'
	echo ''
	echo 'Reference:'
	echo '  https://semver.org/'
	echo ''
	echo 'Versions priority:'
	echo '  1.0.0-alpha < 1.0.0-beta < 1.0.0-rc < 1.0.0'
	exit 0
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
	local strategy=${1:-"sub-folder"}
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
	## expected: heads/{branch_name}
	## expected: {branch_name}
	local gitBranch=$(git rev-parse --abbrev-ref HEAD | cut -d"/" -f2)
	echo "$gitBranch"
}

# get latest/head commit hash number, print it to STDOUT
function head_hash() {
	local commitHash=$(git rev-parse --verify HEAD)
	echo "$commitHash"
}

# extract tag commit hash code, tag name provided by argument, print it to STDOUT.
function tag_hash() {
	local tagHash=$(git log -1 --format=format:"%H" "$1" 2>/dev/null | tail -n1)
	echo "$tagHash"
}

# resolve prefix argument before the actual processing is done. result print to STDOUT.
function prepare_prefix() {
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
	# Limit analysis to 25 most recent tags for performance
	local all_tags=$(git tag --sort=-creatordate -l | head -n 25)

	# If no tags found, return empty prefix
	if [[ -z "$all_tags" ]]; then
		echo:Ver "Auto-detected prefix: No tags found in the repository."
		echo ""
		return
	fi

	# Get semver regex pattern
	local semver_pattern=$(semver:grep)

	# Key-value storage for prefixes
	declare -A prefixes

	# Process each tag
	while read -r tag; do
		# Use semver regex to extract the prefix
		# Expected pattern: {prefix}{semver}{suffix}
		local semver_part=$(echo "$tag" | grep -oE "$semver_pattern")

		# If we found a semver part in the tag
		if [[ -n "$semver_part" ]]; then
			# Extract prefix by removing semver part (and anything after) from the tag
			local prefix=$(echo "$tag" | sed "s/${semver_part}.*//")

			# Count occurrences of this prefix
			if [[ -n "${prefixes[$prefix]}" ]]; then
				prefixes[$prefix]=$((prefixes[$prefix] + 1))
			else
				prefixes[$prefix]=1
			fi
		fi
	done <<<"$all_tags"

	# Find the most common prefix
	local mostUsed=""
	local max=0 # most used prefix

	for prefix in "${!prefixes[@]}"; do
		if [[ ${prefixes[$prefix]} -gt $max ]]; then
			mostUsed="$prefix"
			max=${prefixes[$prefix]}
		fi
	done

	# print detected patterns top-5, if we have more than 1
	if [[ ${#prefixes[@]} -gt 1 ]]; then
		for prefix in "${!prefixes[@]}"; do
			echo:Ver "Auto-detected prefix: ${prefix}, Count: ${prefixes[$prefix]}"
		done | head -n 5
	fi

	# TODO: depends on the strategy we may select another prefix from the list.
	# sub-folder - means that we have a sub-folder path as a prefix, even if tags with
	#   such pattern are not very often.

	# Format tags as comma-separated list
	local csvTags=$(echo "$all_tags" | tr '\n' ',' | gsed 's/,$//; s/,/, /g')
	echo:Ver "Auto-detected prefix: ${mostUsed} from tags: ${cl_gray}${csvTags}${cl_reset}"

	echo "${mostUsed}"
}

# get latest tag in specified branch. result to STDOUT.
function latest_tag() {
	local resolved_prefix=$(prepare_prefix)

	# extract from git latest tag that started from number (OR from prefix and number)
	local tag=$(git describe --tags --abbrev=0 --match="${resolved_prefix}[0-9]*" 2>/dev/null)

	# if tag is empty then try to autodetect the prefix and try extaction again
	if [[ -z "$tag" ]]; then
		echo:Ver "No tag found, trying to auto-detect prefix..."
		resolved_prefix=$(auto_detect_prefix_from_tags)
		tag=$(git describe --tags --abbrev=0 --match="${resolved_prefix}[0-9]*" 2>/dev/null)
	fi

	echo:Ver "Latest tag: ${tag}"
	echo "$tag"
}

# get latest revision number, print it to STDOUT
function latest_revision() {
	local gitRevision=$(git rev-list --count HEAD 2>/dev/null)
	echo "$gitRevision"
}

# parse first PART of the tage, extract PREFIX if any provided
# shellcheck disable=SC2001
function parse_first() {
	# extract into PREFIX variable all non digits chars from the beginning of the PARTS[0]
	local prefix=$(echo "${PARTS[0]}" | sed 's#\([^0-9]*\)\(.*\)#\1#')

	# leave only digits in the PARTS[0]
	local clean_part=$(echo "${PARTS[0]}" | sed 's#\([^0-9]*\)\(.*\)#\2#')

	PREFIX=$prefix
	PARTS[0]=$clean_part
}

# parse last found tag, extract it PARTS
function parse_last() {
	local position=$(($1 - 1))

	# two parts found only
	# shellcheck disable=SC2206
	local segments=(${PARTS[$position]//-/ }) # split by - into array of strings
	#echo ${segments[@]}, size: ${#segments}

	# found NUMBER
	PARTS[$position]=${segments[0]}
	#echo ${PARTS[@]}

	# found SUFFIX
	if [[ ${#segments} -ge 1 ]]; then
		PARTS[4]=${segments[1],,} #lowercase
		#echo ${PARTS[@]}, ${SUBS[@]}
	fi
}

# increment REVISION part, don't touch STAGE
function increment_revision() {
	PARTS[3]=$((PARTS[3] + 1))
	IS_DIRTY=1
}

# increment PATCH part, reset all others lower PARTS, don't touch STAGE
function increment_patch() {
	PARTS[2]=$((PARTS[2] + 1))
	PARTS[3]=0
	IS_DIRTY=1
}

# increment MINOR part, reset all others lower PARTS, don't touch STAGE
function increment_minor() {
	PARTS[1]=$((PARTS[1] + 1))
	PARTS[2]=0
	PARTS[3]=0
	IS_DIRTY=1
}

# increment MAJOR part, reset all others lower PARTS, don't touch STAGE
function increment_major() {
	PARTS[0]=$((PARTS[0] + 1))
	PARTS[1]=0
	PARTS[2]=0
	PARTS[3]=0
	IS_DIRTY=1
}

# increment the number only of last found PART: REVISION --> PATCH --> MINOR. don't touch STAGE
function increment_last_found() {
	if [[ "${#PARTS[3]}" == 0 || "${PARTS[3]}" == "0" ]]; then
		if [[ "${#PARTS[2]}" == 0 || "${PARTS[2]}" == "0" ]]; then
			increment_minor
		else
			increment_patch
		fi
	else
		increment_revision
	fi

	# stage part is not EMPTY
	if [[ "${#PARTS[4]}" != 0 ]]; then
		IS_SHIFT=1
	fi
}

# compose version from PARTS
function compose() {
	local major="${PARTS[0]}"
	local minor=".${PARTS[1]}"
	local patch=".${PARTS[2]}"
	local revision=".${PARTS[3]}"
	local suffix="-${PARTS[4]}"

	if [[ "${#patch}" == 1 ]]; then # if empty {patch}
		patch=""
	fi

	if [[ "${#revision}" == 1 ]]; then # if empty {revision}
		revision=""
	fi

	if [[ "${PARTS[3]}" == "0" ]]; then # if revision is ZERO
		revision=""
	fi

	# shrink patch and revision
	if [[ -z "${revision// /}" ]]; then
		if [[ "${PARTS[2]}" == "0" ]]; then
			patch=""
		fi
	else # revision is not EMPTY
		if [[ "${#patch}" == 0 ]]; then
			patch=".0"
		fi
	fi

	# remove suffix if we don't have alpha/beta/rc
	if [[ "${#suffix}" == 1 ]]; then
		suffix=""
	fi

	echo "${PREFIX}${major}${minor}${patch}${revision}${suffix}" #full format
}

# print error message about conflict with existing tag and proposed tag
function error_conflict_tag() {
	local red=$(tput setaf 1)
	local end=$(tput sgr0)
	local yellow=$(tput setaf 3)

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

	echo "# $(date)" >${publish_path}
	{
		echo "## Version: 3.0.0"
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

	git tag "$(compose)"

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
		echo "Found tag: $TAG in branch '$BRANCH'"
	fi

	# print current revision number based on number of commits
	echo "Current Revision: $REVISION"
	echo "Current Branch  : $BRANCH"
	echo "Repository Dir  : \"$(realpath "$(monorepo_root)")\""
	echo "Current Folder  : \"$(prefix_sub_folder)\""
	echo ""

}

function handle_stage_shift() {
	stage=${PARTS[4]}
	PARTS[4]=''

	# detect first run on repository, INIT_VERSION was used
	if [[ "$(compose)" == "0.0" ]]; then
		increment_minor
	fi

	PARTS[4]=$stage
}

function parse_arguments() {
	local args=("$@")

	local isNoArgs=false
	[ "${#args[@]}" -eq 0 ] && isNoArgs=true

	# parse input parameters
	if [[ "$help" == "1" ]]; then
		help
	elif [[ -n "$version" ]]; then
		echo "version: ${version}"
		exit 0
	else
		if $isNoArgs; then
			if [[ "$TAG_HASH" == "$HEAD_HASH" ]]; then
				echo "Tag $TAG and HEAD are aligned. We will stay on the TAG version."
				# TODO: should we re-create the version.properties file?
				exit 0
			fi

			# are we in the branch that has version tag or name that matches the pattern?
			local semver_grep=$(semver:grep)
			local semver_part=$(echo "$BRANCH" | grep -oE "$semver_grep")

			if [[ -n "$semver_part" ]]; then
				echo "Detected version branch '$BRANCH'. We will auto-increment the last version PART."
				args_default=1
			else
				echo "Detected branch name '$BRANCH' than does not match version pattern. We will increase MINOR."
				args_minor=1
			fi
		fi

		[[ "$args_alpha" == "1" ]] && PARTS[4]="alpha" && IS_SHIFT=1
		[[ "$args_beta" == "1" ]] && PARTS[4]="beta" && IS_SHIFT=1
		[[ "$args_rc" == "1" ]] && PARTS[4]="rc" && IS_SHIFT=1
		[[ "$args_release" == "1" ]] && PARTS[4]="" && IS_SHIFT=1

		[[ "$args_patch" == "1" ]] && increment_patch
		[[ "$args_revision" == "1" ]] && increment_revision
		[[ "$args_git_revision" == "1" ]] && PARTS[3]=$((REVISION)) && IS_DIRTY=1
		[[ "$args_minor" == "1" ]] && increment_minor

		[[ "$args_default" == "1" ]] && increment_last_found
		[[ "$args_major" == "1" ]] && increment_major
		[[ "$args_stay" == "1" ]] && IS_DIRTY=1 && NO_APPLY_MSG=1

		[[ "$args_apply" == "1" ]] && DO_APPLY=1

		[[ -n "$args_prefix" ]] && use_prefix "$args_prefix"
	fi

}

# Check if version.properties exists and process it
# Inputs: none
# Outputs: STDOUT - logs about version properties status
# Side effects: sets VERSION_PROPS_EXISTS global variable, sources properties file
function check_version_properties() {
	local version_props_exists=0

	if [[ -n "${VERSION_PROPS_PATH}" ]]; then
		echo:Ver "Found version.properties file: ${VERSION_PROPS_PATH}"
		process_version_properties "${VERSION_PROPS_PATH}"
		version_props_exists=1
	else
		echo:Ver "No version.properties found. Using default version logic."
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
		echo:Ver "Version tags detected: ${TAG}"
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
		echo:Ver "Known prefix 'v' detected."
		PREFIX="v"
	else
		# Check if it's a subfolder path
		sub_folder=$(prefix_sub_folder)
		if [[ "${prefix}" == "${sub_folder}" ]]; then
			echo:Ver "Prefix matches current subfolder: ${sub_folder}"
			PREFIX="${sub_folder}"
		else
			echo:Ver "Using detected prefix: ${prefix}"
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
		echo:Ver "Prefix detected: ${AUTO_DETECTED_PREFIX}"

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
			echo:Ver "Using subfolder as prefix: ${PREFIX}"
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
		echo:Ver "Tags found in the repository."

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
	# Configure the global variables for triggering proper actions
	parse_arguments "$@"

	# Print current state of the repository on screen
	report_current_state

	# Detected shift between stages, but no increment applied
	[[ "$IS_SHIFT" == "1" ]] && handle_stage_shift

	# No increment applied yet and no shift of state, do minor increase
	[[ "$IS_DIRTY$IS_SHIFT" == "" ]] && increment_minor

	# Instruct user how to apply new TAG
	echo:Ver "Proposed TAG: ${cl_green}$(compose)${cl_reset}"
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

# Main function that orchestrates the versioning process
# Inputs: $@ - command line arguments
# Outputs: STDOUT - logs about version processing
# Side effects: various, handled by subfunctions
function main() {
	echo:Ver "Starting version-up.v2.sh process"

	# Check if version.properties exists and process it
	check_version_properties

	# Process version tag detection and handling
	process_tag_detection

	# Process version calculation and potential conflicts
	process_version "$@"

	# Handle version application
	handle_version_apply

	echo:Ver "Version-up.v2.sh process completed"
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
		echo "Using version definitions from: ${properties_file}"
		# Source the properties file to get variables
		# shellcheck disable=SC1090
		source "${properties_file}"
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

# try to detect the prefix in versioning tags/branches names. expected pattern: {PREFIX}{SEMVER}{SUFFIX}
# PREFIX in this case can be:
#   - '{any-string}' - something defined by user;
#   - '{sub-folder}' - sub-folder path used as a prefix;
#   - '{root}' - empty string;
PREFIX=$(prepare_prefix "$@")
AUTO_DETECTED_PREFIX=$(auto_detect_prefix_from_tags)

# initial version used for repository without tags
INIT_VERSION="${PREFIX}0.0.0.0-alpha"

# do GIT data extracting into globals
TAG=$(latest_tag "$@")
REVISION=$(latest_revision)
BRANCH=$(current_branch)
TOP_TAG=$(highest_tag)
TAG_HASH=$(tag_hash "$TAG")
HEAD_HASH=$(head_hash)
PROPOSED_HASH=""
VERSION_FILE=version.properties

# Find version.properties if it exists
VERSION_PROPS_PATH=$(find_version_properties)

# parse the tag into parts
semver:parse "${TAG}" "PARTS" && echo "${PARTS[@]}" || echo "$? - FAIL parsing '${TAG}'!"

main "$@"

#
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
