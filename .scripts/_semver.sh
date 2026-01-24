#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

##
## Module: Semantic Versioning (_semver.sh)
##
## Provides complete semantic versioning support per semver.org 2.0.0 specification.
## This module implements version parsing, comparison, constraint evaluation, and
## version increment operations for semantic version strings.
##
## Features:
## - Full regex-based parsing following semver.org Backus-Naur form grammar
## - Version comparison with pre-release and build metadata support
## - Constraint expressions (=, !=, >, <, >=, <=, ~, ^)
## - Complex constraint evaluation with OR (||) and AND (space) operators
## - NPM-like prerelease handling (v2 constraints)
## - Version increment operations (major, minor, patch)
##
## Global Variables:
## - SEMVER                      - Compiled semver regex pattern
## - SEMVER_LINE                 - Anchored semver regex for full line matching
## - SEMVER_LINE_WITH_PREFIX     - Anchored semver regex allowing optional 'v' prefix
## - SEMVER_CONSTRAINTS_IMPL     - Implementation selector (v1|v2, default: v2)
## - __semver_parse_result       - Default output for semver:parse
## - __semver_compare_v1         - Internal comparison buffer for version 1
## - __semver_compare_v2         - Internal comparison buffer for version 2
##
## References:
## - https://semver.org/spec/v2.0.0.html
## - https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions
## - https://github.com/Masterminds/semver (constraint syntax reference)
## - https://regex101.com/r/vkijKf/1/ (regex testing)
##

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

##
## semver:grep - Build semantic version regex pattern (INTERNAL)
##
## Constructs a complete regex pattern for matching semantic version strings
## following the semver.org 2.0.0 Backus-Naur form grammar specification.
## The pattern supports major.minor.patch core version, optional pre-release
## identifiers, and optional build metadata.
##
## This function is internal and primarily used during module initialization
## to populate the SEMVER global variable. The implementation systematically
## builds the regex by composing grammatical elements from the semver spec.
##
## Grammar Implementation:
## - <valid semver> ::= <version core> ["-" <pre-release>] ["+" <build>]
## - <version core> ::= <major> "." <minor> "." <patch>
## - <major|minor|patch> ::= <numeric identifier>
## - <numeric identifier> ::= "0" | <positive digit> [<digits>]
## - <pre-release> ::= <dot-separated pre-release identifiers>
## - <build> ::= <dot-separated build identifiers>
##
## Parameters:
##   None
##
## Outputs:
##   Writes the compiled regex pattern to stdout
##   Optionally logs to stderr via echo:Regex if logger is configured
##
## Returns:
##   0 - Always succeeds
##
## Global Variables:
##   None (function is stateless)
##
## Examples:
##   SEMVER="$(semver:grep)"
##   echo "1.2.3-alpha+build" | grep -E "$(semver:grep)"
##
## Notes:
##   - Case-insensitive matching for letters [a-zA-Z]
##   - Implements full semver 2.0.0 grammar (lines 37-107 below)
##   - Generated regex is complex (~500+ characters)
##   - Debug output via echo:Regex (if available and DEBUG=regex enabled)
##
## References:
## - https://regex101.com/r/vkijKf/1/
## - https://semver.org/#backusnaur-form-grammar-for-valid-semver-versions
##
## Original regex (simplified):
## ^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
##
function semver:grep() {
  #  <letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J"
  #             | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T"
  #             | "U" | "V" | "W" | "X" | "Y" | "Z" | "a" | "b" | "c" | "d"
  #             | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n"
  #             | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x"
  #             | "y" | "z"
  local v_letter="[a-z]" # we are case insensitive

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
  local v_dot_separated_build_identifiers="(${v_build_identifier}((\.${v_build_identifier})*))"

  # <build> ::= <dot-separated build identifiers>
  local v_build="(${v_dot_separated_build_identifiers})"

  # <dot-separated pre-release identifiers> ::= <pre-release identifier>
  #                                          | <pre-release identifier> "." <dot-separated pre-release identifiers>
  local v_dot_separated_pre_release_identifiers="(${v_pre_release_identifier}((\.${v_pre_release_identifier})*))"

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
  if declare -F "echo:Regex" >/dev/null; then 
    echo:Regex "${v_valid_semver}" >&2
  fi
  # if type echo:Regex &>/dev/null; then
  #  echo:Regex "${v_valid_semver}" >&2
  # fi
}

##
## semver:recompose - Create version string from parsed results (INTERNAL)
##
## Reconstructs a semantic version string from a parsed version associative array.
## This function reverses the operation of semver:parse, composing major, minor,
## patch, pre-release, and build components back into a valid semver string.
##
## The function reads from an associative array (by variable name) and combines
## the version components following semver format: major.minor.patch[-pre-release][+build]
##
## Parameters:
##   $1 - sourceVariableName (optional, default: "__semver_parse_result")
##        Name of the associative array containing parsed version components
##        Expected keys: major, minor, patch, pre-release, build
##
## Outputs:
##   Writes the recomposed version string to stdout
##
## Returns:
##   0 - Always succeeds (assumes valid input array structure)
##
## Global Variables:
##   None directly (reads from the named variable parameter)
##
## Examples:
##   semver:parse "2.0.0-rc.1+build.123" "V"
##   semver:recompose "V"  # Outputs: 2.0.0-rc.1+build.123
##
##   semver:parse "1.2.3" "__semver_parse_result"
##   semver:recompose  # Uses default variable, outputs: 1.2.3
##
## Notes:
##   - Pre-release and build components are optional (may be empty strings)
##   - Empty pre-release/build are not included in output (no trailing -/+)
##   - Does not validate the input array structure
##   - Some edge cases may not recompose correctly (see demo.semver.sh lines 274-277)
##
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

##
## semver:parse - Parse version string into components (PUBLIC API)
##
## Parses a semantic version string into its constituent components and stores
## the results in an associative array. This is the primary function for breaking
## down version strings into analyzable parts.
##
## The function uses the SEMVER global regex pattern to match and extract version
## components following the semver.org 2.0.0 specification. Results are stored
## in a global associative array with the following keys:
##
## Array Keys:
##   version       - Full matched version string
##   version-core  - Major.minor.patch without pre-release or build
##   major         - Major version number
##   minor         - Minor version number
##   patch         - Patch version number
##   pre-release   - Pre-release identifier (including leading '-') or empty
##   build         - Build metadata (including leading '+') or empty
##   .pre-release  - Pre-release without leading '-' (internal use)
##   .build        - Build metadata without leading '+' (internal use)
##
## Parameters:
##   $1 - version (required)
##        The semantic version string to parse (e.g., "1.2.3-alpha+build")
##   $2 - output_variable (optional, default: "__semver_parse_result")
##        Name of the global associative array to store parsed components
##
## Outputs:
##   On error: Writes error message to stderr via echo:Semver
##
## Returns:
##   0 - Version successfully parsed
##   1 - Invalid semver format (does not match SEMVER regex)
##
## Global Variables:
##   SEMVER                   - Read (regex pattern for matching)
##   <output_variable>        - Written (receives parsed components)
##   __semver_parse_result    - Written (default output variable)
##
## Examples:
##   # Basic usage with default output
##   semver:parse "1.2.3-alpha+build"
##   echo "${__semver_parse_result[major]}"  # Outputs: 1
##   echo "${__semver_parse_result[pre-release]}"  # Outputs: -alpha
##
##   # Custom output variable
##   semver:parse "2.0.0-rc.1+build.123" "MY_VERSION"
##   echo "${MY_VERSION[version-core]}"  # Outputs: 2.0.0
##   echo "${MY_VERSION[build]}"  # Outputs: +build.123
##
##   # Iterate all components
##   semver:parse "2.2.3-rc.1" "V"
##   for key in "${!V[@]}"; do
##     echo "$key: ${V[$key]}"
##   done
##
## Notes:
##   - Output array is declared global (-g -A) and overwrites existing values
##   - Pre-release and build include their prefixes (- and +)
##   - Use semver:recompose to reconstruct version string from parsed array
##   - Some edge cases with leading dots may parse but not recompose correctly
##
function semver:parse() {
  local version="$1"
  local output_variable="${2:-"__semver_parse_result"}"
  #local SEMVER_REGEX="$(semver:grep)"
  local SEMVER_REGEX="$SEMVER"
  declare -A parsed=(["version"]="" ["version-core"]="" ["pre-release"]="" ["build"]="")
  local iSeq=0 # make $iSeq local to avoid conflicts

  if [[ "$version" =~ $SEMVER_REGEX ]]; then
    # debug output (disabled: noisy and slow during profiling)
    # for iSeq in "${!BASH_REMATCH[@]}"; do echo:Regex "$iSeq: ${BASH_REMATCH[$iSeq]}" >&2; done

    # iterate all matches and assign to associative array found parts
    # 0,1 - full match; 2 - version core; `-` start prefix - pre-release; `+` start prefix - build
    for iSeq in "${!BASH_REMATCH[@]}"; do
      case "$iSeq" in
      0) parsed["version"]="${BASH_REMATCH[$iSeq]}" ;;
      2) parsed["version-core"]="${BASH_REMATCH[$iSeq]}" ;;
      3) parsed["major"]="${BASH_REMATCH[$iSeq]}" ;;
      7) parsed["minor"]="${BASH_REMATCH[$iSeq]}" ;;
      11) parsed["patch"]="${BASH_REMATCH[$iSeq]}" ;;
      37) parsed[".pre-release"]="${BASH_REMATCH[$iSeq]}" ;;
      79) parsed[".build"]="${BASH_REMATCH[$iSeq]}" ;;
      *)
        if [[ "${BASH_REMATCH[$iSeq]:0:1}" == "-" ]]; then # index=15
          parsed["pre-release"]="${BASH_REMATCH[$iSeq]}"
        elif [[ "${BASH_REMATCH[$iSeq]:0:1}" == "+" ]]; then # index=57
          parsed["build"]="${BASH_REMATCH[$iSeq]}"
        fi
        ;;
      esac
    done

    # copy local associative array to global without eval
    declare -g -A "$output_variable"
    local -n out="$output_variable"
    for key in "${!parsed[@]}"; do
      out["$key"]="${parsed[$key]}"
    done
  else
    echo:Semver "Invalid semver: $version" >&2
    return 1
  fi
}

##
## semver:increase:major - Increment major version number (PUBLIC API)
##
## Increases the major version component by 1 and resets minor and patch to 0.
## Pre-release and build metadata are preserved from the input version.
## This operation follows semver.org convention where major version changes
## indicate backward-incompatible API changes.
##
## Version transformation: X.Y.Z[-pre][+build] -> (X+1).0.0[-pre][+build]
##
## Parameters:
##   $1 - version (required)
##        The semantic version string to increment (e.g., "1.2.3")
##
## Outputs:
##   Writes the new version string to stdout
##
## Returns:
##   0 - Successfully incremented version
##   Non-zero - Parsing failed (invalid semver format)
##
## Global Variables:
##   __major - Temporary (created and cleaned up during execution)
##
## Examples:
##   semver:increase:major "1.2.3"
##   # Output: 2.0.0
##
##   semver:increase:major "0.5.8-beta+build.1"
##   # Output: 1.0.0-beta+build.1
##
##   new_version=$(semver:increase:major "3.14.159")
##   echo "$new_version"  # Output: 4.0.0
##
## Notes:
##   - Minor and patch are always reset to 0
##   - Pre-release and build metadata are preserved unchanged
##   - Uses semver:parse internally for version decomposition
##   - Temporary variable __major is cleaned up after execution
##
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

##
## semver:increase:minor - Increment minor version number (PUBLIC API)
##
## Increases the minor version component by 1 and resets patch to 0. The major
## version is preserved, as are pre-release and build metadata. This operation
## follows semver.org convention where minor version changes indicate new
## backward-compatible functionality.
##
## Version transformation: X.Y.Z[-pre][+build] -> X.(Y+1).0[-pre][+build]
##
## Parameters:
##   $1 - version (required)
##        The semantic version string to increment (e.g., "1.2.3")
##
## Outputs:
##   Writes the new version string to stdout
##
## Returns:
##   0 - Successfully incremented version
##   Non-zero - Parsing failed (invalid semver format)
##
## Global Variables:
##   __minor - Temporary (created and cleaned up during execution)
##
## Examples:
##   semver:increase:minor "1.2.3"
##   # Output: 1.3.0
##
##   semver:increase:minor "2.9.15-alpha+build.1"
##   # Output: 2.10.0-alpha+build.1
##
##   new_version=$(semver:increase:minor "0.1.9")
##   echo "$new_version"  # Output: 0.2.0
##
## Notes:
##   - Patch is always reset to 0
##   - Major version remains unchanged
##   - Pre-release and build metadata are preserved unchanged
##   - Uses semver:parse internally for version decomposition
##   - Temporary variable __minor is cleaned up after execution
##
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

##
## semver:increase:patch - Increment patch version number (PUBLIC API)
##
## Increases the patch version component by 1 while preserving major and minor
## versions. Pre-release and build metadata are also preserved. This operation
## follows semver.org convention where patch version changes indicate backward-
## compatible bug fixes.
##
## Version transformation: X.Y.Z[-pre][+build] -> X.Y.(Z+1)[-pre][+build]
##
## Parameters:
##   $1 - version (required)
##        The semantic version string to increment (e.g., "1.2.3")
##
## Outputs:
##   Writes the new version string to stdout
##
## Returns:
##   0 - Successfully incremented version
##   Non-zero - Parsing failed (invalid semver format)
##
## Global Variables:
##   __patch - Temporary (created and cleaned up during execution)
##
## Examples:
##   semver:increase:patch "1.2.3"
##   # Output: 1.2.4
##
##   semver:increase:patch "2.9.15-alpha+build.1"
##   # Output: 2.9.16-alpha+build.1
##
##   new_version=$(semver:increase:patch "0.1.0")
##   echo "$new_version"  # Output: 0.1.1
##
## Notes:
##   - Major and minor versions remain unchanged
##   - Pre-release and build metadata are preserved unchanged
##   - Uses semver:parse internally for version decomposition
##   - Temporary variable __patch is cleaned up after execution
##   - Most common version increment operation for bug fixes
##
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

##
## semver:compare - Compare two semantic versions (PUBLIC API)
##
## Compares two semantic version strings according to semver.org 2.0.0 specification,
## specifically implementing spec item #11 (precedence rules). The comparison follows
## these rules in order:
##
## 1. Compare major.minor.patch numerically (left to right)
## 2. Versions without pre-release > versions with pre-release
## 3. Pre-release identifiers compared left to right:
##    - Numeric identifiers compared as integers
##    - Alphanumeric identifiers compared lexically (ASCII sort)
##    - Numeric identifiers < alphanumeric identifiers
##    - Larger set of pre-release fields > smaller set (if all preceding equal)
## 4. Build metadata is IGNORED during comparison
##
## Return Values (Exit Codes):
##   0 - Versions are equal (precedence-wise, build metadata ignored)
##   1 - Version1 is greater than version2
##   2 - Version1 is less than version2
##   3 - Error (invalid semver format in one or both versions)
##
## Parameters:
##   $1 - version1 (required)
##        First semantic version string to compare
##   $2 - version2 (required)
##        Second semantic version string to compare
##
## Outputs:
##   On error: Writes error message to stderr via echo:Semver
##
## Global Variables:
##   __semver_compare_v1 - Temporary (parsed version1, persists between calls)
##   __semver_compare_v2 - Temporary (parsed version2, persists between calls)
##
## Examples:
##   # Simple comparison
##   semver:compare "1.0.0" "2.0.0" && echo "Equal" || echo "Not equal ($?)"
##   # Output: Not equal (2)
##
##   # Pre-release precedence
##   semver:compare "1.0.0-alpha" "1.0.0" && echo "Equal" || echo "Less ($?)"
##   # Output: Less (2)
##
##   # Build metadata ignored
##   semver:compare "1.0.0+build1" "1.0.0+build2"
##   echo $?  # Output: 0 (equal)
##
##   # Use in conditionals
##   if semver:compare "2.1.0" "2.0.0"; then
##     echo "Versions are identical"
##   else
##     case $? in
##       1) echo "2.1.0 is newer" ;;
##       2) echo "2.0.0 is newer" ;;
##       3) echo "Invalid version format" ;;
##     esac
##   fi
##
## Notes:
##   - Quick equality check via string comparison before full parsing
##   - Build metadata (+...) is completely ignored per semver rule #10
##   - Pre-release comparison follows complex precedence rules (see spec item #11)
##   - Handles numeric vs alphanumeric identifier precedence correctly
##   - Global buffers __semver_compare_v1/v2 not automatically cleaned
##   - Sets LC_ALL=C for consistent string comparison behavior
##
## References:
##   - https://semver.org/#spec-item-11 (precedence specification)
##   - https://semver.org/#spec-item-10 (build metadata handling)
##
function semver:compare() {
  local version1="$1"
  local version2="$2"
  local iParts=0 # make $iParts local to avoid conflicts
  local LC_ALL=C

  # quick check for equality
  if [[ "$version1" == "$version2" ]]; then return 0; fi

  # parse versions
  semver:parse "$version1" "__semver_compare_v1" || return 3
  semver:parse "$version2" "__semver_compare_v2" || return 3

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
  # Keep hyphens inside identifiers per semver item #11.
  local parts1=() parts2=()
  local pre_release1_clean="${pre_release1#-}"
  local pre_release2_clean="${pre_release2#-}"
  IFS='.' read -ra parts1 <<<"${pre_release1_clean}"
  IFS='.' read -ra parts2 <<<"${pre_release2_clean}"

  # find the longest array size
  local maxSize=$((${#parts1[@]} > ${#parts2[@]} ? ${#parts1[@]} : ${#parts2[@]}))
  ((maxSize -= 1)) # array index starts from 0

  if [[ "$maxSize" -ge 0 ]]; then
    # if identifier is a number, then compare as a number, otherwise as a string
    # number is always less than string
    for ((iParts = 0; iParts <= maxSize; iParts++)); do
      local part1="${parts1[$iParts]}"
      local part2="${parts2[$iParts]}"

      # if one of the parts is empty, then it is less than the other
      if [[ -z "$part1" && -n "$part2" ]]; then return 2; fi
      if [[ -n "$part1" && -z "$part2" ]]; then return 1; fi

      # compare parts as numbers or strings
      if [[ "$part1" =~ ^[0-9]+$ && "$part2" =~ ^[0-9]+$ ]]; then
        if [[ "$part1" -gt "$part2" ]]; then return 1; fi
        if [[ "$part1" -lt "$part2" ]]; then return 2; fi
      elif [[ "$part1" =~ ^[0-9]+$ ]]; then
        # Numeric identifiers have lower precedence than non-numeric
        return 2
      elif [[ "$part2" =~ ^[0-9]+$ ]]; then
        return 1
      else
        if [[ "$part1" > "$part2" ]]; then return 1; fi
        if [[ "$part1" < "$part2" ]]; then return 2; fi
      fi
    done

    # A larger set of pre-release fields has a higher precedence than a
    # smaller set, if all of the preceding identifiers are equal. (Rule #11.4.4)
    if [[ "${#parts1[@]}" -gt "${#parts2[@]}" ]]; then return 1; fi
    if [[ "${#parts1[@]}" -lt "${#parts2[@]}" ]]; then return 2; fi

    # numbers are equal? but how? Only META left un-compared
    # echo:Semver "Warning: verify versions, are is META an only difference: $version1 $version2"
    return 0
  else
    # echo:Semver "Warning: No pre-release part in versions: $version1 $version2"

    # Build metadata MUST be ignored when determining version precedence. (Rule #10)
    # So versions are equal during the comparison!
    return 0
  fi

  # We should never reach this point!
  # shellcheck disable=SC2059
  echo:Semver "Error: $version1 $version2" >&2
  # shellcheck disable=SC2059
  return 3 # error
}

##
## semver:compare:to:operator - Convert comparison result to operator strings (INTERNAL)
##
## Translates a semver:compare exit code into a space-separated list of comparison
## operators that match the relationship between the two compared versions. This
## function is a helper for semver:compare:readable and constraint evaluation.
##
## Exit Code Mappings:
##   0 -> "= == >= <=" (versions are equal)
##   1 -> "> >= !="     (version1 greater than version2)
##   2 -> "< <= !="     (version1 less than version2)
##   * -> "!="          (error or unknown state)
##
## Parameters:
##   $1 - result (required)
##        Exit code from semver:compare (0, 1, 2, or 3)
##
## Outputs:
##   Writes space-separated operator string to stdout
##
## Returns:
##   0 - Always succeeds
##
## Examples:
##   semver:compare "1.0.0" "2.0.0"
##   operators=$(semver:compare:to:operator $?)
##   echo "$operators"  # Output: "< <= !="
##
##   semver:compare "3.0.0" "3.0.0"
##   operators=$(semver:compare:to:operator $?)
##   echo "$operators"  # Output: "= == >= <="
##
## Notes:
##   - Output includes all operators that represent the relationship
##   - Used internally by semver:constraints:simple for expression evaluation
##   - == is an alias for = (both included for equality)
##   - Error state (3) returns only "!=" operator
##
function semver:compare:to:operator() {
  local result=$1

  case "$result" in
  0) echo "= == >= <=" ;;
  1) echo "> >= !=" ;;
  2) echo "< <= !=" ;;
  *) echo "!=" ;;
  esac
}

##
## semver:compare:readable - Human-readable version comparison (PUBLIC API)
##
## Performs version comparison and outputs the result in human-readable format
## showing the relationship between two versions using comparison operators.
## This is a convenience function combining semver:compare and
## semver:compare:to:operator.
##
## Output Format: "version1 operator1 operator2 ... version2"
##
## Parameters:
##   $1 - version1 (required)
##        First semantic version string to compare
##   $2 - version2 (required)
##        Second semantic version string to compare
##
## Outputs:
##   Writes comparison result to stdout in format:
##   "version1 <operators> version2 "
##   Where <operators> is a space-separated list of all valid operators
##
## Returns:
##   0 - Always succeeds (passes through from semver:compare:to:operator)
##
## Examples:
##   semver:compare:readable "1.0.0" "2.0.0"
##   # Output: "1.0.0 < <= != 2.0.0 "
##
##   semver:compare:readable "1.0.0-alpha" "1.0.0"
##   # Output: "1.0.0-alpha < <= != 1.0.0 "
##
##   semver:compare:readable "2.1.3" "2.1.3"
##   # Output: "2.1.3 = == >= <= 2.1.3 "
##
##   # Use in loop for comparison table
##   for v1 in "1.0.0" "2.0.0" "2.1.0"; do
##     for v2 in "1.0.0" "2.0.0" "2.1.0"; do
##       semver:compare:readable "$v1" "$v2"
##     done
##   done
##
## Notes:
##   - Output includes trailing space after version2
##   - Build metadata is ignored during comparison
##   - Useful for debugging and displaying version relationships
##   - See demo.semver.sh lines 157-173 for extensive usage examples
##
function semver:compare:readable() {
  local version1="$1"
  local version2="$2"

  semver:compare "$1" "$2"
  local operators=$(semver:compare:to:operator $?)

  echo "$version1 $operators $version2 "
}

##
## semver:constraints:simple - Evaluate simple comparison expressions (PUBLIC API)
##
## Evaluates a simple version constraint expression containing two versions and
## a comparison operator. This function validates whether the relationship between
## two versions matches the specified operator.
##
## Supported Operators:
##   =   - Equal (versions have same precedence, build ignored)
##   !=  - Not equal
##   >   - Greater than
##   <   - Less than
##   >=  - Greater than or equal to
##   <=  - Less than or equal to
##
## Expression Format: "version1<operator>version2"
## Whitespace is removed during parsing, so "1.0.0 >= 0.9.0" is valid.
##
## Parameters:
##   $1 - expression (required)
##        Constraint expression string (e.g., "1.0.0>=0.9.0" or "2.0.0 != 1.0.0")
##        Format: <version1><operator><version2>
##
## Outputs:
##   On success: Debug output via echo:Simple if DEBUG=simple enabled
##   On error: Error message to stderr via echo:Simple
##
## Returns:
##   0 - Constraint satisfied (expression is TRUE)
##   1 - Constraint not satisfied (expression is FALSE)
##   3 - Error (invalid expression format or invalid semver)
##
## Examples:
##   # Basic equality
##   semver:constraints:simple "1.0.0 = 1.0.0" && echo "Equal!"
##
##   # Greater than comparison
##   semver:constraints:simple "2.1.0>2.0.0" && echo "Newer version"
##
##   # Range check (combine with AND logic)
##   semver:constraints:simple "1.5.0>=1.0.0" && \
##   semver:constraints:simple "1.5.0<2.0.0" && \
##   echo "Version in range"
##
##   # Not equal
##   semver:constraints:simple "1.0.0-alpha != 1.0.0" && echo "Different!"
##
## Notes:
##   - Whitespace in expression is automatically removed
##   - Expression must contain exactly one operator
##   - Uses semver:compare for version comparison
##   - Debug output shows parsed components and comparison result
##   - Part of the constraint evaluation chain (used by complex constraint functions)
##
## References:
##   - https://github.com/Masterminds/semver#basic-comparisons
##
function semver:constraints:simple() {
  # remove whitespaces during assigning to local variable
  local expression="${1//[[:space:]]/}"
  local left="" operator="" right=""
  local i=0 # make $i local to avoid conflicts

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

##
## semver:constraints:complex - Expand complex constraint operators (PUBLIC API)
##
## Expands complex constraint operators (~, ^) into equivalent simple constraint
## expressions that can be evaluated by semver:constraints:simple. This function
## implements NPM-style tilde and caret range operators.
##
## Supported Operators:
##   ~ (tilde)  - Allows patch-level changes
##                ~1.2.3 expands to >=1.2.3 <1.3.0
##                Permits changes that do not modify left-most non-zero element
##
##   ^ (caret)  - Allows minor and patch changes (compatible changes)
##                ^1.2.3 expands to >=1.2.3 <2.0.0
##                Permits changes that do not modify left-most non-zero element
##
##   Other operators - Pass through with = prepended if no operator present
##
## Parameters:
##   $1 - molecule (required)
##        Version constraint expression with optional complex operator
##        Examples: "~1.0.0", "^2.1.3", "1.5.0", ">=1.0.0"
##
## Outputs:
##   Writes one or more simple constraint expressions to stdout (one per line)
##   - Tilde/caret: outputs two lines (>= and < constraints)
##   - Simple operators: outputs one line (normalized expression)
##
## Returns:
##   0 - Successfully expanded
##   1 - Parsing error (invalid semver in atom)
##
## Global Variables:
##   __semver_constraints_complex_atom - Temporary (created and cleaned up)
##
## Examples:
##   # Tilde expansion
##   semver:constraints:complex "~1.2.3"
##   # Output (two lines):
##   # >=1.2.3
##   # <1.3.0
##
##   # Caret expansion
##   semver:constraints:complex "^1.0.0"
##   # Output (two lines):
##   # >=1.0.0
##   # <2.0.0
##
##   # No operator - adds default =
##   semver:constraints:complex "1.5.0"
##   # Output: =1.5.0
##
##   # Existing operator - pass through
##   semver:constraints:complex ">=2.0.0"
##   # Output: >=2.0.0
##
##   # Use in constraint evaluation
##   while read -r atom; do
##     semver:constraints:simple "1.2.5$atom"
##   done < <(semver:constraints:complex "~1.2.0")
##
## Notes:
##   - Pre-release and build metadata are preserved in boundary calculations
##   - Tilde allows patch updates: ~X.Y.Z means >=X.Y.Z <X.(Y+1).0
##   - Caret allows minor updates: ^X.Y.Z means >=X.Y.Z <(X+1).0.0
##   - TODO: Hyphen range comparisons (not yet implemented)
##   - TODO: Wildcard support (*, x, X) (not yet implemented)
##   - Temporary variable is cleaned up after execution
##
## References:
##   - https://github.com/Masterminds/semver#working-with-prerelease-versions
##   - https://docs.npmjs.com/cli/v6/using-npm/semver#tilde-ranges-123-12-1
##   - https://docs.npmjs.com/cli/v6/using-npm/semver#caret-ranges-123-025-004
##
function semver:constraints:complex() {
  local molecule="$1" atom="$1"

  # resolve `~` operator to `>=` and `<` expression
  # `~1.0.0` - version in range >= 1.0.x, patch releases allowed
  if [[ "$molecule" =~ (~) ]]; then
    atom=${atom//\~/}
    semver:parse "$atom" "__semver_constraints_complex_atom" || return 1
    local atom_core="${__semver_constraints_complex_atom["version-core"]}"
    unset __semver_constraints_complex_atom
    echo ">=$atom"
    echo "<$(semver:increase:minor "$atom_core")"
    return 0
  fi

  # resolve `^` operator to `>=` and `<` expression
  # `^1.0.0` - version in range >= 1.x.x, minor & patch releases allowed
  if [[ "$molecule" =~ (\^) ]]; then
    atom=${atom//\^/}
    semver:parse "$atom" "__semver_constraints_complex_atom" || return 1
    local atom_core="${__semver_constraints_complex_atom["version-core"]}"
    unset __semver_constraints_complex_atom
    echo ">=$atom"
    echo "<$(semver:increase:major "$atom_core")"
    return 0
  fi

  # TODO (olku): https://github.com/Masterminds/semver?tab=readme-ov-file#hyphen-range-comparisons

  # TODO (olku): https://github.com/Masterminds/semver?tab=readme-ov-file#wildcards-in-comparisons

  # check that atom contains operator, otherwise add default $(=) to it
  [[ ! "$atom" =~ (=|!=|>|<|>=|<=) ]] && atom="=$atom"

  # return resolved expression
  echo "$atom"
}

##
## semver:constraints:v1 - Evaluate version constraints v1 implementation (PUBLIC API)
##
## Evaluates whether a version satisfies a constraint expression using OR (||) and
## AND (space) logic. This is the legacy constraint evaluator that does NOT follow
## NPM's prerelease exclusion behavior.
##
## Expression Syntax:
##   - OR operator: || (double pipe separates alternative constraint sets)
##   - AND operator: space (all constraints in set must match)
##   - Supports: =, !=, >, <, >=, <=, ~, ^ operators
##   - Complex operators (~, ^) are expanded to simple constraints
##
## Evaluation Logic:
##   expression := or_expr [ "||" or_expr ]*
##   or_expr := and_expr [ " " and_expr ]*
##   - Result is TRUE if ANY or_expr is TRUE
##   - An or_expr is TRUE if ALL and_expr are TRUE
##
## Prerelease Handling:
##   WARNING: This version (v1) does NOT exclude prerelease versions by default.
##   A prerelease version like "1.0.0-alpha" WILL match constraints like ">=1.0.0"
##   even though NPM would exclude it. Use semver:constraints:v2 for NPM-like behavior.
##
## Parameters:
##   $1 - version (required)
##        The semantic version to test against constraints
##   $2 - expression (required)
##        Constraint expression with OR (||) and AND (space) operators
##        Example: ">=1.0.0 <2.0.0 || ^2.1.0 || ~3.0.0"
##
## Outputs:
##   Debug logging to stderr via echo:Semver if DEBUG=semver enabled
##   Shows constraint evaluation tree and TRUE/FALSE results
##
## Returns:
##   0 - Version satisfies constraints (at least one OR branch succeeded)
##   1 - Version does not satisfy constraints (all OR branches failed)
##
## Examples:
##   # Simple range check
##   semver:constraints:v1 "1.5.0" ">=1.0.0 <2.0.0"
##   # Returns 0 (TRUE) - version in range
##
##   # Multiple OR conditions
##   semver:constraints:v1 "2.1.5" "^1.0.0 || ^2.0.0 || ^3.0.0"
##   # Returns 0 (TRUE) - matches ^2.0.0 branch
##
##   # Complex expression with AND and OR
##   semver:constraints:v1 "1.2.3" ">=1.0.0 <1.5.0 || >=2.0.0 <3.0.0"
##   # Returns 0 (TRUE) - matches first OR branch
##
##   # Prerelease matches (v1 behavior - different from NPM)
##   semver:constraints:v1 "1.0.0-alpha" ">=1.0.0"
##   # Returns 0 (TRUE) - v1 allows prerelease (NPM would return FALSE)
##
## Notes:
##   - Deprecated in favor of semver:constraints:v2 for NPM compatibility
##   - Use SEMVER_CONSTRAINTS_IMPL=v1 to force this implementation
##   - Expression whitespace after operators is normalized during parsing
##   - Empty sub-expressions are skipped
##   - Debug output shows evaluation tree with TRUE/FALSE at each node
##   - Constraint evaluation is short-circuit (stops at first TRUE OR branch)
##
## See Also:
##   - semver:constraints:v2 (NPM-compatible prerelease handling)
##   - semver:constraints (default dispatcher function)
##
function semver:constraints:v1() {
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

##
## semver:constraints:v2 - Evaluate version constraints v2/NPM-like (PUBLIC API)
##
## Evaluates whether a version satisfies a constraint expression with NPM-compatible
## prerelease exclusion logic. This is the recommended and default constraint
## evaluator (as of SEMVER_CONSTRAINTS_IMPL=v2).
##
## Expression Syntax:
##   - OR operator: || (double pipe separates alternative constraint sets)
##   - AND operator: space (all constraints in set must match)
##   - Supports: =, !=, >, <, >=, <=, ~, ^ operators
##   - Complex operators (~, ^) are expanded to simple constraints
##
## Prerelease Handling (NPM-compatible):
##   Prerelease versions are EXCLUDED from constraint matches UNLESS the constraint
##   range explicitly includes a prerelease comparator with the SAME major.minor.patch
##   as the candidate version's core.
##
##   Examples:
##     "1.0.0-alpha" vs ">=1.0.0"        -> FALSE (prerelease excluded)
##     "1.0.0-alpha" vs ">=1.0.0-alpha"  -> TRUE  (prerelease explicitly allowed)
##     "1.0.0-beta"  vs ">=1.0.0-alpha"  -> TRUE  (same 1.0.0 core, pre allowed)
##     "1.0.1-alpha" vs ">=1.0.0-alpha"  -> FALSE (different core 1.0.1 vs 1.0.0)
##     "2.0.0"       vs ">=1.0.0"        -> TRUE  (stable versions always evaluate)
##
## Evaluation Logic:
##   1. Stable versions (no prerelease) use v1 logic (all constraints evaluated)
##   2. Prerelease versions:
##      a. For each OR branch, check if it contains a prerelease comparator
##         with the same major.minor.patch as the candidate
##      b. If no such comparator exists, skip the entire OR branch
##      c. If found, evaluate all AND constraints in that branch normally
##
## Parameters:
##   $1 - version (required)
##        The semantic version to test against constraints
##   $2 - expression (required)
##        Constraint expression with OR (||) and AND (space) operators
##        Example: ">=1.0.0-alpha <2.0.0 || ^2.1.0-beta"
##
## Outputs:
##   Debug logging to stderr via echo:Semver if DEBUG=semver enabled
##   Shows constraint evaluation tree and TRUE/FALSE results
##
## Returns:
##   0 - Version satisfies constraints (at least one OR branch succeeded)
##   1 - Version does not satisfy constraints (all OR branches failed/excluded)
##
## Global Variables:
##   __semver_constraints_v2_version - Temporary (parsed candidate version)
##   __semver_constraints_v2_comp    - Temporary (parsed comparator versions)
##
## Examples:
##   # Stable version - works like v1
##   semver:constraints:v2 "1.5.0" ">=1.0.0 <2.0.0"
##   # Returns 0 (TRUE)
##
##   # Prerelease excluded by default
##   semver:constraints:v2 "1.0.0-alpha" ">=1.0.0"
##   # Returns 1 (FALSE) - no prerelease comparator for 1.0.0
##
##   # Prerelease explicitly allowed
##   semver:constraints:v2 "1.0.0-beta" ">=1.0.0-alpha <1.0.0"
##   # Returns 0 (TRUE) - comparator has prerelease for same 1.0.0 core
##
##   # Prerelease with OR branches
##   semver:constraints:v2 "1.0.0-rc.1" ">=1.0.0 || >=1.0.0-rc.1"
##   # Returns 0 (TRUE) - second OR branch has matching prerelease comparator
##
##   # Different core version
##   semver:constraints:v2 "1.0.1-alpha" ">=1.0.0-beta"
##   # Returns 1 (FALSE) - cores differ (1.0.1 vs 1.0.0)
##
## Notes:
##   - Default implementation (SEMVER_CONSTRAINTS_IMPL=v2)
##   - Follows NPM semver package behavior for prerelease handling
##   - Stable versions delegate to v1 logic (no prerelease filtering)
##   - Comparators are normalized (~ and ^ expanded, operators stripped)
##   - Only checks for '-' in comparator to detect prerelease
##   - Core version (major.minor.patch) must match exactly for prerelease to apply
##   - Temporary variables are not automatically cleaned between calls
##
## See Also:
##   - semver:constraints:v1 (legacy, no prerelease exclusion)
##   - semver:constraints (dispatcher function, respects SEMVER_CONSTRAINTS_IMPL)
##
## References:
##   - https://github.com/npm/node-semver#prerelease-tags
##   - https://github.com/npm/node-semver#advanced-range-syntax
##
function semver:constraints:v2() {
  local version="$1"
  local expression="$2"

  semver:parse "$version" "__semver_constraints_v2_version" || return 1
  local version_pre_release="${__semver_constraints_v2_version["pre-release"]}"
  local version_core="${__semver_constraints_v2_version["version-core"]}"
  unset __semver_constraints_v2_version

  # stable versions use legacy evaluation logic
  if [[ -z "$version_pre_release" ]]; then
    semver:constraints:v1 "$version" "$expression"
    return $?
  fi

  echo:Semver "[$expression]:" >&2

  # split || (or) expressions to multiple sub-expressions and process them in a loop
  local -a expressions=() ors="" resultOr=0
  IFS='||' read -ra expressions <<<"$expression"

  for ors in "${expressions[@]}"; do
    [ -z "$ors" ] && continue # skip empty expressions

    # remove whitespace after operator, so operator stick to the right operand
    ors=$(echo "$ors" | sed -E 's/(=|!=|>|<|>=|<=) /\1/g; s/ $//g; s/^ //g')
    echo:Semver " |-- ($ors)" >&2

    # Determine whether this comparator set explicitly allows prerelease versions
    # for the candidate version's core (major.minor.patch).
    local prerelease_allowed=0
    local -a ands=() molecule=""
    IFS=' ' read -ra ands <<<"$ors"

    for molecule in "${ands[@]}"; do
      [ -z "$molecule" ] && continue

      # Normalize complex operators (~, ^) to the raw version string for prerelease detection
      local comp="${molecule#>=}"
      comp="${comp#<=}"
      comp="${comp#!=}"
      comp="${comp#>}"
      comp="${comp#<}"
      comp="${comp#=}"
      comp="${comp#~}"
      comp="${comp#^}"

      # Only a comparator that contains a prerelease can allow prerelease candidates.
      [[ "$comp" == *"-"* ]] || continue

      semver:parse "$comp" "__semver_constraints_v2_comp" || continue
      local comp_core="${__semver_constraints_v2_comp["version-core"]}"
      unset __semver_constraints_v2_comp

      if [[ "$comp_core" == "$version_core" ]]; then
        prerelease_allowed=1
        break
      fi
    done

    # If this OR-set doesn't explicitly include a prerelease comparator for this
    # major.minor.patch, it cannot match prerelease candidates.
    [[ "$prerelease_allowed" -eq 1 ]] || continue

    # Evaluate the AND-set as in v1.
    local resultAnd=1
    for molecule in "${ands[@]}"; do
      [ -z "$molecule" ] && continue # skip empty expressions
      echo:Semver " |   +-- ($molecule)" >&2

      local atom=""
      while read -r atom; do
        echo:Semver -n " |       +-- ($version$atom)" >&2
        if semver:constraints:simple "$version$atom"; then
          echo:Semver " $? : TRUE" >&2
          ((resultAnd &= 1))
        else
          echo:Semver " $? : FALSE" >&2
          ((resultAnd &= 0))
          break
        fi
      done < <(semver:constraints:complex "$molecule")

      [[ "$resultAnd" -eq 0 ]] && break
    done

    ((resultOr |= resultAnd))
  done

  [[ "$resultOr" -eq 1 ]] && return 0 # true
  return 1                            # false
}

##
## semver:constraints - Evaluate version constraints (PUBLIC API)
##
## Main entry point for evaluating semantic version constraints. This function
## dispatches to the appropriate constraint evaluator based on the
## SEMVER_CONSTRAINTS_IMPL environment variable.
##
## This is the recommended function for all constraint checking as it provides
## a stable API while allowing implementation selection via environment variable.
##
## Implementation Selection:
##   SEMVER_CONSTRAINTS_IMPL=v1  - Legacy evaluator (no prerelease exclusion)
##   SEMVER_CONSTRAINTS_IMPL=v2  - NPM-compatible evaluator (default)
##   Not set or other value     - Defaults to v2
##
## Parameters:
##   $1 - version (required)
##        The semantic version to test against constraints
##   $2 - expression (required)
##        Constraint expression with OR (||) and AND (space) operators
##
## Outputs:
##   Delegates to selected implementation (see semver:constraints:v1 or v2)
##
## Returns:
##   0 - Version satisfies constraints
##   1 - Version does not satisfy constraints
##   Other - Error from underlying implementation
##
## Examples:
##   # Use default implementation (v2)
##   semver:constraints "1.5.0" ">=1.0.0 <2.0.0"
##
##   # Force v1 implementation
##   SEMVER_CONSTRAINTS_IMPL=v1 semver:constraints "1.0.0-alpha" ">=1.0.0"
##
##   # Use in dependency checking
##   required_version="^1.2.0"
##   if semver:constraints "$current_version" "$required_version"; then
##     echo "Version compatible!"
##   else
##     echo "Version incompatible - upgrade required"
##   fi
##
##   # Complex constraints with OR/AND
##   semver:constraints "2.1.5" ">=1.0.0 <1.5.0 || >=2.0.0 <3.0.0"
##
## Notes:
##   - Default behavior (v2) matches NPM semver package
##   - v1 is deprecated but available for backward compatibility
##   - Implementation can be changed per-call via environment variable
##   - Recommended over calling v1/v2 directly for future compatibility
##   - See semver:constraints:v1 and semver:constraints:v2 for detailed docs
##
## Environment Variables:
##   SEMVER_CONSTRAINTS_IMPL - Implementation selector (v1|v2, default: v2)
##
## See Also:
##   - semver:constraints:v1 (legacy implementation)
##   - semver:constraints:v2 (NPM-compatible, default)
##   - demo.semver.sh lines 147-153 (usage examples)
##
function semver:constraints() {
  case "${SEMVER_CONSTRAINTS_IMPL:-v2}" in
  v1) semver:constraints:v1 "$@" ;;
  v2 | *) semver:constraints:v2 "$@" ;;
  esac
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

logger:redirect semver ">&2"
logger:redirect regex ">&2" # redirect regex to STDERR
logger:redirect simple ">&2"

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

# Refs:
# - https://www.baeldung.com/linux/bash-bitwise-operators

#echo "semver:grep: $SEMVER"
