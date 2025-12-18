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
  declare -g HOOKS_DIR="ci-cd"
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
#   2. Execute function hook:{name} if it exists
#   3. Find and execute all matching scripts in ci-cd/{hook_name}-*.sh or ci-cd/{hook_name}_*.sh
#   4. Scripts are executed in alphabetical order
#
# Script naming patterns:
#   - {hook_name}-{purpose}.sh
#   - {hook_name}_{NN}_{purpose}.sh (recommended for ordered execution)
#
# Returns:
#   Last hook's exit code or 0 if not implemented
#   All hooks' stdout is passed through
#
function on:hook() {
  local hook_name="$1"
  shift

  local last_exit_code=0

  # check if hook is defined
  if [[ -z ${HOOKS_DEFINED[$hook_name]+x} ]]; then
    # hook not defined, silent skip
    return 0
  fi

  # execute function implementation first: hook:{name}
  local func_name="${HOOKS_PREFIX}${hook_name}"
  if declare -F "$func_name" >/dev/null 2>&1; then
    "$func_name" "$@"
    last_exit_code=$?
  fi

  # find and execute all matching script implementations
  # patterns: {hook_name}-*.sh or {hook_name}_*.sh
  if [[ -d "$HOOKS_DIR" ]]; then
    local -a hook_scripts=()

    # find scripts matching the patterns
    while IFS= read -r -d '' script; do
      hook_scripts+=("$script")
    done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -executable -print0 2>/dev/null | sort -z)

    # execute each script in alphabetical order
    for script in "${hook_scripts[@]}"; do
      "$script" "$@"
      last_exit_code=$?

      # optionally stop on first failure (uncomment if needed)
      # if [[ $last_exit_code -ne 0 ]]; then
      #   return $last_exit_code
      # fi
    done
  fi

  return $last_exit_code
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
    local implementations=()

    # check if implemented as function
    local func_name="${HOOKS_PREFIX}${hook_name}"
    if declare -F "$func_name" >/dev/null 2>&1; then
      implementations+=("function")
    fi

    # check for script implementations
    if [[ -d "$HOOKS_DIR" ]]; then
      local script_count=0
      while IFS= read -r -d '' script; do
        ((script_count++))
      done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -executable -print0 2>/dev/null)

      if [[ $script_count -gt 0 ]]; then
        implementations+=("${script_count} script(s)")
      fi
    fi

    # format output
    if [[ ${#implementations[@]} -eq 0 ]]; then
      echo "  - $hook_name: not implemented"
    else
      local impl_str=$(IFS=', '; echo "${implementations[*]}")
      echo "  - $hook_name: implemented ($impl_str)"
    fi
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

  # check for script implementations (any matching pattern)
  if [[ -d "$HOOKS_DIR" ]]; then
    local script_count=0
    while IFS= read -r -d '' script; do
      ((script_count++))
      break  # found at least one, no need to count all
    done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -executable -print0 2>/dev/null)

    if [[ $script_count -gt 0 ]]; then
      return 0
    fi
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
