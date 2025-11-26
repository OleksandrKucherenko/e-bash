#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2317

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


#
# Standard helper functions to strip ANSI color codes from ShellSpec output
# These match the pattern used across all e-bash test specs
#
# Usage in ShellSpec tests:
#   When call some_function
#   The result of function no_colors_stderr should include "expected text"
#   The result of function no_colors_stdout should include "expected output"
#
# Arguments:
#   $1 = stdout
#   $2 = stderr
#   $3 = exit status
#
no_colors_stderr() {
  echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '
}

no_colors_stdout() {
  echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '
}

#
# Count occurrences of a word in text (cross-platform compatible)
# Strips ANSI color codes and uses awk for portable counting
#
# Usage: count_word_in_output "word_to_count" "text to search"
# Returns: Number of occurrences
#
count_word_in_output() {
  local word="$1"
  local text="$2"

  # Strip ANSI color codes using standard pattern
  local clean_text
  clean_text=$(echo "$text" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g')

  # Count word occurrences using awk (portable across GNU and BSD)
  # Splits on whitespace and matches whole words
  echo "$clean_text" | awk -v word="$word" '{
    for(i=1; i<=NF; i++) {
      if($i == word) count++
    }
  } END {
    print count+0
  }'
}

#
# Strip ANSI color codes from text
# Usage: strip_colors "text with colors"
# Returns: Clean text without ANSI codes
#
strip_colors() {
  local text="$1"
  echo "$text" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g'
}

#
# Count lines in text
# Usage: count_lines "multiline text"
# Returns: Number of lines
#
count_lines() {
  local text="$1"
  echo "$text" | wc -l | tr -d ' '
}

#
# Check if text contains a substring
# Usage: contains "haystack" "needle"
# Returns: 0 if found, 1 if not found
#
contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]]
}

#
# Normalize whitespace (convert multiple spaces/tabs to single space, trim)
# Usage: normalize_whitespace "text   with    extra    spaces"
# Returns: "text with extra spaces"
#
normalize_whitespace() {
  local text="$1"
  echo "$text" | tr -s '[:space:]' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
