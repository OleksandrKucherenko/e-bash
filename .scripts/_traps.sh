#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Module: _traps.sh
## Description: Enhanced signal trap management system with support for multiple handlers per signal.
##   Provides a robust alternative to bash's native trap mechanism, allowing registration of
##   multiple handler functions per signal with LIFO (Last-In-First-Out) execution order.
##   Includes state management via push/pop operations for scoped cleanup patterns, handler
##   lifecycle management, signal normalization, and legacy trap preservation.
##
##   Key Features:
##   - Multiple handlers per signal (registered handlers execute in order)
##   - LIFO execution order (last registered handler runs first)
##   - Signal normalization (SIGINT→INT, 0→EXIT, int→INT)
##   - Legacy trap preservation and restoration
##   - Scoped handler management (push/pop state snapshots)
##   - Duplicate handler control (--allow-duplicates flag)
##   - Handler validation (checks function existence before registration)
##   - Multi-signal registration (register one handler for multiple signals)
##
##   Global Variables:
##   - __TRAP_PREFIX: Variable prefix for handler arrays ("__TRAP_HANDLERS_SIG_")
##   - __TRAP_LEGACY_PREFIX: Prefix for legacy trap storage ("__TRAP_LEGACY_SIG_")
##   - __TRAP_INIT_PREFIX: Prefix for initialization flags ("__TRAP_INITIALIZED_SIG_")
##   - __TRAP_STACK_PREFIX: Prefix for state stack ("__TRAP_STACK_")
##   - __TRAP_STACK_LEVEL: Current stack depth (integer)
##   - __TRAPS_MODULE_INITIALIZED: Module initialization flag
##
##   Internal Architecture:
##   - Trap::dispatch: Central dispatcher called by OS trap mechanism
##   - Handler arrays: Dynamic arrays named __TRAP_HANDLERS_SIG_{SIGNAL}
##   - Legacy preservation: Original traps captured before module takes over
##   - State stack: Nested associative arrays for push/pop operations
##
##   See: demos/demo.traps.sh, docs/public/traps.md
##
## Public API Functions:
##   trap:on            - Register handler for signal(s)
##   trap:off           - Unregister handler from signal(s)
##   trap:list          - List all registered handlers
##   trap:clear         - Clear all handlers for signal(s)
##   trap:restore       - Restore original trap configuration
##   trap:push          - Save current handler state (snapshot)
##   trap:pop           - Restore previous handler state
##   trap:scope:begin   - Alias for trap:push
##   trap:scope:end     - Alias for trap:pop
##
## Internal Functions:
##   Trap::dispatch              - Main dispatcher invoked by OS
##   _Trap::normalize_signal     - Normalize signal names to standard format
##   _Trap::initialize_signal    - Initialize signal handling
##   _Trap::capture_legacy       - Capture existing trap before override
##   _Trap::contains             - Check if handler exists in list
##   _Trap::remove_handler       - Remove handler from list
##   _Trap::list_all_signals     - List all initialized signals

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

## Function: trap:on
## Description: Register a handler function for one or more signals. Validates that the handler
##   function exists before registration. By default, prevents duplicate registration of the same
##   handler for a signal unless --allow-duplicates flag is provided. Multiple different handlers
##   can be registered for the same signal; they execute in registration order.
##
##   On first registration for a signal, the module:
##   1. Captures any existing trap command (legacy trap)
##   2. Sets Trap::dispatch as the actual OS trap handler
##   3. Creates a handler array to track registered functions
##
## Arguments:
##   --allow-duplicates - (optional) Allow same handler to be registered multiple times
##   $1 - Handler function name (must exist as a shell function)
##   $2...$N - Signal name(s) in any format (INT, SIGINT, int, 2, 0 for EXIT)
##
## Returns:
##   Exit code 0 - Success (all handlers registered)
##   Exit code 1 - Failure (no signals specified, handler function doesn't exist, or unknown flag)
##
## Side Effects:
##   - Creates/modifies global handler array: __TRAP_HANDLERS_SIG_{SIGNAL}
##   - Initializes signal on first use (captures legacy trap, sets dispatcher)
##   - Writes status messages via echo:Trap/printf:Trap
##   - Sets OS trap to Trap::dispatch for newly initialized signals
##
## Example:
##   cleanup_temp() { rm -rf /tmp/myapp/*; }
##   save_state() { echo "Saving..."; }
##
##   trap:on cleanup_temp EXIT
##   trap:on save_state EXIT
##   trap:on handle_interrupt INT TERM HUP
##
##   # Register with duplicates allowed (for counting/multi-execution)
##   trap:on --allow-duplicates log_event EXIT
##   trap:on --allow-duplicates log_event EXIT  # Will execute twice
##
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

## Function: trap:off
## Description: Unregister a previously registered handler function from one or more signals.
##   Removes the handler from the signal's handler list. If the handler was registered multiple
##   times with --allow-duplicates, only the first occurrence is removed. The signal itself
##   remains initialized with other handlers (if any) or an empty handler list.
##
## Arguments:
##   $1 - Handler function name to remove
##   $2...$N - Signal name(s) to remove handler from (INT, EXIT, SIGTERM, etc.)
##
## Returns:
##   Exit code 0 - Success (handler removed from all specified signals)
##   Exit code 1 - Failure (no signals specified)
##
## Side Effects:
##   - Modifies global handler array: __TRAP_HANDLERS_SIG_{SIGNAL}
##   - Writes status messages via printf:Trap/echo:Trap
##   - Does NOT restore legacy trap or remove OS trap (use trap:restore for that)
##
## Example:
##   trap:on cleanup_temp EXIT
##   trap:on save_state EXIT
##
##   trap:off cleanup_temp EXIT  # Removes cleanup_temp, save_state remains
##   trap:list EXIT               # Shows: EXIT: save_state
##
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

## Function: trap:list
## Description: Display all registered handlers for specified signals. If no signals are
##   specified, displays handlers for all initialized signals. Shows both registered handlers
##   and legacy traps (if any were captured during initialization). Useful for debugging
##   and understanding current trap configuration.
##
## Arguments:
##   $@ - (optional) Signal name(s) to list handlers for. If omitted, lists all signals.
##
## Returns:
##   Exit code 0 - Success (always)
##
## Side Effects:
##   - Writes formatted output to stdout with ANSI color codes
##   - For each signal, displays: signal name, handler list, and legacy trap (if exists)
##   - Empty handler lists shown as "(no handlers)"
##
## Example:
##   trap:on cleanup_temp EXIT
##   trap:on save_state EXIT
##   trap:on handle_int INT
##
##   trap:list EXIT           # Shows: EXIT: cleanup_temp save_state
##   trap:list EXIT INT       # Shows both EXIT and INT handlers
##   trap:list                # Shows all initialized signals
##
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

## Function: trap:clear
## Description: Remove all registered handlers from specified signals while preserving the
##   signal's initialization and legacy trap. The signal remains active with an empty handler
##   list. The OS trap (Trap::dispatch) stays installed, and legacy traps are preserved.
##   Use this to reset signal handlers without full restoration.
##
## Arguments:
##   $@ - Signal name(s) to clear handlers from (must specify at least one)
##
## Returns:
##   Exit code 0 - Success (all specified signals cleared)
##   Exit code 1 - Failure (no signals specified)
##
## Side Effects:
##   - Clears handler array: __TRAP_HANDLERS_SIG_{SIGNAL}=()
##   - Writes status messages via printf:Trap
##   - Does NOT remove OS trap or affect legacy trap
##   - Signal remains initialized (can add new handlers with trap:on)
##
## Example:
##   trap:on cleanup_temp EXIT
##   trap:on save_state EXIT
##   trap:list EXIT                # Shows: EXIT: cleanup_temp save_state
##
##   trap:clear EXIT
##   trap:list EXIT                # Shows: EXIT: (no handlers)
##   trap:on new_handler EXIT      # Can register new handlers
##
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

## Function: trap:restore
## Description: Restore the original trap configuration that existed before the traps module
##   initialized the signal. Reinstalls the legacy trap command (if any) and removes all
##   module-managed handlers. This completely reverses the module's initialization for the
##   specified signal(s). Use when you want to return to pre-module behavior.
##
## Arguments:
##   $@ - Signal name(s) to restore to original configuration (must specify at least one)
##
## Returns:
##   Exit code 0 - Success (all specified signals restored)
##   Exit code 1 - Failure (no signals specified)
##
## Side Effects:
##   - Restores OS trap to legacy command via: trap "$legacy_cmd" SIGNAL
##   - If no legacy trap existed, removes OS trap via: trap - SIGNAL
##   - Unsets handler array: __TRAP_HANDLERS_SIG_{SIGNAL}
##   - Writes status messages via printf:Trap/echo:Trap
##   - Signal returns to pre-module state (no longer managed by this module)
##
## Example:
##   # Before module load, script had: trap "echo original" EXIT
##   source "$E_BASH/_traps.sh"
##   trap:on my_handler EXIT       # Module takes over
##
##   trap:restore EXIT              # Restores: trap "echo original" EXIT
##   # Signal now behaves as it did before module loaded
##
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

## Function: trap:push
## Description: Save the current handler state by creating a snapshot on the state stack.
##   Captures handler lists for specified signals (or all active signals if none specified)
##   and stores them in a stack level. Enables scoped cleanup patterns where temporary
##   handlers can be added and later removed by calling trap:pop. Stack operations are
##   nestable (push/push/pop/pop pattern supported).
##
## Arguments:
##   $@ - (optional) Signal name(s) to snapshot. If omitted, snapshots all active signals.
##
## Returns:
##   Exit code 0 - Success (state saved to stack)
##
## Side Effects:
##   - Increments global __TRAP_STACK_LEVEL counter
##   - Creates global associative array: __TRAP_STACK_{level}
##   - Serializes handler arrays as space-separated strings in stack
##   - Writes status message via printf:Trap showing new stack level
##
## Example:
##   trap:on outer_cleanup EXIT
##   trap:push EXIT                      # Save state (level 1)
##
##   trap:on inner_cleanup EXIT          # Add temporary handler
##   trap:list EXIT                      # Shows: outer_cleanup inner_cleanup
##
##   trap:pop EXIT                       # Restore state (back to level 0)
##   trap:list EXIT                      # Shows: outer_cleanup
##
##   # Push all active signals
##   trap:push                           # Snapshots EXIT, INT, TERM, etc.
##
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

## Function: trap:pop
## Description: Restore handler state from the most recent trap:push snapshot. Removes the
##   current handlers and reinstalls handlers from the saved stack level. After restoration,
##   decrements stack level and cleans up the stack data. Fails gracefully if stack is empty.
##   Supports partial restoration (specific signals) or full restoration (all signals in snapshot).
##
## Arguments:
##   $@ - (optional) Specific signal(s) to restore. If omitted, restores all signals from snapshot.
##
## Returns:
##   Exit code 0 - Success (state restored from stack)
##   Exit code 1 - Failure (stack is empty or stack corruption detected)
##
## Side Effects:
##   - Restores handler arrays from stack: __TRAP_HANDLERS_SIG_{SIGNAL}
##   - Decrements global __TRAP_STACK_LEVEL counter
##   - Unsets stack associative array: __TRAP_STACK_{level}
##   - Writes status message via printf:Trap/echo:Trap showing new stack level
##   - Initializes signals if needed (for signals that weren't active before push)
##
## Example:
##   trap:on global_handler EXIT
##   trap:push EXIT                      # Save: global_handler
##
##   trap:on scoped_handler EXIT         # Add temporary
##   trap:list EXIT                      # Shows: global_handler scoped_handler
##
##   trap:pop EXIT                       # Restore
##   trap:list EXIT                      # Shows: global_handler
##
##   # Error handling
##   trap:pop                            # Error: No trap state to pop
##
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

## Function: trap:scope:begin
## Description: Semantic alias for trap:push. Marks the beginning of a scoped trap section
##   for improved code readability. Functionally identical to trap:push - saves current handler
##   state to enable temporary handler registration within a scope. Pair with trap:scope:end
##   to create clear scope boundaries.
##
## Arguments:
##   $@ - (optional) Signal name(s) to snapshot. If omitted, snapshots all active signals.
##
## Returns:
##   Exit code 0 - Success (delegates to trap:push)
##
## Example:
##   trap:on global_cleanup EXIT
##
##   trap:scope:begin EXIT               # Start scoped section
##   trap:on scoped_cleanup EXIT         # Temporary handler
##   # ... do work requiring scoped cleanup ...
##   trap:scope:end EXIT                 # End scoped section (removes scoped_cleanup)
##
function trap:scope:begin() {
  trap:push "$@"
}

## Function: trap:scope:end
## Description: Semantic alias for trap:pop. Marks the end of a scoped trap section for
##   improved code readability. Functionally identical to trap:pop - restores handler state
##   from the most recent trap:scope:begin (or trap:push). Use to clearly delineate scope
##   boundaries and ensure cleanup handlers are properly managed.
##
## Arguments:
##   $@ - (optional) Signal name(s) to restore. If omitted, restores all signals from snapshot.
##
## Returns:
##   Exit code 0 - Success (delegates to trap:pop)
##   Exit code 1 - Failure (no scope to end)
##
## Example:
##   function with_temp_handlers() {
##     trap:scope:begin EXIT INT
##     trap:on cleanup_temp EXIT
##     trap:on handle_int INT
##     # ... work ...
##     trap:scope:end EXIT INT           # Automatic cleanup
##   }
##
function trap:scope:end() {
  trap:pop "$@"
}

# -----------------------------------------------------------------------------
# Internal Dispatcher (Called by OS trap mechanism)
# -----------------------------------------------------------------------------

## Function: Trap::dispatch
## Description: Central dispatcher function invoked by the OS trap mechanism when a signal fires.
##   This function is set as the actual trap handler via: trap "Trap::dispatch SIGNAL" SIGNAL
##   It executes in two phases: 1) Legacy trap execution (if captured), 2) Registered handler
##   execution in order. Critically preserves the original exit code for EXIT signal handlers.
##   All handlers receive the original exit code as their first argument.
##
## Arguments:
##   $1 - Signal name (uppercase normalized: EXIT, INT, TERM, etc.)
##
## Returns:
##   Exit code - Original exit code captured at entry (preserved for script termination)
##
## Side Effects:
##   - Executes legacy trap command (if exists) via eval
##   - Executes all registered handlers in array order
##   - Writes debug traces via printf:Trap
##   - Writes error messages via echo:Trap for failed handlers
##   - Does NOT exit script (returns exit code to allow script continuation/termination)
##
## Internal Architecture:
##   Execution Order (for signal SIGNAL):
##   1. Capture original exit code ($?) before ANY operations
##   2. Execute __TRAP_LEGACY_SIG_SIGNAL command (if exists)
##   3. Execute each handler in __TRAP_HANDLERS_SIG_SIGNAL array
##   4. Return original exit code
##
## Example:
##   # Internal usage (set by module during initialization):
##   trap "Trap::dispatch EXIT" EXIT
##
##   # When script exits with code 42:
##   # 1. OS calls: Trap::dispatch EXIT
##   # 2. Dispatcher captures: exit_code=42
##   # 3. Executes: legacy_trap (if any)
##   # 4. Executes: handler1 42, handler2 42, handler3 42
##   # 5. Returns: 42
##
function Trap::dispatch() {
  # CRITICAL: Capture exit code FIRST before ANY other commands
  # Even 'local x=...' can reset $? in some bash versions
  local exit_code=$?
  local signal="$1"
  local var_name="${__TRAP_PREFIX}${signal}"
  local legacy_var="${__TRAP_LEGACY_PREFIX}${signal}"

  # Debug trace
  printf:Trap "Dispatching trap for ${cl_cyan}%s${cl_reset} (exit_code=%s)\n" "$signal" "$exit_code"

  # 1. Execute Legacy Trap (if any) - before our handlers
  if [[ -n "${!legacy_var+x}" ]]; then
    local legacy_cmd="${!legacy_var}"
    if [[ -n "$legacy_cmd" ]]; then
      printf:Trap "  ${cl_grey}→ Executing legacy trap${cl_reset}\n"
      eval "$legacy_cmd" || echo:Trap "${cl_red}✗${cl_reset} Legacy trap failed (exit code: $?)"
    fi
  fi

  # 2. Execute Registered Handlers in order
  # Handlers receive exit_code as first argument (for EXIT signal compatibility)
  if [[ -n "${!var_name+x}" ]]; then
    local -n handlers="$var_name"

    for handler in "${handlers[@]}"; do
      if declare -F "$handler" >/dev/null 2>&1; then
        printf:Trap "  ${cl_grey}→ Executing: ${cl_yellow}%s${cl_reset}\n" "$handler"
        "$handler" "$exit_code" || echo:Trap "${cl_red}✗${cl_reset} Handler failed: $handler (exit code: $?)"
      else
        echo:Trap "${cl_red}✗${cl_reset} Handler not found during execution: $handler"
      fi
    done
  fi

  # Return the original exit code so script exits with correct status
  return $exit_code
}

# -----------------------------------------------------------------------------
# Internal Helper Functions
# -----------------------------------------------------------------------------

## Function: _Trap::normalize_signal
## Description: Internal helper that normalizes signal names to a standard uppercase format
##   without the SIG prefix. Handles multiple input formats: full names (SIGINT), short names
##   (INT, int), numeric signals (2), and special cases (0→EXIT). Uses kill -l for numeric
##   signal conversion. Ensures consistent signal naming throughout the module.
##
## Arguments:
##   $1 - Signal name in any format (SIGINT, INT, int, 2, 0, etc.)
##
## Returns:
##   Stdout: Normalized signal name (EXIT, INT, TERM, HUP, etc.)
##   Exit code 0 - Success (always succeeds, falls back to input if normalization fails)
##
## Side Effects:
##   None (pure function, no global state modification)
##
## Normalization Rules:
##   - 0 → EXIT (special case)
##   - Numeric (2, 15, etc.) → Name via kill -l (2→INT, 15→TERM)
##   - SIGINT, sigint, SIGint → INT (remove SIG prefix, uppercase)
##   - INT, int, Int → INT (uppercase)
##   - Fallback: Return input unchanged if kill -l fails
##
## Example:
##   _Trap::normalize_signal "SIGINT"    # Output: INT
##   _Trap::normalize_signal "int"       # Output: INT
##   _Trap::normalize_signal "2"         # Output: INT
##   _Trap::normalize_signal "0"         # Output: EXIT
##   _Trap::normalize_signal "15"        # Output: TERM
##
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

## Function: _Trap::initialize_signal
## Description: Internal helper that performs one-time initialization for a signal. Called
##   automatically when a signal is first registered via trap:on. Captures any existing trap
##   command (legacy trap), sets Trap::dispatch as the OS trap handler, and creates the
##   handler array. Marks signal as initialized to prevent duplicate initialization.
##
## Arguments:
##   $1 - Normalized signal name (EXIT, INT, TERM, etc.)
##
## Returns:
##   Exit code 0 - Success (always)
##
## Side Effects:
##   - Sets global flag: __TRAP_INITIALIZED_SIG_{SIGNAL}=1
##   - Captures legacy trap via: _Trap::capture_legacy (sets __TRAP_LEGACY_SIG_{SIGNAL})
##   - Installs OS trap: trap "Trap::dispatch SIGNAL" SIGNAL
##   - Creates global array: __TRAP_HANDLERS_SIG_{SIGNAL}=()
##   - Writes status message via printf:Trap
##
## Initialization Sequence:
##   1. Mark signal as initialized
##   2. Capture existing trap (before we override it)
##   3. Install Trap::dispatch as the OS trap handler
##   4. Create empty handler array
##
## Example:
##   # Internal usage (called by trap:on on first registration):
##   _Trap::initialize_signal "EXIT"
##   # Result:
##   # - __TRAP_INITIALIZED_SIG_EXIT=1
##   # - __TRAP_LEGACY_SIG_EXIT="previous trap command" (if any)
##   # - trap "Trap::dispatch EXIT" EXIT
##   # - __TRAP_HANDLERS_SIG_EXIT=()
##
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

## Function: _Trap::capture_legacy
## Description: Internal helper that captures the existing trap command for a signal before
##   the module overrides it. Parses the output of 'trap -p SIGNAL' to extract the trap
##   command string. Only stores the legacy trap if it's not already our dispatcher (prevents
##   recursive capture if module reloaded). Preserves legacy traps for later restoration.
##
## Arguments:
##   $1 - Signal name (EXIT, INT, TERM, etc.)
##
## Returns:
##   Exit code 0 - Success (always, even if no legacy trap exists)
##
## Side Effects:
##   - Sets global variable: __TRAP_LEGACY_SIG_{SIGNAL}="command"
##   - Only sets if legacy trap exists AND is not Trap::dispatch
##   - Writes status message via printf:Trap if legacy trap captured
##
## Parsing Logic:
##   Input:  trap -p EXIT → "trap -- 'echo cleanup' EXIT"
##   Extract: 'echo cleanup' (command between quotes)
##   Skip: Commands containing "Trap::dispatch" (our own dispatcher)
##
## Example:
##   # Before module load: trap "rm -rf /tmp/foo" EXIT
##   _Trap::capture_legacy "EXIT"
##   # Result: __TRAP_LEGACY_SIG_EXIT="rm -rf /tmp/foo"
##
##   # If no trap: trap -p EXIT returns empty
##   _Trap::capture_legacy "INT"
##   # Result: __TRAP_LEGACY_SIG_INT remains unset
##
##   # If already initialized: trap -p EXIT → "trap -- 'Trap::dispatch EXIT' EXIT"
##   _Trap::capture_legacy "EXIT"
##   # Result: No capture (skips our own dispatcher)
##
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

## Function: _Trap::contains
## Description: Internal helper that checks if a specific handler function name exists in a
##   handler array (identified by variable name). Uses nameref to access the array without
##   eval. Performs exact string matching to detect duplicate registrations.
##
## Arguments:
##   $1 - Variable name of handler array (e.g., "__TRAP_HANDLERS_SIG_EXIT")
##   $2 - Handler function name to search for (e.g., "cleanup_temp")
##
## Returns:
##   Exit code 0 - Handler found in array (duplicate)
##   Exit code 1 - Handler not found in array (unique)
##
## Side Effects:
##   None (pure function, read-only array access via nameref)
##
## Example:
##   # Given: __TRAP_HANDLERS_SIG_EXIT=(cleanup_temp save_state)
##   _Trap::contains "__TRAP_HANDLERS_SIG_EXIT" "cleanup_temp"
##   echo $?  # Output: 0 (found)
##
##   _Trap::contains "__TRAP_HANDLERS_SIG_EXIT" "other_handler"
##   echo $?  # Output: 1 (not found)
##
function _Trap::contains() {
  local var_name="$1"
  local seeking="$2"
  local -n list="$var_name"

  for element in "${list[@]}"; do
    [[ "$element" == "$seeking" ]] && return 0
  done

  return 1
}

## Function: _Trap::remove_handler
## Description: Internal helper that removes a specific handler from a handler array. Creates
##   a new array containing all elements except the target handler, then replaces the original
##   array. Only removes the first occurrence if duplicates exist (allows gradual removal of
##   handlers registered with --allow-duplicates).
##
## Arguments:
##   $1 - Variable name of handler array (e.g., "__TRAP_HANDLERS_SIG_EXIT")
##   $2 - Handler function name to remove (e.g., "cleanup_temp")
##
## Returns:
##   Exit code 0 - Success (always, even if handler not found)
##
## Side Effects:
##   - Modifies the handler array via nameref (removes first matching element)
##   - Preserves order of remaining handlers
##   - If handler not in array, array remains unchanged
##
## Example:
##   # Given: __TRAP_HANDLERS_SIG_EXIT=(cleanup save_state finalize)
##   _Trap::remove_handler "__TRAP_HANDLERS_SIG_EXIT" "save_state"
##   # Result: __TRAP_HANDLERS_SIG_EXIT=(cleanup finalize)
##
##   # With duplicates: __TRAP_HANDLERS_SIG_EXIT=(log log cleanup)
##   _Trap::remove_handler "__TRAP_HANDLERS_SIG_EXIT" "log"
##   # Result: __TRAP_HANDLERS_SIG_EXIT=(log cleanup)  # Only first removed
##
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

## Function: _Trap::list_all_signals
## Description: Internal helper that discovers all signals currently managed by the traps module.
##   Uses bash's compgen to find all global variables matching the handler array prefix, then
##   extracts signal names. Used by trap:list (when no signals specified) and trap:push (when
##   snapshotting all signals). Returns space-separated list suitable for array assignment.
##
## Arguments:
##   None
##
## Returns:
##   Stdout: Space-separated list of signal names (e.g., "EXIT INT TERM")
##   Exit code 0 - Success (always, empty string if no signals initialized)
##
## Side Effects:
##   None (read-only, uses compgen to inspect global variables)
##
## Discovery Logic:
##   1. Use compgen -v to find variables matching "__TRAP_HANDLERS_SIG_*"
##   2. Strip prefix to extract signal name
##   3. Build array of signal names
##   4. Output space-separated list
##
## Example:
##   # Given initialized signals: EXIT, INT, TERM
##   signals=($(_Trap::list_all_signals))
##   echo "${signals[@]}"  # Output: EXIT INT TERM
##
##   # With no initialized signals:
##   signals=($(_Trap::list_all_signals))
##   echo "${#signals[@]}"  # Output: 0
##
##   # Usage in trap:list:
##   if [[ $# -eq 0 ]]; then
##     signals=($(_Trap::list_all_signals))
##   fi
##
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

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"
