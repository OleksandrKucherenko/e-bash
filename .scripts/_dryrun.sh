#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# include e-bash scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=./_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

# Global DRY_RUN, UNDO_RUN and SILENT, can be overridden per command with DRY_RUN_{SUFFIX}, UNDO_RUN_{SUFFIX}, SILENT_{SUFFIX}
export DRY_RUN=${DRY_RUN:-false}
export UNDO_RUN=${UNDO_RUN:-false}
export SILENT=${SILENT:-false}

##
## Internal shared execution helper for dry-run wrapper functions
##
## Parameters:
## - logger_suffix - Logger tag suffix (Exec/Undo), string, required
## - is_silent - Whether to suppress output, string ("true"/"false")
## - cmd - Command to execute, string, required
## - @ - Arguments for the command, variadic
##
## Globals:
## - reads/listen: cl_green, cl_red, cl_reset
## - mutate/publish: none
##
## Side effects:
## - Executes command and logs result
## - Temporarily disables 'set -e' if active
##
## Returns:
## - Exit code from executed command
##
## Usage:
## - _dryrun:exec "Exec" "false" "git" "status"
##
function _dryrun:exec() {
  local logger_suffix="$1"
  local is_silent="$2"
  local cmd="$3"
  shift 3

  # prevent command failure from exiting the script
  local output result immediate_exit_on_error color
  [[ $- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
  set +e

  # log command with arguments before execution (with logger prefix)
  printf:${logger_suffix} "%s" "${cmd} $*"

  # execute command and capture output and exit code
  output=$("$cmd" "$@" 2>&1)
  result=$?

  # print command result (without logger prefix) as continuos output 
  [ $result -eq 0 ] && color=${cl_green} || color=${cl_red}
  printf " / code: ${color}%s${cl_reset}\n" "$result" >&2

  # log command output
  [ -n "$output" ] && [ "$is_silent" != "true" ] && printf '%s\n' "$output" | log:Output

  # restore immediate exit flag state
  [ "$immediate_exit_on_error" = true ] && set -e
  
  # return output to stdout (avoid emitting a newline when output is empty), unless in silent mode
  [ -n "$output" ] && [ "$is_silent" != "true" ] && printf '%s\n' "$output" || true

  # TODO: should we store output in global variable before return exit code?

  return $result
}

##
## Generate run:{cmd}, dry:{cmd}, rollback:{cmd}, undo:{cmd} wrapper functions
##
## Parameters:
## - commands - Command names to wrap, string array, variadic
##   Each command can optionally be followed by a custom suffix (uppercase)
##
## Globals:
## - reads/listen: DRY_RUN, UNDO_RUN, SILENT
## - mutate/publish: Creates run:{cmd}, dry:{cmd}, rollback:{cmd}, undo:{cmd} functions
##
## Side effects:
## - Defines wrapper functions for each command
## - Wrapper functions respect DRY_RUN_{SUFFIX}, UNDO_RUN_{SUFFIX}, SILENT_{SUFFIX}
##
## Usage:
## - dryrun git docker               # create run:git, dry:git, etc.
## - dryrun npm BOWER                # use custom suffix BOWER instead of NPM
## - DRY_RUN=true dry:git status     # show what would run
## - UNDO_RUN=true undo:rm -rf /tmp # rollback mode
##
function dryrun() {
  local cmd suffix dry_var undo_var silent_var
  while [ $# -gt 0 ]; do
    cmd="$1"
    shift
    if [ $# -gt 0 ] && [[ "$1" =~ ^[A-Z_]+$ ]]; then
      suffix="_${1}"
      shift
    else
      suffix="_$(echo "$cmd" | tr '[:lower:]' '[:upper:]')"
    fi
    dry_var="DRY_RUN${suffix}"
    undo_var="UNDO_RUN${suffix}"
    silent_var="SILENT${suffix}"

    # Generate run:{cmd}
    eval "
    function run:${cmd}() {
      local is_undo=\${${undo_var}:-\${UNDO_RUN:-false}} is_silent=\${${silent_var}:-\${SILENT:-false}}
      if [ \"\$is_undo\" = true ]; then
        echo:Dry \"${cmd} \$*\"
        return 0
      fi
      _dryrun:exec Exec \"\$is_silent\" ${cmd} \"\$@\"
    }
    "

    # Generate dry:{cmd}
    eval "
    function dry:${cmd}() {
      local is_dry=\${${dry_var}:-\${DRY_RUN:-false}} is_undo=\${${undo_var}:-\${UNDO_RUN:-false}} is_silent=\${${silent_var}:-\${SILENT:-false}}
      if [ \"\$is_dry\" = true ] || [ \"\$is_undo\" = true ]; then
        echo:Dry \"${cmd} \$*\"
        return 0
      fi
      _dryrun:exec Exec \"\$is_silent\" ${cmd} \"\$@\"
    }
    "

    # Generate rollback:{cmd} with undo:{cmd}
    eval "
    function rollback:${cmd}() {
      local is_undo=\${${undo_var}:-\${UNDO_RUN:-false}} is_dry=\${${dry_var}:-\${DRY_RUN:-false}} is_silent=\${${silent_var}:-\${SILENT:-false}}
      if [ \"\$is_undo\" != true ]; then
        echo:Udry \"${cmd} \$*\"
        return 0
      fi
      if [ \"\$is_dry\" = true ]; then
        echo:Udry \"${cmd} \$*\"
        return 0
      fi
      _dryrun:exec Undo \"\$is_silent\" ${cmd} \"\$@\"
    }
    function undo:${cmd}() { rollback:${cmd} \"\$@\"; }
    "
  done
}

##
## Backward compatibility alias for dryrun
##
## Parameters:
## - @ - Same as dryrun
##
## Globals:
## - reads/listen: none
## - mutate/publish: none (forwards to dryrun)
##
function dry-run() { dryrun "$@"; }

##
## Complex undo handler for function calls (shows function body in dry-run mode)
##
## Parameters:
## - func_name - Function name to execute, string, required
## - @ - Arguments for the function, variadic
##
## Globals:
## - reads/listen: UNDO_RUN, DRY_RUN, SILENT
## - mutate/publish: none
##
## Side effects:
## - In dry-run mode: displays function body
## - In undo mode: executes function
##
## Usage:
## - undo:func my_function arg1 arg2
##
function undo:func() {
  local func_name="$1"
  shift
  local is_undo=${UNDO_RUN:-false} is_dry=${DRY_RUN:-false} is_silent=${SILENT:-false}
  if [ "$is_undo" != true ]; then
    echo:Undo "(dry-func): ${func_name} $*"
    if type "$func_name" &>/dev/null; then
      declare -f "$func_name" | tail -n +3 | sed '$d' | sed 's/^/    /' >&2
    fi
    return 0
  fi
  if [ "$is_dry" = true ]; then
    echo:Undo "(dry-func): ${func_name} $*"
    if type "$func_name" &>/dev/null; then
      declare -f "$func_name" | tail -n +3 | sed '$d' | sed 's/^/    /' >&2
    fi
    return 0
  fi
  _dryrun:exec Undo "$is_silent" "$func_name" "$@"
}

##
## Backward compatibility alias for undo:func
##
## Parameters:
## - @ - Same as undo:func
##
## Globals:
## - reads/listen: none
## - mutate/publish: none (forwards to undo:func)
##
function rollback:func() { undo:func "$@"; }

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code bellow those line in shellspec tests
${__SOURCED__:+return}

logger:init exec "${cl_cyan}execute: ${cl_reset}" ">&2"
logger:init dry "${cl_green}dry run: ${cl_reset}" ">&2"
logger:init udry "${cl_purple}on undo: ${cl_reset}" ">&2"
logger:init undo "${cl_yellow}undoing: ${cl_reset}" ">&2"
logger:init output "${cl_gray}| ${cl_reset}" ">&2"

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

##
## Module: Dry-Run and Rollback Command Wrappers
##
## This module provides a three-mode execution system: Normal, Dry-run, and Undo/Rollback.
##
## References:
## - demo: demo.dryrun.sh, demo.dryrun-modes.sh, demo.dryrun-v2.sh
## - bin: git.sync-by-patches.sh, npm.versions.sh
## - documentation: docs/public/dryrun-wrapper.md
## - tests: spec/dryrun_spec.sh
##
## Globals:
## - E_BASH - Path to .scripts directory
## - DRY_RUN - Global dry-run mode ("true"/"false"), default: "false"
## - UNDO_RUN - Global undo/rollback mode ("true"/"false"), default: "false"
## - SILENT - Global silent mode ("true"/"false"), default: "false"
## - DRY_RUN_{SUFFIX} - Command-specific dry-run override
## - UNDO_RUN_{SUFFIX} - Command-specific undo mode override
## - SILENT_{SUFFIX} - Command-specific silent mode override
##
## Execution Modes:
## 1. EXEC (normal): Commands execute normally
##    run:git status -> executes "git status"
##
## 2. DRY (preview): Commands are logged but not executed
##    DRY_RUN=true dry:git status -> shows "git status" but doesn't run
##
## 3. UNDO (rollback): Only rollback commands execute
##    UNDO_RUN=true rollback:rm -rf /tmp -> removes /tmp
##    UNDO_RUN=false undo:rm -rf /tmp -> shows what would be removed
##
## Usage Pattern:
##   dryrun git docker npm
##   dry:git pull origin main     # respects DRY_RUN
##   run:npm install              # always executes
##   rollback:docker rmi $(docker images -q)  # only in UNDO_RUN mode
##