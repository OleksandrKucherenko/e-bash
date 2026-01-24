#!/usr/bin/env bash
# shellcheck disable=SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

#
# MODULE: Dependency Management System
#
# Provides comprehensive dependency validation, version checking, and optional auto-installation
# for command-line tools. Uses semantic versioning patterns to validate tool versions and can
# automatically install missing or outdated tools in CI environments.
#
# Key Features:
#   - Semantic version constraint checking with wildcard support (5.*.*, [45].*.*)
#   - Tool alias resolution (nodejs->node, golang->go, homebrew->brew, etc.)
#   - CI auto-install mode (controlled via CI_E_BASH_INSTALL_DEPENDENCIES)
#   - Optional dependencies (won't fail script if missing)
#   - Custom version flag support for non-standard tools
#   - Extensive exception handling for tools with non-standard version flags
#
# Environment Variables:
#   CI - Set to 1/true/yes to enable CI mode
#   CI_E_BASH_INSTALL_DEPENDENCIES - Set to 1/true/yes to enable auto-install in CI
#   DEBUG - Comma-separated tags (use "dependencies" to enable debug logging)
#   SKIP_DEALIAS - Set to 1 to bypass tool alias resolution
#
# Examples:
#   dependency bash "5.*.*" "brew install bash"
#   dependency go "1.17.*" "brew install go" "version"
#   dependency java "11.*.*" "brew install openjdk@11" "-version"
#   optional kcov "43" "brew install kcov"
#
# See demos/demo.dependencies.sh for comprehensive usage examples.
#

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=./_commons.sh
source "$E_BASH/_commons.sh"
# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

#set -x # Uncomment to DEBUG

#
# Internal: Check if --debug flag is present in arguments
#
# Parameters:
#   $@ - Arguments array to check
#
# Output:
#   Prints "true" if --debug flag found, "false" otherwise
#
# shellcheck disable=SC2001,SC2155,SC2046,SC2116
function isDebug() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--debug" ]]; then echo true; else echo false; fi
}

#
# Internal: Check if --exec flag is present in arguments
#
# When --exec is set, install commands run automatically on version mismatch
# instead of just displaying installation instructions.
#
# Parameters:
#   $@ - Arguments array to check
#
# Output:
#   Prints "true" if --exec flag found, "false" otherwise
#
function isExec() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--exec" ]]; then echo true; else echo false; fi
}

#
# Internal: Check if --optional flag is present in arguments
#
# Optional dependencies won't cause script failure if missing or wrong version.
# Useful for nice-to-have tools that aren't critical for script operation.
#
# Parameters:
#   $@ - Arguments array to check
#
# Output:
#   Prints "true" if --optional flag found, "false" otherwise
#
function isOptional() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--optional" ]]; then echo true; else echo false; fi
}

#
# Internal: Check if --silent flag is present in arguments
#
# Silent mode suppresses non-critical output messages.
#
# Parameters:
#   $@ - Arguments array to check
#
# Output:
#   Prints "true" if --silent flag found, "false" otherwise
#
function isSilent() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--silent" ]]; then echo true; else echo false; fi
}

#
# Internal: Version flag exceptions mapping
#
# Many tools use non-standard flags to display version information.
# This associative array maps tool names to their correct version flags.
#
# Common patterns:
#   --version (default) - Most GNU/Linux tools
#   -version            - Java ecosystem tools
#   -V                  - Some Unix utilities (ssh, tmux, etc.)
#   -v                  - Rare cases (screen, unzip)
#   version             - Go (no dash prefix)
#
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

#
# Internal: Resolve tool aliases to their canonical command names
#
# Many tools have multiple common names (e.g., nodejs vs node, golang vs go).
# This function normalizes aliases to the actual executable command name.
#
# Supported Aliases:
#   rust|rustc -> rustc
#   golang|go -> go
#   nodejs|node -> node
#   jre|java -> java
#   jdk|javac -> javac
#   homebrew|brew -> brew
#   awsebcli|eb -> eb
#   awscli|aws -> aws
#   postgresql|psql -> psql
#   mongodb|mongo -> mongo
#   openssh -> ssh
#   goreplay|gor -> gor
#   httpie|http -> http
#
# Parameters:
#   $1 - Tool name or alias to resolve
#
# Output:
#   Prints canonical command name
#
# Environment:
#   SKIP_DEALIAS - Set to 1 to bypass alias resolution (returns input as-is)
#
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

#
# Internal: Get the appropriate version flag for a tool
#
# Resolves the correct flag to use for version checking, with priority:
# 1. User-provided flag (parameter $2)
# 2. Built-in exception from __DEPS_VERSION_FLAGS_EXCEPTIONS
# 3. Default --version
#
# Parameters:
#   $1 - Tool name (canonical, after dealias)
#   $2 - Optional user-provided version flag (overrides built-in exceptions)
#
# Output:
#   Prints the version flag to use
#
# Examples:
#   dependency:known:flags "bash" ""          # outputs: --version
#   dependency:known:flags "java" ""          # outputs: -version
#   dependency:known:flags "go" ""            # outputs: version
#   dependency:known:flags "custom" "-ver"    # outputs: -ver
#
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

#
# Internal: Check if CI auto-install mode is enabled
#
# Auto-install only activates when BOTH conditions are met:
# 1. Running in CI environment (CI variable is set)
# 2. Auto-install is explicitly enabled (CI_E_BASH_INSTALL_DEPENDENCIES=1/true/yes)
#
# This dual-gate prevents accidental installations in CI without explicit opt-in.
#
# Parameters:
#   None
#
# Output:
#   Prints "true" if auto-install enabled, "false" otherwise
#
# Environment Variables:
#   CI - Must be set (any value) to indicate CI environment
#   CI_E_BASH_INSTALL_DEPENDENCIES - Must be 1, true, or yes (case-insensitive)
#
# Returns:
#   Always returns 0 (function outputs result via echo)
#
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

#
# PUBLIC API: Validate tool dependency with version constraint
#
# Checks if a command-line tool exists and matches the required version pattern.
# Supports semantic versioning wildcards, CI auto-installation, and custom version flags.
#
# Usage:
#   dependency <tool> <version_pattern> [install_command] [version_flag] [--debug] [--exec] [--optional]
#
# Parameters:
#   $1 - Tool name (supports aliases: nodejs, golang, homebrew, etc.)
#   $2 - Version pattern (supports wildcards: 5.*.*, [45].*.*)
#   $3 - Installation command or hint (default: "No details. Please google it.")
#   $4 - Version flag override (default: auto-detected or --version)
#   --debug    - Enable debug output for this dependency check
#   --exec     - Execute install command on failure (instead of just showing hint)
#   --optional - Mark as optional (won't fail script if missing/wrong version)
#
# Version Pattern Examples:
#   "5.*.*"           - Any 5.x.x version
#   "5.0.*"           - Any 5.0.x version
#   "5.0.18"          - Exact version 5.0.18
#   "[45].*.*"        - Version 4.x.x or 5.x.x
#   "1.17.*"          - Any 1.17.x version
#   "HEAD-[a-f0-9]*"  - Git HEAD with commit hash
#
# Output:
#   Success: "Dependency [OK]: `tool` - version: X.Y.Z" (exit 0)
#   Missing: Error message with install hint (exit 1, or 0 if --optional/CI auto-install)
#   Wrong version: Error message with install hint (exit 1, or 0 if --optional/CI auto-install)
#
# Returns:
#   0 - Dependency met, optional dependency (any status), or auto-installed successfully
#   1 - Required dependency missing/wrong version and not auto-installed
#
# Environment:
#   DEBUG - Add "dependencies" tag to enable debug logging for all checks
#   CI + CI_E_BASH_INSTALL_DEPENDENCIES - Enable auto-install mode
#
# Examples:
#   dependency bash "5.*.*" "brew install bash"
#   dependency go "1.17.*" "brew install go" "version"
#   dependency java "11.*.*" "brew install openjdk@11" "-version"
#   dependency custom "1.0.*" "make install" "--ver" --debug
#   dependency tool "2.*.*" "apt install tool" "" --exec
#
# See Also:
#   optional() - Wrapper function for optional dependencies
#   demos/demo.dependencies.sh - Comprehensive usage examples
#
# shellcheck disable=SC2001,SC2155,SC2086
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

#
# PUBLIC API: Declare an optional dependency
#
# Convenience wrapper around dependency() that automatically adds the --optional flag.
# Optional dependencies won't cause script failure if missing or version doesn't match.
#
# Usage:
#   optional <tool> <version_pattern> [install_command] [version_flag]
#
# Parameters:
#   $1 - Tool name (supports aliases)
#   $2 - Version pattern (supports wildcards)
#   $3 - Installation command or hint (default: "No details. Please google it.")
#   $4 - Version flag override (default: auto-detected or --version)
#
# Output:
#   Success: "Optional [OK]: `tool` - version: X.Y.Z"
#   Missing: "Optional [NO]: `tool` - not found! Try: <install_command>"
#   Wrong:   "Optional [NO]: `tool` - wrong version! Try: <install_command>"
#
# Returns:
#   Always returns 0 (success) - optional dependencies never fail
#
# Examples:
#   optional kcov "43" "brew install kcov"
#   optional shellcheck "0.11.*" "brew install shellcheck"
#   optional watchman "2024.*" "brew install watchman"
#
# Notes:
#   - Automatically fills in default values for missing parameters
#   - Always appends --optional flag before calling dependency()
#   - Useful for nice-to-have tools (code coverage, linters, formatters, etc.)
#
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
