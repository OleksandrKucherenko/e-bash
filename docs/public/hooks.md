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

**Method 2: Script-based (external files)**
```bash
# Create .hooks/begin.sh
cat > .hooks/begin.sh <<'EOF'
#!/usr/bin/env bash
echo "Initialization from external script"
EOF

chmod +x .hooks/begin.sh
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

**Priority Order**: When both function and script implementations exist, the function takes precedence.

1. **Function Implementation** (`hook:{name}`)
   ```bash
   hook:begin() {
     echo "Function-based hook"
   }
   ```

2. **Script Implementation** (`.hooks/{name}.sh`)
   ```bash
   # File: .hooks/begin.sh
   #!/usr/bin/env bash
   echo "Script-based hook"
   ```

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
10. **Make external hook scripts executable**: `chmod +x .hooks/*.sh`

## Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOOKS_DIR` | `.hooks` | Directory containing hook scripts |
| `HOOKS_PREFIX` | `hook:` | Prefix for hook function names |

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

**Parameters:**
- `$1` - Hook name
- `$@` - Additional parameters passed to the hook

**Returns:**
- Hook's exit code or `0` if not implemented
- Hook's stdout is passed through

**Example:**
```bash
on:hook begin
on:hook error "Something failed" 1
result=$(on:hook decide "Continue?")
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

### Example 4: Script-Based Hooks

**Main script:**
```bash
#!/usr/bin/env bash
source "$E_BASH/_hooks.sh"

hooks:define validate backup deploy verify

echo "Starting deployment..."
on:hook validate || { echo "Validation failed"; exit 1; }
on:hook backup || { echo "Backup failed"; exit 1; }
on:hook deploy || { echo "Deployment failed"; exit 1; }
on:hook verify || { echo "Verification failed"; exit 1; }
echo "Deployment complete!"
```

**.hooks/validate.sh:**
```bash
#!/usr/bin/env bash
echo "Validating environment..."
[[ -f config.yml ]] || { echo "Missing config.yml"; exit 1; }
[[ -d /var/www/app ]] || { echo "Missing app directory"; exit 1; }
echo "Validation passed"
```

**.hooks/backup.sh:**
```bash
#!/usr/bin/env bash
backup_dir="/backups/$(date +%Y%m%d_%H%M%S)"
echo "Creating backup: $backup_dir"
mkdir -p "$backup_dir"
cp -r /var/www/app "$backup_dir/"
echo "Backup complete"
```

**.hooks/deploy.sh:**
```bash
#!/usr/bin/env bash
echo "Deploying application..."
rsync -av --delete ./dist/ /var/www/app/
systemctl restart app-service
echo "Deployment complete"
```

**.hooks/verify.sh:**
```bash
#!/usr/bin/env bash
echo "Verifying deployment..."
sleep 2
if curl -sf http://localhost/health > /dev/null; then
  echo "Health check passed"
  exit 0
else
  echo "Health check failed"
  exit 1
fi
```

---

For more information on e-bash modules, see:
- [Logger Documentation](./logger.md)
- [Arguments Documentation](./arguments.md)
- [Traps Documentation](./traps.md)
