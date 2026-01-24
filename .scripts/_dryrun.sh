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
## Purpose: Provide the `_dryrun:exec` helper for  dryrun exec operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## - $2 - secondary argument.
## - $3 - tertiary argument.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - _dryrun:exec "$@"
## - # Conditional usage pattern
## - if _dryrun:exec "$@"; then :; fi
## 
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
## Purpose: Provide the `dryrun` helper for dryrun operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: DRY_RUN, SILENT, UNDO_RUN, Z_.
## 
## Usage:
## - dryrun "$@"
## - # Conditional usage pattern
## - if dryrun "$@"; then :; fi
## 
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
## Purpose: Provide the `dry-run` helper for dry-run operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - dry-run "$@"
## - # Conditional usage pattern
## - if dry-run "$@"; then :; fi
## 
## 
function dry-run() { dryrun "$@"; }

## 
## Purpose: Provide the `undo:func` helper for undo func operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: DRY_RUN, SILENT, UNDO_RUN.
## 
## Usage:
## - undo:func "$@"
## - # Conditional usage pattern
## - if undo:func "$@"; then :; fi
## 
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
## Purpose: Provide the `rollback:func` helper for rollback func operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - rollback:func "$@"
## - # Conditional usage pattern
## - if rollback:func "$@"; then :; fi
## 
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


## Module notes: global variables, docs, and usage references.
## Links:
## - docs/public/dryrun-wrapper.md.
## - demos/demo.dryrun-modes.sh.
## - README.md (Dry-Run Wrapper System section).
## - docs/public/functions-docgen.md.
