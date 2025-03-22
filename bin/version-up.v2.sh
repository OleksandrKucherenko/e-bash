#!/usr/bin/env bash
# shellcheck disable=SC2155,SC1090

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-20
## Version: 2.0.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Fix: 2023-10-01, prefix for initial INIT_VERSION was not applied
## Fix: 2023-10-01, correct extraction of latest tag that match version pattern
## Added: 2023-09-30, @mrares prefix modification implemented
## Bug fixes: 2021-06-09, @slmingol changes applied

# For help:
#   ./version-up.sh --help

# For developer / references:
#  https://ryanstutorials.net/bash-scripting-tutorial/bash-functions.php
#  http://tldp.org/LDP/abs/html/comparison-ops.html
#  https://misc.flogisoft.com/bash/tip_colors_and_formatting

DEBUG=${DEBUG:-"loader,ver,-parser"}

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
ARGS_DEFINITION+=" --prefix=args_prefix:sub-folder:1" # sub-folder|root|{any_string_prefix}
#endregion

[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"

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

logger ver "$@"           # echo:Ver and printf:Ver - loggers
logger:redirect ver ">&2" # redirect Ver to stderr

## display help
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

## find the monorepo root folder, print it to STDOUT
function monorepo_root() {
	# Navigate up from the script directory until we find the .git sub-folder to determine the monorepo root
	local monorepoRootDir=$(
		dir="$(dirname "${BASH_SOURCE[0]}")"
		while [[ "$dir" != '/' && ! -d "$dir/.git" ]]; do dir="$(dirname "$dir")"; done
		echo "$dir"
	)
	echo "$monorepoRootDir"
}

# https://stackoverflow.com/a/67449155
function get_relative_path() {
	local targetFilename=$(basename "$1")
	local targetFolder=$(cd "$(dirname "$1")" && pwd) # absolute target folder path
	local currentFolder=$(cd "$2" && pwd)             # absolute source folder
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

## get monorepo sub-folder, print it to STDOUT
function prefix_sub_folder() {
	local tmpFileName="temp.file"
	local repoDir=$(realpath "$(monorepo_root)")
	local relativePath=$(get_relative_path "$(pwd)/$tmpFileName" "$repoDir")

	# expected / at the end
	echo "${relativePath/$tmpFileName/}"
}

## resolve income parameter into prefix, print it to STDOUT
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

## calculate the prefix based on the strategy. Modifies PREFIX variable.
function use_prefix() {
	PREFIX=$(prefix_strategy "$1")

	echo:Ver "Tag prefix: '$PREFIX'"
}

## get the highest version tag for all branches, print it to STDOUT
function highest_tag() {
	local gitTag=$(git tag --list 2>/dev/null | sort -V | tail -n1 2>/dev/null)
	echo "$gitTag"
}

## extract current branch name, print it to STDOUT
function current_branch() {
	## expected: heads/{branch_name}
	## expected: {branch_name}
	local gitBranch=$(git rev-parse --abbrev-ref HEAD | cut -d"/" -f2)
	echo "$gitBranch"
}

## get latest/head commit hash number, print it to STDOUT
function head_hash() {
	local commitHash=$(git rev-parse --verify HEAD)
	echo "$commitHash"
}

## extract tag commit hash code, tag name provided by argument, print it to STDOUT
function tag_hash() {
	local tagHash=$(git log -1 --format=format:"%H" "$1" 2>/dev/null | tail -n1)
	echo "$tagHash"
}

## resolve prefix argument before the actual processing is done
function preparse_prefix_argument() {
	local resolved_prefix=$(prefix_strategy)

	# if --prefix provided, then required filtering of the tags by provided prefix pattern
	if [[ -n "$args_prefix" ]]; then
		resolved_prefix=$(prefix_strategy "$args_prefix")
	fi

	echo "$resolved_prefix"
}

## get latest tag in specified branch
# shellcheck disable=SC2001
function latest_tag() {
	local resolved_prefix=$(preparse_prefix_argument)

	# extract from git latest tag that started from number (OR from prefix and number)
	local tag=$(git describe --tags --abbrev=0 --match="${resolved_prefix}[0-9]*" 2>/dev/null)
	echo "$tag"
}

## get latest revision number, print it to STDOUT
function latest_revision() {
	local gitRevision=$(git rev-list --count HEAD 2>/dev/null)
	echo "$gitRevision"
}

## parse first PART of the tage, extract PREFIX if any provided
# shellcheck disable=SC2001
function parse_first() {
	# extract into PREFIX variable all non digits chars from the beginning of the PARTS[0]
	local prefix=$(echo "${PARTS[0]}" | sed 's#\([^0-9]*\)\(.*\)#\1#')

	# leave only digits in the PARTS[0]
	local clean_part=$(echo "${PARTS[0]}" | sed 's#\([^0-9]*\)\(.*\)#\2#')

	PREFIX=$prefix
	PARTS[0]=$clean_part
}

## parse last found tag, extract it PARTS
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

## increment REVISION part, don't touch STAGE
function increment_revision() {
	PARTS[3]=$((PARTS[3] + 1))
	IS_DIRTY=1
}

## increment PATCH part, reset all others lower PARTS, don't touch STAGE
function increment_patch() {
	PARTS[2]=$((PARTS[2] + 1))
	PARTS[3]=0
	IS_DIRTY=1
}

## increment MINOR part, reset all others lower PARTS, don't touch STAGE
function increment_minor() {
	PARTS[1]=$((PARTS[1] + 1))
	PARTS[2]=0
	PARTS[3]=0
	IS_DIRTY=1
}

## increment MAJOR part, reset all others lower PARTS, don't touch STAGE
function increment_major() {
	PARTS[0]=$((PARTS[0] + 1))
	PARTS[1]=0
	PARTS[2]=0
	PARTS[3]=0
	IS_DIRTY=1
}

## increment the number only of last found PART: REVISION --> PATCH --> MINOR. don't touch STAGE
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

## compose version from PARTS
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

## print error message about conflict with existing tag and proposed tag
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

## print help message how to apply changes manually
function help_manual_apply() {
	echo 'To apply changes manually execute the command(s):'
	echo -e "\033[90m"
	echo "  git tag $(compose)"
	echo "  git push origin $(compose)"
	echo -e "\033[0m"
}

## save all support information into version.properties file
function publish_version_file() {
	echo "# $(date)" >${VERSION_FILE}
	{
		echo "snapshot.version=$(compose)"
		echo "snapshot.lasttag=$TAG"
		echo "snapshot.revision=$REVISION"
		echo "snapshot.hightag=$TOP_TAG"
		echo "snapshot.branch=$BRANCH"
		echo '# end of file'
	} >>"${VERSION_FILE}"
}

## apply changes to GIT repository, local changes only
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

## print current state of the repository
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

function main() {
	# print current state of the repository on screen
	report_current_state

	# detected shift between stages, but no increment applied
	[[ "$IS_SHIFT" == "1" ]] && handle_stage_shift

	# no increment applied yet and no shift of state, do minor increase
	[[ "$IS_DIRTY$IS_SHIFT" == "" ]] && increment_minor

	# instruct user how to apply new TAG
	echo -e "Proposed TAG: \033[32m$(compose)\033[0m"
	echo ''

	# is proposed tag in conflict with any other TAG
	PROPOSED_HASH=$(tag_hash "$(compose)")
	if [[ "${#PROPOSED_HASH}" -gt 0 && "$NO_APPLY_MSG" == "" ]]; then
		error_conflict_tag
	fi

	if [[ "$NO_APPLY_MSG" == "" ]]; then
		help_manual_apply
	fi

	# compose version override file
	if [[ "$TAG" == "$INIT_VERSION" ]]; then
		TAG='0.0'
	fi

	publish_version_file

	# should we apply the changes
	if [[ "$DO_APPLY" == "1" ]]; then
		apply_git_changes
	fi
}

PREFIX=$(preparse_prefix_argument)

# initial version used for repository without tags
INIT_VERSION="${PREFIX}0.0.0.0-alpha"

# do GIT data extracting, globals
TAG=$(latest_tag)
REVISION=$(latest_revision)
BRANCH=$(current_branch)
TOP_TAG=$(highest_tag)
TAG_HASH=$(tag_hash "$TAG")
HEAD_HASH=$(head_hash)
PROPOSED_HASH=""
VERSION_FILE=version.properties

# if tag and branch commit hashes are different, then print info about that
#echo $HEAD_HASH vs $TAG_HASH
# shellcheck disable=SC2199
if [[ "$@" == "" ]]; then
	if [[ "$TAG_HASH" == "$HEAD_HASH" ]]; then
		echo "Tag $TAG and HEAD are aligned. We will stay on the TAG version."
		echo ""
		NO_ARGS_VALUE='--stay'
	else
		PATTERN="^[0-9]+.[0-9]+(.[0-9]+)*(-(alpha|beta|rc))*$"

		if [[ "$BRANCH" =~ $PATTERN ]]; then
			echo "Detected version branch '$BRANCH'. We will auto-increment the last version PART."
			echo ""
			NO_ARGS_VALUE='--default'
		else
			echo "Detected branch name '$BRANCH' than does not match version pattern. We will increase MINOR."
			echo ""
			NO_ARGS_VALUE='--minor'
		fi
	fi
fi

#
# [PREFIX]{MAJOR}.{MINOR}[.{PATCH}[.{REVISION}][-(.*)]
#
#  Suffix: alpha, beta, rc
#    No Suffix --> {NEW_VERSION}-alpha
#    alpha --> beta
#    beta --> rc
#    rc --> {VERSION}
#
semver:parse "${TAG}" "PARTS" && echo "${PARTS[@]}" || echo "$? - FAIL!"

# shellcheck disable=SC2206
PARTS=(${TAG//./ })
parse_first
parse_last ${#PARTS[@]} # array size as argument
#echo ${PARTS[@]}

# if no parameters than emulate --default parameter
# shellcheck disable=SC2199
if [[ "$@" == "" ]]; then
	# shellcheck disable=SC2086
	set -- ${NO_ARGS_VALUE}
fi

# parse input parameters
if [[ "$help" == "1" ]]; then
	help
elif [[ -n "$version" ]]; then
	echo "version: ${version}"
	exit 0
else
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

main

#
# Major logic of the script - "on each run script propose future version of the product".
#
#  - if no tags on project --> propose '0.1-alpha'
#  - do multiple build iterations until you become satisfied with result
#  - run 'version-up.v2.sh --apply' to save result in GIT
#
