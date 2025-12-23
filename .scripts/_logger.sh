#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# one time initialization, CUID
if type logger | grep -q "is a function"; then return 0; fi

# global helpers
export __SESSION=$(uuidgen 2>/dev/null || echo "session-$$-$RANDOM")
export __TTY=$(tty 2>/dev/null || echo "notty")

# declare global associative array
if [[ -z $TAGS ]]; then declare -g -A TAGS; fi
if [[ -z $TAGS_PREFIX ]]; then declare -g -A TAGS_PREFIX; fi
if [[ -z $TAGS_PIPE ]]; then declare -g -A TAGS_PIPE; fi
if [[ -z $TAGS_REDIRECT ]]; then declare -g -A TAGS_REDIRECT; fi
if [[ -z $TAGS_STACK ]]; then declare -g TAGS_STACK="0"; fi

#
# Create a dynamic functions with a Tag name as a suffix
#
function logger:compose() {
  local tag=${1}
  local suffix=${2}
  local flags=${3:-""}

  cat <<EOF
  #
  # begin
  #
  function echo:${suffix}() {
    [[ "\${TAGS[$tag]}" == "1" ]] && ({ builtin echo -n "\${TAGS_PREFIX[$tag]}"; builtin echo "\$@"; } ${TAGS_REDIRECT[$tag]})
  }
  #
  function printf:${suffix}() {
    [[ "\${TAGS[$tag]}" == "1" ]] && ({ builtin printf "%s\${@:1:1}" "\${TAGS_PREFIX[$tag]}" "\${@:2}"; } ${TAGS_REDIRECT[$tag]})
  }
  #
EOF
}

#
# Create a dynamic helper functions with a Tag name as a suffix
#
function logger:compose:helpers() {
  local tag=${1}
  local suffix=${2}
  local flags=${3:-""}

  cat <<EOF
  #
  # begin
  #
  function config:logger:${suffix}() {
    local args=("\$@")
    IFS="," read -r -a tags <<<\$(echo "\$DEBUG")
    [[ "\${args[*]}" =~ "--debug" ]] && TAGS+=([$tag]=1)
    [[ "\${tags[*]}" =~ "$tag" ]] && TAGS+=([$tag]=1)
    [[ "\${tags[*]}" =~ "*" ]] && TAGS+=([$tag]=1)
    [[ "\${tags[*]}" =~ "-$tag" ]] && TAGS+=([$tag]=0)
    #builtin echo "done! \${!TAGS[@]} \${TAGS[@]}"
  }
  #
  function log:${suffix}() {
    # if no input params and stdin is tty, then print named_pipe name
    if [ \$# -eq 0 ] && [ -t 0 ]; then echo "\${TAGS_PIPE[$tag]}"; else
      local prefix=\${1:-""} && shift
      if [ -t 0 ] && [ -t 1 ]; then set - "\${prefix}" "\$@"; fi
      if [ -t 0 ]; then echo:${suffix} "\$@"; return 0; fi
      while read -r -t 0.1 line; do echo:${suffix} "\${prefix}\${line}"; done
    fi
  }
  #
EOF
}

#
# Create dynamic function that listen to parent process and delete named pipe on parent process exit/kill
#
function pipe:killer:compose() {
  local pipe=${1}
  local myPid=${2:-"${BASHPID}"}

  cat <<EOF
    trap "rm -f \"${pipe}\" >/dev/null" HUP INT QUIT ABRT TERM KILL EXIT
    while kill -0 "${myPid}" 2>/dev/null; do sleep 0.1; done
EOF
}

#
# Register debug logger functions that are controlled by DEBUG= environment variable
#
function logger() {
  #
  # Usage:
  #   source "$SCRIPT_DIR/commons.sh" && logger tag "$@"
  #   echo:Tag "print only if DEBUG=tag is set"
  #   printf:Tag "print only if DEBUG=tag is set %s" "something"
  #
  local tag=${1}
  local suffix=${1^} # capitalize first letter

  # check if logger already exists, then skip
  # if type "echo:${suffix}" &>/dev/null; then return 0; fi
  if declare -F "echo:${suffix}" >/dev/null; then return 0; fi

  # keep it disabled by default
  TAGS+=([$tag]=0)

  # declare logger functions
  # source /dev/stdin <<EOF
  eval "$(logger:compose "$tag" "$suffix")"
  eval "$(logger:compose:helpers "$tag" "$suffix")"

  # configure logger
  # shellcheck disable=SC2294
  eval "config:logger:${suffix}" "$@" 2>/dev/null

  # dump created loggers
  # shellcheck disable=SC2154
  [[ "$tag" != "common" ]] && (
    # ignore output error
    eval "echo:Common \"Logger tags  :\" \"\${!TAGS[@]}\" \"|\" \"\${TAGS[@]}\" " 2>/dev/null | tee >(cat >&2)
  )

  # create named pipe, if it does not exist
  local pipe="/tmp/_logger.${suffix}.${__SESSION}"
  if [[ ! -p "${pipe}" ]]; then
    mkfifo "${pipe}" || echo "Failed to create named pipe: ${pipe}" >&2
    TAGS_PIPE+=([$tag]="${pipe}")

    # run background process to wait for parent process exit and delete the named pipe
    bash <(pipe:killer:compose "$pipe" "$myPid") &
  fi

  return 0 # force exit code success
}

# save current $TAGS state
# bashsupport disable=BP2001
function logger:push() {
  TAGS_STACK=$((TAGS_STACK + 1))
  local new_stack="__TAGS_STACK_$TAGS_STACK"
  declare -g -A "$new_stack"

  # shellcheck disable=SC1087
  for key in "${!TAGS[@]}"; do
    eval "$new_stack[\"$key\"]=\"${TAGS[$key]}\""
  done
}

# recover previous $TAGS state
function logger:pop() {
  local stacked="__TAGS_STACK_$TAGS_STACK"
  TAGS_STACK=$((TAGS_STACK - 1))

  unset TAGS && declare -g -A TAGS

  # shellcheck disable=SC1087
  eval "for key in \"\${!$stacked[@]}\"; do eval \"TAGS[\\\"\$key\\\"]=\\\${$stacked[\\\"\$key\\\"]}\"; done"

  unset "$stacked"
}

# cleanup all named pipes
function logger:cleanup() {
  # iterate TAGS_PIPE and remove all named pipes
  for pipe in "${TAGS_PIPE[@]}"; do
    [[ -p "${pipe}" ]] && rm -f "${pipe}"
  done

  # reset array
  TAGS_PIPE=()
}

# run background process to listen the named pipe
function logger:listen() {
  local tag=${1}
  local pipe=${TAGS_PIPE[$tag]}

  # run background process to read from pipe and output that to parent process TTY
  cat <"${pipe}" >/dev/tty &
}

# force logger redirections
function logger:redirect() {
  local tag=${1}
  local redirect=${2:-""}
  local suffix=${1^} # capitalize first letter

  # redirect to named pipe
  TAGS_REDIRECT[$tag]="${redirect}"

  # recreate logger functions with the redirects
  eval "$(logger:compose "$tag" "$suffix")"
}

# force logger prefix
function logger:prefix() {
  local tag=${1}
  local prefix=${2:-""}
  local suffix=${1^} # capitalize first letter

  if [ -z "${prefix}" ]; then
    # reset to default the prefix
    # shellcheck disable=SC2184
    unset TAGS_PREFIX["$tag"]
  else
    # setup the prefix
    TAGS_PREFIX["$tag"]="${prefix}"
  fi
}

# initialization helper, allows to setup prefix and redirect in one line
# By default prefix will the tag name in '[]' and redirect will be to STDERR
function logger:init() {
  local tag=${1}
  local prefix=${2:-"[${tag}] "}
  local redirect=${3:-">&2"}

  logger "${tag}" && logger:prefix "${tag}" "${prefix}" && logger:redirect "${tag}" "${redirect}"
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger loader "$@"             # initialize logger
logger:redirect "loader" ">&2" # redirect to STDERR

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090  source=_colors.sh
[ -f "${E_BASH}/_colors.sh" ] && source "${E_BASH}/_colors.sh" # load if available

echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"
