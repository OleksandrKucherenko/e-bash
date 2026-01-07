#!/usr/bin/env bash
# E2E Integration Test Helper for Trap Dispatcher (Minimal Version)
# Usage: ./trap_dispatcher_e2e_minimal.sh <test_mode>
# test_mode: "basic" or "failure"

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

# Validate arguments
TEST_MODE="${1:-basic}"
if [[ "$TEST_MODE" != "basic" && "$TEST_MODE" != "failure" ]]; then
  echo "ERROR:unknown_mode" >&2
  exit 1
fi

# Minimal trap implementation without logger dependencies
# Copy the core trap functionality to avoid logger dependency
__TRAP_PREFIX="__TRAP_HANDLERS_SIG_"
__TRAP_LEGACY_PREFIX="__TRAP_LEGACY_SIG_"
__TRAP_INIT_PREFIX="__TRAP_INITIALIZED_SIG_"

# Function to normalize signal names
_Trap::normalize_signal() {
  local input="$1"
  case "$input" in
    "0") echo "EXIT" ;;
    "SIGINT"|"INT") echo "INT" ;;
    "SIGTERM"|"TERM") echo "TERM" ;;
    *) echo "$input" | tr '[:lower:]' '[:upper:]' ;;
  esac
}

# Function to initialize signal
_Trap::initialize_signal() {
  local signal="$1"
  declare -g "${__TRAP_INIT_PREFIX}${signal}=1"
  declare -g -a "${__TRAP_PREFIX}${signal}"
  echo "DEBUG: Setting trap for $signal, PID: $$"
  # Use eval to properly set the trap command
  eval "trap 'Trap::dispatch $signal' $signal"
  echo "DEBUG: Trap set: $(trap -p "$signal")"
}

# Main dispatcher function
Trap::dispatch() {
  local signal="$1"
  echo "DEBUG: Dispatcher called for signal: $signal, PID: $$"
  local var_name="${__TRAP_PREFIX}${signal}"

  # Check if the variable is declared using declare -p
  if declare -p "$var_name" >/dev/null 2>&1; then
    echo "DEBUG: Found handlers array for $signal"
    local -n handlers="$var_name"
    echo "DEBUG: Handler count: ${#handlers[@]}"
    for handler in "${handlers[@]}"; do
      echo "DEBUG: Executing handler: $handler"
      if declare -F "$handler" >/dev/null 2>&1; then
        "$handler" || true  # Continue even if handler fails
      else
        echo "DEBUG: Handler $handler not found"
      fi
    done
  else
    echo "DEBUG: No handlers array found for $signal"
    echo "DEBUG: Available variables with prefix:"
    declare | grep "${__TRAP_PREFIX}" || echo "None found"
  fi
}

# Simplified trap:on function
trap:on() {
  local handler="${1}"
  shift
  local signals=("$@")

  for raw_signal in "${signals[@]}"; do
    local signal
    signal=$(_Trap::normalize_signal "$raw_signal")
    local var_name="${__TRAP_PREFIX}${signal}"

    # Check if the variable is declared
    if ! declare -p "$var_name" >/dev/null 2>&1; then
      _Trap::initialize_signal "$signal"
    fi

    local -n handlers="$var_name"
    handlers+=("$handler")
  done
}

# Test state variables
HANDLERS_EXECUTED=""

# Test handlers
handler_a() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}a,"
  echo "HANDLER_A_EXECUTED"
}

handler_b() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}b,"
  echo "HANDLER_B_EXECUTED"
}

handler_failing() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}failing,"
  echo "HANDLER_FAILING_EXECUTED"
  return 1  # Simulate failure
}

# Register handlers based on test mode
case "$TEST_MODE" in
  "basic")
    trap:on handler_a INT
    trap:on handler_b INT
    echo "READY:basic"
    ;;
  "failure")
    trap:on handler_a INT
    trap:on handler_failing INT
    trap:on handler_b INT
    echo "READY:failure"
    ;;
esac

# Keep process alive for signal delivery
while true; do
  sleep 0.1
done