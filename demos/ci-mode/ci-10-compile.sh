#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Demo CI Script: ci-10-compile.sh
## Demonstrates the CI script pattern with hooks and mode support

#region Initialization
# Resolve E_BASH path
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.scripts && pwd)"

# Set DEBUG for visibility (in real scripts, this would be configurable)
export DEBUG="${DEBUG:-hooks,exec,dry,ci}"

# Source e-bash modules
# shellcheck disable=SC1090 source=../../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck disable=SC1090 source=../../.scripts/_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck disable=SC1090 source=../../.scripts/_dryrun.sh
source "$E_BASH/_dryrun.sh"
# shellcheck disable=SC1090 source=../../.scripts/_traps.sh
source "$E_BASH/_traps.sh"
# shellcheck disable=SC1090 source=../../.scripts/_hooks.sh
source "$E_BASH/_hooks.sh"

# Initialize CI logger using e-bash logger module
logger:init ci "${cl_blue}[ci-10]${cl_reset} " ">&2"
#endregion

#region CI Script Boilerplate
# Script identification
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configure hooks directory and EXECUTION MODE
# CRITICAL: Use source mode so mode hooks can export DRY_RUN back to parent
export HOOKS_EXEC_MODE="source"
export HOOKS_DIR="${SCRIPT_DIR}/hooks"

# Define optional hooks (begin/end are auto-declared by _hooks)
hooks:declare decide rollback

# End hook runs via hooks auto-trap
hook:end() {
  local exit_code="${1:-$?}"
  local status="$([[ $exit_code -ne 0 ]] && echo "${cl_red}✗ " || echo "${cl_green}✓ ")"
  echo:Ci -e "\n${status}${SCRIPT_NAME:-script} finished, exit code: ${exit_code}${cl_reset}\n"
  return $exit_code
}


# Create dry-run wrappers for commands we'll use
dry-run npm node tsc echo

# Ensure hook scripts are executable
for hook_script in "${HOOKS_DIR}"/begin_*.sh "${HOOKS_DIR}"/end_*.sh; do
  [[ -f "$hook_script" ]] && chmod +x "$hook_script"
done
#endregion

#region Hooks Execution: BEGIN
echo:Ci ""
echo:Ci "${st_b}=== ${SCRIPT_NAME} ===${st_no_b}"
echo:Ci ""

# Execute begin hooks (includes mode intercept)
# Pass script name as argument for mode resolution
hooks:do begin "${SCRIPT_NAME}"

# Check if mode hooks requested termination (OK, SKIP, ERROR, TEST modes)
if [[ "${__HOOKS_FLOW_TERMINATE:-}" == "true" ]]; then
  echo:Ci "Mode requested early termination (exit: ${__HOOKS_FLOW_EXIT_CODE:-0})"
  exit "${__HOOKS_FLOW_EXIT_CODE:-0}"
fi
#endregion

#region Decision Point: Should Skip?
# Decision hook example - check if compilation is needed
hook:decide() {
  local decision="Continue"
  
  # Example: skip if no source changes
  # In real scenario, this would check git diff or timestamps
  if [[ "${CI_FORCE_BUILD:-}" != "true" ]] && [[ -f ".build-cache" ]]; then
    echo:Ci "Build cache found, checking if rebuild needed..."
    # Simulate cache check
    decision="Skip"
  fi
  
  echo "$decision"
}

DECISION=$(hooks:do decide)
echo:Ci "Decision hook returned: ${DECISION}"

if [[ "${DECISION}" == "Skip" ]]; then
  echo:Ci "Skipping compilation (cached)"
  exit 0  # trap will call hooks:do end
fi
#endregion

#region Main Logic
echo:Ci ""
echo:Ci "Starting compilation..."

# These commands respect DRY_RUN mode
dry:npm install --prefer-offline
dry:npm run lint
dry:tsc --build

echo:Ci "Compilation complete!"
#endregion

#region Rollback Registration
# Register rollback commands (only execute if UNDO_RUN=true)
hook:rollback() {
  echo:Ci "Rollback: cleaning build artifacts..."
  rm -rf dist node_modules/.cache
}
#endregion

# Script ends here - trap will call hooks:do end and show status
