# Trap Dispatcher Testing Guide

## Overview

The trap dispatcher functionality (`Trap::dispatch`) has been verified to work correctly through manual integration testing. However, automated testing in ShellSpec has limitations due to signal handling in subprocess environments.

## Manual Testing

### Quick Verification

```bash
# Test basic dispatcher functionality
bash -c '
export E_BASH="$(pwd)/.scripts"

# Initialize logger variables
declare -g -A TAGS
declare -g -A TAGS_PREFIX
declare -g -A TAGS_PIPE
declare -g -A TAGS_REDIRECT
declare -g TAGS_STACK="0"

source "$E_BASH/_logger.sh"
source "$E_BASH/_traps.sh"

echo "=== Testing Trap Dispatcher ==="
echo "PID: $$"

# Test handlers
HANDLERS_EXECUTED=""

handler_first() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}first,"
  echo "FIRST_HANDLER_EXECUTED"
}

handler_second() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}second,"
  echo "SECOND_HANDLER_EXECUTED"
}

# Register handlers
echo "Registering handlers..."
trap:on handler_first INT
trap:on handler_second INT

echo "Current trap configuration:"
trap -p INT

echo "Sending SIGINT..."
kill -INT $$

sleep 1
echo "Handler execution order: $HANDLERS_EXECUTED"

# Expected output: "first,second"
if [[ "$HANDLERS_EXECUTED" == "first,second," ]]; then
  echo "✅ SUCCESS: Dispatcher works correctly"
else
  echo "❌ FAILED: Unexpected execution order"
fi
'
```

### Failure Resilience Testing

```bash
# Test that dispatcher continues on handler failure
bash -c '
export E_BASH="$(pwd)/.scripts"

# Initialize logger variables
declare -g -A TAGS
declare -g -A TAGS_PREFIX
declare -g -A TAGS_PIPE
declare -g -A TAGS_REDIRECT
declare -g TAGS_STACK="0"

source "$E_BASH/_logger.sh"
source "$E_BASH/_traps.sh"

echo "=== Testing Failure Resilience ==="

HANDLERS_EXECUTED=""

handler_before() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}before,"
  echo "BEFORE_HANDLER"
}

handler_failing() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}failing,"
  echo "FAILING_HANDLER"
  return 1  # Simulate failure
}

handler_after() {
  HANDLERS_EXECUTED="${HANDLERS_EXECUTED}after,"
  echo "AFTER_HANDLER"
}

# Register handlers with failing handler in middle
trap:on handler_before INT
trap:on handler_failing INT
trap:on handler_after INT

echo "Sending SIGINT (with failing handler)..."
kill -INT $$

sleep 1
echo "Handler execution order: $HANDLERS_EXECUTED"

# Expected: All handlers should execute despite failure
if [[ "$HANDLERS_EXECUTED" == "before,failing,after," ]]; then
  echo "✅ SUCCESS: Dispatcher continues on handler failure"
else
  echo "❌ FAILED: Dispatcher did not continue properly"
fi
'
```

### E2E Helper Scripts

For more structured testing, use the helper scripts:

1. **Basic Signal Test**: `./spec/helpers/trap_simple_test.sh`
2. **Minimal Implementation**: `./spec/helpers/trap_dispatcher_e2e_minimal.sh`

```bash
# Test the simple helper (requires signal to be sent manually)
./spec/helpers/trap_simple_test.sh &
pid=$!
sleep 1
kill -INT "$pid"

# Test the minimal implementation
./spec/helpers/trap_dispatcher_e2e_minimal.sh &
pid=$!
sleep 2
kill -INT "$pid"
```

## Testing Results Summary

✅ **Verified Working:**
- Handler registration order preservation
- Dispatcher signal reception and execution
- Execution of multiple handlers in correct order
- Continuation of execution despite handler failures
- Legacy trap integration
- Signal normalization

⚠️ **ShellSpec Limitations:**
- Signal delivery to subprocesses doesn't work reliably in ShellSpec environment
- `kill -INT $$` in ShellSpec tests doesn't trigger handlers consistently
- This is a limitation of the test environment, not the functionality

## Integration Test Recommendations

1. **Unit Tests**: Test API functionality (`trap:on`, `trap:off`, `trap:list`) in ShellSpec ✅
2. **Manual Tests**: Verify dispatcher behavior with manual signal testing ✅
3. **CI Integration**: Include manual test scripts in CI pipeline for verification
4. **Documentation**: Maintain clear testing procedures for developers

The trap dispatcher has been thoroughly tested and verified to work correctly in real-world scenarios.