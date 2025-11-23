# Dry-Run Wrapper System

A comprehensive dry-run wrapper system for safe command execution with automatic rollback capabilities.

## Overview

The dry-run wrapper system provides three types of command wrappers:

- **`run:{command}`** - Always executes with logging (safe commands)
- **`dry:{command}`** - Respects `DRY_RUN` flag (potentially unsafe commands)
- **`rollback:{command}`** / **`undo:{command}`** - Rollback commands

## Features

- ✅ Dynamic wrapper generation using `eval`
- ✅ Global `DRY_RUN` environment variable support
- ✅ Command-specific dry run flags via suffixes
- ✅ Silent mode for reduced output
- ✅ Multi-command rollback support
- ✅ e-bash logging integration
- ✅ Automatic rollback stack collection
- ✅ Customizable behavior through environment variables

## Installation

Source the dry-run script in your shell:

```bash
source "$E_BASH/_dryrun.sh"
```

## Usage

### Creating Wrappers

```bash
# Create wrappers for multiple commands
dryrun create ls git npm docker

# Or source and create directly
source "$E_BASH/_dryrun.sh"
dryrun:create_wrappers ls git
```

### Basic Usage

```bash
# Safe command (always executes)
run:ls ./

# Potentially unsafe command (respects DRY_RUN)
dry:git checkout -b new_branch

# Rollback command
rollback:git checkout main
undo:git branch -D new_branch  # alias for rollback
```

### Environment Variables

| Variable         | Default | Description                              |
| ---------------- | ------- | ---------------------------------------- |
| `DRY_RUN`        | `false` | Global dry run flag                      |
| `DRY_RUN_SUFFIX` | `""`    | Suffix for command-specific flags        |
| `SILENT_SUFFIX`  | `""`    | Suffix for command-specific silent flags |
| `ROLLBACK_STACK` | `""`    | Enable automatic rollback stack          |

### Command-Specific Control

```bash
# Command-specific dry run flag
DRY_RUN_GIT=true dry:git status  # Dry run for git only
DRY_RUN_GIT=false dry:git status # Execute git command

# Command-specific silent mode
SILENT_LS=true run:ls -la  # Execute silently
SILENT_LS=false run:ls -la # Show output
```

### Multi-Command Rollback

```bash
# Using the rollback-multi function
dryrun:rollback_multi "git checkout main
git branch -D new_branch
git clean -fd"

# Or with dry run mode
DRY_RUN=true dryrun:rollback_multi "git checkout main
git branch -D new_branch"
```

### Advanced Examples

#### Git Branch Management

```bash
# Create wrappers
dryrun create git

# Safe: Create new branch
dry:git checkout -b feature/new-feature

# If something goes wrong, rollback
rollback:git checkout main
undo:git branch -D feature/new-feature
```

#### Package Management

```bash
# Create wrappers
dryrun create npm apt

# Install package (dry run first)
DRY_RUN=true dry:npm install lodash
DRY_RUN=false dry:npm install lodash

# Rollback if needed
rollback:npm uninstall lodash
```

#### File Operations

```bash
# Create wrappers
dryrun create rm cp mv

# Dry run file operations
DRY_RUN=true dry:rm -rf /tmp/old_files
DRY_RUN=true dry:cp -r src/ backup/

# Execute when confirmed
DRY_RUN=false dry:rm -rf /tmp/old_files
DRY_RUN=false dry:cp -r src/ backup/
```

## Function Reference

### Core Functions

- `dryrun:create_wrappers <command1> [command2...]` - Create wrappers for commands
- `dryrun:generate_wrapper <cmd> [suffix] [type]` - Generate specific wrapper type
- `dryrun:rollback_multi <script>` - Execute multi-command rollback

### Generated Wrappers

For each command `<cmd>`, the following functions are generated:

- `run:<cmd>` - Always executes with logging
- `dry:<cmd>` - Executes unless `DRY_RUN=true`
- `rollback:<cmd>` - Executes rollback command
- `undo:<cmd>` - Alias for `rollback:<cmd>`

### Logging Functions

The system uses e-bash logging with these loggers:

- `dryrun` - Dry run messages (cyan)
- `wrapper` - Execution messages (green)
- `rollback` - Rollback messages (red)

## Implementation Details

### Wrapper Generation

The system uses `eval` to dynamically create wrapper functions:

```bash
eval "$(dryrun:generate_wrapper git)"          # dry:git
eval "$(dryrun:generate_wrapper git git run)"    # run:git
eval "$(dryrun:generate_wrapper git git rollback)" # rollback:git
```

### Error Handling

All wrappers preserve shell error state and provide proper exit codes:

```bash
# Preserves 'set -e' behavior
# Captures command output and exit codes
# Provides detailed logging
```

### Rollback Stack

When `ROLLBACK_STACK` is enabled, successful `dry:` commands are automatically added to a rollback stack:

```bash
ROLLBACK_STACK=/tmp/my_rollback.stack dry:git checkout -b feature
# Command added to stack for later rollback
```

## Best Practices

1. **Always use `run:` for read-only operations** (ls, cat, grep, etc.)
2. **Use `dry:` for potentially destructive operations** (rm, git checkout, etc.)
3. **Test with `DRY_RUN=true` before executing**
4. **Use command-specific flags for granular control**
5. **Implement rollback strategies for critical operations**

## Examples in the Wild

See the demo script for comprehensive examples:

```bash
# Run the demo
./demos/demo.dryrun.wrapper.sh
```

## Troubleshooting

### Common Issues

1. **Wrappers not found**: Make sure to source the script and create wrappers
2. **DRY_RUN not working**: Check variable scope and inheritance
3. **Logging not showing**: Verify DEBUG variable includes required tags

### Debug Mode

Enable debug logging:

```bash
DEBUG="dryrun,wrapper,rollback,demo" ./demos/demo.dryrun.wrapper.sh
```

## License

MIT License - see source file for details.
