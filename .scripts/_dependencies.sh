#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=./_commons.sh
source "$E_BASH/_commons.sh"
# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

#set -x # Uncomment to DEBUG

## 
## Purpose: Provide the `isDebug` helper for isDebug operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - isDebug "$@"
## - # Conditional usage pattern
## - if isDebug "$@"; then :; fi
## 
## 
function isDebug() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--debug" ]]; then echo true; else echo false; fi
}
## 
## Purpose: Provide the `isExec` helper for isExec operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - isExec "$@"
## - # Conditional usage pattern
## - if isExec "$@"; then :; fi
## 
## 
function isExec() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--exec" ]]; then echo true; else echo false; fi
}
## 
## Purpose: Provide the `isOptional` helper for isOptional operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - isOptional "$@"
## - # Conditional usage pattern
## - if isOptional "$@"; then :; fi
## 
## 
function isOptional() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--optional" ]]; then echo true; else echo false; fi
}
## 
## Purpose: Provide the `isSilent` helper for isSilent operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - isSilent "$@"
## - # Conditional usage pattern
## - if isSilent "$@"; then :; fi
## 
## 
function isSilent() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--silent" ]]; then echo true; else echo false; fi
}

# Internal: Version flag exceptions - tools that don't use --version
# shellcheck disable=SC2034
declare -gA __DEPS_VERSION_FLAGS_EXCEPTIONS

# Populate version flag exceptions
__DEPS_VERSION_FLAGS_EXCEPTIONS[java]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[javac]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[scala]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[kotlin]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[ant]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[go]="version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[ssh]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[tmux]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[ab]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[unrar]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[composer]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[screen]="-v"
__DEPS_VERSION_FLAGS_EXCEPTIONS[unzip]="-v"

## 
## Purpose: Provide the `dependency:dealias` helper for dependency dealias operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: SKIP_DEALIAS.
## 
## Usage:
## - dependency:dealias "$@"
## - # Conditional usage pattern
## - if dependency:dealias "$@"; then :; fi
## 
## 
function dependency:dealias() {
  # Skip dealiasing if requested (workaround for wrong resolutions)
  if [[ "${SKIP_DEALIAS:-}" == "1" ]]; then
    echo "$1"
    return
  fi

  local alias_name="$1"

  case "$alias_name" in
    rust|rustc)         echo "rustc" ;;
    golang|go)          echo "go" ;;
    nodejs|node)        echo "node" ;;
    jre|java)           echo "java" ;;
    jdk|javac)          echo "javac" ;;
    homebrew|brew)      echo "brew" ;;
    awsebcli|eb)        echo "eb" ;;
    awscli|aws)         echo "aws" ;;
    postgresql|psql)    echo "psql" ;;
    mongodb|mongo)      echo "mongo" ;;
    openssh)            echo "ssh" ;;
    goreplay|gor)       echo "gor" ;;
    httpie|http)        echo "http" ;;
    *)                  echo "$alias_name" ;;
  esac
}

## 
## Purpose: Provide the `dependency:known:flags` helper for dependency known flags operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## - $2 - secondary argument.
## 
## Globals:
## - Reads and mutates: __DEPS_VERSION_FLAGS_EXCEPTIONS.
## 
## Usage:
## - dependency:known:flags "$@"
## - # Conditional usage pattern
## - if dependency:known:flags "$@"; then :; fi
## 
## 
function dependency:known:flags() {
  local tool="$1"
  local provided_flag="$2"

  if [[ -n "$provided_flag" ]]; then
    echo "$provided_flag"
  elif [[ -v __DEPS_VERSION_FLAGS_EXCEPTIONS[$tool] ]]; then
    echo "${__DEPS_VERSION_FLAGS_EXCEPTIONS[$tool]}"
  else
    echo "--version"
  fi
}
## 
## Purpose: Provide the `isCIAutoInstallEnabled` helper for isCIAutoInstallEnabled operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: AND, CI_E_BASH_INSTALL_DEPENDENCIES.
## 
## Usage:
## - isCIAutoInstallEnabled "$@"
## - # Conditional usage pattern
## - if isCIAutoInstallEnabled "$@"; then :; fi
## 
## 
function isCIAutoInstallEnabled() {
  # Only enable auto-install if we're in a CI environment AND the flag is set
  if [[ -n "${CI:-}" ]]; then
    local value="${CI_E_BASH_INSTALL_DEPENDENCIES:-}"
    # Convert to lowercase for case-insensitive comparison (bash 4.0+ syntax)
    value="${value,,}"
    case "$value" in
      1|true|yes) echo true ;;
      *) echo false ;;
    esac
  else
    echo false
  fi
}

## 
## Purpose: Provide the `dependency` helper for dependency operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## - $2 - secondary argument.
## 
## Globals:
## - Reads and mutates: BAD, NO, OK, YEP.
## 
## Usage:
## - dependency "$@"
## - # Conditional usage pattern
## - if dependency "$@"; then :; fi
## 
## 
function dependency() {
  local tool_name=$1
  local tool_name_resolved=$(dependency:dealias "$tool_name")
  local tool_version_pattern=$2
  local tool_fallback=${3:-"No details. Please google it."}
  local tool_version_flag=${4:-""}
  # Resolve version flag (user-provided or built-in exception or default --version)
  tool_version_flag=$(dependency:known:flags "$tool_name_resolved" "$tool_version_flag")
  local is_exec=$(isExec "$@")
  local is_optional=$(isOptional "$@")
  local is_ci_auto_install=$(isCIAutoInstallEnabled)

  # Local constants for success/failure symbols
  local YEP="${cl_green}✓${cl_reset}"
  local BAD="${cl_red}✗${cl_reset}"

  config:logger:Dependencies "$@" # refresh debug flags

  # escape symbols: & / . { }, remove end of line, replace * by expectation from 1 to 4 digits
  local tool_version=$(sed -e 's#[&\\/\.{}]#\\&#g; s#$#\\#' -e '$s#\\$##' -e 's#*#[0-9]\\{1,4\\}#g' <<<$tool_version_pattern)

  # try to find tool
  local which_tool=$(command -v $tool_name_resolved)

  if [ -z "$which_tool" ]; then
    printf:Dependencies "which  : %s\npattern: %s, sed: \"s#.*\(%s\).*#\1#g\"\n-------\n" \
      "${which_tool:-"command -v $tool_name"}" "$tool_version_pattern" "$tool_version"

    if $is_ci_auto_install && ! $is_optional; then
      # In CI mode: only auto-install required dependencies, skip optional ones
      echo:Install "auto-installing missing dependency \`${cl_yellow}$tool_name${cl_reset}\`"

      if eval $tool_fallback; then
        # Trust the exit code - if install command succeeded, assume it worked
        # Optionally check if tool is now available (informational only)
        if command -v "$tool_name_resolved" >/dev/null 2>&1; then
          echo:Install "$YEP Successfully installed \`$tool_name\`"
        else
          # Installation command succeeded but tool not in PATH yet
          # This can happen if PATH needs to be reloaded or in test environments
          printf:Dependencies "Note: Install command succeeded but \`$tool_name\` not immediately found in PATH\n"
        fi
        return 0
      else
        echo:Install "$BAD Failed to install \`$tool_name\`"
        return 1
      fi
    elif $is_optional; then
      # shellcheck disable=SC2154
      echo "Optional   [${cl_red}NO${cl_reset}]: \`$tool_name\` - ${cl_red}not found${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}"
      return 0
    else
      echo "${cl_red}Error: dependency \`$tool_name\` not found."
      echo "${cl_reset} Hint. To install tool use the command below: "
      echo " \$>  $tool_fallback"
      return 1
    fi
  fi

  local version_message=$($tool_name_resolved $tool_version_flag 2>&1)
  local version_cleaned=$(echo "'$version_message'" | sed -n "s#.*\($tool_version\).*#\1#p" | head -1)

  printf:Dependencies "which  : %s\nversion: %s\npattern: %s, sed: \"s#.*\(%s\).*#\\\1#g\"\nver.   : %s\n-------\n" \
    "$which_tool" "$version_message" "$tool_version_pattern" "$tool_version" "$version_cleaned"

  if [ "$version_cleaned" == "" ]; then
    if $is_ci_auto_install && ! $is_optional; then
      # In CI mode: only auto-install required dependencies, skip optional ones
      echo:Install "auto-installing dependency with wrong version \`${cl_yellow}$tool_name${cl_reset}\`"

      if eval $tool_fallback; then
        # Trust the exit code - if install command succeeded, assume it worked
        # Optionally check if tool is now available (informational only)
        if command -v "$tool_name_resolved" >/dev/null 2>&1; then
          echo:Install "$YEP Successfully installed \`$tool_name\`"
        else
          # Installation command succeeded but tool not in PATH yet
          # This can happen if PATH needs to be reloaded or in test environments
          printf:Dependencies "Note: Install command succeeded but \`$tool_name\` not immediately found in PATH\n"
        fi
        return 0
      else
        echo:Install "$BAD Failed to install \`$tool_name\`"
        return 1
      fi
    elif $is_optional; then
      echo "Optional   [${cl_red}NO${cl_reset}]: \`$tool_name\` - ${cl_red}wrong version${cl_reset}! Try: ${cl_purple}$tool_fallback${cl_reset}"
      return 0
    else
      echo "${cl_red}Error: dependency version \`$tool_name\` is wrong."
      echo " Captured : ${cl_grey}$version_message${cl_red}"
      echo " Extracted: \`$version_cleaned\`"
      echo " Expected : \`$tool_version_pattern\`${cl_reset}"

      if $is_exec; then
        # shellcheck disable=SC2006,SC2154
        echo " Executing: ${cl_yellow}${tool_fallback}${cl_reset}"
        echo ""
        eval $tool_fallback
      else
        echo ""
        echo " Hint. To install tool use the command below: "
        echo " \$>  $tool_fallback"
        return 1
      fi
    fi
  else
    if $is_optional; then echo -n "Optional   "; else echo -n "Dependency "; fi
    # shellcheck disable=SC2154
    echo "[${cl_green}OK${cl_reset}]: \`$tool_name\` - version: $version_cleaned"
  fi
}
## 
## Purpose: Provide the `optional` helper for optional operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - optional "$@"
## - # Conditional usage pattern
## - if optional "$@"; then :; fi
## 
## 
function optional() {
  local args=("$@")

  # Ensure we have minimum required parameters before adding --optional flag
  # This prevents --optional from being treated as a positional parameter
  case ${#args[@]} in
    2) args+=("No details. Please google it." "--version") ;;
    3) args+=("--version") ;;
  esac

  # Add --optional flag and forward to dependency()
  dependency "${args[@]}" --optional
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

logger dependencies "$@" # register own debug tag & logger functions
logger:redirect dependencies ">&2"

logger:init install "${cl_blue}[install]${cl_reset} " ">&2" # register logger for CI auto-install operations

logger loader "$@" # initialize loader logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

# ref:
#  https://docs.gradle.org/current/userguide/single_versions.html
#  https://github.com/qzb/sh-semver
#  https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash


## Module notes: global variables, docs, and usage references.
## Links:
## - docs/public/conventions.md.
## - README.md (project documentation).
## - docs/public/functions-docgen.md.
## - docs/public/functions-docgen.md.
