#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

################################################################################
# MODULE: _logger.sh
#
# DESCRIPTION:
#   Advanced tag-based logging system with dynamic function generation, FIFO
#   pipes, and flexible output redirection. Creates logger functions that can
#   be enabled/disabled via DEBUG environment variable, supports wildcards,
#   negation, piping, named pipes, and state management.
#
# FEATURES:
#   - Tag-based filtering (DEBUG=tag1,tag2 or DEBUG=* or DEBUG=*,-excluded)
#   - Dynamic function generation (echo:Tag, printf:Tag, log:Tag per tag)
#   - FIFO/named pipe support for advanced inter-process communication
#   - Flexible output redirection (stdout, stderr, files, pipes)
#   - Custom prefixes per logger tag
#   - State management (push/pop logger configurations)
#   - Pipe mode: find . | log:Tag
#   - Redirect mode: cmd >log:Tag
#
# GLOBAL VARIABLES:
#   __SESSION        - Unique session ID for this logger instance
#   __TTY            - Current terminal device path
#   TAGS             - Associative array of tag states (1=enabled, 0=disabled)
#   TAGS_PREFIX      - Associative array of custom prefixes per tag
#   TAGS_PIPE        - Associative array of named pipe paths per tag
#   TAGS_REDIRECT    - Associative array of redirect commands per tag
#   TAGS_STACK       - Stack counter for logger state management
#
# USAGE:
#   source "$E_BASH/_logger.sh"
#   logger myapp "$@"
#   DEBUG=myapp ./script.sh
#   echo:Myapp "Hello World"
#
# SEE ALSO:
#   demos/demo.logs.sh - Comprehensive usage examples
#   demos/demo.debug.sh - Debug tracing examples
#   docs/public/logger.md - Complete documentation
################################################################################

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

################################################################################
# Function: logger:compose
# Description: Internal function generator that creates echo:Tag and printf:Tag
#              functions for a specific logger tag. These functions only output
#              when the tag is enabled in the TAGS array and respect custom
#              prefixes and redirections.
# Arguments:
#   $1 (tag)    - Logger tag name (lowercase, e.g., "myapp")
#   $2 (suffix) - Function suffix (capitalized, e.g., "Myapp")
#   $3 (flags)  - Optional flags for future use (currently unused)
# Returns:
#   stdout: Shell code defining echo:${suffix} and printf:${suffix} functions
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Generates code that references TAGS, TAGS_PREFIX, and TAGS_REDIRECT arrays
#   - Generated functions use builtin echo/printf for performance
# Example:
#   eval "$(logger:compose "myapp" "Myapp")"
#   # Creates: echo:Myapp and printf:Myapp functions
################################################################################
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

################################################################################
# Function: logger:compose:helpers
# Description: Internal function generator that creates config:logger:Tag and
#              log:Tag helper functions. config:logger:Tag handles tag enabling
#              based on DEBUG variable and --debug flag. log:Tag supports both
#              piping and direct logging modes.
# Arguments:
#   $1 (tag)    - Logger tag name (lowercase, e.g., "myapp")
#   $2 (suffix) - Function suffix (capitalized, e.g., "Myapp")
#   $3 (flags)  - Optional flags for future use (currently unused)
# Returns:
#   stdout: Shell code defining config:logger:${suffix} and log:${suffix}
#   exit code: 0 (always succeeds)
# Side Effects:
#   - config:logger:Tag modifies TAGS array based on DEBUG and --debug
#   - log:Tag reads from stdin with timeout or returns named pipe path
#   - Generated functions reference TAGS and TAGS_PIPE arrays
# Example:
#   eval "$(logger:compose:helpers "myapp" "Myapp")"
#   # Creates: config:logger:Myapp and log:Myapp functions
#   find . -name "*.sh" | log:Myapp  # Pipe mode
#   FIFO=$(log:Myapp)                # Get named pipe path
################################################################################
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

################################################################################
# Function: pipe:killer:compose
# Description: Internal function that generates cleanup script for named pipes.
#              Creates a background process that monitors the parent process and
#              automatically removes the named pipe when the parent exits or is
#              killed. Ensures proper cleanup without manual intervention.
# Arguments:
#   $1 (pipe)  - Full path to the named pipe to monitor and cleanup
#   $2 (myPid) - PID of parent process to monitor (defaults to ${BASHPID})
# Returns:
#   stdout: Shell code for background cleanup process
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Generated code sets up traps for multiple signals
#   - Removes named pipe on parent process exit
#   - Runs as background process polling every 0.1 seconds
# Example:
#   bash <(pipe:killer:compose "/tmp/pipe.123" "$$") &
#   # Background process monitors PID $$ and cleans up pipe on exit
################################################################################
function pipe:killer:compose() {
  local pipe=${1}
  local myPid=${2:-"${BASHPID}"}

  cat <<EOF
    trap "rm -f \"${pipe}\" >/dev/null" HUP INT QUIT ABRT TERM KILL EXIT
    while kill -0 "${myPid}" 2>/dev/null; do sleep 0.1; done
EOF
}

################################################################################
# Function: logger
# Description: PUBLIC API - Main entry point for logger system. Registers a new
#              logger tag and creates associated functions (echo:Tag, printf:Tag,
#              log:Tag, config:logger:Tag). Enables/disables based on DEBUG
#              environment variable and --debug flag. Creates named pipe for
#              advanced IPC scenarios.
# Arguments:
#   $1 (tag)       - Logger tag name (lowercase, e.g., "myapp", "api", "db")
#   $@ (remaining) - Additional arguments passed to config:logger:Tag
#                    Supports: --debug to force enable this logger
# Returns:
#   exit code: 0 (always succeeds, even if logger exists)
# Side Effects:
#   - Creates echo:Tag, printf:Tag, log:Tag, config:logger:Tag functions
#   - Adds entry to TAGS array (disabled by default, enabled via DEBUG)
#   - Creates named pipe at /tmp/_logger.${Tag}.${__SESSION}
#   - Starts background process to cleanup pipe on parent exit
#   - Logs registration to echo:Common (if common logger exists)
# Example:
#   logger myapp "$@"
#   DEBUG=myapp ./script.sh
#   echo:Myapp "This only prints if DEBUG=myapp"
#
#   logger api --debug  # Force enable
#   echo:Api "Always prints"
#
#   DEBUG=* logger db   # Enable all including db
#   DEBUG=*,-internal logger internal  # Enable all except internal
################################################################################
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

################################################################################
# Function: logger:push
# Description: PUBLIC API - Saves the current state of all logger tags to a
#              stack. Useful for temporarily modifying logger states and then
#              restoring them. Enables nested state management for complex
#              operations or recursive functions.
# Arguments:
#   None
# Returns:
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Increments TAGS_STACK counter
#   - Creates new global associative array __TAGS_STACK_N
#   - Copies all TAGS array entries to stack
# Example:
#   logger:push  # Save current logger states
#   TAGS["debug"]=1  # Enable debug logger temporarily
#   echo:Debug "This will print"
#   logger:pop  # Restore previous logger states
#
#   # Nested state management
#   logger:push
#     TAGS["verbose"]=1
#     logger:push
#       TAGS["trace"]=1
#     logger:pop  # Restore to verbose only
#   logger:pop  # Restore to original state
################################################################################
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

################################################################################
# Function: logger:pop
# Description: PUBLIC API - Restores the previous state of logger tags from the
#              stack. Must be paired with logger:push. Replaces current TAGS
#              array with the most recently saved state and cleans up the stack
#              entry.
# Arguments:
#   None
# Returns:
#   exit code: 0 (always succeeds, even if stack is empty)
# Side Effects:
#   - Decrements TAGS_STACK counter
#   - Clears current TAGS array
#   - Restores TAGS from __TAGS_STACK_N array
#   - Removes __TAGS_STACK_N array from memory
# Example:
#   logger:push
#   TAGS["api"]=1
#   TAGS["db"]=0
#   echo:Api "Temporarily enabled"
#   logger:pop  # Restore previous TAGS state
#
#   # Error handling with state restoration
#   logger:push
#   if complex_operation; then
#     logger:pop
#   else
#     logger:pop
#     return 1
#   fi
################################################################################
function logger:pop() {
  local stacked="__TAGS_STACK_$TAGS_STACK"
  TAGS_STACK=$((TAGS_STACK - 1))

  unset TAGS && declare -g -A TAGS

  # shellcheck disable=SC1087
  eval "for key in \"\${!$stacked[@]}\"; do eval \"TAGS[\\\"\$key\\\"]=\\\${$stacked[\\\"\$key\\\"]}\"; done"

  unset "$stacked"
}

################################################################################
# Function: logger:cleanup
# Description: PUBLIC API - Manually removes all named pipes created by loggers
#              and clears the TAGS_PIPE array. Normally not needed as pipes are
#              auto-cleaned by background killer processes, but useful for
#              explicit cleanup or troubleshooting.
# Arguments:
#   None
# Returns:
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Removes all named pipe files in TAGS_PIPE array
#   - Clears TAGS_PIPE array
#   - Pipe killer background processes become orphaned (harmless)
# Example:
#   logger:cleanup  # Remove all logger pipes
#
#   # Explicit cleanup before exit
#   trap logger:cleanup EXIT
#
#   # Troubleshooting: remove stale pipes
#   logger:cleanup
#   logger myapp  # Recreates pipe with fresh state
################################################################################
function logger:cleanup() {
  # iterate TAGS_PIPE and remove all named pipes
  for pipe in "${TAGS_PIPE[@]}"; do
    [[ -p "${pipe}" ]] && rm -f "${pipe}"
  done

  # reset array
  TAGS_PIPE=()
}

################################################################################
# Function: logger:listen
# Description: PUBLIC API - Starts a background process that reads from a
#              logger's named pipe and outputs to the current TTY. Useful for
#              monitoring inter-process communication or displaying async log
#              messages in real-time.
# Arguments:
#   $1 (tag) - Logger tag name whose named pipe to listen to
# Returns:
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Starts background cat process reading from TAGS_PIPE[$tag]
#   - Output goes to current TTY (/dev/tty)
#   - Process runs until pipe is closed or parent exits
# Example:
#   logger myapp
#   logger:listen myapp &  # Listen in background
#   FIFO=$(log:Myapp)
#   echo "Message from another process" >"$FIFO" &
#   # Output appears in current terminal
#
#   # Monitor async operations
#   logger:listen api
#   background_api_calls &  # Writes to named pipe
################################################################################
function logger:listen() {
  local tag=${1}
  local pipe=${TAGS_PIPE[$tag]}

  # run background process to read from pipe and output that to parent process TTY
  cat <"${pipe}" >/dev/tty &
}

################################################################################
# Function: logger:redirect
# Description: PUBLIC API - Changes output destination for a logger by setting
#              redirect command and regenerating echo:Tag/printf:Tag functions.
#              Supports stdout, stderr, files, pipes, and complex redirections.
# Arguments:
#   $1 (tag)      - Logger tag name to redirect
#   $2 (redirect) - Redirect command (e.g., ">&2", "> file", "| tee file >&2")
#                   Empty string resets to default (no redirect)
# Returns:
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Updates TAGS_REDIRECT[$tag] with redirect command
#   - Regenerates echo:Tag and printf:Tag functions
#   - Does not affect log:Tag function
# Example:
#   logger:redirect myapp ">&2"  # Send to stderr
#   logger:redirect myapp "> /tmp/app.log"  # Write to file
#   logger:redirect myapp ">> /tmp/app.log"  # Append to file
#   logger:redirect myapp "| tee -a /tmp/app.log >&2"  # Both file and stderr
#   logger:redirect myapp  # Reset to default
#
#   # Dynamic redirect based on environment
#   [[ "$CI" == "true" ]] && logger:redirect api "> /dev/null"
################################################################################
function logger:redirect() {
  local tag=${1}
  local redirect=${2:-""}
  local suffix=${1^} # capitalize first letter

  # redirect to named pipe
  TAGS_REDIRECT[$tag]="${redirect}"

  # recreate logger functions with the redirects
  eval "$(logger:compose "$tag" "$suffix")"
}

################################################################################
# Function: logger:prefix
# Description: PUBLIC API - Sets or removes a custom prefix that appears before
#              all log messages for a specific logger tag. Prefixes are applied
#              by echo:Tag and printf:Tag functions. Supports color codes and
#              any string content.
# Arguments:
#   $1 (tag)    - Logger tag name to set prefix for
#   $2 (prefix) - Prefix string to prepend to all messages
#                 Empty string removes the prefix
# Returns:
#   exit code: 0 (always succeeds)
# Side Effects:
#   - Updates TAGS_PREFIX[$tag] with prefix string
#   - Removes TAGS_PREFIX[$tag] entry if prefix is empty
#   - Prefix applies immediately to all subsequent logs
#   - Does not regenerate logger functions (prefix stored in array)
# Example:
#   logger:prefix myapp "[MyApp] "
#   echo:Myapp "Started"  # Output: [MyApp] Started
#
#   # Color-coded prefixes
#   logger:prefix error "${cl_red}[ERROR]${cl_reset} "
#   logger:prefix warn "${cl_yellow}[WARN]${cl_reset} "
#   logger:prefix info "${cl_blue}[INFO]${cl_reset} "
#
#   # Dynamic prefix with timestamp (use subshell in message instead)
#   logger:prefix api "[API] "
#   echo:Api "$(date +%H:%M:%S) Request received"
#
#   # Remove prefix
#   logger:prefix myapp ""  # No prefix
################################################################################
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

################################################################################
# Function: logger:init
# Description: PUBLIC API - Convenience function that combines logger creation,
#              prefix setup, and redirect configuration in one call. Default
#              behavior creates a logger with [tag] prefix sent to stderr,
#              which is the most common pattern.
# Arguments:
#   $1 (tag)      - Logger tag name to initialize
#   $2 (prefix)   - Custom prefix (default: "[${tag}] ")
#   $3 (redirect) - Redirect command (default: ">&2")
# Returns:
#   exit code: 0 if all operations succeed
# Side Effects:
#   - Creates logger with all associated functions
#   - Sets TAGS_PREFIX[$tag] to specified prefix
#   - Sets TAGS_REDIRECT[$tag] to specified redirect
#   - Regenerates logger functions with redirect
# Example:
#   # Standard initialization (stderr with [tag] prefix)
#   logger:init myapp
#   echo:Myapp "Error occurred"  # stderr: [myapp] Error occurred
#
#   # Custom prefix, stderr output
#   logger:init api "${cl_blue}[API]${cl_reset} "
#   echo:Api "Request received"  # stderr: [API] Request received
#
#   # Custom prefix and redirect to file
#   logger:init audit "[AUDIT] " ">> /var/log/audit.log"
#   echo:Audit "User login"  # appends: [AUDIT] User login
#
#   # Initialize multiple loggers with common pattern
#   for tag in error warn info debug; do
#     logger:init "$tag" "[$tag] " ">&2"
#   done
################################################################################
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
