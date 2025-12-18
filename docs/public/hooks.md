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
hooks:define begin end

# Later in your script, delegate control to hooks
on:hook begin
echo "Main script logic here"
on:hook end
```

### Implementing Hooks

You can implement hooks in two ways:

**Method 1: Function-based (in the same script)**
```bash
# Define the hook function
hook:begin() {
  echo "Initialization started"
}

# The hook will be automatically called when on:hook begin is executed
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

1. **Hook Definition** (`hooks:define`): Declares which hooks are available in your script
2. **Hook Execution** (`on:hook`): Executes a hook if it has an implementation

## Features and Capabilities

### Hook Definition

Define available hooks at the beginning of your script to make them discoverable:

```bash
# Define standard lifecycle hooks
hooks:define begin end

# Define multiple hooks at once
hooks:define begin end decide error rollback

# Define custom domain-specific hooks
hooks:define validate_input sanitize_data notify_completion
```

Hook names must be alphanumeric with optional underscores and dashes.

### Hook Execution

Execute hooks at strategic points in your script:

```bash
# Simple hook execution
on:hook begin

# Hook with parameters
on:hook error "Database connection failed" 1

# Capture hook output
result=$(on:hook decide "Continue processing?")

# Use hook output in conditionals
if [[ "$(on:hook decide)" == "yes" ]]; then
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
if hooks:is_defined begin; then
  echo "begin hook is available"
fi

# Check if a hook has an implementation
if hooks:has_implementation begin; then
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
hooks:define decide

# In your script
if [[ "$(on:hook decide "Process large file?")" == "yes" ]]; then
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
hooks:define error rollback

perform_operation() {
  if ! critical_task; then
    on:hook error "Critical task failed" $?
    on:hook rollback
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
hooks:define pre_validate validate post_validate pre_process process post_process

main() {
  on:hook pre_validate
  on:hook validate || { echo "Validation failed"; return 1; }
  on:hook post_validate

  on:hook pre_process
  on:hook process || { echo "Processing failed"; return 1; }
  on:hook post_process
}
```

### Custom Hooks

Create domain-specific hooks for your application:

```bash
# For a deployment script
hooks:define backup pre_deploy deploy post_deploy verify notify

# For a build script
hooks:define clean prepare compile test package publish

# For a data pipeline
hooks:define extract transform validate load index notify
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
hooks:define begin end

hook:begin() {
  echo "Starting at $(date)"
  export START_TIME=$SECONDS
}

hook:end() {
  local duration=$((SECONDS - START_TIME))
  echo "Completed in ${duration}s"
}

on:hook begin
# Main logic here
on:hook end
```

### Script-Based Hooks

Best for complex, reusable implementations:

```bash
# Main script
source "$E_BASH/_hooks.sh"
hooks:define validate process

on:hook validate || exit 1
on:hook process
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
hooks:define begin validate process end

# Quick inline implementations
hook:begin() { echo "Started"; }
hook:end() { echo "Finished"; }

# Complex external implementations
# .hooks/validate.sh - comprehensive validation
# .hooks/process.sh - heavy processing logic

on:hook begin
on:hook validate || exit 1
on:hook process "$@"
on:hook end
```

## Best Practices

1. **Always declare hooks upfront** using `hooks:define` to make them discoverable
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
- Hook registration during `hooks:define`
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

#### `hooks:define hook1 hook2 ...`

Declares available hooks in the script.

**Parameters:**
- `$@` - List of hook names to define

**Returns:**
- `0` - Success
- `1` - Invalid hook name

**Example:**
```bash
hooks:define begin end decide error rollback
```

#### `on:hook hook_name [params...]`

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
on:hook begin
on:hook error "Something failed" 1
result=$(on:hook decide "Continue?")
```

**Script Pattern Examples:**
```bash
# These scripts will execute in this order for: on:hook deploy
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

#### `hooks:is_defined hook_name`

Checks if a hook is defined.

**Parameters:**
- `$1` - Hook name

**Returns:**
- `0` - Hook is defined
- `1` - Hook is not defined

**Example:**
```bash
if hooks:is_defined begin; then
  echo "begin hook is available"
fi
```

#### `hooks:has_implementation hook_name`

Checks if a hook has an implementation (function or script).

**Parameters:**
- `$1` - Hook name

**Returns:**
- `0` - Hook has implementation
- `1` - Hook has no implementation

**Example:**
```bash
if hooks:has_implementation begin; then
  on:hook begin
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
hooks:define begin end

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
on:hook begin

echo "Running main application logic..."
sleep 2

on:hook end
```

### Example 2: Decision Hook

```bash
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"

hooks:define decide

hook:decide() {
  local question="$1"
  local default="${2:-no}"

  read -p "$question [$default]: " answer
  answer=${answer:-$default}

  echo "$answer"
}

# Use the decision hook
if [[ "$(on:hook decide "Delete old files?" "yes")" == "yes" ]]; then
  echo "Deleting old files..."
  find /tmp -name "*.tmp" -mtime +7 -delete
fi
```

### Example 3: Error Recovery

```bash
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"

hooks:define error rollback

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
trap 'on:hook error "Unexpected error" $?; on:hook rollback; exit 1' ERR

mysql -e "INSERT INTO users VALUES (...);" || {
  on:hook error "Failed to insert user" $?
  on:hook rollback
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

hooks:define pre_deploy deploy post_deploy verify

echo "Starting deployment pipeline..."
on:hook pre_deploy || { echo "Pre-deployment failed"; exit 1; }
on:hook deploy || { echo "Deployment failed"; exit 1; }
on:hook post_deploy || { echo "Post-deployment failed"; exit 1; }
on:hook verify || { echo "Verification failed"; exit 1; }
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
on:hook pre_deploy
  → pre_deploy_01_validate.sh  (alphabetically first)
  → pre_deploy_02_backup.sh

on:hook deploy
  → deploy_01_stop.sh
  → deploy_02_update.sh
  → deploy_03_start.sh

on:hook post_deploy
  → post_deploy-migrations.sh

on:hook verify
  → verify-health.sh
```

---

For more information on e-bash modules, see:
- [Logger Documentation](./logger.md)
- [Arguments Documentation](./arguments.md)
- [Traps Documentation](./traps.md)
