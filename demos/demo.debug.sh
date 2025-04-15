#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-04-15
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


shopt -s extdebug

# force debug variable to be available for this demo
DEBUG=${DEBUG:-"1"}

readonly GRAY=$(tput setaf 8) # dark gray
readonly BLUE=$(tput setaf 4) # blue
readonly NC=$(tput sgr0)      # No Color

__FUNC_STACK="" # CSV list of functions

function on_entry() {
  local current_func="${FUNCNAME[1]}" indent_level indent last_on_stack
  last_on_stack="${__FUNC_STACK##*,}"
  indent_level=$(echo "$__FUNC_STACK" | tr -cd ',' | wc -c)
  indent=$(printf '%*s' "$indent_level" '' | tr ' ' '  ')

  # if we got "<<" exit from nested function, then print current new level
  if [[ "$last_on_stack" == "<<" ]]; then
    __FUNC_STACK=${__FUNC_STACK%,*}

    indent=$(printf '%*s' "$((indent_level - 1))" '' | tr ' ' '  ')
    echo -e "${indent}${GRAY}-- ${BLUE}$current_func${NC}" >&2
  elif [[ "$current_func" != "on_entry" &&
    "$current_func" != "on_return" &&
    "$current_func" != "$last_on_stack" ]]; then
    echo -e "${indent}${GRAY}>> ${BLUE}$current_func${NC}" >&2
    __FUNC_STACK="$__FUNC_STACK,$current_func"
  fi
}

function on_return() {
  local current_func="${FUNCNAME[1]}" indent_level indent

  __FUNC_STACK=${__FUNC_STACK%,*}
  indent_level=$(echo "$__FUNC_STACK" | tr -cd ',' | wc -c)
  indent=$(printf '%*s' "$indent_level" '' | tr ' ' '  ')
  echo -e "${indent}${GRAY}<< ${BLUE}$current_func${NC}" >&2

  __FUNC_STACK="${__FUNC_STACK},<<" #
}

[ -n "$DEBUG" ] && trap on_entry DEBUG && trap on_return RETURN

# ---- Example functions ----
foo() {
  echo "Inside foo"
}

bar() {
  echo "Inside bar"
  foo
}

# ---- Example calls ----
foo
bar
