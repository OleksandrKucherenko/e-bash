#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-30
## Version: 0.15.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"demo,exec,dry,output,rollback,-loader"}

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_colors.sh
# shellcheck disable=SC1090 source=../.scripts/_logger.sh
# shellcheck disable=SC1090 source=../.scripts/dryrun.sh
source "$E_BASH/_dryrun.sh"

logger:init demo "${cl_blue}[DEMO]${cl_reset} "

echo:Demo "Starting dryrun wrapper demonstration..."

# Create wrappers for ls and git commands
echo:Demo "Creating wrappers for ls and git commands..."
dryrun ls git

echo:Demo "Wrappers created successfully!"
echo:Demo ""

# Example 1: Safe command execution (always runs)
echo:Demo "=== Example 1: Safe command execution (run: wrappers) ==="
run:ls -la

echo:Demo ""
echo:Demo "=== Example 2: Dry run mode (dry: wrappers) ==="

# Example 2: Dry run mode
echo:Demo "Testing with DRY_RUN=false (normal execution):"
DRY_RUN=false dry:ls -la

echo:Demo ""
echo:Demo "Testing with DRY_RUN=true (dry run only):"
DRY_RUN=true dry:ls -la

echo:Demo ""
echo:Demo "=== Example 3: Rollback commands ==="

# Example 3: Rollback commands (in dry run mode for safety)
echo:Demo "Testing rollback commands (dry run mode for safety):"
DRY_RUN=true rollback:git status
DRY_RUN=true undo:git status

echo:Demo ""
echo:Demo "=== Example 4: Multi-command rollback ==="

# Example 4: Multi-command rollback
echo:Demo "Testing multi-command rollback (dry run mode):"
function rollback_step() {
  git status
  git log --oneline -1
  pwd
}
DRY_RUN=true undo:func rollback_step

echo:Demo ""
echo:Demo "=== Example 5: Custom suffixes ==="

# Example 5: Custom suffixes for command-specific behavior
echo:Demo "Testing command-specific dry run flags:"
DRY_RUN_LS=true dry:ls -la  # This should be dry run
DRY_RUN_LS=false dry:ls -la # This should execute

echo:Demo ""
echo:Demo "=== Example 6: Silent mode ==="

# Example 6: Silent mode
echo:Demo "Testing silent mode:"
SILENT_LS=true run:ls -la  # Should execute silently
SILENT_LS=false run:ls -la # Should show output

echo:Demo ""
echo:Demo "Demo completed!"
