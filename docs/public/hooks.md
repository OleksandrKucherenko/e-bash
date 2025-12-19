# e-bash Hooks Documentation

<!-- TOC -->

- [e-bash Hooks Documentation](#e-bash-hooks-documentation)
  - [Quick Start Guide](#quick-start-guide)
    - [Basic Usage](#basic-usage)
    - [Implementing Hooks](#implementing-hooks)
  - [Overview](#overview)
  - [Features and Capabilities](#features-and-capabilities)
    - [Hook Definition](#hook-definition)
    - [Hook Execution](#hook-execution)
    - [Hook Implementation Methods](#hook-implementation-methods)
    - [Hook Introspection](#hook-introspection)
  - [Standard Hook Names](#standard-hook-names)
  - [Advanced Use Cases](#advanced-use-cases)
    - [Decision Hooks](#decision-hooks)
    - [Error Handling Hooks](#error-handling-hooks)
    - [Lifecycle Hooks](#lifecycle-hooks)
    - [Custom Hooks](#custom-hooks)
  - [Implementation Patterns](#implementation-patterns)
    - [Function-Based Hooks](#function-based-hooks)
    - [Script-Based Hooks](#script-based-hooks)
    - [Hybrid Approach](#hybrid-approach)
  - [Best Practices](#best-practices)
  - [Reference](#reference)
    - [Environment Variables](#environment-variables)
    - [Global Arrays](#global-arrays)
    - [Key Functions](#key-functions)
  - [Examples](#examples)
    - [Example 1: Basic Lifecycle Hooks](#example-1-basic-lifecycle-hooks)
    - [Example 2: Decision Hook](#example-2-decision-hook)
    - [Example 3: Error Recovery](#example-3-error-recovery)
    - [Example 4: Script-Based Hooks](#example-4-script-based-hooks)

<!-- /TOC -->

## Quick Start Guide

### Basic Usage

The e-bash hooks system provides a declarative way to add extension points to your bash scripts. Here's how to get started:

```bash
# Import the hooks module
source "$E_BASH/_hooks.sh"

# Declare available hooks in your script
hooks:declare begin end

# Later in your script, delegate control to hooks
hooks:do begin
echo "Main script logic here"
hooks:do end
```

### Implementing Hooks

You can implement hooks in two ways:

**Method 1: Function-based (in the same script)**
```bash
# Define the hook function
hook:begin() {
  echo "Initialization started"
}

# The hook will be automatically called when hooks:do begin is executed
```

**Method 2: Script-based (external files in ci-cd folder)**
```bash
# Create ci-cd/begin-init.sh
mkdir -p ci-cd
cat > ci-cd/begin-init.sh <<'EOF'
#!/usr/bin/env bash
echo "Initialization from external script"
EOF

chmod +x ci-cd/begin-init.sh

# You can have multiple scripts per hook (executed in alphabetical order)
cat > ci-cd/begin_01_setup.sh <<'EOF'
#!/usr/bin/env bash
echo "Step 1: Setup"
EOF

chmod +x ci-cd/begin_01_setup.sh
```

## Overview

Hooks are named points in your script where you delegate control to external implementations. They enable:

- **Extensibility**: Allow users to customize script behavior without modifying the main script
- **Separation of concerns**: Keep core logic separate from customizations
- **Testability**: Easily mock or replace hook implementations for testing
- **Modularity**: Break complex scripts into manageable, loosely-coupled components

The hooks system consists of two main components:

1. **Hook Definition** (`hooks:declare`): Declares which hooks are available in your script
2. **Hook Execution** (`hooks:do`): Executes a hook if it has an implementation

## Features and Capabilities

### Hook Definition

Define available hooks at the beginning of your script to make them discoverable:

```bash
# Define standard lifecycle hooks
hooks:declare begin end

# Define multiple hooks at once
hooks:declare begin end decide error rollback

# Define custom domain-specific hooks
hooks:declare validate_input sanitize_data notify_completion
```

Hook names must be alphanumeric with optional underscores and dashes.

### Hook Execution

Execute hooks at strategic points in your script:

```bash
# Simple hook execution
hooks:do begin

# Hook with parameters
hooks:do error "Database connection failed" 1

# Capture hook output
result=$(hooks:do decide "Continue processing?")

# Use hook output in conditionals
if [[ "$(hooks:do decide)" == "yes" ]]; then
  echo "Proceeding with operation"
fi
```

### Hook Implementation Methods

**Execution Order**: Function implementations execute first, then all matching scripts in alphabetical order.

1. **Function Implementation** (`hook:{name}`)
   ```bash
   hook:begin() {
     echo "Function-based hook"
   }
   ```

2. **Multiple Script Implementations** (`ci-cd/{hook_name}-*.sh` or `ci-cd/{hook_name}_*.sh`)

   **Naming Patterns:**
   - `{hook_name}-{purpose}.sh` - Simple descriptive naming
   - `{hook_name}_{NN}_{purpose}.sh` - Numbered for explicit ordering (recommended)

   ```bash
   # File: ci-cd/begin-setup.sh
   #!/usr/bin/env bash
   echo "Script 1: Setup"

   # File: ci-cd/begin_01_init.sh
   #!/usr/bin/env bash
   echo "Script 2: Init (executed before begin_02)"

   # File: ci-cd/begin_02_validate.sh
   #!/usr/bin/env bash
   echo "Script 3: Validate"
   ```

   **Key Points:**
   - All scripts matching the pattern are executed
   - Scripts execute in **alphabetical order**
   - Use numbered prefixes (`01`, `02`, `10`) for explicit ordering
   - Both dash (`-`) and underscore (`_`) separators are supported

### Hook Introspection

Query hook status and implementations:

```bash
# List all defined hooks
hooks:list

# Check if a hook is defined
if hooks:known begin; then
  echo "begin hook is available"
fi

# Check if a hook has an implementation
if hooks:runnable begin; then
  echo "begin hook is implemented"
else
  echo "begin hook needs implementation"
fi
```

## Standard Hook Names

While you can define custom hooks, these standard names are commonly used:

| Hook Name | Purpose | Typical Use Case |
|-----------|---------|------------------|
| `begin` | Script initialization | Setup, validation, resource allocation |
| `end` | Script completion | Cleanup, reporting, resource deallocation |
| `decide` | Decision points | Conditional logic, user confirmation |
| `error` | Error handling | Logging, recovery, notifications |
| `rollback` | Undo operations | Revert changes, restore state |

## Advanced Use Cases

### Decision Hooks

Use hooks to externalize decision-making logic:

```bash
hooks:declare decide

# In your script
if [[ "$(hooks:do decide "Process large file?")" == "yes" ]]; then
  process_large_file
else
  skip_processing
fi

# Implementation
hook:decide() {
  local question="$1"
  read -p "$question (yes/no): " answer
  echo "$answer"
}
```

### Error Handling Hooks

Delegate error handling to hooks:

```bash
hooks:declare error rollback

perform_operation() {
  if ! critical_task; then
    hooks:do error "Critical task failed" $?
    hooks:do rollback
    return 1
  fi
  return 0
}

# Implementation
hook:error() {
  local message="$1"
  local code="$2"
  echo "ERROR: $message (exit code: $code)" >&2
  # Send notification, log to file, etc.
}

hook:rollback() {
  echo "Rolling back changes..."
  # Undo operations
}
```

### Lifecycle Hooks

Structure complex scripts with lifecycle hooks:

```bash
hooks:declare pre_validate validate post_validate pre_process process post_process

main() {
  hooks:do pre_validate
  hooks:do validate || { echo "Validation failed"; return 1; }
  hooks:do post_validate

  hooks:do pre_process
  hooks:do process || { echo "Processing failed"; return 1; }
  hooks:do post_process
}
```

### Custom Hooks

Create domain-specific hooks for your application:

```bash
# For a deployment script
hooks:declare backup pre_deploy deploy post_deploy verify notify

# For a build script
hooks:declare clean prepare compile test package publish

# For a data pipeline
hooks:declare extract transform validate load index notify
```

### Nested Hooks (Composability)

The hooks system supports nested/composed scripts where multiple scripts can define the same hook names. This is essential when your script sources libraries or helper scripts that also use hooks.

**How It Works:**
- Each `hooks:declare` call tracks which script/context defined the hook
- The same hook name can be defined from multiple contexts
- When a hook is defined from multiple contexts, a warning is issued
- All implementations (functions + scripts) are executed regardless of context

**Example - Library Using Hooks:**

```bash
# library.sh - A reusable library
source "$E_BASH/_hooks.sh"
hooks:declare init cleanup

hook:init() {
  echo "Library initialized"
}

hook:cleanup() {
  echo "Library cleanup"
}
```

**Example - Main Script Using Same Hooks:**

```bash
# main.sh - Your main script
source "$E_BASH/_hooks.sh"
source ./library.sh  # Sources library that also defines init/cleanup

# Define same hooks in main script - will warn but both work
hooks:declare init cleanup

hook:init() {
  echo "Main script initialized"
}

hook:cleanup() {
  echo "Main script cleanup"
}

# Execute hooks - both library and main implementations run
hooks:do init     # Outputs: "Library initialized\nMain script initialized"
hooks:do cleanup  # Outputs: "Library cleanup\nMain script cleanup"
```

**Warning Output:**

When the same hook is defined from multiple contexts, you'll see:

```
⚠ Warning: Hook 'init' is being defined from multiple contexts:
    Existing: /path/to/library.sh
    New:      /path/to/main.sh
  This is supported for nested/composed scripts, but verify it's intentional.
```

**Best Practices:**
- Use unique hook names in libraries when possible to avoid conflicts
- Document when libraries define standard hooks (init, cleanup, etc.)
- Verify warnings are intentional when composing scripts
- Use `hooks:list` to see which hooks are defined from multiple contexts

**Checking for Multiple Contexts:**

```bash
# List hooks shows context warnings
hooks:list

# Output includes:
#   - init: implemented (function)
#       ⚠ defined in 2 contexts
```

## Execution Modes

The hooks system supports two execution modes for scripts, controlled by `HOOKS_EXEC_MODE`:

### Exec Mode (Default)

Scripts are executed directly as subprocesses. This provides isolation - scripts cannot modify the parent shell's environment.

```bash
export HOOKS_EXEC_MODE="exec"  # Default
source "$E_BASH/_hooks.sh"

# Scripts run in subprocesses
# Changes to variables don't affect parent shell
```

**Use exec mode when:**
- Scripts should be isolated
- Scripts shouldn't modify parent environment
- Standard subprocess behavior is desired
- Scripts are standalone tools

### Source Mode

Scripts are sourced into the current shell and must provide a `hook:run` function. This allows scripts to modify the parent shell environment.

```bash
export HOOKS_EXEC_MODE="source"
source "$E_BASH/_hooks.sh"

# Scripts are sourced and hook:run is called
# Can modify parent shell variables
```

**Hook script example for source mode:**
```bash
#!/usr/bin/env bash

# This function is called when script is sourced
function hook:run() {
  local param1="$1"
  local param2="$2"

  # Can access parent shell variables
  echo "Current directory: $PWD"

  # Can modify parent shell variables
  DEPLOYMENT_STATUS="completed"
  export BUILD_NUMBER="$param1"

  # Can change directory, set variables, etc.
  # These changes persist in the parent shell
}
```

**Use source mode when:**
- Hooks need to modify parent shell environment
- Setting environment variables for subsequent hooks
- Changing current directory
- Defining functions for later use
- Maintaining state across hook executions

**Note**: In source mode, if a script doesn't define `hook:run`, it will be skipped with a warning (visible with `DEBUG=hooks`).

## Implementation Patterns

### Function-Based Hooks

Best for simple, inline implementations:

```bash
source "$E_BASH/_hooks.sh"
hooks:declare begin end

hook:begin() {
  echo "Starting at $(date)"
  export START_TIME=$SECONDS
}

hook:end() {
  local duration=$((SECONDS - START_TIME))
  echo "Completed in ${duration}s"
}

hooks:do begin
# Main logic here
hooks:do end
```

### Script-Based Hooks

Best for complex, reusable implementations:

```bash
# Main script
source "$E_BASH/_hooks.sh"
hooks:declare validate process

hooks:do validate || exit 1
hooks:do process
```

```bash
# .hooks/validate.sh
#!/usr/bin/env bash
echo "Validating environment..."

if [[ ! -f config.json ]]; then
  echo "ERROR: config.json not found" >&2
  exit 1
fi

echo "Validation passed"
exit 0
```

```bash
# .hooks/process.sh
#!/usr/bin/env bash
config_file="$1"
echo "Processing with config: $config_file"
# Complex processing logic
```

### Hybrid Approach

Combine both methods for flexibility:

```bash
source "$E_BASH/_hooks.sh"
hooks:declare begin validate process end

# Quick inline implementations
hook:begin() { echo "Started"; }
hook:end() { echo "Finished"; }

# Complex external implementations
# .hooks/validate.sh - comprehensive validation
# .hooks/process.sh - heavy processing logic

hooks:do begin
hooks:do validate || exit 1
hooks:do process "$@"
hooks:do end
```

### Registered Functions

Register any Bash function as a hook implementation dynamically. This is perfect for adding observability, metrics, or forwarding to external scripts.

**Key Features:**
- Register multiple functions per hook
- Functions execute in alphabetical order by friendly name
- Functions can be registered and unregistered at runtime
- Useful for metrics, logging, and external script forwarding

**Basic Registration:**

```bash
source "$E_BASH/_hooks.sh"
hooks:declare deploy

# Define functions to register
track_metrics() {
  echo "📊 Tracking deployment metrics..."
  # Send metrics to monitoring system
}

notify_team() {
  echo "📢 Notifying team..."
  # Send notification
}

# Register functions with friendly names for sorting
hooks:register deploy "10-metrics" track_metrics
hooks:register deploy "20-notify" notify_team

# Execute hook - all registered functions run in alphabetical order
hooks:do deploy
# Output:
#   📊 Tracking deployment metrics...
#   📢 Notifying team...
```

**Forwarding to External Scripts:**

```bash
# Function that forwards to an external script
forward_to_datadog() {
  /usr/local/bin/datadog-deploy.sh "$@"
}

forward_to_slack() {
  /usr/local/bin/slack-notify.sh "deployment" "$@"
}

hooks:declare deploy
hooks:register deploy "50-datadog" forward_to_datadog
hooks:register deploy "60-slack" forward_to_slack

hooks:do deploy "production" "v1.2.3"
# Calls: datadog-deploy.sh production v1.2.3
# Calls: slack-notify.sh deployment production v1.2.3
```

**Dynamic Registration for Observability:**

```bash
# Add observability hooks dynamically
add_observability() {
  local hook_name="$1"

  # Create timing wrapper
  local timing_func="${hook_name}_timing"
  eval "${timing_func}() {
    local start=\$SECONDS
    echo \"⏱️  Starting ${hook_name}\"
    # Hook already executed by hooks:do
    local duration=\$((SECONDS - start))
    echo \"✓ ${hook_name} completed in \${duration}s\"
  }"

  # Register timing function
  hooks:register "$hook_name" "99-timing" "$timing_func"
}

hooks:declare build test deploy
add_observability build
add_observability test
add_observability deploy
```

**Unregistering Functions:**

```bash
# Register a function
hooks:register build "metrics" track_build_metrics

# Later, unregister it by friendly name
hooks:unregister build "metrics"
```

**Execution Order:**
1. `hook:{name}()` function (if exists)
2. Registered functions (alphabetical by friendly name)
3. External scripts (alphabetical by filename)

**Use Cases:**
1. **Metrics & Observability**: Track execution time, success rates, resource usage
2. **External Tool Integration**: Forward to Datadog, Slack, PagerDuty, etc.
3. **Conditional Logic**: Register different functions based on environment
4. **Testing**: Register mock functions to override production behavior
5. **Plugin Systems**: Allow plugins to register their hook handlers

**Checking Registrations:**

```bash
# List hooks shows registered function count
hooks:list
# Output:
#   - deploy: implemented (function, 3 registered, 2 script(s))
```

## Best Practices

1. **Always declare hooks upfront** using `hooks:declare` to make them discoverable
2. **Use descriptive hook names** that clearly indicate their purpose
3. **Document expected parameters** for each hook in your script comments
4. **Handle missing implementations gracefully** - hooks without implementations are silently skipped
5. **Return meaningful exit codes** from hook implementations
6. **Keep hook implementations focused** - each hook should do one thing well
7. **Use function hooks for simple logic**, script hooks for complex operations
8. **Test hook implementations independently** before integrating
9. **Consider hook execution order** when defining multiple hooks
10. **Make external hook scripts executable**: `chmod +x ci-cd/*.sh`

### CI/CD Hook Scripting Best Practices

11. **Use numbered prefixes for ordered execution**: `begin_01_init.sh`, `begin_02_validate.sh`
12. **Pad numbers with leading zeros**: `01`, `02`, ... `10`, `11` ensures proper alphabetical sorting
13. **Use descriptive names after the number**: `deploy_10_backup.sh`, `deploy_20_update.sh`
14. **Group related hooks**: Keep all `begin` hooks together, all `deploy` hooks together
15. **Make scripts idempotent**: Scripts should be safe to run multiple times
16. **Exit with meaningful codes**: `0` for success, non-zero for failure
17. **Log what each script does**: Help debugging by echoing script actions
18. **Keep scripts focused**: Each script should do one specific task
19. **Test scripts independently**: Ensure each script works standalone
20. **Use consistent naming**: Choose either dash or underscore and stick with it

### Logging and Debugging Best Practices

21. **Enable hook logging for debugging**: `export DEBUG=hooks` to see execution flow
22. **Use stderr for hook output**: Logging goes to stderr, leaving stdout for data
23. **Monitor exit codes**: Check logs for non-zero exit codes indicating failures
24. **Verify script discovery**: Logs show which scripts were found and executed
25. **Check execution order**: Logs display script execution sequence
26. **Use exec mode for isolation**: Default mode runs scripts in subprocess
27. **Use source mode for state sharing**: When hooks need to modify parent environment
28. **Implement hook:run for sourced mode**: Define this function in scripts for source execution

## Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOOKS_DIR` | `ci-cd` | Directory containing hook scripts |
| `HOOKS_PREFIX` | `hook:` | Prefix for hook function names |
| `HOOKS_EXEC_MODE` | `exec` | Execution mode: `exec` (subprocess) or `source` (current shell) |
| `DEBUG` | (unset) | Enable logging: `hooks` for hooks only, `*` for all modules |

**Configuration Examples:**
```bash
# Use custom directory
export HOOKS_DIR="my-hooks"

# Enable sourced execution mode
export HOOKS_EXEC_MODE="source"

# Enable hooks logging for debugging (respects existing DEBUG value)
export DEBUG=${DEBUG:-"hooks"}

# Or enable all logging
# export DEBUG=${DEBUG:-"*"}

# Then source the module
source "$E_BASH/_hooks.sh"
```

### Logging

The hooks system provides comprehensive logging for traceability and debugging.

**Enable Logging:**
```bash
# Respect existing DEBUG value, or set default
export DEBUG=${DEBUG:-"hooks"}  # Enable hooks logging only (respects user's DEBUG)
export DEBUG=${DEBUG:-"*"}      # Enable all module logging (respects user's DEBUG)
export DEBUG=${DEBUG:-"-"}      # Disable all logging (respects user's DEBUG)

# Or override unconditionally (use sparingly)
export DEBUG="hooks"  # Force hooks logging only
export DEBUG="*"      # Force all module logging
export DEBUG="-"      # Force disable all logging
```

**What Gets Logged (to stderr):**
- Hook registration during `hooks:declare`
- Hook execution start/completion
- Function hook execution
- Script discovery (count and names)
- Script execution order (1/N, 2/N, etc.)
- Execution mode (exec vs source)
- Exit codes for each implementation
- Warnings for missing implementations or functions

**Log Output Example:**
```
Defining hooks: deploy
  ✓ Registered hook: deploy
Executing hook: deploy
  Found 3 script(s) for hook 'deploy'
  → [script 1/3] deploy_01_backup.sh (exec mode)
    ↳ exit code: 0
  → [script 2/3] deploy_02_update.sh (exec mode)
    ↳ exit code: 0
  → [script 3/3] deploy_03_verify.sh (exec mode)
    ↳ exit code: 0
  ✓ Completed hook 'deploy' (3 implementation(s), final exit code: 0)
```

### Global Arrays

| Array | Description |
|-------|-------------|
| `HOOKS_DEFINED` | Associative array tracking defined hooks |

### Key Functions

#### `hooks:declare hook1 hook2 ...`

Declares available hooks in the script.

**Parameters:**
- `$@` - List of hook names to define

**Returns:**
- `0` - Success
- `1` - Invalid hook name

**Example:**
```bash
hooks:declare begin end decide error rollback
```

#### `hooks:do hook_name [params...]`

Executes a hook if it's defined and has an implementation.

**Execution Order:**
1. Function `hook:{name}` (if exists)
2. All scripts matching `ci-cd/{hook_name}-*.sh` (alphabetically)
3. All scripts matching `ci-cd/{hook_name}_*.sh` (alphabetically)

**Parameters:**
- `$1` - Hook name
- `$@` - Additional parameters passed to the hook (and all scripts)

**Returns:**
- Exit code of the last executed hook/script, or `0` if not implemented
- All hooks' stdout is passed through

**Example:**
```bash
hooks:do begin
hooks:do error "Something failed" 1
result=$(hooks:do decide "Continue?")
```

**Script Pattern Examples:**
```bash
# These scripts will execute in this order for: hooks:do deploy
ci-cd/deploy-backup.sh      # 1. Alphabetically first
ci-cd/deploy-update.sh      # 2. Alphabetically second
ci-cd/deploy_01_init.sh     # 3. Underscore pattern
ci-cd/deploy_02_verify.sh   # 4. Underscore pattern
```

#### `hooks:list`

Lists all defined hooks with their implementation status.

**Returns:**
- `0` - Success
- Prints list of hooks to stdout

**Example:**
```bash
hooks:list
# Output:
# Defined hooks:
#   - begin: implemented (function)
#   - end: not implemented
#   - decide: implemented (script)
```

#### `hooks:known hook_name`

Checks if a hook is defined.

**Parameters:**
- `$1` - Hook name

**Returns:**
- `0` - Hook is defined
- `1` - Hook is not defined

**Example:**
```bash
if hooks:known begin; then
  echo "begin hook is available"
fi
```

#### `hooks:runnable hook_name`

Checks if a hook has an implementation (function or script).

**Parameters:**
- `$1` - Hook name

**Returns:**
- `0` - Hook has implementation
- `1` - Hook has no implementation

**Example:**
```bash
if hooks:runnable begin; then
  hooks:do begin
else
  echo "Using default initialization"
fi
```

## Examples

### Example 1: Basic Lifecycle Hooks

```bash
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"

# Declare available hooks
hooks:declare begin end

# Implement hooks
hook:begin() {
  echo "Initializing application..."
  export APP_START_TIME=$(date +%s)
}

hook:end() {
  local end_time=$(date +%s)
  local duration=$((end_time - APP_START_TIME))
  echo "Application completed in ${duration}s"
}

# Main script
hooks:do begin

echo "Running main application logic..."
sleep 2

hooks:do end
```

### Example 2: Decision Hook

```bash
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"

hooks:declare decide

hook:decide() {
  local question="$1"
  local default="${2:-no}"

  read -p "$question [$default]: " answer
  answer=${answer:-$default}

  echo "$answer"
}

# Use the decision hook
if [[ "$(hooks:do decide "Delete old files?" "yes")" == "yes" ]]; then
  echo "Deleting old files..."
  find /tmp -name "*.tmp" -mtime +7 -delete
fi
```

### Example 3: Error Recovery

```bash
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"

hooks:declare error rollback

hook:error() {
  local message="$1"
  local code="${2:-1}"
  echo "[$(date)] ERROR: $message (code: $code)" | tee -a error.log >&2
}

hook:rollback() {
  echo "Rolling back transaction..."
  mysql -e "ROLLBACK;" 2>/dev/null
  rm -f /tmp/transaction_*
  echo "Rollback complete"
}

# Main logic with error handling
mysql -e "START TRANSACTION;"
trap 'hooks:do error "Unexpected error" $?; hooks:do rollback; exit 1' ERR

mysql -e "INSERT INTO users VALUES (...);" || {
  hooks:do error "Failed to insert user" $?
  hooks:do rollback
  exit 1
}

mysql -e "COMMIT;"
echo "Transaction successful"
```

### Example 4: CI/CD Pipeline with Multiple Hook Scripts

**Main deployment script:**
```bash
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"

hooks:declare pre_deploy deploy post_deploy verify

echo "Starting deployment pipeline..."
hooks:do pre_deploy || { echo "Pre-deployment failed"; exit 1; }
hooks:do deploy || { echo "Deployment failed"; exit 1; }
hooks:do post_deploy || { echo "Post-deployment failed"; exit 1; }
hooks:do verify || { echo "Verification failed"; exit 1; }
echo "Deployment complete!"
```

**ci-cd/pre_deploy_01_validate.sh:**
```bash
#!/usr/bin/env bash
echo "[01] Validating environment..."
[[ -f config.yml ]] || { echo "ERROR: Missing config.yml"; exit 1; }
[[ -d /var/www/app ]] || { echo "ERROR: Missing app directory"; exit 1; }
echo "✓ Validation passed"
```

**ci-cd/pre_deploy_02_backup.sh:**
```bash
#!/usr/bin/env bash
backup_dir="/backups/$(date +%Y%m%d_%H%M%S)"
echo "[02] Creating backup: $backup_dir"
mkdir -p "$backup_dir"
cp -r /var/www/app "$backup_dir/"
echo "✓ Backup complete"
```

**ci-cd/deploy_01_stop.sh:**
```bash
#!/usr/bin/env bash
echo "[Deploy 01] Stopping application service..."
systemctl stop app-service
echo "✓ Service stopped"
```

**ci-cd/deploy_02_update.sh:**
```bash
#!/usr/bin/env bash
echo "[Deploy 02] Deploying new version..."
rsync -av --delete ./dist/ /var/www/app/
echo "✓ Files updated"
```

**ci-cd/deploy_03_start.sh:**
```bash
#!/usr/bin/env bash
echo "[Deploy 03] Starting application service..."
systemctl start app-service
sleep 2
echo "✓ Service started"
```

**ci-cd/post_deploy-migrations.sh:**
```bash
#!/usr/bin/env bash
echo "[Post] Running database migrations..."
cd /var/www/app && ./manage.py migrate
echo "✓ Migrations complete"
```

**ci-cd/verify-health.sh:**
```bash
#!/usr/bin/env bash
echo "[Verify] Checking application health..."
sleep 2
if curl -sf http://localhost/health > /dev/null; then
  echo "✓ Health check passed"
  exit 0
else
  echo "✗ Health check failed"
  exit 1
fi
```

**Execution Flow:**
```
hooks:do pre_deploy
  → pre_deploy_01_validate.sh  (alphabetically first)
  → pre_deploy_02_backup.sh

hooks:do deploy
  → deploy_01_stop.sh
  → deploy_02_update.sh
  → deploy_03_start.sh

hooks:do post_deploy
  → post_deploy-migrations.sh

hooks:do verify
  → verify-health.sh
```

---

For more information on e-bash modules, see:
- [Logger Documentation](./logger.md)
- [Arguments Documentation](./arguments.md)
- [Traps Documentation](./traps.md)
