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

# shellcheck disable=SC1090 source=./_colors.sh
source "$E_BASH/_colors.sh"

# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

# Initialize logger for hooks (disabled by default, enable with DEBUG=hooks or DEBUG=*)
# Output to stderr for traceability (user output goes to stdout, logging to stderr)
logger:init hooks "${cl_grey}[hooks]${cl_reset} " ">&2"

# declare global associative array for hooks tracking (internal)
# stores hook_name -> "1" for quick existence check
if [[ -z ${__HOOKS_DEFINED+x} ]]; then declare -g -A __HOOKS_DEFINED; fi

# declare global associative array for tracking hook contexts (internal)
# stores hook_name -> "context1|context2|context3" pipe-separated list
if [[ -z ${__HOOKS_CONTEXTS+x} ]]; then declare -g -A __HOOKS_CONTEXTS; fi

# declare global arrays for execution mode pattern registration (internal)
if [[ -z ${____HOOKS_SOURCE_PATTERNS+x} ]]; then declare -g -a ____HOOKS_SOURCE_PATTERNS=(); fi
if [[ -z ${____HOOKS_SCRIPT_PATTERNS+x} ]]; then declare -g -a ____HOOKS_SCRIPT_PATTERNS=(); fi

# default hooks directory (can be overridden)
if [[ -z ${HOOKS_DIR+x} ]]; then
  declare -g HOOKS_DIR="ci-cd"
fi

# default hooks function prefix
if [[ -z ${HOOKS_PREFIX+x} ]]; then
  declare -g HOOKS_PREFIX="hook:"
fi

# default hooks execution mode: "exec" or "source"
# exec - execute script directly (default, runs in subprocess)
# source - source script and call hook:run function (runs in current shell)
if [[ -z ${HOOKS_EXEC_MODE+x} ]]; then
  declare -g HOOKS_EXEC_MODE="exec"
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

  # Get the calling script context (the script that called hooks:define)
  # BASH_SOURCE[0] = _hooks.sh, BASH_SOURCE[1] = calling script
  local caller_context="${BASH_SOURCE[1]:-main}"

  # Normalize context path (remove ./ prefix and resolve to absolute path if possible)
  if [[ "$caller_context" != "main" && -f "$caller_context" ]]; then
    caller_context="$(cd "$(dirname "$caller_context")" && pwd)/$(basename "$caller_context")"
  fi

  echo:Hooks "Defining hooks from context: $caller_context"
  echo:Hooks "  hooks: $*"

  # validate and register each hook
  for hook_name in "$@"; do
    # validate hook name (alphanumeric, underscore, dash only)
    if ! [[ "$hook_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo "Error: Invalid hook name '$hook_name'. Only alphanumeric, underscore, and dash allowed." >&2
      return 1
    fi

    # check if hook already exists from a different context
    if [[ -n ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
      # hook already defined - check contexts
      local existing_contexts="${__HOOKS_CONTEXTS[$hook_name]}"

      # check if this context already registered this hook
      if [[ "|${existing_contexts}|" == *"|${caller_context}|"* ]]; then
        echo:Hooks "  ℹ Hook '$hook_name' already registered from this context, skipping"
        continue
      fi

      # different context - warn about potential conflict
      printf "${cl_yellow}[hooks]${cl_reset} " >&2
      echo "⚠ Warning: Hook '$hook_name' is being defined from multiple contexts:" >&2
      echo "    Existing: $existing_contexts" >&2
      echo "    New:      $caller_context" >&2
      echo "  This is supported for nested/composed scripts, but verify it's intentional." >&2

      # append new context to existing list
      __HOOKS_CONTEXTS[$hook_name]="${existing_contexts}|${caller_context}"
    else
      # first time defining this hook
      __HOOKS_CONTEXTS[$hook_name]="$caller_context"
    fi

    # register the hook
    __HOOKS_DEFINED[$hook_name]=1
    echo:Hooks "  ✓ Registered hook: $hook_name (context: $caller_context)"
  done

  return 0
}

#
# Register file patterns to always execute in sourced mode
#
# Usage:
#   hook:as:source "begin-*-init.sh"
#   hook:as:source "env-*.sh" "config-*.sh"
#
# Parameters:
#   $@ - File patterns (wildcards supported)
#
# Returns:
#   0 - Success
#
function hook:as:source() {
  local pattern

  for pattern in "$@"; do
    __HOOKS_SOURCE_PATTERNS+=("$pattern")
    echo:Hooks "Registered pattern for sourced execution: $pattern"
  done

  return 0
}

#
# Register file patterns to always execute as scripts
#
# Usage:
#   hook:as:script "end-datadog.sh"
#   hook:as:script "notify-*.sh"
#
# Parameters:
#   $@ - File patterns (wildcards supported)
#
# Returns:
#   0 - Success
#
function hook:as:script() {
  local pattern

  for pattern in "$@"; do
    __HOOKS_SCRIPT_PATTERNS+=("$pattern")
    echo:Hooks "Registered pattern for script execution: $pattern"
  done

  return 0
}

#
# Determine execution mode for a specific script
#
# Parameters:
#   $1 - Script filename (basename)
#
# Returns:
#   Echoes "source" or "exec"
#
function hooks:get_exec_mode() {
  local script_name="$1"
  local pattern

  # Check source patterns first (higher priority)
  for pattern in "${__HOOKS_SOURCE_PATTERNS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$script_name" == $pattern ]]; then
      echo "source"
      return 0
    fi
  done

  # Check script patterns
  for pattern in "${__HOOKS_SCRIPT_PATTERNS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$script_name" == $pattern ]]; then
      echo "exec"
      return 0
    fi
  done

  # Fall back to global mode
  echo "$HOOKS_EXEC_MODE"
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
# Execution modes (controlled by HOOKS_EXEC_MODE):
#   - "exec" (default): Execute scripts directly in subprocess
#   - "source": Source scripts and call hook:run function (runs in current shell)
#
# Logging:
#   Enable with DEBUG=hooks or DEBUG=* to see:
#   - Hook definitions and registrations
#   - Hook execution flow
#   - Script discovery and execution order
#   - Exit codes for each implementation
#
# Returns:
#   Last hook's exit code or 0 if not implemented
#   All hooks' stdout is passed through
#
function on:hook() {
  local hook_name="$1"
  shift

  local last_exit_code=0
  local impl_count=0

  # check if hook is defined
  if [[ -z ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
    echo:Hooks "Hook '$hook_name' not defined, skipping"
    return 0
  fi

  echo:Hooks "Executing hook: $hook_name"

  # execute function implementation first: hook:{name}
  local func_name="${HOOKS_PREFIX}${hook_name}"
  if declare -F "$func_name" >/dev/null 2>&1; then
    echo:Hooks "  → [function] ${func_name}"
    "$func_name" "$@"
    last_exit_code=$?
    echo:Hooks "    ↳ exit code: $last_exit_code"
    ((impl_count++))
  fi

  # find and execute all matching script implementations
  # patterns: {hook_name}-*.sh or {hook_name}_*.sh
  if [[ -d "$HOOKS_DIR" ]]; then
    local -a hook_scripts=()

    # find scripts matching the patterns
    while IFS= read -r -d '' script; do
      hook_scripts+=("$script")
    done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -executable -print0 2>/dev/null | sort -z)

    # log discovered scripts
    if [[ ${#hook_scripts[@]} -gt 0 ]]; then
      echo:Hooks "  Found ${#hook_scripts[@]} script(s) for hook '$hook_name'"
    fi

    # execute each script in alphabetical order
    local script_num=0
    for script in "${hook_scripts[@]}"; do
      ((script_num++))
      local script_name=$(basename "$script")
      local exec_mode=$(hooks:get_exec_mode "$script_name")

      if [[ "$exec_mode" == "source" ]]; then
        echo:Hooks "  → [script $script_num/$((${#hook_scripts[@]}))] ${script_name} (sourced mode)"
        # Source the script and call hook:run function if it exists
        # shellcheck disable=SC1090
        source "$script"
        if declare -F "hook:run" >/dev/null 2>&1; then
          hook:run "$@"
          last_exit_code=$?
        else
          echo:Hooks "    ⚠ No hook:run function found in ${script_name}, skipping"
          last_exit_code=0
        fi
      else
        echo:Hooks "  → [script $script_num/${#hook_scripts[@]}] ${script_name} (exec mode)"
        "$script" "$@"
        last_exit_code=$?
      fi

      echo:Hooks "    ↳ exit code: $last_exit_code"
      ((impl_count++))

      # optionally stop on first failure (uncomment if needed)
      # if [[ $last_exit_code -ne 0 ]]; then
      #   echo:Hooks "  ✗ Hook failed, stopping execution"
      #   return $last_exit_code
      # fi
    done
  fi

  if [[ $impl_count -eq 0 ]]; then
    echo:Hooks "  ⚠ No implementations found for hook '$hook_name'"
  else
    echo:Hooks "  ✓ Completed hook '$hook_name' (${impl_count} implementation(s), final exit code: $last_exit_code)"
  fi

  return $last_exit_code
}

#
# Execute a hook with scripts sourced (ignores HOOKS_EXEC_MODE for call-level override)
#
# Usage:
#   on:source-hook begin
#   on:source-hook deploy param1 param2
#
# Parameters:
#   $1 - Hook name
#   $@ - Additional parameters passed to the hook
#
# Returns:
#   Last hook's exit code or 0 if not implemented
#
function on:source-hook() {
  local saved_mode="$HOOKS_EXEC_MODE"
  HOOKS_EXEC_MODE="source"

  echo:Hooks "Call-level override: forcing sourced mode for this hook execution"
  on:hook "$@"
  local exit_code=$?

  HOOKS_EXEC_MODE="$saved_mode"
  return $exit_code
}

#
# Execute a hook with scripts executed as subprocesses (ignores HOOKS_EXEC_MODE for call-level override)
#
# Usage:
#   on:script-hook end
#   on:script-hook notify url status
#
# Parameters:
#   $1 - Hook name
#   $@ - Additional parameters passed to the hook
#
# Returns:
#   Last hook's exit code or 0 if not implemented
#
function on:script-hook() {
  local saved_mode="$HOOKS_EXEC_MODE"
  HOOKS_EXEC_MODE="exec"

  echo:Hooks "Call-level override: forcing exec mode for this hook execution"
  on:hook "$@"
  local exit_code=$?

  HOOKS_EXEC_MODE="$saved_mode"
  return $exit_code
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

  if [[ ${#__HOOKS_DEFINED[@]} -eq 0 ]]; then
    echo "No hooks defined"
    return 0
  fi

  echo "Defined hooks:"
  for hook_name in "${!__HOOKS_DEFINED[@]}"; do
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

    # get context info
    local contexts="${__HOOKS_CONTEXTS[$hook_name]:-unknown}"
    local context_count=$(echo "$contexts" | tr '|' '\n' | wc -l)

    # format output
    if [[ ${#implementations[@]} -eq 0 ]]; then
      echo "  - $hook_name: not implemented"
    else
      local impl_str=$(IFS=', '; echo "${implementations[*]}")
      echo "  - $hook_name: implemented ($impl_str)"
    fi

    # show context info if multiple contexts
    if [[ $context_count -gt 1 ]]; then
      echo "      ${cl_yellow}⚠ defined in $context_count contexts${cl_reset}"
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

  if [[ -n ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
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
  unset __HOOKS_DEFINED
  unset __HOOKS_CONTEXTS
  unset __HOOKS_SOURCE_PATTERNS
  unset __HOOKS_SCRIPT_PATTERNS
  unset HOOKS_DIR
  unset HOOKS_PREFIX
  unset HOOKS_EXEC_MODE
}
