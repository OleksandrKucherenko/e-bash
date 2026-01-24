#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash
## Description: Dry-run wrapper system for safe command execution preview

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

# Function: _dryrun:exec
#
# Description:
#   Internal shared execution function used by generated wrapper functions.
#   Executes a command, captures output and exit code, and logs execution details.
#
# Arguments:
#   $1 - logger_suffix (string) - Logger tag suffix (e.g., "Exec", "Undo")
#   $2 - is_silent (boolean) - Whether to suppress output logging ("true"/"false")
#   $3 - cmd (string) - Command to execute
#   $@ - Additional arguments passed to the command
#
# Returns:
#   Exit code of the executed command
#
# Side Effects:
#   - Logs command execution to printf:{logger_suffix}
#   - Logs command output to log:Output (unless silent)
#   - Outputs command result to stdout (unless silent)
#   - Temporarily disables 'set -e' during execution to capture exit codes
#
# Example:
#   _dryrun:exec Exec "false" git status
#   # Logs: "git status / code: 0" and outputs git status result
#
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

# Function: dryrun
#
# Description:
#   Generates dynamic wrapper functions for commands with dry-run/undo capabilities.
#   Creates run:{cmd}, dry:{cmd}, rollback:{cmd}, and undo:{cmd} functions that respect
#   DRY_RUN, UNDO_RUN, and SILENT environment variables (global or command-specific).
#
# Arguments:
#   $1 - cmd (string) - Command name to wrap (e.g., "git", "docker", "kubectl")
#   $2 - suffix (string, optional) - Custom suffix for environment variables (defaults to uppercase cmd)
#
# Returns:
#   None (defines functions in current shell)
#
# Side Effects:
#   - Dynamically creates run:{cmd}() function (executes unless UNDO_RUN=true)
#   - Dynamically creates dry:{cmd}() function (dry-run when DRY_RUN=true or UNDO_RUN=true)
#   - Dynamically creates rollback:{cmd}() and undo:{cmd}() functions (executes only when UNDO_RUN=true)
#   - Each function respects DRY_RUN_{SUFFIX}, UNDO_RUN_{SUFFIX}, SILENT_{SUFFIX} variables
#
# Example:
#   # Generate wrappers for git command
#   dryrun git
#
#   # Use the generated functions
#   dry:git status              # Executes git status normally
#   DRY_RUN=true dry:git commit # Logs "dry run: git commit" without executing
#
#   # Generate with custom suffix
#   dryrun docker DOCK
#   DRY_RUN_DOCK=true dry:docker ps  # Uses DRY_RUN_DOCK instead of DRY_RUN_DOCKER
#
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

# Function: dry-run
#
# Description:
#   Backward compatibility alias for dryrun() function.
#   Provided for scripts using the old hyphenated naming convention.
#
# Arguments:
#   $@ - All arguments are passed through to dryrun()
#
# Returns:
#   Returns value from dryrun()
#
# Example:
#   dry-run git  # Same as: dryrun git
#
function dry-run() { dryrun "$@"; }

# Function: undo:func
#
# Description:
#   Executes or simulates undo operations for bash functions (not external commands).
#   In undo mode (UNDO_RUN=true and DRY_RUN=false), executes the function.
#   Otherwise, logs the function body for inspection without executing.
#
# Arguments:
#   $1 - func_name (string) - Name of the bash function to execute in undo mode
#   $@ - Additional arguments passed to the function
#
# Returns:
#   Exit code 0 when in dry mode, or the function's exit code when executed
#
# Side Effects:
#   - In dry/preview mode: Logs function name and displays function body
#   - In undo mode: Executes the function with provided arguments
#   - Respects global DRY_RUN, UNDO_RUN, and SILENT variables
#
# Example:
#   function cleanup_files() { rm -rf /tmp/myapp/*; }
#
#   # Preview what would be undone
#   undo:func cleanup_files
#   # Output: "(dry-func): cleanup_files"
#   #         "    rm -rf /tmp/myapp/*"
#
#   # Execute undo
#   UNDO_RUN=true undo:func cleanup_files
#   # Executes the cleanup_files function
#
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

# Function: rollback:func
#
# Description:
#   Backward compatibility alias for undo:func() function.
#   Provided for scripts using the rollback naming convention.
#
# Arguments:
#   $@ - All arguments are passed through to undo:func()
#
# Returns:
#   Returns value from undo:func()
#
# Example:
#   rollback:func cleanup_files  # Same as: undo:func cleanup_files
#
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
