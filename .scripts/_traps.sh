#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-25
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# One-time initialization guard
if type "trap:on" &>/dev/null; then return 0; fi

# Ensure E_BASH is set
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load dependencies
# shellcheck source=./_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck source=./_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck source=./_dependencies.sh
source "$E_BASH/_dependencies.sh"

# Global variable prefixes
__TRAP_PREFIX="__TRAP_HANDLERS_SIG_"
__TRAP_LEGACY_PREFIX="__TRAP_LEGACY_SIG_"
__TRAP_INIT_PREFIX="__TRAP_INITIALIZED_SIG_"
__TRAP_STACK_PREFIX="__TRAP_STACK_"
__TRAP_STACK_LEVEL=0

# Module initialization flag
__TRAPS_MODULE_INITIALIZED="yes"

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------

#
# Register handler for signal(s)
# Usage: trap:on [--allow-duplicates] <handler_function> <signal> [signal2] ...
# Example: trap:on cleanup_temp EXIT
#          trap:on handle_interrupt INT TERM
#
function trap:on() {
  local allow_duplicates=false

  # Parse flags
  while [[ "$1" == --* ]]; do
    case "$1" in
      --allow-duplicates) allow_duplicates=true; shift ;;
      *)
        echo:Trap "${cl_red}✗${cl_reset} Unknown flag: $1"
        return 1
        ;;
    esac
  done

  local handler="${1?Handler function required}"
  shift
  local signals=("$@")

  if [[ ${#signals[@]} -eq 0 ]]; then
    echo:Trap "${cl_red}✗${cl_reset} No signals specified for handler '$handler'"
    return 1
  fi

  # Validation: check if handler function exists
  if ! declare -F "$handler" >/dev/null 2>&1; then
    echo:Trap "${cl_red}✗${cl_reset} Function '${handler}' does not exist"
    return 1
  fi

  # Register for each signal
  for raw_signal in "${signals[@]}"; do
    local signal
    signal=$(_Trap::normalize_signal "$raw_signal") || continue

    local var_name="${__TRAP_PREFIX}${signal}"

    # If this is the first time we touch this signal, initialize it
    if [[ -z "${!var_name+x}" ]]; then
      _Trap::initialize_signal "$signal"
    fi

    # Add handler to our internal list (check for duplicates)
    if _Trap::contains "$var_name" "$handler"; then
      if $allow_duplicates; then
        # Add anyway (for counting/multi-execution)
        local -n handlers="$var_name"
        handlers+=("$handler")
        printf:Trap "${cl_green}✓${cl_reset} Handler registered (duplicate): ${cl_yellow}%s${cl_reset} for ${cl_cyan}%s${cl_reset}\n" "$handler" "$signal"
      else
        echo:Trap "${cl_yellow}⚠${cl_reset} Handler already registered: $handler for $signal (use --allow-duplicates to override)"
      fi
    else
      # Add handler using nameref
      local -n handlers="$var_name"
      handlers+=("$handler")
      printf:Trap "${cl_green}✓${cl_reset} Handler registered: ${cl_yellow}%s${cl_reset} for ${cl_cyan}%s${cl_reset}\n" "$handler" "$signal"
    fi
  done

  return 0
}

#
# Unregister handler from signal(s)
# Usage: trap:off <handler_function> <signal> [signal2] ...
# Example: trap:off cleanup_temp EXIT
#
function trap:off() {
  local handler="${1?Handler function required}"
  shift
  local signals=("$@")

  if [[ ${#signals[@]} -eq 0 ]]; then
    echo:Trap "${cl_red}✗${cl_reset} No signals specified for handler '$handler'"
    return 1
  fi

  for raw_signal in "${signals[@]}"; do
    local signal
    signal=$(_Trap::normalize_signal "$raw_signal") || continue

    local var_name="${__TRAP_PREFIX}${signal}"

    if [[ -n "${!var_name+x}" ]]; then
      _Trap::remove_handler "$var_name" "$handler"
      printf:Trap "${cl_red}✗${cl_reset} Handler removed: ${cl_yellow}%s${cl_reset} from ${cl_cyan}%s${cl_reset}\n" "$handler" "$signal"
    else
      echo:Trap "${cl_yellow}⚠${cl_reset} No handlers registered for signal: $signal"
    fi
  done

  return 0
}

#
# List all registered handlers for signal(s)
# Usage: trap:list [signal] ...
# Example: trap:list EXIT INT
#          trap:list  # all signals
#
function trap:list() {
  local signals=("$@")

  # If no signals specified, find all initialized signals
  if [[ ${#signals[@]} -eq 0 ]]; then
    signals=($(_Trap::list_all_signals))
  fi

  if [[ ${#signals[@]} -eq 0 ]]; then
    echo:Trap "${cl_grey}No signals initialized${cl_reset}"
    return 0
  fi

  for raw_signal in "${signals[@]}"; do
    local signal
    signal=$(_Trap::normalize_signal "$raw_signal") || continue

    local var_name="${__TRAP_PREFIX}${signal}"

    if [[ -n "${!var_name+x}" ]]; then
      local -n handlers="$var_name"

      if [[ ${#handlers[@]} -eq 0 ]]; then
        printf "${cl_cyan}%s${cl_reset}: ${cl_grey}(no handlers)${cl_reset}\n" "$signal"
      else
        printf "${cl_cyan}%s${cl_reset}: ${cl_yellow}%s${cl_reset}\n" "$signal" "${handlers[*]}"
      fi

      # Show legacy trap if exists
      local legacy_var="${__TRAP_LEGACY_PREFIX}${signal}"
      if [[ -n "${!legacy_var+x}" ]]; then
        local legacy_cmd="${!legacy_var}"
        if [[ -n "$legacy_cmd" ]]; then
          printf "  ${cl_grey}[legacy: %s]${cl_reset}\n" "$legacy_cmd"
        fi
      fi
    fi
  done

  return 0
}

#
# Clear all handlers for signal(s) (keeps legacy trap)
# Usage: trap:clear <signal> [signal2] ...
# Example: trap:clear EXIT
#
function trap:clear() {
  local signals=("$@")

  if [[ ${#signals[@]} -eq 0 ]]; then
    echo:Trap "${cl_red}✗${cl_reset} No signals specified"
    return 1
  fi

  for raw_signal in "${signals[@]}"; do
    local signal
    signal=$(_Trap::normalize_signal "$raw_signal") || continue

    local var_name="${__TRAP_PREFIX}${signal}"

    if [[ -n "${!var_name+x}" ]]; then
      # Clear all handlers
      eval "${var_name}=()"
      printf:Trap "${cl_green}✓${cl_reset} Cleared all handlers for ${cl_cyan}%s${cl_reset}\n" "$signal"
    fi
  done

  return 0
}

#
# Restore original trap configuration (before trap module loaded)
# Usage: trap:restore <signal> [signal2] ...
# Example: trap:restore EXIT
#
function trap:restore() {
  local signals=("$@")

  if [[ ${#signals[@]} -eq 0 ]]; then
    echo:Trap "${cl_red}✗${cl_reset} No signals specified"
    return 1
  fi

  for raw_signal in "${signals[@]}"; do
    local signal
    signal=$(_Trap::normalize_signal "$raw_signal") || continue

    local legacy_var="${__TRAP_LEGACY_PREFIX}${signal}"

    if [[ -n "${!legacy_var+x}" ]]; then
      local legacy_cmd="${!legacy_var}"

      # Restore the legacy trap
      if [[ -n "$legacy_cmd" ]]; then
        trap "$legacy_cmd" "$signal"
      else
        trap - "$signal"  # Remove trap
      fi

      # Clear our handlers
      local var_name="${__TRAP_PREFIX}${signal}"
      if [[ -n "${!var_name+x}" ]]; then
        unset "$var_name"
      fi

      printf:Trap "${cl_green}✓${cl_reset} Restored original trap for ${cl_cyan}%s${cl_reset}\n" "$signal"
    else
      echo:Trap "${cl_yellow}⚠${cl_reset} No legacy trap to restore for signal: $signal"
    fi
  done

  return 0
}

#
# Push current handler state (create snapshot)
# Usage: trap:push [signal] ...
# Example: trap:push EXIT INT
#          trap:push  # all active signals
#
function trap:push() {
  local signals=()

  if [[ $# -eq 0 ]]; then
    # No arguments - snapshot all active signals
    # Read into array properly (word splitting intended)
    signals=($(_Trap::list_all_signals))
  else
    # Specific signals provided
    signals=("$@")
  fi

  __TRAP_STACK_LEVEL=$((__TRAP_STACK_LEVEL + 1))
  local stack_var="${__TRAP_STACK_PREFIX}${__TRAP_STACK_LEVEL}"

  # Create associative array for this stack level
  declare -g -A "$stack_var"

  for raw_signal in "${signals[@]}"; do
    local signal
    signal=$(_Trap::normalize_signal "$raw_signal") || continue

    local var_name="${__TRAP_PREFIX}${signal}"

    # Save current handlers if any
    if [[ -n "${!var_name+x}" ]]; then
      local -n handlers="$var_name"
      # Serialize handlers as space-separated string
      eval "${stack_var}[${signal}]=\"\${handlers[*]}\""
    else
      eval "${stack_var}[${signal}]=\"\""
    fi
  done

  printf:Trap "${cl_cyan}📚${cl_reset} Trap state pushed (level: ${cl_yellow}%d${cl_reset})\n" "$__TRAP_STACK_LEVEL"
  return 0
}

#
# Pop and restore previous handler state
# Usage: trap:pop [signal] ...
# Example: trap:pop EXIT INT
#          trap:pop  # all signals in last push
#
function trap:pop() {
  if [[ $__TRAP_STACK_LEVEL -eq 0 ]]; then
    echo:Trap "${cl_red}✗${cl_reset} No trap state to pop"
    return 1
  fi

  local stack_var="${__TRAP_STACK_PREFIX}${__TRAP_STACK_LEVEL}"

  # Check if stack variable exists
  if ! declare -p "$stack_var" &>/dev/null; then
    echo:Trap "${cl_red}✗${cl_reset} Stack corruption detected at level $__TRAP_STACK_LEVEL"
    return 1
  fi

  local -n saved_state="$stack_var"

  # Restore handlers from stack
  for signal in "${!saved_state[@]}"; do
    local var_name="${__TRAP_PREFIX}${signal}"

    # Initialize if needed
    if [[ -z "${!var_name+x}" ]]; then
      _Trap::initialize_signal "$signal"
    fi

    # Clear current handlers
    eval "${var_name}=()"

    # Restore saved handlers
    local saved_handlers_str="${saved_state[$signal]}"
    if [[ -n "$saved_handlers_str" ]]; then
      local -a saved_handlers
      IFS=' ' read -r -a saved_handlers <<< "$saved_handlers_str"

      local -n handlers="$var_name"
      handlers=("${saved_handlers[@]}")
    fi
  done

  # Cleanup stack level
  unset "$stack_var"
  __TRAP_STACK_LEVEL=$((__TRAP_STACK_LEVEL - 1))

  printf:Trap "${cl_cyan}📚${cl_reset} Trap state popped (level: ${cl_yellow}%d${cl_reset})\n" "$__TRAP_STACK_LEVEL"
  return 0
}

#
# Begin scoped trap section (alias for trap:push)
# Usage: trap:scope:begin [signal] ...
#
function trap:scope:begin() {
  trap:push "$@"
}

#
# End scoped trap section (alias for trap:pop)
# Usage: trap:scope:end [signal] ...
#
function trap:scope:end() {
  trap:pop "$@"
}

# -----------------------------------------------------------------------------
# Internal Dispatcher (Called by OS trap mechanism)
# -----------------------------------------------------------------------------

#
# Main dispatcher called by the OS trap mechanism
# This function is set as the actual trap handler
#
function Trap::dispatch() {
  local signal="$1"
  local var_name="${__TRAP_PREFIX}${signal}"
  local legacy_var="${__TRAP_LEGACY_PREFIX}${signal}"

  # Debug trace
  printf:Trap "Dispatching trap for ${cl_cyan}%s${cl_reset}\n" "$signal"

  # 1. Execute Legacy Trap (if any) - before our handlers
  if [[ -n "${!legacy_var+x}" ]]; then
    local legacy_cmd="${!legacy_var}"
    if [[ -n "$legacy_cmd" ]]; then
      printf:Trap "  ${cl_grey}→ Executing legacy trap${cl_reset}\n"
      eval "$legacy_cmd" || echo:Trap "${cl_red}✗${cl_reset} Legacy trap failed (exit code: $?)"
    fi
  fi

  # 2. Execute Registered Handlers in order
  if [[ -n "${!var_name+x}" ]]; then
    local -n handlers="$var_name"

    for handler in "${handlers[@]}"; do
      if declare -F "$handler" >/dev/null 2>&1; then
        printf:Trap "  ${cl_grey}→ Executing: ${cl_yellow}%s${cl_reset}\n" "$handler"
        "$handler" || echo:Trap "${cl_red}✗${cl_reset} Handler failed: $handler (exit code: $?)"
      else
        echo:Trap "${cl_red}✗${cl_reset} Handler not found during execution: $handler"
      fi
    done
  fi
}

# -----------------------------------------------------------------------------
# Internal Helper Functions
# -----------------------------------------------------------------------------

#
# Normalize signal name to standard format
# Handles: SIGINT->INT, 0->EXIT, 2->INT, int->INT
#
function _Trap::normalize_signal() {
  local input="$1"
  local name

  # Special case: 0 -> EXIT
  if [[ "$input" == "0" ]]; then
    echo "EXIT"
    return 0
  fi

  # Handle integer signals (2 -> INT) using kill -l
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    if name=$(kill -l "$input" 2>/dev/null); then
      echo "$name"
      return 0
    else
      # Fallback to original if kill -l fails
      echo "$input"
      return 0
    fi
  fi

  # Handle standard names: remove SIG prefix and uppercase
  # SIGINT -> INT, sigint -> INT, int -> INT
  name=$(echo "${input#SIG}" | tr '[:lower:]' '[:upper:]')
  echo "$name"
  return 0
}

#
# Initialize signal (capture legacy trap, set dispatcher)
#
function _Trap::initialize_signal() {
  local signal="$1"

  # Mark as initialized
  declare -g "${__TRAP_INIT_PREFIX}${signal}=1"

  # 1. Capture existing trap command for this signal (if any)
  _Trap::capture_legacy "$signal"

  # 2. Set the native trap to our dispatcher
  trap "Trap::dispatch ${signal}" "$signal"

  # 3. Initialize the handler array using declare -ga (Global Array)
  declare -g -a "${__TRAP_PREFIX}${signal}"

  printf:Trap "${cl_grey}Initialized signal: ${cl_cyan}%s${cl_reset}\n" "$signal"
}

#
# Capture existing trap configuration before we override it
#
function _Trap::capture_legacy() {
  local signal="$1"
  local existing_trap_str

  # Get current trap using trap -p
  existing_trap_str=$(trap -p "$signal" 2>/dev/null)

  if [[ -n "$existing_trap_str" ]]; then
    # Parse trap output: "trap -- 'command' SIGNAL"
    # Extract the command part between the quotes
    local temp="${existing_trap_str#trap -- \'}"
    local legacy_cmd="${temp%\' *}"

    # Only store if it's not our dispatcher
    if [[ "$legacy_cmd" != *"Trap::dispatch"* ]]; then
      # Use declare -g for global assignment
      declare -g "${__TRAP_LEGACY_PREFIX}${signal}=${legacy_cmd}"
      printf:Trap "${cl_grey}Captured legacy handler for ${cl_cyan}%s${cl_reset}: ${cl_yellow}%s${cl_reset}\n" "$signal" "$legacy_cmd"
    fi
  fi
}

#
# Check if handler exists in list
#
function _Trap::contains() {
  local var_name="$1"
  local seeking="$2"
  local -n list="$var_name"

  for element in "${list[@]}"; do
    [[ "$element" == "$seeking" ]] && return 0
  done

  return 1
}

#
# Remove handler from list
#
function _Trap::remove_handler() {
  local var_name="$1"
  local target="$2"
  local -n list="$var_name"
  local keep=()

  for element in "${list[@]}"; do
    [[ "$element" != "$target" ]] && keep+=("$element")
  done

  # Rebuild the list
  list=("${keep[@]}")
}

#
# List all initialized signals
#
function _Trap::list_all_signals() {
  local signals=()

  # Iterate through all global variables matching our prefix
  for var in $(compgen -v "${__TRAP_PREFIX}"); do
    # Extract signal name from variable name
    local signal="${var#${__TRAP_PREFIX}}"
    signals+=("$signal")
  done

  echo "${signals[@]}"
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

# Skip logger initialization if functions are already mocked (e.g., in ShellSpec tests)
logger trap "$@" # declare echo:Trap & printf:Trap functions
# logger:init trap "[${cl_lblue}trap${cl_reset}] " ">&2"

echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"