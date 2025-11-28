# e-bash Traps Documentation

<!-- TOC -->
- [e-bash Traps Documentation](#e-bash-traps-documentation)
  - [Quick Start Guide](#quick-start-guide)
    - [Basic Usage](#basic-usage)
    - [Multiple Handlers](#multiple-handlers)
    - [Scoped Cleanup](#scoped-cleanup)
  - [Features and Capabilities](#features-and-capabilities)
    - [Multiple Handlers Per Signal](#multiple-handlers-per-signal)
    - [Legacy Trap Preservation](#legacy-trap-preservation)
    - [Signal Normalization](#signal-normalization)
    - [Stack-Based Scoping](#stack-based-scoping)
    - [Handler Lifecycle Management](#handler-lifecycle-management)
  - [Advanced Use Cases](#advanced-use-cases)
    - [Cleanup Chains](#cleanup-chains)
    - [Nested Script Loading](#nested-script-loading)
    - [Library Pattern with Guards](#library-pattern-with-guards)
    - [Multi-Signal Handlers](#multi-signal-handlers)
    - [Scoped Resource Management](#scoped-resource-management)
  - [API Reference](#api-reference)
    - [trap:on](#trapon)
    - [trap:off](#trapoff)
    - [trap:list](#traplist)
    - [trap:clear](#trapclear)
    - [trap:restore](#traprestore)
    - [trap:push](#trappush)
    - [trap:pop](#trappop)
    - [trap:scope:begin](#trapscopebegin)
    - [trap:scope:end](#trapscopeend)
  - [Environment Variables](#environment-variables)
  - [Best Practices](#best-practices)
  - [Common Patterns](#common-patterns)
    - [Pattern 1: Simple Cleanup](#pattern-1-simple-cleanup)
    - [Pattern 2: Cleanup Chain](#pattern-2-cleanup-chain)
    - [Pattern 3: Scoped Resource](#pattern-3-scoped-resource)
    - [Pattern 4: Library Initialization](#pattern-4-library-initialization)
    - [Pattern 5: Temporary Override](#pattern-5-temporary-override)
  - [Debugging](#debugging)
  - [Limitations and Known Issues](#limitations-and-known-issues)
  - [Examples](#examples)
    - [Example 1: Basic File Cleanup](#example-1-basic-file-cleanup)
    - [Example 2: Database Connection Cleanup](#example-2-database-connection-cleanup)
    - [Example 3: Nested Script with Scoped Cleanup](#example-3-nested-script-with-scoped-cleanup)
    - [Example 4: Complex Application](#example-4-complex-application)
<!-- /TOC -->

## Quick Start Guide

### Basic Usage

The e-bash traps module extends Bash's built-in `trap` command to support multiple handlers per signal, while preserving existing trap configurations.

```bash
# Import the traps module
source "$E_BASH/_traps.sh"

# Define cleanup function
cleanup_temp() {
  rm -rf /tmp/myapp.*
  echo "Temporary files cleaned"
}

# Register handler for EXIT signal
trap:on cleanup_temp EXIT

# Your application logic here...
# cleanup_temp will execute automatically on exit
```

### Multiple Handlers

Unlike native `trap`, you can register multiple handlers for the same signal:

```bash
cleanup_temp() {
  rm -rf /tmp/myapp.*
}

save_state() {
  echo "Saving application state..."
  # Save logic
}

# Register multiple handlers for EXIT
trap:on cleanup_temp EXIT
trap:on save_state EXIT

# Both will execute in registration order
```

### Scoped Cleanup

Use scoping to automatically clean up handlers when leaving a section:

```bash
# Global cleanup
trap:on global_cleanup EXIT

# Start scoped section
trap:scope:begin EXIT

  # Add temporary handler
  trap:on temporary_cleanup EXIT

  # Do work that needs temporary_cleanup

# End scope - temporary_cleanup automatically removed
trap:scope:end EXIT

# Only global_cleanup remains
```

## Features and Capabilities

### Multiple Handlers Per Signal

Register as many handlers as needed for any signal:

```bash
trap:on handler1 EXIT
trap:on handler2 EXIT
trap:on handler3 EXIT

# All three execute on EXIT in registration order
```

### Legacy Trap Preservation

Existing trap configurations are automatically captured and executed:

```bash
# Existing trap
trap 'echo "Legacy cleanup"' EXIT

# Load module and add new handler
source "$E_BASH/_traps.sh"
trap:on new_cleanup EXIT

# On EXIT: both "Legacy cleanup" and new_cleanup execute
```

### Signal Normalization

All signal formats are normalized automatically:

```bash
trap:on handler SIGINT  # → INT
trap:on handler sigterm # → TERM
trap:on handler 0       # → EXIT
trap:on handler 2       # → INT (using kill -l)
trap:on handler int     # → INT
```

### Stack-Based Scoping

Push and pop trap state for complex scenarios:

```bash
# Save current state
trap:push EXIT

  # Add temporary handlers
  trap:on temp_handler EXIT

  # Do work...

# Restore previous state
trap:pop EXIT

# temp_handler is gone, previous handlers restored
```

### Handler Lifecycle Management

Full control over handler lifecycle:

```bash
# Register
trap:on my_handler EXIT

# List handlers
trap:list EXIT

# Remove specific handler
trap:off my_handler EXIT

# Clear all handlers (keeps legacy)
trap:clear EXIT

# Restore original trap
trap:restore EXIT
```

## Advanced Use Cases

### Cleanup Chains

Build complex cleanup sequences:

```bash
cleanup_phase1() {
  echo "Phase 1: Stopping services..."
  systemctl stop myapp
}

cleanup_phase2() {
  echo "Phase 2: Saving data..."
  save_data_to_disk
}

cleanup_phase3() {
  echo "Phase 3: Removing temp files..."
  rm -rf /tmp/myapp.*
}

# Register in execution order
trap:on cleanup_phase1 EXIT
trap:on cleanup_phase2 EXIT
trap:on cleanup_phase3 EXIT
```

### Nested Script Loading

When scripts source other scripts that use `trap:on`, handlers accumulate:

```bash
# main.sh
source "$E_BASH/_traps.sh"
trap:on main_cleanup EXIT

# Source library (also uses traps)
source lib_database.sh  # Registers db_cleanup
source lib_cache.sh     # Registers cache_cleanup

# On EXIT: main_cleanup, db_cleanup, cache_cleanup all execute
```

**Prevent duplicates with guards:**

```bash
# lib_database.sh
if [[ -z "${LIB_DB_LOADED}" ]]; then
  export LIB_DB_LOADED="yes"
  source "$E_BASH/_traps.sh"
  trap:on db_cleanup EXIT
fi
```

### Library Pattern with Guards

For reusable libraries that may be sourced multiple times:

```bash
# lib_feature.sh

# Initialization guard
if [[ -z "${LIB_FEATURE_INITIALIZED}" ]]; then
  export LIB_FEATURE_INITIALIZED="yes"

  # Load dependencies
  source "$E_BASH/_traps.sh"

  # Define cleanup
  feature_cleanup() {
    echo "Cleaning up feature resources"
  }

  # Register only once
  trap:on feature_cleanup EXIT
fi

# Feature functions...
```

### Multi-Signal Handlers

Register handlers for multiple signals at once:

```bash
handle_interrupt() {
  echo "Interrupted! Cleaning up..."
  cleanup_all
  exit 1
}

# Handle all interrupt signals
trap:on handle_interrupt INT TERM HUP QUIT
```

### Scoped Resource Management

Automatically manage resources within scopes:

```bash
process_file() {
  local file="$1"

  # Start scoped section
  trap:scope:begin EXIT

  # Mount temporary filesystem
  mount_tmpfs /mnt/temp
  trap:on cleanup_tmpfs EXIT

  # Process file...

  # Automatic cleanup on function exit
  trap:scope:end EXIT
}

cleanup_tmpfs() {
  umount /mnt/temp
}
```

## API Reference

### trap:on

Register handler for signal(s).

**Syntax:**
```bash
trap:on [--allow-duplicates] <handler_function> <signal> [signal2] ...
```

**Parameters:**
- `--allow-duplicates` - Optional flag to allow duplicate handler registration
- `handler_function` - Function to execute (must exist)
- `signal` - One or more signals (EXIT, INT, TERM, etc.)

**Returns:**
- `0` - Success
- `1` - Invalid arguments or handler doesn't exist

**Examples:**
```bash
trap:on cleanup EXIT
trap:on handle_int INT TERM
trap:on --allow-duplicates repeating_task EXIT
```

### trap:off

Unregister handler from signal(s).

**Syntax:**
```bash
trap:off <handler_function> <signal> [signal2] ...
```

**Parameters:**
- `handler_function` - Function to remove
- `signal` - One or more signals

**Returns:**
- `0` - Success
- `1` - No signals specified

**Examples:**
```bash
trap:off cleanup EXIT
trap:off handle_int INT TERM
```

### trap:list

List registered handlers for signal(s).

**Syntax:**
```bash
trap:list [signal] ...
```

**Parameters:**
- `signal` - Optional signal(s) to list (defaults to all)

**Returns:**
- `0` - Always succeeds

**Examples:**
```bash
trap:list           # List all signals
trap:list EXIT      # List EXIT handlers only
trap:list INT TERM  # List multiple signals
```

**Output Format:**
```
EXIT: handler1 handler2 handler3
  [legacy: echo "old trap"]
INT: interrupt_handler
```

### trap:clear

Clear all handlers for signal(s), keeping legacy trap.

**Syntax:**
```bash
trap:clear <signal> [signal2] ...
```

**Parameters:**
- `signal` - One or more signals to clear

**Returns:**
- `0` - Success
- `1` - No signals specified

**Examples:**
```bash
trap:clear EXIT
trap:clear INT TERM HUP
```

### trap:restore

Restore original trap configuration (before module loaded).

**Syntax:**
```bash
trap:restore <signal> [signal2] ...
```

**Parameters:**
- `signal` - One or more signals to restore

**Returns:**
- `0` - Success
- `1` - No signals specified

**Examples:**
```bash
trap:restore EXIT
```

### trap:push

Save current handler state (create snapshot).

**Syntax:**
```bash
trap:push [signal] ...
```

**Parameters:**
- `signal` - Optional signal(s) to save (defaults to all active)

**Returns:**
- `0` - Success

**Examples:**
```bash
trap:push           # Push all active signals
trap:push EXIT      # Push EXIT only
trap:push INT TERM  # Push multiple signals
```

### trap:pop

Restore previous handler state from stack.

**Syntax:**
```bash
trap:pop [signal] ...
```

**Parameters:**
- `signal` - Optional signal(s) to restore (defaults to all in last push)

**Returns:**
- `0` - Success
- `1` - Stack empty or corruption detected

**Examples:**
```bash
trap:pop           # Pop all signals from last push
trap:pop EXIT      # Pop EXIT only
trap:pop INT TERM  # Pop multiple signals
```

### trap:scope:begin

Begin scoped trap section (alias for `trap:push`).

**Syntax:**
```bash
trap:scope:begin [signal] ...
```

### trap:scope:end

End scoped trap section (alias for `trap:pop`).

**Syntax:**
```bash
trap:scope:end [signal] ...
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEBUG` | Enable debug output (use `trap` tag) | - |
| `E_BASH` | Path to .scripts directory | Auto-detected |

**Enable debug output:**
```bash
DEBUG=trap ./your-script.sh
DEBUG=*,-common ./your-script.sh  # All except common
```

## Best Practices

1. **Always check function exists before registering:**
   ```bash
   cleanup() { rm -rf /tmp/myapp.*; }
   trap:on cleanup EXIT  # ✓ Function defined first
   ```

2. **Use scoping for temporary handlers:**
   ```bash
   trap:scope:begin EXIT
   trap:on temp_handler EXIT
   # ... temporary work ...
   trap:scope:end EXIT
   ```

3. **Guard against re-registration in libraries:**
   ```bash
   if [[ -z "${LIB_LOADED}" ]]; then
     trap:on lib_cleanup EXIT
     export LIB_LOADED="yes"
   fi
   ```

4. **Register handlers early in script:**
   ```bash
   #!/usr/bin/env bash
   source "$E_BASH/_traps.sh"
   trap:on cleanup EXIT  # Register before any work
   # ... rest of script ...
   ```

5. **Use meaningful handler names:**
   ```bash
   cleanup_temp_files()    # ✓ Clear purpose
   cleanup()               # ✗ Too generic
   ```

6. **Handle errors gracefully:**
   ```bash
   cleanup() {
     rm -rf /tmp/myapp.* 2>/dev/null || true
     # Continue cleanup even if removal fails
   }
   ```

## Common Patterns

### Pattern 1: Simple Cleanup

```bash
#!/usr/bin/env bash
source "$E_BASH/_traps.sh"

TEMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TEMP_DIR"
}

trap:on cleanup EXIT

# Use TEMP_DIR...
```

### Pattern 2: Cleanup Chain

```bash
cleanup_temp() { rm -rf /tmp/myapp.*; }
cleanup_db() { pg_ctl stop; }
cleanup_logs() { gzip /var/log/myapp.log; }

trap:on cleanup_temp EXIT
trap:on cleanup_db EXIT
trap:on cleanup_logs EXIT
```

### Pattern 3: Scoped Resource

```bash
with_lock() {
  trap:scope:begin EXIT

  flock -x 200
  trap:on unlock_file EXIT

  # Critical section

  trap:scope:end EXIT
} 200>/var/lock/myapp.lock

unlock_file() {
  flock -u 200
}
```

### Pattern 4: Library Initialization

```bash
# lib.sh
if [[ -z "${LIB_INITIALIZED}" ]]; then
  export LIB_INITIALIZED="yes"
  source "$E_BASH/_traps.sh"

  lib_cleanup() {
    echo "Cleaning up library resources"
  }

  trap:on lib_cleanup EXIT
fi
```

### Pattern 5: Temporary Override

```bash
# Save current handlers
trap:push EXIT

# Override for special case
trap:clear EXIT
trap:on special_cleanup EXIT

# Do special work...

# Restore original handlers
trap:pop EXIT
```

## Debugging

Enable debug output to see trap operations:

```bash
DEBUG=trap ./your-script.sh
```

**Output:**
```
✓ Traps module loaded
✓ Handler registered: cleanup_temp for EXIT
✓ Handler registered: save_state for EXIT
📚 Trap state pushed (level: 1)
✓ Handler registered: temp_handler for EXIT
📚 Trap state popped (level: 0)
Dispatching trap for EXIT
  → Executing: cleanup_temp
  → Executing: save_state
```

## Limitations and Known Issues

1. **Bash 5.0+ Required**: Module uses nameref which requires Bash 5.0+
   ```bash
   dependency bash "5.*.*" "brew install bash"
   ```

2. **Subshell Isolation**: Trap handlers registered in subshells don't affect parent
   ```bash
   trap:on parent_cleanup EXIT
   (
     trap:on child_cleanup EXIT  # Only affects subshell
   )
   # child_cleanup does NOT execute in parent
   ```

3. **Handler Persistence**: Handlers persist until explicitly removed or process exits
   ```bash
   # In sourced script
   trap:on my_handler EXIT
   # Handler remains active even after script returns
   ```

4. **No Auto-Cleanup**: Sourced scripts don't automatically clean up their handlers
   ```bash
   # Solution: Use scoping
   trap:scope:begin EXIT
   trap:on my_handler EXIT
   # ... work ...
   trap:scope:end EXIT  # Explicit cleanup
   ```

5. **Signal Numbers**: Signal number mapping depends on platform
   ```bash
   # Prefer names over numbers
   trap:on handler INT   # ✓ Portable
   trap:on handler 2     # ✗ Platform-specific
   ```

## Examples

### Example 1: Basic File Cleanup

```bash
#!/usr/bin/env bash
source "$E_BASH/_traps.sh"

# Create temp directory
TEMP_DIR=$(mktemp -d)
echo "Working in: $TEMP_DIR"

# Register cleanup
cleanup_temp() {
  echo "Cleaning up temporary directory..."
  rm -rf "$TEMP_DIR"
}
trap:on cleanup_temp EXIT

# Do work
echo "Processing files..."
touch "$TEMP_DIR"/file{1..10}.txt

# Simulate work
sleep 2

echo "Done! (cleanup will run automatically)"
```

### Example 2: Database Connection Cleanup

```bash
#!/usr/bin/env bash
source "$E_BASH/_traps.sh"

DB_PID=""

start_db() {
  pg_ctl start -D /data/postgres
  DB_PID=$(cat /data/postgres/postmaster.pid)
}

stop_db() {
  if [[ -n "$DB_PID" ]]; then
    echo "Stopping database (PID: $DB_PID)..."
    pg_ctl stop -D /data/postgres
  fi
}

# Register cleanup first
trap:on stop_db EXIT INT TERM

# Start database
start_db

# Do database work...
psql -c "SELECT * FROM users"

# stop_db executes automatically on exit or interrupt
```

### Example 3: Nested Script with Scoped Cleanup

```bash
#!/usr/bin/env bash
# main.sh
source "$E_BASH/_traps.sh"

main_cleanup() {
  echo "Main cleanup"
}

trap:on main_cleanup EXIT

# Source library with its own cleanup
source lib_processing.sh

process_data data.txt

# lib_processing.sh
source "$E_BASH/_traps.sh"

process_data() {
  local file="$1"

  # Scoped cleanup for this function
  trap:scope:begin EXIT

  local temp_file=$(mktemp)

  cleanup_temp_file() {
    rm -f "$temp_file"
  }

  trap:on cleanup_temp_file EXIT

  # Process file using temp_file...

  # Automatic cleanup when function returns
  trap:scope:end EXIT
}
```

### Example 4: Complex Application

```bash
#!/usr/bin/env bash
source "$E_BASH/_traps.sh"

# Global state
declare -a TEMP_FILES=()
declare -a CHILD_PIDS=()

# Cleanup functions in execution order
cleanup_children() {
  echo "Stopping child processes..."
  for pid in "${CHILD_PIDS[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
}

cleanup_temp_files() {
  echo "Removing temporary files..."
  for file in "${TEMP_FILES[@]}"; do
    rm -f "$file" 2>/dev/null || true
  done
}

save_state() {
  echo "Saving application state..."
  echo "${TEMP_FILES[@]}" > /var/run/myapp.state
}

# Register cleanup chain
trap:on cleanup_children EXIT INT TERM
trap:on cleanup_temp_files EXIT
trap:on save_state EXIT

# Application logic
start_worker() {
  worker_process &
  CHILD_PIDS+=($!)
}

create_temp() {
  local temp=$(mktemp)
  TEMP_FILES+=("$temp")
  echo "$temp"
}

# Start application
for i in {1..5}; do
  start_worker
done

temp_data=$(create_temp)
echo "Processing..." > "$temp_data"

# Wait for completion
wait

# All cleanup happens automatically in order:
# 1. cleanup_children
# 2. cleanup_temp_files
# 3. save_state
```

---

For more information, see:
- [Installation Guide](installation.md)
- [Logger Documentation](logger.md)
- [e-bash GitHub Repository](https://github.com/OleksandrKucherenko/e-bash)
