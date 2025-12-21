#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"dbg,-semver"}

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

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
  (semver:constraints:simple "$1<$2") && return 0 || return 1
}

function compare:strings() {
  [[ "$1" < "$2" ]] && return 0 || return 1
}

# Merge-Sort implementation (stable, O(n log n))
function array:merge() {
  local compare=$1
  local -n left_ref=$2
  local -n right_ref=$3
  local i=0 j=0
  local left_val right_val

  while ((i < ${#left_ref[@]} && j < ${#right_ref[@]})); do
    left_val="${left_ref[i]}"
    right_val="${right_ref[j]}"

    if eval "$compare" "$left_val" "$right_val"; then
      printf '%s\n' "$left_val"
      ((i++))
    elif eval "$compare" "$right_val" "$left_val"; then
      printf '%s\n' "$right_val"
      ((j++))
    else
      # Equal by comparator: keep left element to preserve stability
      printf '%s\n' "$left_val"
      ((i++))
    fi
  done

  while ((i < ${#left_ref[@]})); do
    printf '%s\n' "${left_ref[i]}"
    ((i++))
  done

  while ((j < ${#right_ref[@]})); do
    printf '%s\n' "${right_ref[j]}"
    ((j++))
  done
}

  # array:msort - Sorts an array using the Merge-Sort algorithm (stable, O(n log n))
  #
  # Parameters:
  #   $1 - Comparator function (e.g. compare:numbers, compare:versions, compare:strings)
  #   $@ - array to sort
  #
  # Output:
  #   Sorted array elements, one per line
  #
  # Examples:
  #   array:msort compare:numbers "${array[@]}"
  #   array:msort compare:versions "${versions[@]}"
  #   array:msort compare:strings "${strings[@]}"
  #
  # Returns:
  #   0 on success, 1 on failure
function array:msort() {
  local compare=$1 && shift
  local array=("$@")
  local length=${#array[@]}

  if ((length <= 1)); then
    printf '%s\n' "${array[@]}"
    return
  fi

  local mid=$((length / 2))
  local left=("${array[@]:0:mid}")
  local right=("${array[@]:mid}")
  local sorted_left=()
  local sorted_right=()

  mapfile -t sorted_left < <(array:msort "$compare" "${left[@]}")
  mapfile -t sorted_right < <(array:msort "$compare" "${right[@]}")

  array:merge "$compare" sorted_left sorted_right
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
  echo "output:"

  local version
  while read -r version; do
    [ -z "$version" ] && continue # skip empty line
    echo "$version"
  done < <(array:msort "compare:versions" "${versions[@]}")
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
  done < <(array:msort "compare:versions" "${versions[@]}")
}

test:git-tags
test:version-strings
