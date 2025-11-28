#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


# Setup paths
# Note: Set DEBUG=trap to see detailed debug output
# export DEBUG="${DEBUG:-trap}"
export E_BASH="${E_BASH:-.scripts}"

# Load the traps module
source "$E_BASH/_traps.sh"

# Demo header
echo ""
echo "=========================================="
echo "  e-bash Traps Module Demonstration"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Demo 1: Basic Multiple Handlers
# -----------------------------------------------------------------------------

demo1_basic_handlers() {
  echo "━━━ Demo 1: Basic Multiple Handlers ━━━"
  echo ""

  # Define cleanup functions
  cleanup_step1() {
    echo "  [Cleanup] Step 1: Cleaning temporary files..."
  }

  cleanup_step2() {
    echo "  [Cleanup] Step 2: Saving state..."
  }

  cleanup_step3() {
    echo "  [Cleanup] Step 3: Finalizing..."
  }

  # Register multiple handlers for EXIT
  echo "Registering three cleanup handlers for EXIT signal:"
  trap:on cleanup_step1 EXIT
  trap:on cleanup_step2 EXIT
  trap:on cleanup_step3 EXIT

  echo ""
  echo "Current EXIT handlers:"
  trap:list EXIT

  echo ""
  echo "Note: All handlers will execute in registration order when script exits."
  echo ""
}

# -----------------------------------------------------------------------------
# Demo 2: Signal Normalization
# -----------------------------------------------------------------------------

demo2_signal_normalization() {
  echo "━━━ Demo 2: Signal Normalization ━━━"
  echo ""

  normalize_handler() {
    echo "  [Handler] Signal handler executed"
  }

  echo "Registering handlers with different signal formats:"
  echo "  - SIGINT (full name)"
  echo "  - term (lowercase)"
  echo "  - HUP (uppercase)"
  echo "  - 0 (number for EXIT)"
  echo ""

  trap:on normalize_handler SIGINT
  trap:on normalize_handler term
  trap:on normalize_handler HUP

  echo ""
  echo "All signals normalized to standard format:"
  trap:list INT TERM HUP

  # Clean up demo handlers
  trap:off normalize_handler INT TERM HUP

  echo ""
}

# -----------------------------------------------------------------------------
# Demo 3: Scoped Cleanup
# -----------------------------------------------------------------------------

demo3_scoped_cleanup() {
  echo "━━━ Demo 3: Scoped Cleanup (Push/Pop) ━━━"
  echo ""

  outer_cleanup() {
    echo "  [Cleanup] Outer scope cleanup"
  }

  inner_cleanup() {
    echo "  [Cleanup] Inner scope cleanup"
  }

  echo "Setting up outer scope handler:"
  trap:on outer_cleanup EXIT

  echo ""
  echo "Current handlers:"
  trap:list EXIT

  echo ""
  echo "Pushing state and adding inner scope handler:"
  trap:push EXIT
  trap:on inner_cleanup EXIT

  echo ""
  echo "Handlers with inner scope:"
  trap:list EXIT

  echo ""
  echo "Popping state (removing inner scope):"
  trap:pop EXIT

  echo ""
  echo "Back to outer scope handlers:"
  trap:list EXIT

  echo ""
}

# -----------------------------------------------------------------------------
# Demo 4: Scope Begin/End Pattern
# -----------------------------------------------------------------------------

demo4_scope_pattern() {
  echo "━━━ Demo 4: Scope Begin/End Pattern ━━━"
  echo ""

  global_handler() {
    echo "  [Cleanup] Global handler"
  }

  scoped_handler() {
    echo "  [Cleanup] Scoped handler"
  }

  echo "Setting up global handler:"
  trap:on global_handler EXIT

  echo ""
  echo "Starting scoped section:"
  trap:scope:begin EXIT
  trap:on scoped_handler EXIT

  echo ""
  echo "Handlers in scoped section:"
  trap:list EXIT

  echo ""
  echo "Ending scoped section:"
  trap:scope:end EXIT

  echo ""
  echo "After scope end (scoped_handler removed):"
  trap:list EXIT

  echo ""
}

# -----------------------------------------------------------------------------
# Demo 5: Multi-Signal Handler
# -----------------------------------------------------------------------------

demo5_multi_signal() {
  echo "━━━ Demo 5: Multi-Signal Handler ━━━"
  echo ""

  interrupt_handler() {
    echo "  [Handler] Interrupt received!"
    trap:list INT TERM HUP
    exit 1
  }

  echo "Registering handler for multiple signals:"
  echo "  INT, TERM, HUP"
  trap:on interrupt_handler INT TERM HUP

  echo ""
  echo "Handlers registered:"
  trap:list INT TERM HUP

  echo ""
  echo "Try: kill -INT $$ (or Ctrl+C) to trigger interrupt_handler"
  echo ""

  # Clean up demo handler
  trap:off interrupt_handler INT TERM HUP
}

# -----------------------------------------------------------------------------
# Demo 6: Handler Management
# -----------------------------------------------------------------------------

demo6_handler_management() {
  echo "━━━ Demo 6: Handler Management ━━━"
  echo ""

  handler_a() { echo "Handler A"; }
  handler_b() { echo "Handler B"; }
  handler_c() { echo "Handler C"; }

  echo "Registering three handlers:"
  trap:on handler_a EXIT
  trap:on handler_b EXIT
  trap:on handler_c EXIT

  echo ""
  trap:list EXIT

  echo ""
  echo "Removing handler_b:"
  trap:off handler_b EXIT

  echo ""
  trap:list EXIT

  echo ""
  echo "Clearing all handlers:"
  trap:clear EXIT

  echo ""
  trap:list EXIT

  echo ""
}

# -----------------------------------------------------------------------------
# Demo 7: Nested Scopes
# -----------------------------------------------------------------------------

demo7_nested_scopes() {
  echo "━━━ Demo 7: Nested Scopes ━━━"
  echo ""

  level1() { echo "  [Cleanup] Level 1"; }
  level2() { echo "  [Cleanup] Level 2"; }
  level3() { echo "  [Cleanup] Level 3"; }

  echo "Creating nested scopes:"
  echo ""

  echo "Level 1:"
  trap:on level1 EXIT
  trap:push EXIT

  echo "  Handlers: $(trap:list EXIT | grep EXIT | cut -d: -f2)"

  echo ""
  echo "Level 2:"
  trap:on level2 EXIT
  trap:push EXIT

  echo "  Handlers: $(trap:list EXIT | grep EXIT | cut -d: -f2)"

  echo ""
  echo "Level 3:"
  trap:on level3 EXIT

  echo "  Handlers: $(trap:list EXIT | grep EXIT | cut -d: -f2)"

  echo ""
  echo "Popping back to Level 2:"
  trap:pop EXIT
  echo "  Handlers: $(trap:list EXIT | grep EXIT | cut -d: -f2)"

  echo ""
  echo "Popping back to Level 1:"
  trap:pop EXIT
  echo "  Handlers: $(trap:list EXIT | grep EXIT | cut -d: -f2)"

  echo ""
  echo "Clearing all for next demo:"
  trap:clear EXIT

  echo ""
}

# -----------------------------------------------------------------------------
# Demo 8: Practical Example - File Processing
# -----------------------------------------------------------------------------

demo8_practical_example() {
  echo "━━━ Demo 8: Practical Example - File Processing ━━━"
  echo ""

  # Create temp directory
  TEMP_DIR=$(mktemp -d)
  echo "Created temporary directory: $TEMP_DIR"

  cleanup_temp_dir() {
    echo "  [Cleanup] Removing temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
  }

  cleanup_log() {
    echo "  [Cleanup] Finalizing log"
  }

  # Register cleanup handlers
  trap:on cleanup_temp_dir EXIT
  trap:on cleanup_log EXIT

  echo ""
  echo "Processing files (creating dummy files)..."

  # Simulate file processing
  for i in {1..5}; do
    touch "$TEMP_DIR/file_$i.txt"
    echo "  Created: file_$i.txt"
  done

  echo ""
  echo "Files in temp directory:"
  ls -la "$TEMP_DIR"

  echo ""
  echo "Cleanup handlers registered:"
  trap:list EXIT

  echo ""
  echo "Note: Cleanup will execute when script exits."
  echo ""
}

# -----------------------------------------------------------------------------
# Demo 9: Allow Duplicates
# -----------------------------------------------------------------------------

demo9_allow_duplicates() {
  echo "━━━ Demo 9: Allow Duplicates ━━━"
  echo ""

  counter=0
  count_handler() {
    counter=$((counter + 1))
    echo "  [Handler] Execution #$counter"
  }

  echo "Registering handler without --allow-duplicates:"
  trap:on count_handler EXIT
  trap:on count_handler EXIT

  echo ""
  trap:list EXIT

  echo ""
  echo "Clearing and registering with --allow-duplicates:"
  trap:clear EXIT

  trap:on count_handler EXIT
  trap:on --allow-duplicates count_handler EXIT
  trap:on --allow-duplicates count_handler EXIT

  echo ""
  trap:list EXIT

  echo ""
  echo "Note: Handler registered 3 times, will execute 3 times on EXIT"

  # Clean up for final demo
  trap:clear EXIT

  echo ""
}

# -----------------------------------------------------------------------------
# Demo 10: Stack Level Tracking
# -----------------------------------------------------------------------------

demo10_stack_tracking() {
  echo "━━━ Demo 10: Stack Level Tracking ━━━"
  echo ""

  dummy_handler() { echo "dummy"; }

  echo "Initial stack level: $__TRAP_STACK_LEVEL"

  echo ""
  echo "Pushing state (3 times):"
  trap:on dummy_handler EXIT

  trap:push EXIT
  echo "  After push #1: $__TRAP_STACK_LEVEL"

  trap:push EXIT
  echo "  After push #2: $__TRAP_STACK_LEVEL"

  trap:push EXIT
  echo "  After push #3: $__TRAP_STACK_LEVEL"

  echo ""
  echo "Popping state (3 times):"

  trap:pop EXIT
  echo "  After pop #1: $__TRAP_STACK_LEVEL"

  trap:pop EXIT
  echo "  After pop #2: $__TRAP_STACK_LEVEL"

  trap:pop EXIT
  echo "  After pop #3: $__TRAP_STACK_LEVEL"

  echo ""
  echo "Trying to pop empty stack (should fail):"
  trap:pop EXIT || echo "  ✓ Correctly prevented pop from empty stack"

  trap:clear EXIT

  echo ""
}

# -----------------------------------------------------------------------------
# Run all demos
# -----------------------------------------------------------------------------

main() {
  demo1_basic_handlers
  sleep 1

  demo2_signal_normalization
  sleep 1

  demo3_scoped_cleanup
  sleep 1

  demo4_scope_pattern
  sleep 1

  demo5_multi_signal
  sleep 1

  demo6_handler_management
  sleep 1

  demo7_nested_scopes
  sleep 1

  demo8_practical_example
  sleep 1

  demo9_allow_duplicates
  sleep 1

  demo10_stack_tracking

  echo "=========================================="
  echo "  Demonstration Complete!"
  echo "=========================================="
  echo ""
  echo "Final registered handlers (will execute on exit):"
  trap:list
  echo ""
  echo "Exiting... watch for cleanup execution below:"
  echo ""
}

# Run main demo
main

# Exit normally - cleanup handlers will execute
exit 0
