#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-03-26
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./_colors.sh
# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

# reserved global variable for parsing, declare associated array structure
declare -A -g __semver_parse_result=(
  ["version"]=""
  ["version-core"]=""
  ["major"]=""
  ["minor"]=""
  ["patch"]=""
  ["pre-release"]=""
  ["build"]=""
)

# reserved global variables for comparison of two versions
declare -A -g __semver_compare_v1=()
declare -A -g __semver_compare_v2=()

# ref: https://regex101.com/r/vkijKf/1/,
# ^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
# \d - any digit
function semver:grep() {
  #  <letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
  #             | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T"
  #             | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d"
  #             | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n"
  #             | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x"
  #             | "y" | "z"
  local v_letter="[a-z]"

  # <positive digit> ::= "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
  local v_positive_digit="[1-9]"

  # <digit> ::= "0" | <positive digit>
  local v_digit="(0|${v_positive_digit})"

  # <digits> ::= <digit> | <digit> <digits>
  local v_digits="(${v_digit}+)"

  # <non-digit> ::= <letter> | "-"
  local v_non_digit="(${v_letter}|-)"

  # <identifier character> ::= <digit> | <non-digit>
  local v_identifier_character="(${v_digit}|${v_non_digit})"

  # <identifier characters> ::= <identifier character> | <identifier character> <identifier characters>
  local v_identifier_characters="(${v_identifier_character}+)"

  # <numeric identifier> ::= "0" | <positive digit> | <positive digit> <digits>
  local v_numeric_identifier="(0|${v_positive_digit}${v_digits}?)"

  # <alphanumeric identifier> ::= <non-digit>
  #                            | <non-digit> <identifier characters>
  #                            | <identifier characters> <non-digit>
  #                            | <identifier characters> <non-digit> <identifier characters>
  local v_alphanumeric_identifier="(${v_non_digit}${v_identifier_characters}?|${v_identifier_characters}${v_non_digit}${v_identifier_characters}?)"

  # <build identifier> ::= <alphanumeric identifier> | <digits>
  local v_build_identifier="(${v_alphanumeric_identifier}|${v_digits})"

  # <pre-release identifier> ::= <alphanumeric identifier> | <numeric identifier>
  local v_pre_release_identifier="(${v_alphanumeric_identifier}|${v_numeric_identifier})"

  # <dot-separated build identifiers> ::= <build identifier> | <build identifier> "." <dot-separated build identifiers>
  local v_dot_separated_build_identifiers="(${v_build_identifier}(\.${v_build_identifier})*)"

  # <build> ::= <dot-separated build identifiers>
  local v_build="(${v_dot_separated_build_identifiers})"

  # <dot-separated pre-release identifiers> ::= <pre-release identifier>
  #                                          | <pre-release identifier> "." <dot-separated pre-release identifiers>
  local v_dot_separated_pre_release_identifiers="(${v_pre_release_identifier}(\.${v_pre_release_identifier})*)"

  # <pre-release> ::= <dot-separated pre-release identifiers>
  local v_pre_release="(${v_dot_separated_pre_release_identifiers})"

  # <patch> ::= <numeric identifier>
  local v_patch="(${v_numeric_identifier})"

  # <minor> ::= <numeric identifier>
  local v_minor="(${v_numeric_identifier})"

  # <major> ::= <numeric identifier>
  local v_major="(${v_numeric_identifier})"

  # <version core> ::= <major> "." <minor> "." <patch>
  local v_version_core="(${v_major}\.${v_minor}\.${v_patch})"

  # <valid semver> ::= <version core>
  #                  | <version core> "-" <pre-release>
  #                  | <version core> "+" <build>
  #                  | <version core> "-" <pre-release> "+" <build>
  local v_valid_semver="(${v_version_core}(-${v_pre_release})?(\+${v_build})?)"

  echo "${v_valid_semver}"

  # debug output
  if type echo:Regex &>/dev/null; then
    echo:Regex "${v_valid_semver}" >&2
  fi
}

# create version from parsed results
function semver:recompose() {
  local sourceVariableName=${1:-"__semver_parse_result"}
  declare -A parsed=()

  # copy source associative array to local associative array
  local keys=() _keys=$(eval "echo \"\${!${sourceVariableName}[@]}\"")
  for key in $_keys; do keys+=("$key"); done
  for key in "${keys[@]}"; do parsed[$key]="$(eval "echo \"\${${sourceVariableName}[\"$key\"]}\"")"; done

  # extract all parts
  local major=${parsed["major"]}
  local minor=${parsed["minor"]}
  local patch=${parsed["patch"]}
  local pre_release=${parsed["pre-release"]}
  local build=${parsed["build"]}

  # compose version
  echo "${major}.${minor}.${patch}${pre_release}${build}"
}

# parse version code to segments
function semver:parse() {
  local version="$1"
  local output_variable="${2:-"__semver_parse_result"}"
  local SEMVER_REGEX="$(semver:grep)"
  declare -A parsed=(["version"]="" ["version-core"]="" ["pre-release"]="" ["build"]="")

  if [[ "$version" =~ $SEMVER_REGEX ]]; then
    # debug output
    for i in "${!BASH_REMATCH[@]}"; do echo:Regex "$i: ${BASH_REMATCH[$i]}" >&2; done

    # iterate all matches and assign to associative array found parts
    # 0,1 - full match; 2 - version core; `-` start prefix - pre-release; `+` start prefix - build
    for i in "${!BASH_REMATCH[@]}"; do
      case "$i" in
      0) parsed["version"]="${BASH_REMATCH[$i]}" ;;
      2) parsed["version-core"]="${BASH_REMATCH[$i]}" ;;
      3) parsed["major"]="${BASH_REMATCH[$i]}" ;;
      7) parsed["minor"]="${BASH_REMATCH[$i]}" ;;
      11) parsed["patch"]="${BASH_REMATCH[$i]}" ;;
      *)
        if [[ "${BASH_REMATCH[$i]:0:1}" == "-" ]]; then # index=15
          parsed["pre-release"]="${BASH_REMATCH[$i]}"
        elif [[ "${BASH_REMATCH[$i]:0:1}" == "+" ]]; then # index=57
          parsed["build"]="${BASH_REMATCH[$i]}"
        fi
        ;;
      esac
    done

    # print associative array as key-value pairs
    eval "declare -g -A ${output_variable}" ## declare global associative array
    for key in "${!parsed[@]}"; do
      eval "${output_variable}[${key}]=\"${parsed[$key]}\"" ## copy local associative array to global
    done
  else
    echo:Semver "Invalid semver: $version" >&2
    return 1
  fi
}

# increase major part of the version core
# shellcheck disable=SC2154
function semver:increase:major() {
  local version="$1"

  # parse provided version
  semver:parse "$version" "__major"

  # increase major version, reset minor and patch to 0
  local major=${__major["major"]} && ((major += 1))
  local minor=0
  local patch=0
  local pre_release=${__major["pre-release"]}
  local build=${__major["build"]}

  echo "${major}.${minor}.${patch}${pre_release}${build}"

  unset __major # clean up
}

# increase minor part of the version core
# shellcheck disable=SC2154
function semver:increase:minor() {
  local version="$1"

  semver:parse "$version" "__minor"

  # increase minor version, reset patch to 0
  local major=${__minor["major"]}
  local minor=${__minor["minor"]} && ((minor += 1))
  local patch=0
  local pre_release=${__minor["pre-release"]}
  local build=${__minor["build"]}

  echo "${major}.${minor}.${patch}${pre_release}${build}"

  unset __minor # clean up
}

# increase patch part of the version core
# shellcheck disable=SC2154
function semver:increase:patch() {
  local version="$1"

  semver:parse "$version" "__patch"

  # increase patch version
  local major=${__patch["major"]}
  local minor=${__patch["minor"]}
  local patch=${__patch["patch"]} && ((patch += 1))
  local pre_release=${__patch["pre-release"]}
  local build=${__patch["build"]}

  echo "${major}.${minor}.${patch}${pre_release}${build}"

  unset __patch # clean up
}

# compare two versions and return 0 if equal, 1 if greater, 2 if less, 3 if error
# implementation of https://semver.org/#spec-item-11 specs
function semver:compare() {
  local version1="$1"
  local version2="$2"

  # quick check for equality
  if [[ "$version1" == "$version2" ]]; then return 0; fi

  # parse versions
  semver:parse "$version1" "__semver_compare_v1"
  semver:parse "$version2" "__semver_compare_v2"

  # "build" parts of the versions are ignored during comparison
  local major1=${__semver_compare_v1["major"]} major2=${__semver_compare_v2["major"]}
  local minor1=${__semver_compare_v1["minor"]} minor2=${__semver_compare_v2["minor"]}
  local patch1=${__semver_compare_v1["patch"]} patch2=${__semver_compare_v2["patch"]}
  local pre_release1=${__semver_compare_v1["pre-release"]} pre_release2=${__semver_compare_v2["pre-release"]}

  # compare major, minor and patch parts
  if [[ "$major1" -gt "$major2" ]]; then return 1; fi
  if [[ "$major1" -lt "$major2" ]]; then return 2; fi
  if [[ "$minor1" -gt "$minor2" ]]; then return 1; fi
  if [[ "$minor1" -lt "$minor2" ]]; then return 2; fi
  if [[ "$patch1" -gt "$patch2" ]]; then return 1; fi
  if [[ "$patch1" -lt "$patch2" ]]; then return 2; fi

  # version-core is the same, so first we should compare availability of pre-release parts
  # version with pre-release part is less than version without pre-release part
  if [[ -z "$pre_release1" && -n "$pre_release2" ]]; then return 1; fi
  if [[ -n "$pre_release1" && -z "$pre_release2" ]]; then return 2; fi

  # compare pre-release parts as an array of identifiers.
  # We should split pre-release by '.' and compare each part (identifier) separately
  local parts1=() parts2=()
  IFS='.' read -ra parts1 <<<"${pre_release1//\-/}"
  IFS='.' read -ra parts2 <<<"${pre_release2//\-/}"

  # find the longest array size
  local maxSize=$((${#parts1[@]} > ${#parts2[@]} ? ${#parts1[@]} : ${#parts2[@]}))
  ((maxSize -= 1)) # array index starts from 0

  # if identifier is a number, then compare as a number, otherwise as a string
  # number is always less than string
  for i in $(seq 0 $maxSize); do
    local part1="${parts1[$i]}"
    local part2="${parts2[$i]}"

    # if one of the parts is empty, then it is less than the other
    if [[ -z "$part1" && -n "$part2" ]]; then return 2; fi
    if [[ -n "$part1" && -z "$part2" ]]; then return 1; fi

    # compare parts as numbers or strings
    if [[ "$part1" =~ ^[0-9]+$ && "$part2" =~ ^[0-9]+$ ]]; then
      if [[ "$part1" -gt "$part2" ]]; then return 1; fi
      if [[ "$part1" -lt "$part2" ]]; then return 2; fi
    else
      if [[ "$part1" > "$part2" ]]; then return 1; fi
      if [[ "$part1" < "$part2" ]]; then return 2; fi
    fi
  done

  echo:Semver "Error: $version1 $version2" >&2
  return 3 # error
}

# interpret result of semver:compare to operator string, separated by ` ` (space)
function semver:compare:to:operator() {
  local result=$1

  case "$result" in
  0) echo "= == >= <=" ;;
  1) echo "> >= !=" ;;
  2) echo "< <= !=" ;;
  *) echo "!=" ;;
  esac
}

# convert compare results to human-readable output
function semver:compare:readable() {
  local version1="$1"
  local version2="$2"

  semver:compare "$1" "$2"
  local operators=$(semver:compare:to:operator $?)

  echo "$version1 $operators $version2 "
}

# The basic comparisons are:
# =: equal (aliased to no operator)
# !=: not equal
# >: greater than
# <: less than
# >=: greater than or equal to
# <=: less than or equal to
# ref: https://github.com/Masterminds/semver?tab=readme-ov-file#basic-comparisons
function semver:constraints:simple() {
  # remove whitespaces during assigning to local variable
  local expression="${1//[[:space:]]/}"
  local left="" operator="" right=""

  # split expression to left, operator and right parts
  if [[ "$expression" =~ ^([^<>=!]+)(!=|>=|<=|>|=|<)(.+)$ ]]; then
    for i in "${!BASH_REMATCH[@]}"; do echo:Regex "$i: ${BASH_REMATCH[$i]}" >&2; done
    left="${BASH_REMATCH[1]}"
    operator="${BASH_REMATCH[2]}"
    right="${BASH_REMATCH[3]}"
  else
    echo:Simple "Invalid expression: $expression" >&2
    return 3 # error
  fi

  # compare versions via semver:compare and interpret result to covered operator
  local op=$(
    semver:compare "$left" "$right"
    semver:compare:to:operator $?
  )
  local op1=""

  echo:Simple " ($left $operator $right) -> ($op)" >&2

  # compare result with the original expression operator; keep in mind that
  # operators have whitespaces and | separator, so we need a loop of comparisons
  while read -r op1; do
    if [[ "$op1" = "$operator" ]]; then
      return 0 # true
    fi
  done < <(echo "$op" | awk '{for(i=1;i<=NF;i++){print $i}}')

  return 1 # false
}

# resolve simple expression with '~' and '^' operators to simple expression
function semver:constraints:complex() {
  local molecule="$1" atom="$1"

  # resolve `~` operator to `>=` and `<` expression
  # `~1.0.0` - version in range >= 1.0.x, patch releases allowed
  if [[ "$molecule" =~ (~) ]]; then
    atom=${atom//\~/}
    echo ">=$atom"
    echo "<$(semver:increase:minor "$atom")"
    return 0
  fi

  # resolve `^` operator to `>=` and `<` expression
  # `^1.0.0` - version in range >= 1.x.x, minor & patch releases allowed
  if [[ "$molecule" =~ (\^) ]]; then
    atom=${atom//\^/}
    echo ">=$atom"
    echo "<$(semver:increase:major "$atom")"
    return 0
  fi

  # TODO (olku): https://github.com/Masterminds/semver?tab=readme-ov-file#hyphen-range-comparisons

  # TODO (olku): https://github.com/Masterminds/semver?tab=readme-ov-file#wildcards-in-comparisons

  # check that atom contains operator, otherwise add default $(=) to it
  [[ ! "$atom" =~ (=|!=|>|<|>=|<=) ]] && atom="=$atom"

  # return resolved expression
  echo "$atom"
}

# verify that provided version matches constraints
function semver:constraints() {
  local version="$1"
  local expression="$2"

  echo:Semver "[$expression]:" >&2

  # split || (or) expressions to multiple sub-expressions and process them in a loop
  local -a expressions=() ors="" resultOr=0
  IFS='||' read -ra expressions <<<"$expression"

  # iterate all sub-expressions, first TRUE will break the loop
  for ors in "${expressions[@]}"; do
    [ -z "$ors" ] && continue # skip empty expressions

    # each ORs expression can have multiple ANDs expressions, so we need to split them
    # remove whitespace after operator, so operator stick to the right operand
    ors=$(echo "$ors" | sed -E 's/(=|!=|>|<|>=|<=) /\1/g; s/ $//g; s/^ //g')
    echo:Semver " |-- ($ors)" >&2

    # clean $ors may contain multiple ANDs expressions, so we need to split them
    local -a ands=() molecule="" resultAnd=1
    IFS=' ' read -ra ands <<<"$ors"

    for molecule in "${ands[@]}"; do
      [ -z "$molecule" ] && continue # skip empty expressions
      echo:Semver " |   +-- ($molecule)" >&2

      local atom=""

      # we may have complex expressions that should be expanded to set of simple expressions
      while read -r atom; do
        echo:Semver -n " |       +-- ($version$atom)" >&2
        # process simple expression
        if semver:constraints:simple "$version$atom"; then
          echo:Semver " $? : TRUE" >&2
          ((resultAnd &= 1))
        else
          # simple expression is false or error, try next ORs expression
          echo:Semver " $? : FALSE" >&2
          ((resultAnd &= 0))
          break
        fi
      done < <(semver:constraints:complex "$molecule")

      # if any of ANDs expressions is FALSE, then we should try next ORs expression
      [[ "$resultAnd" -eq 0 ]] && break
    done

    ((resultOr |= resultAnd))
  done

  # inverse resultOr, because we need to return 0 if any of ORs expressions is TRUE
  # BASH expected 0 for success, any other number for failure
  [[ "$resultOr" -eq 1 ]] && return 0 # true
  return 1                            # false
}

export SEMVER="$(semver:grep)"
export SEMVER_LINE="^${SEMVER}\$"
export SEMVER_LINE_WITH_PREFIX="^v?${SEMVER}\$"

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger semver "$@" # declare echo:Semver & printf:Semver functions
logger regex "$@"  # declare echo:Regex & printf:Regex functions
logger simple "$@" # declare echo:Simple & printf:Simple functions

logger:redirect regex ">&2" # redirect regex to STDERR

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

# Refs:
# - https://www.baeldung.com/linux/bash-bitwise-operators

#echo "semver:grep: $SEMVER"
