#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# one time initialization, CUID
if type logger 2>/dev/null | grep -q "is a function"; then return 0; fi

# global helpers
export __SESSION=$(uuidgen 2>/dev/null || echo "session-$$-$RANDOM")
export __TTY=$(tty 2>/dev/null || echo "notty")

# declare global associative array
if [[ -z $TAGS ]]; then declare -g -A TAGS; fi
if [[ -z $TAGS_PREFIX ]]; then declare -g -A TAGS_PREFIX; fi
if [[ -z $TAGS_PIPE ]]; then declare -g -A TAGS_PIPE; fi
if [[ -z $TAGS_REDIRECT ]]; then declare -g -A TAGS_REDIRECT; fi
if [[ -z $TAGS_STACK ]]; then declare -g TAGS_STACK="0"; fi

##
## Generate Bash code to create dynamic echo:Tag and printf:Tag logging functions
##
## Parameters:
## - tag - The logger tag name (lowercase), string, required, e.g. "debug"
## - suffix - Capitalized tag name for function suffix, string, required, e.g. "Debug"
## - flags - Additional flags (unused), string, default: ""
##
## Globals:
## - reads/listen: TAGS, TAGS_PREFIX, TAGS_REDIRECT
## - mutate/publish: none (outputs generated function code)
##
## Usage:
## - eval "$(logger:compose "mytag" "Mytag")" # creates echo:Mytag and printf:Mytag
##
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

##
## Generate Bash code to create helper functions (log:Tag, config:logger:Tag)
##
## Parameters:
## - tag - The logger tag name (lowercase), string, required, e.g. "debug"
## - suffix - Capitalized tag name for function suffix, string, required, e.g. "Debug"
## - flags - Additional flags (unused), string, default: ""
##
## Globals:
## - reads/listen: DEBUG, TAGS
## - mutate/publish: TAGS (may modify tag state)
##
## Usage:
## - eval "$(logger:compose:helpers "mytag" "Mytag")"
##
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

##
## Generate a background process that monitors parent and cleans up named pipe on exit
##
## Parameters:
## - pipe - Path to the named pipe to clean up, string, required
## - myPid - Parent process ID to monitor, integer, default: "$BASHPID"
##
## Globals:
## - reads/listen: none
## - mutate/publish: none (outputs generated process code)
##
## Side effects:
## - Creates background process with trap to delete pipe on parent exit
##
## Usage:
## - bash <(pipe:killer:compose "/tmp/my.pipe" "$$") &
##
function pipe:killer:compose() {
  local pipe=${1}
  local myPid=${2:-"${BASHPID}"}

  cat <<EOF
    trap "rm -f \"${pipe}\" >/dev/null" HUP INT QUIT ABRT TERM KILL EXIT
    while kill -0 "${myPid}" 2>/dev/null; do sleep 0.1; done
EOF
}

##
## Register a tag-based logger that creates dynamic logging functions
##
## Parameters:
## - tag - Logger tag name (lowercase), string, required, e.g. "debug"
## - @ - Optional flags for initial tag enablement (e.g., "--debug"), string, default: none
##
## Globals:
## - reads/listen: DEBUG (environment variable, controls tag visibility)
## - mutate/publish: TAGS (associative array), TAGS_PREFIX, TAGS_PIPE, TAGS_REDIRECT
##
## Side effects:
## - Creates named pipe in /tmp for pipe logging (path: /tmp/_logger.{Tag}.{__SESSION})
## - Creates background process to clean up named pipe on parent exit
## - Defines the following dynamic functions:
##   - echo:{Tag}() - Print output if tag enabled (with TAGS_PREFIX if set, respecting TAGS_REDIRECT)
##   - printf:{Tag}() - Formatted print if tag enabled
##   - log:{Tag}() - Pipe-friendly logger (reads stdin, supports prefix argument)
##   - config:logger:{Tag}() - Re-configure tag based on DEBUG variable changes
##
## Usage:
## - logger debug "$@"                    # basic logger
## - logger myapp --debug                 # enabled by --debug flag
## - echo:Debug "Only shows when DEBUG=debug"  # use generated function
## - find . | log:Debug                   # pipe mode logging
## - DEBUG=myapp ./script.sh              # enable specific tag
## - DEBUG=* ./script.sh                  # enable all tags
## - DEBUG=*,-dbg ./script.sh              # enable all except debug tag
##
function logger() {
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

##
## Save current TAGS state to stack for temporary modification
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: TAGS
## - mutate/publish: TAGS_STACK, creates __TAGS_STACK_N associative arrays
##
## Side effects:
## - Increments TAGS_STACK counter
## - Creates snapshot of current TAGS state
##
## Usage:
## - logger:push    # save state
## - DEBUG=temp ./script.sh
## - logger:pop     # restore state
##
function logger:push() {
  TAGS_STACK=$((TAGS_STACK + 1))
  local new_stack="__TAGS_STACK_$TAGS_STACK"
  declare -g -A "$new_stack"

  # shellcheck disable=SC1087
  for key in "${!TAGS[@]}"; do
    eval "$new_stack[\"$key\"]=\"${TAGS[$key]}\""
  done
}

##
## Restore previous TAGS state from stack
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: TAGS_STACK
## - mutate/publish: TAGS (replaces with stacked state), removes __TAGS_STACK_N
##
## Side effects:
## - Decrements TAGS_STACK counter
## - Removes stacked snapshot after restoration
##
## Usage:
## - logger:push
## - TAGS([temp])=1
## - logger:pop
##
function logger:pop() {
  local stacked="__TAGS_STACK_$TAGS_STACK"
  TAGS_STACK=$((TAGS_STACK - 1))

  unset TAGS && declare -g -A TAGS

  # shellcheck disable=SC1087
  eval "for key in \"\${!$stacked[@]}\"; do eval \"TAGS[\\\"\$key\\\"]=\\\${$stacked[\\\"\$key\\\"]}\"; done"

  unset "$stacked"
}

##
## Remove all named pipes created by the logger system
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: TAGS_PIPE
## - mutate/publish: TAGS_PIPE (empties array)
##
## Side effects:
## - Deletes all FIFO files in TAGS_PIPE
##
## Usage:
## - logger:cleanup    # typically in EXIT trap
##
function logger:cleanup() {
  # iterate TAGS_PIPE and remove all named pipes
  for pipe in "${TAGS_PIPE[@]}"; do
    [[ -p "${pipe}" ]] && rm -f "${pipe}"
  done

  # reset array
  TAGS_PIPE=()
}

##
## Run background process to read from named pipe and output to TTY
##
## Parameters:
## - tag - Logger tag name, string, required
##
## Globals:
## - reads/listen: TAGS_PIPE
## - mutate/publish: none (creates background process)
##
## Side effects:
## - Creates background cat process
##
## Usage:
## - logger:listen myapp    # forward pipe to terminal
##
function logger:listen() {
  local tag=${1}
  local pipe=${TAGS_PIPE[$tag]}

  # run background process to read from pipe and output that to parent process TTY
  cat <"${pipe}" >/dev/tty &
}

##
## Set or change output redirection for a logger tag
##
## Parameters:
## - tag - Logger tag name, string, required
## - redirect - Redirection target, string, default: ""
##
## Globals:
## - reads/listen: TAGS
## - mutate/publish: TAGS_REDIRECT, recreates echo:Tag and printf:Tag
##
## Side effects:
## - Recreates logger functions with new redirection
##
## Usage:
## - logger:redirect myapp ">&2"              # to stderr
## - logger:redirect myapp ">/tmp/myapp.log"  # to file
## - logger:redirect myapp ""                 # reset
##
function logger:redirect() {
  local tag=${1}
  local redirect=${2:-""}
  local suffix=${1^} # capitalize first letter

  # redirect to named pipe
  TAGS_REDIRECT[$tag]="${redirect}"

  # recreate logger functions with the redirects
  eval "$(logger:compose "$tag" "$suffix")"
}

##
## Set or change the prefix string for a logger tag
##
## Parameters:
## - tag - Logger tag name, string, required
## - prefix - Prefix string (empty to reset), string, default: ""
##
## Globals:
## - reads/listen: TAGS
## - mutate/publish: TAGS_PREFIX
##
## Side effects:
## - Unsets TAGS_PREFIX[$tag] if prefix is empty
##
## Usage:
## - logger:prefix myapp "[ MyApp ] "
## - logger:prefix myapp ""    # reset to default
##
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

##
## Initialize logger with prefix and redirect in one call
##
## Parameters:
## - tag - Logger tag name, string, required
## - prefix - Prefix string, string, default: "[${tag}] "
## - redirect - Redirection target, string, default: ">&2"
##
## Globals:
## - reads/listen: none
## - mutate/publish: none (calls logger, logger:prefix, logger:redirect)
##
## Side effects:
## - Creates logger and configures prefix/redirect
##
## Usage:
## - logger:init myapp                    # defaults: [myapp] to stderr
## - logger:init myapp "[MyApp] " ">&2"   # explicit
## - logger:init myapp "" ""              # no prefix, no redirect
##
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

##
## Module: Advanced Tag-Based Logging System
##
## This module provides a flexible logging system with tag-based filtering,
## pipe/redirect support, and dynamic function creation.
##
## References:
## - demo: demo.logs.sh, demo.ecs-json-logging.sh, benchmark.ecs.sh
## - bin: git.log.sh, git.sync-by-patches.sh, git.verify-all-commits.sh
##   ci.validate-envrc.sh, ipv6.sh, tree.sh, vhd.sh, npm.versions.sh
## - documentation: docs/public/logger.md
## - tests: spec/logger_spec.sh
##
## Globals:
## - __SESSION - Unique session ID (uuidgen or "session-$$-$RANDOM")
## - __TTY - TTY device path or "notty"
## - DEBUG - Comma-separated tags to enable (supports wildcards: *, negation: -tag)
## - TAGS - Associative array of tag enable state (0=disabled, 1=enabled)
## - TAGS_PREFIX - Associative array of tag to prefix string
## - TAGS_PIPE - Associative array of tag to named pipe path
## - TAGS_REDIRECT - Associative array of tag to redirection string
## - TAGS_STACK - Stack level counter for push/pop operations
##
## Key Features:
## - Tag-based filtering: DEBUG=tag1,tag2 enables specific tags
## - Wildcard support: DEBUG=* enables all, DEBUG=*,-dbg enables all except debug
## - Pipe mode: find . | log:Tag streams through logger
## - Redirect mode: cmd >log:Tag or logger:redirect Tag ">/file"
## - Dynamic functions: logger tag creates echo:Tag, printf:Tag, log:Tag
##
