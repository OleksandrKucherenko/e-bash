#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"loader,semver,-regex,-simple"}

# shellcheck disable=SC2155 # evaluate E_BASH from project structure if it's not set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_semver.sh
source "$E_BASH/_semver.sh"

function compare:versions() {
  (semver:constraints:simple "$1<$2") && return 0 || return 1
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

function array:qsort() {
  local compare=$1 && shift
  local array=("$@")
  local length=${#array[@]}

  if ((length == 0)); then
    return
  fi

  if ((length == 1)); then
    printf '%s\n' "${array[0]}"
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
  printf '%s\n' "$pivot"
  array:qsort "$compare" "${right[@]}"
}

function now_ns() {
  local now="${EPOCHREALTIME:-}"
  local seconds fraction

  if [[ "$now" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
    seconds="${BASH_REMATCH[1]}"
    fraction="${BASH_REMATCH[2]}"
    # Normalize to 6 digits (microseconds)
    fraction="${fraction:0:6}"
    while ((${#fraction} < 6)); do fraction="${fraction}0"; done
    echo "${seconds}${fraction}"
    return
  fi

  echo "$((SECONDS * 1000000000))"
}

function bench_sort() {
  local label=$1 func=$2 iterations=$3
  shift 3
  local data=("$@")
  local start end iCount

  start=$(now_ns)
  for ((iCount = 0; iCount < iterations; iCount++)); do
    "$func" "compare:versions" "${data[@]}" &>/dev/null
    echo -e -n "."
  done
  end=$(now_ns)

  echo ""
  echo "$label: $((end - start)) ns (Σ=${iterations} each=$(((end - start) / iterations)) ns)"
}

## constraints Expressions
echo "-- constraints expressions"
semver:constraints "1.0.0-alpha" "1.0.0-alpha" && echo "OK!" || echo "$? - FAIL!"                # EQUAL
semver:constraints "1.0.0-alpha" ">1.0.0-beta || <1.0.0" && echo "$? - OK!" || echo "$? - FAIL!" # expected OK
semver:constraints "1.0.0-beta.10" "~1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints "1.0.0-beta.10" "^1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints "1.0.0-alpha" "~1.0.0-beta.2 || ^1.0.0-alpha.beta || > 1.0.0-beta < 1.0.0 || 1.0.0-alpha < 1.0.0-alpha.1" && echo "OK!" || echo "$? - FAIL!"
semver:constraints "1.0.0-alpha" ">1.0.0-beta <1.0.0" && echo "$? - FAIL!" || echo "OK ($?)!"

## 1.0.0 < 2.0.0 < 2.1.0 < 2.1.1, 1.0.0-alpha < 1.0.0
echo "-- compare version in readable format"
semver:compare:readable "1.0.0" "2.0.0"
semver:compare:readable "2.0.0" "2.1.0"
semver:compare:readable "2.1.0" "2.1.1"
semver:compare:readable "1.0.0-alpha" "1.0.0"
semver:compare:readable "3.0.0" "1.0.0"

## Example: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0.
## 1.0.0-beta.10 > 1.0.0-beta.2
semver:compare:readable "1.0.0-alpha" "1.0.0-alpha"
semver:compare:readable "1.0.0-alpha" "1.0.0-alpha.1"
semver:compare:readable "1.0.0-alpha.1" "1.0.0-alpha.beta"
semver:compare:readable "1.0.0-alpha.beta" "1.0.0-beta"
semver:compare:readable "1.0.0-beta" "1.0.0-beta.2"
semver:compare:readable "1.0.0-beta.2" "1.0.0-beta.11"
semver:compare:readable "1.0.0-beta.11" "1.0.0-rc.1"
semver:compare:readable "1.0.0-rc.1" "1.0.0"
semver:compare:readable "1.0.0-beta.10" "1.0.0-beta.2"

echo "-- difficult semver versions (sorted for comparison)"
difficult_versions=(
  "0.0.4"
  "1.2.3"
  "10.20.30"
  "1.1.2-prerelease+meta"
  "1.1.2+meta"
  "1.1.2+meta-valid"
  "1.0.0-alpha"
  "1.0.0-beta"
  "1.0.0-alpha.beta"
  "1.0.0-alpha.beta.1"
  "1.0.0-alpha.1"
  "1.0.0-alpha0.valid"
  "1.0.0-alpha.0valid"
  "1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay"
  "1.0.0-rc.1+build.1"
  "2.0.0-rc.1+build.123"
  "1.2.3-beta"
  "10.2.3-DEV-SNAPSHOT"
  "1.2.3-SNAPSHOT-123"
  "1.0.0"
  "2.0.0"
  "1.1.7"
  "2.0.0+build.1848"
  "2.0.1-alpha.1227"
  "1.0.0-alpha+beta"
  "1.2.3----RC-SNAPSHOT.12.9.1--.12+788"
  "1.2.3----R-S.12.9.1--.12+meta"
  "1.2.3----RC-SNAPSHOT.12.9.1--.12"
  "1.0.0+0.build.1-rc.10000aaa-kk-0.1"
  "99999999999999999999999.999999999999999999.99999999999999999"
  "1.0.0-0A.is.legal"
)

echo "input:" "${difficult_versions[@]}"
mapfile -t sorted_versions < <(array:msort "compare:versions" "${difficult_versions[@]}")
echo "sorted:"
printf '%s\n' "${sorted_versions[@]}"

echo "-- difficult semver comparisons (adjacent)"
for ((i = 0; i < ${#sorted_versions[@]} - 1; i++)); do
  semver:compare:readable "${sorted_versions[i]}" "${sorted_versions[i + 1]}"
done

echo "-- qsort vs msort (same data)"
mapfile -t qsort_versions < <(array:qsort "compare:versions" "${difficult_versions[@]}")
mapfile -t msort_versions < <(array:msort "compare:versions" "${difficult_versions[@]}")

echo "qsort:"
printf '%s\n' "${qsort_versions[@]}"
echo "msort:"
printf '%s\n' "${msort_versions[@]}"

bench_iterations=10
echo "-- benchmarks"
echo "qsort, # of iterations: $bench_iterations with data size: ${#difficult_versions[@]}"
bench_sort "qsort" array:qsort "$bench_iterations" "${difficult_versions[@]}"
echo "msort, # of iterations: $bench_iterations with data size: ${#difficult_versions[@]}"
bench_sort "msort" array:msort "$bench_iterations" "${difficult_versions[@]}"

## constraints Complex
echo "-- constraints complex"
semver:constraints:complex "~1.0.0-beta.2" && echo "" || echo "$? - FAIL!"
semver:constraints:complex "^1.0.0-alpha.beta" && echo "" || echo "$? - FAIL!"

## constraints Simple
echo "-- constraints simple"
semver:constraints:simple "1.0.0-alpha = 1.0.0-alpha" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-alpha < 1.0.0-alpha.1" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-alpha <= 1.0.0-alpha.1" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-beta.10 > 1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-beta.10 >= 1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"
semver:constraints:simple "1.0.0-beta.10 != 1.0.0-beta.2" && echo "OK!" || echo "$? - FAIL!"

## Parse And Recompose
echo "-- parse and recompose"
semver:parse "1.0.0-alpha" && echo "${__semver_parse_result[@]}"
semver:parse "1.0.0-alpha0.valid" "VER_1" && echo "${VER_1[@]}"
semver:parse "2.0.0-rc.1+build.123" "V" && echo "${V[@]}"
semver:parse "1.0.0+0.build.1-rc.10000aaa-kk-0.1" && echo "${__semver_parse_result[@]}"

## Demo common cases
echo "-- parse parts"
semver:parse "2.0.0-rc.1+build.123" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-rc.1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-1.2.3.4.5.6" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3-rc+1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3+1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3+1.2.3.4.5.6" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.3" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

semver:parse "2.0.0-rc.1.12.yy.14+build.123.xz.12" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

# not valid
semver:parse "2.2" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

# parsed by cannot be recomposed! (corner cases)
echo "-- parsed by cannot be recomposed! (corner cases)"
semver:parse "2.2.1-.1" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.1+.4" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V
semver:parse "2.2.1-.3+.4" "V" && for i in "${!V[@]}"; do echo -n "$i: ${V[$i]}, "; done && semver:recompose "V" && unset V

## Valid
#echo "0.0.4" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "10.20.30" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.2-prerelease+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.2+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.2+meta-valid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.beta.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha0.valid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha.0valid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-rc.1+build.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.0-rc.1+build.123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3-beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "10.2.3-DEV-SNAPSHOT" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3-SNAPSHOT-123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.0" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.1.7" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.0+build.1848" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "2.0.1-alpha.1227" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-alpha+beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3----RC-SNAPSHOT.12.9.1--.12+788" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3----R-S.12.9.1--.12+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.2.3----RC-SNAPSHOT.12.9.1--.12" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0+0.build.1-rc.10000aaa-kk-0.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "99999999999999999999999.999999999999999999.99999999999999999" | grep -E "${SEMVER_LINE}" --color=always --ignore-case
#echo "1.0.0-0A.is.legal" | grep -E "${SEMVER_LINE}" --color=always --ignore-case

## Invalid
#echo "1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.3-0123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.3-0123.0123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.1.2+.123" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "+invalid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-invalid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-invalid+invalid" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-invalid.01" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.beta.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha+beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha_beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "alpha.." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha_beta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-alpha." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha.." | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha..1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha...1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha....1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha.....1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha......1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.0.0-alpha.......1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "01.1.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.01.1" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.1.01" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.3.DEV" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2-SNAPSHOT" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2.31.2.3----RC-SNAPSHOT.12.09.1--..12+788" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "1.2-RC-SNAPSHOT" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "-1.0.3-gamma+b7718" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "+justmeta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "9.8.7+meta+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "9.8.7-whatever+meta+meta" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
#echo "99999999999999999999999.999999999999999999.99999999999999999----RC-SNAPSHOT.12.09.1--------------------------------..12" | grep -E "${SEMVER_LINE}" --color=always --ignore-case || echo "OK!"
