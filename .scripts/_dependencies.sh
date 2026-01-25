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

# shellcheck disable=SC2001,SC2155,SC2046,SC2116

##
## Check if --debug flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --debug present, "false" otherwise
##
function isDebug() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--debug" ]]; then echo true; else echo false; fi
}

##
## Check if --exec flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --exec present, "false" otherwise
##
function isExec() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--exec" ]]; then echo true; else echo false; fi
}

##
## Check if --optional flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --optional present, "false" otherwise
##
function isOptional() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--optional" ]]; then echo true; else echo false; fi
}

##
## Check if --silent flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --silent present, "false" otherwise
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
__DEPS_VERSION_FLAGS_EXCEPTIONS[tmux]="-VV"
__DEPS_VERSION_FLAGS_EXCEPTIONS[ab]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[unrar]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[composer]="-V"
__DEPS_VERSION_FLAGS_EXCEPTIONS[screen]="-v"
__DEPS_VERSION_FLAGS_EXCEPTIONS[unzip]="-v"

##
## Resolve tool aliases to their canonical command names
##
## Parameters:
## - alias_name - Tool alias to resolve, string, required
##
## Globals:
## - reads/listen: SKIP_DEALIAS
## - mutate/publish: none
##
## Returns:
## - Canonical command name
##
## Usage:
## - dependency:dealias "rust" -> "rustc"
## - dependency:dealias "brew" -> "brew"
## - SKIP_DEALIAS=1 dependency:dealias "rust" -> "rust"
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
## Get the version flag for a tool (exception or default --version)
##
## Parameters:
## - tool - Tool name, string, required
## - provided_flag - User-provided flag override, string, optional
##
## Globals:
## - reads/listen: __DEPS_VERSION_FLAGS_EXCEPTIONS
## - mutate/publish: none
##
## Returns:
## - Version flag (e.g. "--version", "-V", "-version")
##
## Usage:
## - dependency:known:flags "java" -> "-version"
## - dependency:known:flags "git" -> "--version"
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
## Check if CI auto-install mode is enabled
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: CI, CI_E_BASH_INSTALL_DEPENDENCIES
## - mutate/publish: none
##
## Returns:
## - "true" if in CI and auto-install enabled, "false" otherwise
##
## Usage:
## - if [ "$(isCIAutoInstallEnabled)" = "true" ]; then ...; fi
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
## Check and optionally install a dependency with version constraint
##
## Parameters:
## - tool_name - Tool to check, string, required
## - tool_version_pattern - Semver pattern (e.g. "5.*.*", "HEAD-[a-f0-9]{1,8}"), string, required
## - tool_fallback - Install command, string, default: "No details. Please google it."
## - tool_version_flag - Custom version flag, string, default: auto-detected
## - --optional - Mark as optional dependency (soft fail)
## - --exec - Execute install command on version mismatch
## - --debug - Enable debug output
##
## Globals:
## - reads/listen: CI, CI_E_BASH_INSTALL_DEPENDENCIES, SKIP_DEALIAS
## - mutate/publish: none (may execute install command)
##
## Side effects:
## - May execute install command in CI or with --exec
##
## Returns:
## - 0 if dependency found/installed, 1 otherwise
##
## Usage:
## - dependency bash "5.*.*" "brew install bash"
## - dependency shellspec "0.28.*" "brew install shellspec" "--version"
## - optional kcov "43" "brew install kcov"
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
## Declare an optional dependency (wrapper for dependency with --optional flag)
##
## Parameters:
## - tool_name - Tool to check, string, required
## - tool_version_pattern - Semver pattern, string, required
## - tool_fallback - Install command, string, default: "No details. Please google it."
## - tool_version_flag - Custom version flag, string, default: "--version"
##
## Globals:
## - reads/listen: none
## - mutate/publish: none (forwards to dependency)
##
## Returns:
## - 0 (always succeeds for optional deps)
##
## Usage:
## - optional kcov "43" "brew install kcov"
## - optional hyperfine "" "brew install hyperfine"
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

##
## Module: Dependency Management with Version Constraints
##
## This module provides dependency checking with semantic versioning constraints
## and optional auto-installation in CI environments.
##
## References:
## - demo: demo.dependencies.sh, demo.cache.sh
## - bin: git.sync-by-patches.sh, version-up.v2.sh, vhd.sh,
##   ci.validate-envrc.sh, npm.versions.sh, un-link.sh
## - documentation: Referenced in docs/public/installation.md
## - tests: spec/dependencies_spec.sh
##
## Globals:
## - E_BASH - Path to .scripts directory
## - __DEPS_VERSION_FLAGS_EXCEPTIONS - Associative array of tools with non-standard version flags
## - CI - Set by CI environments (GitHub Actions, GitLab CI, etc.)
## - CI_E_BASH_INSTALL_DEPENDENCIES - Enable auto-install in CI (1/true/yes)
## - SKIP_DEALIAS - Bypass alias resolution when set to "1"
##
## Supported Version Patterns:
## - "5.*.*" - Any 5.x.x version
## - "^1.0.0" - 1.0.0 or higher (compatible)
## - "~1.2.3" - 1.2.x versions (patch-level updates)
## - "HEAD-[a-f0-9]{1,8}" - Git commit hash pattern
## - ">1.0.0" - Greater than 1.0.0
##
## Tool Aliases (auto-resolved):
## - rust/rustc -> rustc
## - golang/go -> go
## - nodejs/node -> node
## - jre/java -> java
## - homebrew/brew -> brew
##
## ref:
##  https://docs.gradle.org/current/userguide/single_versions.html
##  https://github.com/qzb/sh-semver
##  https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
##