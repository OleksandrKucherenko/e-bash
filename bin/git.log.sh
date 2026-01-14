#!/usr/bin/env bash
# shellcheck disable=SC2059,SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# Ultra-optimized bootstrap: E_BASH discovery + gnubin PATH
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; . "$E_BASH/_gnu.sh"; PATH="$E_BASH/../bin/gnubin:$PATH"; }

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck source=../.scripts/_colors.sh
source /dev/null # trick shellcheck
# shellcheck disable=SC1090 source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck disable=SC1090 source=../.scripts/_arguments.sh
source "$E_BASH/_arguments.sh"

logger:init debug "[${cl_blue}debug${cl_reset}] "

# Get terminal width
tput cols &>/dev/null # trick to force tput correctly detect terminal width
readonly TERM_WIDTH=$(tput cols)

# Define column widths based on terminal width
readonly ID_WIDTH=3
readonly HASH_WIDTH=7
readonly TIME_WIDTH=4

export AUTHOR_WIDTH=12
export MESSAGE_WIDTH=$((TERM_WIDTH - HASH_WIDTH - TIME_WIDTH - AUTHOR_WIDTH - 5 * 4)) # 5 columns, each 4 chars extra

function adjust:to:terminal() {
	echo:Debug "MESSAGE_WIDTH: ${MESSAGE_WIDTH}"

	# If terminal is wide enough, increase author width
	if [ "${TERM_WIDTH}" -gt 100 ]; then
		export AUTHOR_WIDTH=20
		export MESSAGE_WIDTH=$((TERM_WIDTH - HASH_WIDTH - TIME_WIDTH - AUTHOR_WIDTH - 5 * 4))
		echo:Debug "MESSAGE_WIDTH(2): ${MESSAGE_WIDTH}"
	fi
}

# ellipsis in the middle of the string
function ellipsis() {
	local type="$1"
	local text="$2"
	local width="$3"
	local truncated="${text}"

	# if type==mid
	if [ "${type}" = "mid" ]; then
		if [ "${#text}" -gt "${width}" ]; then
			local middle=$((width / 2))
			local start=${text:0:$((middle - 3))}
			local end=${text:$((${#text} - middle))}
			truncated="${start}...${end}"
		fi
	elif [ "${type}" = "end" ]; then
		if [ "${#text}" -gt "${width}" ]; then
			local end=${text:0:$((${#text} - width - 3))}
			truncated="${end}..."
		fi
	fi

	echo "${truncated}"
}

function ellipsis:mid() {
	ellipsis mid "$1" "$2"
}

function ellipsis:end() {
	ellipsis end "$1" "$2"
}

# remove ansi colors
function no_colors() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g' | tr -s ' '; }

# repeat spacer string N times. $1 - N, $2 - spacer/filler.
function sp() { printf "%${1}s\n" | tr ' ' "${2:-"-"}"; }

function color_refs() {
	local refs=$1

	# highlight in different colors: HEAD, remotes and local branches
	IFS=',' read -r -a branches <<<"$refs"
	separators=", " ptrs=""
	for branch in "${branches[@]}"; do
		branch="${branch// /}" # remove spaces
		echo:Debug "branch: ${branch}"

		if [[ "$branch" == origin/* ]]; then
			# if contains `origin/`, color yellow
			ptrs+="${separators}${cl_yellow}${branch}${cl_reset}"
		elif [[ "$branch" == tag:* ]]; then
			# if contains `tags/`, color green
			ptrs+="${separators}${cl_green}${branch}${cl_reset}"
		elif [[ "$branch" == HEAD* ]]; then
			# if contains `HEAD ->`, color blue
			ptrs+="${separators}${cl_blue}${branch}${cl_reset}"
		else
			# else, color purple
			ptrs+="${separators}${cl_purple}${branch}${cl_reset}"
		fi
	done

	# use emoji to reduce the length of the string
	ptrs="$(echo "$ptrs" | gsed -e "s#tag:#🏷️::#g; s#HEAD->#👑:#g; s#/HEAD#/👑#g; s#origin/#🔀/#g")"

	echo "$ptrs"
}

# Simplifies log output using sed replacements for time units, merge/pull request markers, and colors.
simplify_log() {
	sed -e "s# hours ago#h#; s# seconds ago#s#; s# days ago#d#; s# weeks ago#w#; s# months ago#M#; s# minutes ago#m#; s# year, #y#; s# year ago#y#" \
		-e "s# to master##" \
		-e "s#Pull request #PR#" \
		-e "s#Merge branch#${cl_cyan}Merge${cl_reset}#" \
		-e "s#Merge pull request#${cl_cyan}Merge${cl_reset}#"
}

function main() {
	# adjust output to terminal width
	adjust:to:terminal

	# prepare table printing templates
	title_row="%${ID_WIDTH}s | %${HASH_WIDTH}s | %${TIME_WIDTH}s | %${AUTHOR_WIDTH}s | %-${MESSAGE_WIDTH}s"
	separator_row="%${ID_WIDTH}s-+-%${HASH_WIDTH}s-+-%${TIME_WIDTH}s-+-%${AUTHOR_WIDTH}s-+-%${MESSAGE_WIDTH}s"
	log_row="%${ID_WIDTH}s | ${cl_grey}%${HASH_WIDTH}s${cl_reset} | ${cl_blue}%${TIME_WIDTH}s${cl_reset} | ${cl_green}%-${AUTHOR_WIDTH}s${cl_reset} | %-${MESSAGE_WIDTH}s"

	# Print table header
	printf "${title_row}\n" "#" "hash" "time" "author" "message, tags, branches"
	printf "${separator_row}\n" "$(sp $ID_WIDTH)" "$(sp $HASH_WIDTH)" "$(sp $TIME_WIDTH)" "$(sp $AUTHOR_WIDTH)" "$(sp $MESSAGE_WIDTH)"

	# Extract logs
	PATTERN="%h%x09"   # short commit hash
	PATTERN+="%cr%x09" # committer date, relative
	PATTERN+="%aN%x09" # author name (respecting .mailmap)
	PATTERN+="%s%x09"  # subject
	PATTERN+="%D%x09"  # ref names, tags

	git --no-pager log --pretty=format:"${PATTERN}" --color -n "${TOP}" --date=short | nl -w2 | simplify_log |
		while read -r line; do
			# split line into columns by TAB|\x09: id, hash, time, author, message, refs
			IFS=$'\t' read -r id hash time author message refs <<<"$line"

			author="$(ellipsis:mid "$author" $AUTHOR_WIDTH)"

			ptrs="$(color_refs "$refs")"
			onlytext_ptrs="$(no_colors "$ptrs")"
			msg="$(ellipsis:mid "$message" $((MESSAGE_WIDTH - ${#onlytext_ptrs})))$ptrs"

			printf -- "${log_row}\n" "$id" "$hash" "$time" "$author" "$msg"
		done
}

# detect the MAIN/MASTER branch name
git_master_name=$(git rev-parse --verify master >/dev/null 2>&1 && echo master || echo main)

# total commits in branch
git_commits=$(git rev-list --no-merges --count "${git_master_name}..")

export TOP=${ARGS_NO_FLAGS[0]:-$((git_commits + 2))}

main "$@"
