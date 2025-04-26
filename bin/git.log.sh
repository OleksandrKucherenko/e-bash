#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


TOP=${1:-10}

# shellcheck source=../.scripts/_colors.sh
source /dev/null # trick shellcheck

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_commons.sh
source "$E_BASH/_logger.sh"

# Get terminal width
tput cols &>/dev/null
TERM_WIDTH=$(tput cols)

# Define column widths based on terminal width
ID_WIDTH=3
HASH_WIDTH=7
TIME_WIDTH=5
AUTHOR_WIDTH=15
MESSAGE_WIDTH=$((TERM_WIDTH - HASH_WIDTH - TIME_WIDTH - AUTHOR_WIDTH - 5 * 4)) # 5 columns, each 4 chars extra

# If terminal is wide enough, increase author width
if [ "${TERM_WIDTH}" -gt 100 ]; then
	AUTHOR_WIDTH=20
	MESSAGE_WIDTH=$((TERM_WIDTH - HASH_WIDTH - TIME_WIDTH - AUTHOR_WIDTH - 5 * 4))
fi

function format_column() {
	local text="$1"
	local width="$2"
	local truncated

	if [ "${#text}" -gt "${width}" ]; then
		truncated="${text:0:$((width - 3))}...${text:$((${#text} - 3))}"
	else
		truncated="$text"
	fi

	# Calculate padding to center the text
	local padding_left=$(((width - ${#truncated}) / 2))
	local padding_right=$((width - ${#truncated} - padding_left))

	printf "%-${padding_left}s%s%-${padding_right}s" " " "$truncated" " "
}

# repeat spacer string N times
function sp() {
	local num="$1"
	local filler="-"

	printf "%${num}s\n" | tr ' ' "$filler"
}

# Print table header
title_row="%${ID_WIDTH}s | %${HASH_WIDTH}s | %${TIME_WIDTH}s | %${AUTHOR_WIDTH}s | %-${MESSAGE_WIDTH}s"
separator_row="%${ID_WIDTH}s-+-%${HASH_WIDTH}s-+-%${TIME_WIDTH}s-+-%${AUTHOR_WIDTH}s-+-%${MESSAGE_WIDTH}s"
log_row="%${ID_WIDTH}s | %${HASH_WIDTH}s | ${cl_blue}%${TIME_WIDTH}s${cl_reset} | %-${AUTHOR_WIDTH}s | %-${MESSAGE_WIDTH}s"

echo "---"
echo "${log_row}"
echo "---"

printf "${title_row}\n" "#" "hash" "time" "author" "message, tags, branches"
printf "${separator_row}\n" "$(sp $ID_WIDTH)" "$(sp $HASH_WIDTH)" "$(sp $TIME_WIDTH)" "$(sp $AUTHOR_WIDTH)" "$(sp $MESSAGE_WIDTH)"

# Extract logs
PATTERN="%h%x09"   # short commit hash
PATTERN+="%cr%x09" # committer date, relative
PATTERN+="%aN%x09" # author name (respecting .mailmap)
PATTERN+="%s%x09"  # subject
PATTERN+="%D"      # ref names, tags

git --no-pager log --pretty=format:"${PATTERN}" --color -n "${TOP}" --date=short | # extract logs
	nl -w2 |                                                                          # number lines
	sed -e "s# hours ago#h#" \
		-e "s# seconds ago#s#" \
		-e "s# days ago#d#" \
		-e "s# weeks ago#w#" \
		-e "s# months ago#M#" \
		-e "s# minutes ago#m#" \
		-e "s# to master##" \
		-e "s#Pull request #PR#" \
		-e "s#Merge pull request#Merge#" | # cleanup texts
	while read -r line; do
		# split line into columns: id, hash, time, author, message, refs
		IFS=$'\t' read -r id hash time author message refs <<<"$line"

		# remove 0x0A (line break) from message
		message="$(echo "$message" | tr '\n' " ")"
		# hexdump -C <<<"$message-"

		echo "${cl_grey} $id $hash $time $author $message ${cl_reset}"
		printf "${log_row}\n" "$id" "$hash" "$time" "$author" "$message" "" #"$refs"
	done

# git --no-pager log --pretty=format:"${PATTERN}" --color -n "${TOP}" --date=short | # extract logs
# 	nl -w2 -s"  " |                                                                   # number lines
# 	sed -e "s# hours ago#h#" \
# 		-e "s# seconds ago#s#" \
# 		-e "s# days ago#d#" \
# 		-e "s# weeks ago#w#" \
# 		-e "s# months ago#M#" \
# 		-e "s# minutes ago#m#" \
# 		-e "s#in KLAPP/klarna-app from#<~#" \
# 		-e "s# to master##" \
# 		-e "s#Pull request #PR#" \
# 		-e "s#Merge pull request#Merge#" | # cleanup texts
# 	awk -v id_width=$ID_WIDTH -v hash_width=$HASH_WIDTH -v time_width=$TIME_WIDTH -v author_width=$AUTHOR_WIDTH -v message_width=$MESSAGE_WIDTH -F"\t" '
# 	  BEGIN {OFS="|"};
# 	  {
# 	    hash = $1
# 	    time = $2
# 	    author = $3
# 	    message = $4
# 	    refs = $5

# 	    # Trim if necessary
# 	    if (length(author) > author_width) {
# 	      author = substr(author, 1, author_width-3) "..." substr(author, length(author) - 3, 3)
# 	    }

# 	    # Add spacing for alignment
# 	    hash_part = " " hash " "
# 	    time_part = " " time " "
# 	    author_part = " " author " "

# 	    # Print formatted line
# 	    printf("%${id_width}s | %${hash_width}s | %${time_width}s | %${author_width}s | %${message_width}s\n", "", hash_part, time_part, author_part, " " message refs)
# 	  }
# 	' |
# 	gsed -e "s#tag:#\n\t\t\t\t\t\t       🏷️::#g" \
# 		-e "s#HEAD#\n\t\t\t\t\t\t       👑#g" \
# 		-e "s#origin/#\n\t\t\t\t\t\t       🔀: origin/#g" # put tags and branches on new line
