#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-11-28
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"demo,exec,dry,output,rollback,-loader"}

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_colors.sh
# shellcheck disable=SC1090 source=../.scripts/_logger.sh
# shellcheck disable=SC1090 source=../.scripts/dryrun.sh
source "$E_BASH/_dryrun.sh"

logger:init demo "${cl_blue}[DEMO]${cl_reset} " ">&2"

echo:Demo "Testing dry-run wrapper three-mode system..."
echo:Demo ""

# Create wrappers for commands
echo:Demo "Creating wrappers for ls and git commands..."
dry-run ls git
echo:Demo ""

# ============================================================================
# MODE 1: Normal Execution
# ============================================================================
echo:Demo "========================================"
echo:Demo "MODE 1: Normal Execution (default)"
echo:Demo "========================================"
echo:Demo "Expected: All commands execute normally"
echo:Demo ""

echo:Demo "Test 1.1: run:ls (should execute)"
run:ls -d /tmp

echo:Demo ""
echo:Demo "Test 1.2: dry:ls (should execute)"
dry:ls -d /tmp

echo:Demo ""
echo:Demo "Test 1.3: rollback:git status (should be dry-run)"
rollback:git status

echo:Demo ""
echo:Demo "Test 1.4: rollback:func (should be dry-run)"
function sample_rollback() {
  echo "This would undo changes"
  return 0
}
rollback:func sample_rollback

# ============================================================================
# MODE 2: Dry-Run Mode
# ============================================================================
echo:Demo ""
echo:Demo "========================================"
echo:Demo "MODE 2: Dry-Run Mode (DRY_RUN=true)"
echo:Demo "========================================"
echo:Demo "Expected: All commands show dry-run messages"
echo:Demo ""

echo:Demo "Test 2.1: run:ls (should be dry-run)"
DRY_RUN=true run:ls -d /tmp

echo:Demo ""
echo:Demo "Test 2.2: dry:ls (should be dry-run)"
DRY_RUN=true dry:ls -d /tmp

echo:Demo ""
echo:Demo "Test 2.3: rollback:git status (should be dry-run)"
DRY_RUN=true rollback:git status

echo:Demo ""
echo:Demo "Test 2.4: rollback:func (should be dry-run)"
DRY_RUN=true rollback:func sample_rollback

# ============================================================================
# MODE 3: Undo/Rollback Mode
# ============================================================================
echo:Demo ""
echo:Demo "========================================"
echo:Demo "MODE 3: Undo Mode (UNDO_RUN=true)"
echo:Demo "========================================"
echo:Demo "Expected: rollback commands execute, others are dry-run"
echo:Demo ""

echo:Demo "Test 3.1: run:ls (should be dry-run)"
UNDO_RUN=true run:ls -d /tmp

echo:Demo ""
echo:Demo "Test 3.2: dry:ls (should be dry-run)"
UNDO_RUN=true dry:ls -d /tmp

echo:Demo ""
echo:Demo "Test 3.3: rollback:git status (should EXECUTE)"
UNDO_RUN=true rollback:git status

echo:Demo ""
echo:Demo "Test 3.4: undo:git status (should EXECUTE)"
UNDO_RUN=true undo:git status

echo:Demo ""
echo:Demo "Test 3.5: rollback:func (should EXECUTE)"
UNDO_RUN=true rollback:func sample_rollback

# ============================================================================
# MODE 4: Combined modes (edge case testing)
# ============================================================================
echo:Demo ""
echo:Demo "========================================"
echo:Demo "MODE 4: Combined DRY_RUN=true UNDO_RUN=true"
echo:Demo "========================================"
echo:Demo "Expected: rollback commands dry-run (DRY_RUN wins)"
echo:Demo ""

echo:Demo "Test 4.1: rollback:git status (should be dry-run)"
DRY_RUN=true UNDO_RUN=true rollback:git status

echo:Demo ""
echo:Demo "Test 4.2: rollback:func (should be dry-run)"
DRY_RUN=true UNDO_RUN=true rollback:func sample_rollback

# ============================================================================
# MODE 5: Command-specific overrides
# ============================================================================
echo:Demo ""
echo:Demo "========================================"
echo:Demo "MODE 5: Command-specific overrides"
echo:Demo "========================================"
echo:Demo ""

echo:Demo "Test 5.1: UNDO_RUN=true but UNDO_RUN_GIT=false (should be dry-run)"
UNDO_RUN=true UNDO_RUN_GIT=false rollback:git status

echo:Demo ""
echo:Demo "Test 5.2: UNDO_RUN=false but UNDO_RUN_GIT=true (should EXECUTE)"
UNDO_RUN=false UNDO_RUN_GIT=true rollback:git status

echo:Demo ""
echo:Demo "========================================"
echo:Demo "Demo completed!"
echo:Demo "========================================"
