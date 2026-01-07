#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Demo CI Script: ci-20-compile.sh
## Demonstrates exec-mode hooks with middleware contract

#region Initialization
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../../.scripts && pwd)"

export DEBUG="${DEBUG:-hooks,exec,dry,ci,modes}"

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

logger:init ci "${cl_blue}[ci-20]${cl_reset} " ">&2"
#endregion

#region CI Script Boilerplate
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HOOKS_DIR="${SCRIPT_DIR}/hooks-mw"

hooks:declare decide rollback

dry-run npm node tsc echo
#endregion

#region Exit Handling (graceful)
# End hook runs via hooks auto-trap; define it for consistent footer output.
hook:end() {
  local exit_code="${1:-$?}"
  local status="$([[ $exit_code -ne 0 ]] && echo "${cl_red}✗ " || echo "${cl_green}✓ ")"
  echo:Ci -e "\n${status}${SCRIPT_NAME:-script} finished, exit code: ${exit_code}${cl_reset}\n"
  return "$exit_code"
}
#endregion

#region Hooks Execution: BEGIN
echo:Ci ""
echo:Ci "${st_b}=== ${SCRIPT_NAME} ===${st_no_b}"
echo:Ci ""

hooks:middleware begin _hooks:middleware:modes
hooks:do begin "${SCRIPT_NAME}"
begin_exit=$?
hooks:flow:apply
if [[ $begin_exit -ne 0 ]]; then
  exit "$begin_exit"
fi
#endregion

#region Decision Point: Should Skip?
decision="$(hooks:do decide)"
decide_exit=$?
if [[ $decide_exit -ne 0 ]]; then
  exit "$decide_exit"
fi
echo:Ci "Decision hook returned: ${decision}"

if [[ "${decision}" == "Skip" ]]; then
  echo:Ci "Skipping compilation (cached)"
  exit 0
fi
#endregion

#region Main Logic
echo:Ci ""
echo:Ci "Starting compilation..."

dry:npm install --prefer-offline
dry:npm run lint
dry:tsc --build

echo:Ci "Compilation complete!"
#endregion
