#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-14
## Version: 2.0.1
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

DEBUG=${DEBUG:-"exec,dry,output,-internal"}

# Ultra-optimized bootstrap: E_BASH discovery + gnubin PATH
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; . "$E_BASH/_gnu.sh"; PATH="$E_BASH/../bin/gnubin:$PATH"; }

# include other scripts: _colors, _logger, _commons, _dependencies, _arguments
# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck disable=SC1090 source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"

export DRY_RUN=true

logger:init exec "${cl_cyan}execute: ${cl_reset}"
logger:init dry "${cl_cyan}dry run: ${cl_reset}"
logger:init output "${cl_gray}| ${cl_reset}"

## Updated git command execution
SILENT_GIT=false
function exec:git2() {
  if [ "$DRY_RUN" = true ]; then
    echo -e "${cl_cyan}dry run: git $*${cl_reset}" >&2
    return 0
  fi

  # is immediate exit on error is enabled? remember the state
  local immediate_exit_on_error
  [[ $- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
  set +e # disable immediate exit on error

  echo -n -e "${cl_cyan}execute: git $*${cl_reset}" >&2
  local output result
  output=$(git "$@" 2>&1)
  result=$?
  echo -e " / code: ${cl_yellow}$result${cl_reset}" >&2
  [ -n "$output" ] && [ "$SILENT_GIT" = false ] && echo -e "$output" >&2

  [ "$immediate_exit_on_error" = "true" ] && set -e # recover state
  return $result
}

function exec:dryrun() {
  local cmd=${1}
  local suffix=${2:-""}

  cat <<EOF
  #
  # Begin: Dry Run ${cmd}
  #
  function exec:${cmd}() {
    local output result immediate_exit_on_error

    if [ "\$DRY_RUN${suffix}" = true ]; then
      echo:Dry -e "${cmd} \$*${cl_reset}" && return 0
    fi

    [[ \$- == *e* ]] && immediate_exit_on_error=true || immediate_exit_on_error=false
    set +e # disable immediate exit on error

    echo:Exec -n -e "${cmd} \$*${cl_reset}"
    output=\$(${cmd} "\$@" 2>&1)
    result=\$?
    echo -e " / code: ${cl_yellow}\$result${cl_reset}" >&2
    [ -n "\$output" ] && [ -z "\$SILENT${suffix}" ] && echo -e "\$output" | log:Output

    [ "\$immediate_exit_on_error" = "true" ] && set -e # recover state
    return \$result
  }
  #
  # End: Dry Run ${cmd}
  #
EOF
}

# old implementation
exec:git2 -b master /home/developer/workspace/tmp/.e-bash

# declare dynamic functions
eval "$(exec:dryrun git)"    # controled by: DRY_RUN and SILENT
eval "$(exec:dryrun ls _LS)" # controled by: DRY_RUN_LS and SILENT_LS

exec:git -b main /home/developer/workspace/tmp/.e-bash

# normal run
exec:ls --color

# silent run
SILENT_LS=true exec:ls -a -l -c               # no output
DRY_RUN_LS=false SILENT_LS=true exec:ls -la   # no output
DRY_RUN_LS=false SILENT_LS='' exec:ls -l -a   # with output to log:Output/STDERR
DRY_RUN_LS=true SILENT_LS='' exec:ls -l -a -c # dry run
