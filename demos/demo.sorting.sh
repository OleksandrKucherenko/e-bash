#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"dbg,-semver"}

# Ultra-optimized bootstrap: E_BASH discovery + gnubin PATH
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; . "$E_BASH/_gnu.sh"; PATH="$E_BASH/../bin/gnubin:$PATH"; }

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_semver.sh
source "$E_BASH/_semver.sh"

logger:init dbg

function compare:numbers() {
  local a=$1 b=$2
  if ((a < b)); then return 0; fi
  return 1
}

function compare:versions() {
  #echo:Dbg "${cl_green}$1${cl_reset} < ${cl_blue}$2${cl_reset}: $( (semver:constraints:simple "$1<$2") && echo 'yes' || echo 'no')"

  (semver:constraints:simple "$1<$2") && return 0 || return 1
}

function compare:strings() {
  [[ "$1" < "$2" ]] && return 0 || return 1
}

# Quick-Sort implementation
# Sorts an array of strings using the given comparison function.
#
# The first argument should be a function name that takes two arguments and
# returns 0 if the first argument is less than or equal to the second,
# and 1 otherwise.
#
# The rest of the arguments should be the elements of the array to be sorted.
#
# The function will print the sorted array to stdout.
#
# Example:
#   array:qsort compare:versions 1.0.0-beta 1.0.0-beta.11 1.0.0-beta.2
function array:qsort() {
  local compare=$1 && shift
  local array=("$@")
  local length=${#array[@]}

  if ((length == 0)); then
    return
  fi

  if ((length == 1)); then
    echo "${array[0]}"
    return
  fi

  local pivot="${array[0]}"
  local left=()
  local right=()

  for ((i = 1; i < length; i++)); do
    if eval "$compare" "${array[i]}" "${pivot}"; then
      left+=("${array[i]}")
    else
      right+=("${array[i]}")
    fi
  done

  array:qsort "$compare" "${left[@]}"
  echo "$pivot"
  array:qsort "$compare" "${right[@]}"
}

function test:version-strings() {
  local versions=()
  versions+=("1.0.0-beta")
  versions+=("1.0.0-beta.11")
  versions+=("1.0.0-beta.2")
  versions+=("1.0.0-rc.1")
  versions+=("1.0.0")
  versions+=("1.0.0-alpha")
  versions+=("1.0.0-alpha.1")
  versions+=("1.0.0-alpha.beta")
  versions+=("2.2.3-rc.1+build.123")
  versions+=("2.2.3-rc.1")
  versions+=("2.2.3-1")       # pre-release
  versions+=("2.2.3-rc+1")    # pre-release and build meta
  versions+=("2.2.3-rc.10+1") # pre-release and build meta
  versions+=("2.2.3+1")       # build meta
  versions+=("2.2.3")

  echo "input:" "${versions[@]}"

  # expected:
  # 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
  #  set -x
  local version
  echo "output:"

  while read -r version; do
    [ -z "$version" ] && continue # skip empty line
    echo "$version"
  done < <(array:qsort "compare:versions" "${versions[@]}")
}

readonly VERSION_PATTERN="v?${SEMVER}"

function test:git-tags() {
  local -a versions=()
  local line version

  while IFS= read -r line; do
    versions+=("$line")
  done < <(git tag -l --sort="v:refname" | grep -i -E "^${VERSION_PATTERN}\$" | sed -E "s/^v?//gi")

  echo "input:" "${versions[@]}"
  echo "output:"

  while IFS= read -r version; do
    [ -z "$version" ] && continue # skip empty line
    echo "$version"
  done < <(array:qsort "compare:versions" "${versions[@]}")
}

test:git-tags
test:version-strings
