# Dry-Run Wrapper System (_dryrun.sh)

A comprehensive dry-run wrapper system for safe command execution with built-in support for testing (dry-run) and rollback operations. It supports three distinct execution modes that allow you to:

- **Execute commands normally** with rollback protection
- **Preview operations** before making any changes (dry-run mode)
- **Execute rollback operations** while blocking normal commands (undo mode)

All wrappers include color-coded logging, command exit status tracking, and flexible per-command configuration.

## Features

- ✅ Three execution modes: Normal, Dry-run, and Undo/Rollback
- ✅ Dynamic wrapper generation using `eval`
- ✅ Global `DRY_RUN` and `UNDO_RUN` environment variable support
- ✅ Command-specific dry run flags via suffixes
- ✅ Silent mode for reduced output
- ✅ Multi-command undo support with `undo:func` (alias: `rollback:func`)
- ✅ e-bash logging integration with color-coded output
- ✅ Command exit status tracking
- ✅ Customizable behavior through environment variables

## Quick Start

```bash
#!/usr/bin/env bash

# 1. Load the dryrun system
export E_BASH=/path/to/e-bash/.scripts
source "$E_BASH/_dryrun.sh"

# 2. Create wrappers for commands you want to control
dryrun git docker kubectl

# 3. Use the wrappers in your script
run:git clone https://github.com/user/repo.git
dry:docker build -t myapp .
rollback:kubectl delete deployment myapp

# 4. Run in different modes
# Normal:    ./script.sh
# Dry-run:   DRY_RUN=true ./script.sh
# Rollback:  UNDO_RUN=true ./script.sh
```

## Execution Modes

### Mode 1: Normal Execution (Default)

**Variables:** `DRY_RUN=false` (default), `UNDO_RUN=false` (default)

**Behavior:**

- `run:{cmd}` → **Executes command**
- `dry:{cmd}` → **Executes command**
- `rollback:{cmd}` / `undo:{cmd}` → Shows dry-run message (no execution)
- `undo:func` → Shows dry-run message with function body

**Use case:** Standard script execution where you want commands to run normally but prevent accidental rollback operations.

```bash
# Normal execution
run:ls -la        # Executes ls
dry:git status    # Executes git status
rollback:git reset HEAD~1  # Shows dry-run (safe by default)
```

### Mode 2: Dry-Run Mode

**Variables:** `DRY_RUN=true`, `UNDO_RUN=false`

**Behavior:**

- `run:{cmd}` → **Executes command**
- `dry:{cmd}` → Shows dry-run message
- `rollback:{cmd}` / `undo:{cmd}` → Shows dry-run message
- `undo:func` → Shows dry-run message with function body

**Use case:** Testing and validation before actual execution. Preview what would happen without making any changes.

```bash
# Test mode - see what would run without executing
DRY_RUN=true ./deploy.sh
```

### Mode 3: Undo/Rollback Mode

**Variables:** `DRY_RUN=false`, `UNDO_RUN=true`

**Behavior:**

- `run:{cmd}` → **Executes command**
- `dry:{cmd}` → Shows dry-run message (prevents normal operations)
- `rollback:{cmd}` / `undo:{cmd}` → **Executes command** (enables rollback)
- `undo:func` → **Executes function** (enables rollback)

**Use case:** Rollback mode where you want to execute undo operations while preventing all normal operations from running.

```bash
# Rollback mode - execute rollback commands, dry-run everything else
UNDO_RUN=true ./deploy.sh
```

### Mode 4: Combined Safety Mode

**Variables:** `DRY_RUN=true`, `UNDO_RUN=true`

**Behavior:**

- All commands show dry-run messages
- `DRY_RUN` takes precedence - even rollback commands won't execute

**Use case:** Maximum safety when you want to preview rollback operations without executing anything.

```bash
# Preview rollback without executing
DRY_RUN=true UNDO_RUN=true ./deploy.sh
```

## Mode Comparison Table

| Mode        | DRY_RUN | UNDO_RUN | run:        | dry:        | undo:       | Use Case            |
| ----------- | ------- | -------- | ----------- | ----------- | ----------- | ------------------- |
| **Normal**  | false   | false    | **Execute** | **Execute** | Dry-run     | Standard operations |
| **Dry-run** | true    | false    | **Execute** | Dry-run     | Dry-run     | Testing/Preview     |
| **Undo**    | false   | true     | **Execute** | Dry-run     | **Execute** | Rollback operations |
| **Safe**    | true    | true     | Dry-run     | Dry-run     | Dry-run     | Preview rollback    |

## Logger Output

The system uses color-coded logger prefixes to clearly indicate what's happening:

```bash
# Cyan "execute:" - command is running
execute: ls -la  / code: 0
| /tmp

# Green "dry run:" - command would run (showing preview)
dry run: ls -la

# Yellow "undoing:" - rollback command (may execute or show dry-run)
undoing: git reset --hard HEAD~1  / code: 0
undoing: (dry) git reset --hard HEAD~1  # dry-run rollback

# Gray "|" - command output
| On branch main
| Your branch is up to date
```

## Command-Specific Overrides

Each mode supports per-command customization using suffixed variables. The suffix is derived from the command name in uppercase (e.g., `git` → `_GIT`, `ls` → `_LS`).

```bash
# Global settings affect all commands
DRY_RUN=true
UNDO_RUN=false
SILENT=false

# Command-specific overrides take precedence
DRY_RUN_GIT=false     # git commands execute despite global DRY_RUN=true
UNDO_RUN_LS=true      # ls rollbacks execute despite global UNDO_RUN=false
SILENT_GIT=true       # git commands run silently (no output)

# Examples with overrides
DRY_RUN=true DRY_RUN_GIT=false dry:git status  # Executes git
UNDO_RUN=true UNDO_RUN_LS=false rollback:ls    # Dry-run (blocks rollback)
SILENT=true SILENT_GIT=false run:git log       # Shows git output only
```

### Custom Suffix Names

You can specify custom suffixes when creating wrappers:

```bash
# Use custom suffix "DEPLOY" instead of "KUBECTL"
dryrun kubectl DEPLOY

# Now control with DRY_RUN_DEPLOY instead of DRY_RUN_KUBECTL
DRY_RUN=true DRY_RUN_DEPLOY=false dry:kubectl apply -f app.yaml  # Executes
```

## Variable Precedence

The system follows this precedence chain (highest to lowest):

1. **Command-specific variable** (e.g., `DRY_RUN_LS`, `UNDO_RUN_GIT`)
2. **Global variable** (e.g., `DRY_RUN`, `UNDO_RUN`)
3. **Default value** (`false`)

## Wrapper Types

> **Note:** The old function names `dry-run` and `rollback:func` are still supported for backward compatibility, but the new names `dryrun` and `undo:func` are recommended.

### `run:{cmd}`

Safe execution wrapper that respects `DRY_RUN` and `UNDO_RUN`.

```bash
run:ls -la           # Normal: executes
DRY_RUN=true run:ls  # Shows dry-run
UNDO_RUN=true run:ls # Shows dry-run (prevents normal ops in rollback mode)
```

### `dry:{cmd}`

Conditional execution based on dry-run flags.

```bash
dry:git status              # Normal: executes
DRY_RUN=true dry:git status # Shows dry-run
UNDO_RUN=true dry:git status # Shows dry-run
```

### `rollback:{cmd}` / `undo:{cmd}`

Rollback operations that only execute in `UNDO_RUN` mode.

```bash
rollback:git reset --hard HEAD~1  # Normal: dry-run (safe)
DRY_RUN=true rollback:git reset   # Dry-run
UNDO_RUN=true rollback:git reset  # EXECUTES (rollback mode)
```

### `undo:func`

Complex undo operations with function body preview.

```bash
function cleanup() {
  rm -rf /tmp/build
  git checkout main
}

undo:func cleanup              # Normal: shows dry-run with body
UNDO_RUN=true undo:func cleanup # EXECUTES cleanup

# Backward compatibility: rollback:func still works
rollback:func cleanup  # Same as undo:func
```

## Setup and Initialization

### Basic Setup

```bash
#!/usr/bin/env bash

# 1. Ensure E_BASH is set (required)
export E_BASH="/path/to/e-bash/.scripts"

# 2. Optional: Configure logging (before sourcing)
DEBUG=${DEBUG:-"myapp,exec,dry,rollback,-loader"}

# 3. Load the dryrun system
source "$E_BASH/_dryrun.sh"

# 4. Create wrappers for commands you need
dryrun ls git rm cp docker kubectl

# 5. Use the wrappers
run:ls -la
dry:git status
rollback:rm -rf /tmp/backup
```

### With direnv

Add to `.envrc` in your project root:

```bash
export E_BASH="$(expand_path .scripts)"
# or point to e-bash installation
export E_BASH="/usr/local/lib/e-bash"
```

## Real-World Examples

### Example 1: Deployment Script with Rollback

```bash
#!/usr/bin/env bash
## deploy.sh - Deploy application with rollback support

source "$E_BASH/_dryrun.sh"

# Create wrappers for deployment commands
dryrun git docker kubectl

function deploy() {
  echo "Deploying application..."
  
  # Pull latest code
  dry:git pull origin main || return 1
  
  # Build and push Docker image
  local version=$(git rev-parse --short HEAD)
  dry:docker build -t myapp:${version} . || return 1
  dry:docker push myapp:${version} || return 1
  
  # Deploy to Kubernetes
  dry:kubectl set image deployment/myapp app=myapp:${version} || return 1
  dry:kubectl rollout status deployment/myapp
}

function rollback_deploy() {
  echo "Rolling back deployment..."
  
  # Rollback Kubernetes deployment
  rollback:kubectl rollout undo deployment/myapp
  rollback:kubectl rollout status deployment/myapp
  
  # Reset git to previous state
  rollback:git reset --hard HEAD~1
}

# Main execution
if [ "${UNDO_RUN}" = "true" ]; then
  rollback_deploy
else
  deploy
fi

# Usage:
# Normal:       ./deploy.sh                    # Execute deployment
# Test:         DRY_RUN=true ./deploy.sh        # Preview what would run
# Rollback:     UNDO_RUN=true ./deploy.sh       # Execute rollback
# Safe preview: DRY_RUN=true UNDO_RUN=true ./deploy.sh  # Preview rollback
```

### Example 2: Database Migration with Undo

```bash
#!/usr/bin/env bash
## migrate.sh - Database migration with rollback

source "$E_BASH/_dryrun.sh"
dryrun psql git

function migrate_up() {
  echo "Running migrations..."
  
  for migration in migrations/*.sql; do
    echo "Applying: $migration"
    dry:psql -f "$migration" mydb || return 1
  done
  
  # Tag the migration
  local tag="migration-$(date +%Y%m%d-%H%M%S)"
  dry:git tag "$tag"
  echo "Tagged as: $tag"
}

function migrate_down() {
  echo "Reverting migrations..."
  
  # Run rollback scripts in reverse order
  for migration in $(ls -r migrations/rollback/*.sql); do
    echo "Rolling back: $migration"
    rollback:psql -f "$migration" mydb || return 1
  done
  
  # Remove migration tag
  local last_tag=$(git describe --tags --abbrev=0)
  rollback:git tag -d "$last_tag"
}

if [ "${UNDO_RUN}" = "true" ]; then
  migrate_down
else
  migrate_up
fi
```

### Example 3: File Operations with Safety

```bash
#!/usr/bin/env bash
## backup.sh - Backup with automatic cleanup and rollback

source "$E_BASH/_dryrun.sh"
dryrun tar rsync rm

BACKUP_DIR="/backup/$(date +%Y%m%d)"
SOURCE_DIR="/data/important"

function create_backup() {
  echo "Creating backup..."
  
  # Create backup directory
  run:mkdir -p "$BACKUP_DIR"
  
  # Sync files
  dry:rsync -av --delete "$SOURCE_DIR/" "$BACKUP_DIR/"
  
  # Create tarball
  dry:tar czf "${BACKUP_DIR}.tar.gz" -C "$BACKUP_DIR" .
  
  # Cleanup old backups (keep last 7 days)
  local cutoff_date=$(date -d '7 days ago' +%Y%m%d)
  for old_backup in /backup/*; do
    local backup_date=$(basename "$old_backup")
    if [ "$backup_date" -lt "$cutoff_date" ]; then
      dry:rm -rf "$old_backup"
    fi
  done
}

function restore_backup() {
  echo "Restoring from backup..."
  
  if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup not found: $BACKUP_DIR"
    return 1
  fi
  
  # Restore files
  rollback:rsync -av --delete "$BACKUP_DIR/" "$SOURCE_DIR/"
}

if [ "${UNDO_RUN}" = "true" ]; then
  restore_backup
else
  create_backup
fi

# Usage:
# Backup:       ./backup.sh                    # Create backup
# Test:         DRY_RUN=true ./backup.sh        # Preview backup
# Restore:      UNDO_RUN=true ./backup.sh       # Restore from backup
```

## Best Practices

1. **Default Safe:** Rollback commands are dry-run by default in normal mode
2. **Explicit Rollback:** Set `UNDO_RUN=true` explicitly to execute rollback operations
3. **Test First:** Use `DRY_RUN=true` to preview operations before execution
4. **Command-Specific:** Override global settings for specific commands when needed
5. **Silent Operations:** Use `SILENT=true` or `SILENT_{SUFFIX}=true` to suppress output
6. **Always use `run:` for read-only operations** (ls, cat, grep, etc.)
7. **Use `dry:` for potentially destructive operations** (rm, git checkout, etc.)
8. **Implement rollback strategies for critical operations**

## Visual Decision Tree

```text
Command execution flow:

run:{cmd} or dry:{cmd}:
  ├─ DRY_RUN_{SUFFIX}=true?  → Show dry-run
  ├─ DRY_RUN=true?           → Show dry-run
  ├─ UNDO_RUN_{SUFFIX}=true? → Show dry-run (block normal ops)
  ├─ UNDO_RUN=true?          → Show dry-run (block normal ops)
  └─ Execute command

rollback:{cmd} or undo:{cmd}:
  ├─ UNDO_RUN_{SUFFIX}=false? → Show dry-run
  ├─ UNDO_RUN=false?          → Show dry-run
  ├─ DRY_RUN_{SUFFIX}=true?   → Show dry-run
  ├─ DRY_RUN=true?            → Show dry-run
  └─ Execute command (rollback)
```

## FAQ

### Q: What's the difference between `run:{cmd}` and `dry:{cmd}`?

**A:** Both behave identically - they execute commands normally and respect `DRY_RUN`/`UNDO_RUN` flags. Use `run:` for clarity when you always want to execute, and `dry:` when the command is conditionally executed based on flags. `run:` should be a first choice for read-only operations, lookups, search etc.

### Q: Why do rollback commands show "[on undo]" by default?

**A:** Rollback operations are potentially destructive. The system defaults to dry-run mode for safety. You must explicitly set `UNDO_RUN=true` to execute rollbacks.

### Q: Can I mix wrapped and unwrapped commands?

**A:** Yes, but unwrapped commands won't respect `DRY_RUN`/`UNDO_RUN` flags:

```bash
dryrun git
dry:git status     # Respects DRY_RUN
git status         # Always executes (unwrapped)
```

### Q: How do I silence specific command output?

**A:** Use `SILENT_{SUFFIX}=true` for the command:

```bash
SILENT_GIT=true run:git status  # No output shown
```

### Q: Can I use these wrappers in functions?

**A:** Yes, wrappers work in functions and are inherited:

```bash
function deploy() {
  dry:git pull
  dry:docker build -t app .
}

DRY_RUN=true deploy  # Both commands show dry-run
```

## Troubleshooting

### Issue: "command not found: run:ls"

**Cause:** Wrapper not created or script not sourced.

**Solution:**

```bash
# Ensure E_BASH is set and script is sourced
export E_BASH=/path/to/e-bash/.scripts
source "$E_BASH/_dryrun.sh"

# Create wrapper before using
dryrun ls
run:ls -la  # Now works
```

### Issue: Commands execute despite `DRY_RUN=true`

**Cause:** Variable set after sourcing, or command-specific override.

**Solution:**

```bash
# Set BEFORE sourcing for global effect
export DRY_RUN=true
source "$E_BASH/_dryrun.sh"

# Or set when calling
DRY_RUN=true ./script.sh

# Check for command-specific overrides
unset DRY_RUN_GIT  # Remove any overrides
```

### Issue: Rollback commands won't execute in undo mode

**Cause:** `DRY_RUN=true` takes precedence over `UNDO_RUN=true`.

**Solution:**

```bash
# Use only UNDO_RUN for rollback
UNDO_RUN=true ./script.sh

# Not: DRY_RUN=true UNDO_RUN=true (will show dry-run)
```

### Debug Mode

Enable debug logging:

```bash
# special loggers only enabled
DEBUG="exec,dry,rollback,output" ./demos/demo.dryrun-modes.sh
# Or all loggers, VERBOSE mode:
DEBUG="*" ./demos/demo.dryrun-modes.sh
```

## Integration Patterns

### Pattern 1: Script with Built-in Mode Detection

```bash
#!/usr/bin/env bash
source "$E_BASH/_dryrun.sh"
dryrun git docker

# Auto-detect mode from arguments
case "${1:-}" in
  --dry-run|-n)
    export DRY_RUN=true
    shift
    ;;
  --rollback|-r)
    export UNDO_RUN=true
    shift
    ;;
esac

# Your script logic here
dry:git pull
dry:docker build -t app .

# Usage: ./script.sh --dry-run
#        ./script.sh --rollback
```

### Pattern 2: Makefile Integration

```makefile
.PHONY: deploy deploy-dry rollback

deploy:
	@bash deploy.sh

deploy-dry:
	@DRY_RUN=true bash deploy.sh

rollback:
	@UNDO_RUN=true bash deploy.sh

# Usage: make deploy-dry
#        make deploy
#        make rollback
```

### Pattern 3: CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Preview deployment
        run: DRY_RUN=true ./deploy.sh
  
  deploy:
    needs: preview
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v2
      - name: Deploy
        run: ./deploy.sh
```

## Testing

Run the comprehensive test suite:

```bash
export E_BASH=/path/to/e-bash/.scripts
bash demos/demo.dryrun-modes.sh
```

This demonstrates all three modes with various command types and override scenarios.

## See Also

- `_logger.sh` - E-bash logging system used by dry-run wrappers
- `_colors.sh` - Color definitions for terminal output
- `demos/demo.dryrun-v2.sh` - Basic dry-run examples
- `demos/demo.dryrun-modes.sh` - Comprehensive three-mode tests

## License

MIT License - Copyright (C) 2017-present, Oleksandr Kucherenko
