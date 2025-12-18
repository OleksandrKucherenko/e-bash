#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# one time initialization
if type hooks:define 2>/dev/null | grep -q "is a function"; then return 0; fi

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# declare global associative array for hooks tracking
if [[ -z ${HOOKS_DEFINED+x} ]]; then declare -g -A HOOKS_DEFINED; fi

# default hooks directory (can be overridden)
if [[ -z ${HOOKS_DIR+x} ]]; then
  declare -g HOOKS_DIR=".hooks"
fi

# default hooks function prefix
if [[ -z ${HOOKS_PREFIX+x} ]]; then
  declare -g HOOKS_PREFIX="hook:"
fi

#
# Define available hooks in the script
#
# Usage:
#   hooks:define begin end decide error rollback
#   hooks:define custom_hook another_hook
#
# Parameters:
#   $@ - List of hook names to define
#
# Returns:
#   0 - Success
#   1 - Invalid hook name
#
function hooks:define() {
  local hook_name

  # validate and register each hook
  for hook_name in "$@"; do
    # validate hook name (alphanumeric, underscore, dash only)
    if ! [[ "$hook_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo "Error: Invalid hook name '$hook_name'. Only alphanumeric, underscore, and dash allowed." >&2
      return 1
    fi

    # register the hook
    HOOKS_DEFINED[$hook_name]=1
  done

  return 0
}

#
# Execute a hook if it's defined and has an implementation
#
# Usage:
#   on:hook begin
#   on:hook decide param1 param2
#   result=$(on:hook decide "question")
#
# Parameters:
#   $1 - Hook name
#   $@ - Additional parameters passed to the hook
#
# Execution order:
#   1. Check if hook is defined via hooks:define
#   2. Check if function hook:{name} exists
#   3. Check if script .hooks/{name}.sh exists
#   4. Execute and return result
#
# Returns:
#   Hook's exit code or 0 if not implemented
#   Hook's stdout is passed through
#
function on:hook() {
  local hook_name="$1"
  shift

  # check if hook is defined
  if [[ -z ${HOOKS_DEFINED[$hook_name]+x} ]]; then
    # hook not defined, silent skip
    return 0
  fi

  # check for function implementation: hook:{name}
  local func_name="${HOOKS_PREFIX}${hook_name}"
  if declare -F "$func_name" >/dev/null 2>&1; then
    # execute the hook function
    "$func_name" "$@"
    return $?
  fi

  # check for script implementation: .hooks/{name}.sh
  local script_path="${HOOKS_DIR}/${hook_name}.sh"
  if [[ -f "$script_path" ]] && [[ -x "$script_path" ]]; then
    # execute the hook script
    "$script_path" "$@"
    return $?
  fi

  # hook defined but not implemented, silent skip
  return 0
}

#
# List all defined hooks
#
# Usage:
#   hooks:list
#
# Returns:
#   0 - Success
#   Prints list of defined hooks to stdout
#
function hooks:list() {
  local hook_name

  if [[ ${#HOOKS_DEFINED[@]} -eq 0 ]]; then
    echo "No hooks defined"
    return 0
  fi

  echo "Defined hooks:"
  for hook_name in "${!HOOKS_DEFINED[@]}"; do
    local status="not implemented"
    local impl_type=""

    # check if implemented as function
    local func_name="${HOOKS_PREFIX}${hook_name}"
    if declare -F "$func_name" >/dev/null 2>&1; then
      status="implemented"
      impl_type="(function)"
    fi

    # check if implemented as script
    local script_path="${HOOKS_DIR}/${hook_name}.sh"
    if [[ -f "$script_path" ]] && [[ -x "$script_path" ]]; then
      status="implemented"
      impl_type="(script)"
    fi

    echo "  - $hook_name: $status $impl_type"
  done

  return 0
}

#
# Check if a hook is defined
#
# Usage:
#   if hooks:is_defined begin; then
#     echo "begin hook is defined"
#   fi
#
# Parameters:
#   $1 - Hook name
#
# Returns:
#   0 - Hook is defined
#   1 - Hook is not defined
#
function hooks:is_defined() {
  local hook_name="$1"

  if [[ -n ${HOOKS_DEFINED[$hook_name]+x} ]]; then
    return 0
  fi

  return 1
}

#
# Check if a hook has an implementation
#
# Usage:
#   if hooks:has_implementation begin; then
#     echo "begin hook has implementation"
#   fi
#
# Parameters:
#   $1 - Hook name
#
# Returns:
#   0 - Hook has implementation (function or script)
#   1 - Hook has no implementation
#
function hooks:has_implementation() {
  local hook_name="$1"

  # check for function implementation
  local func_name="${HOOKS_PREFIX}${hook_name}"
  if declare -F "$func_name" >/dev/null 2>&1; then
    return 0
  fi

  # check for script implementation
  local script_path="${HOOKS_DIR}/${hook_name}.sh"
  if [[ -f "$script_path" ]] && [[ -x "$script_path" ]]; then
    return 0
  fi

  return 1
}

#
# Cleanup function for tests
#
function hooks:cleanup() {
  unset HOOKS_DEFINED
  unset HOOKS_DIR
  unset HOOKS_PREFIX
}
