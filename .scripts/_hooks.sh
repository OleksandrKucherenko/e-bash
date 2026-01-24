#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# one time initialization
if type hooks:declare 2>/dev/null | grep -q "is a function"; then return 0; fi

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=./_colors.sh
source "$E_BASH/_colors.sh"
# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"
# shellcheck disable=SC1090 source=./_commons.sh
source "$E_BASH/_commons.sh"
# shellcheck disable=SC1090 source=./_traps.sh
source "$E_BASH/_traps.sh"

# keep error logging enabled by default
if [[ -z ${DEBUG+x} || -z "$DEBUG" ]]; then
  export DEBUG="error"
elif [[ "$DEBUG" != *"error"* && "$DEBUG" != *"*"* && "$DEBUG" != *"-error"* ]]; then
  export DEBUG="${DEBUG},error"
fi

# declare global associative array for hooks tracking (internal)
# stores hook_name -> "1" for quick existence check
if [[ -z ${__HOOKS_DEFINED+x} ]]; then declare -g -A __HOOKS_DEFINED; fi

# declare global associative array for tracking hook contexts (internal)
# stores hook_name -> "context1|context2|context3" pipe-separated list
if [[ -z ${__HOOKS_CONTEXTS+x} ]]; then declare -g -A __HOOKS_CONTEXTS; fi

# declare global associative array for registered functions (internal)
# stores hook_name -> "friendly1:func1|friendly2:func2" pipe-separated list
if [[ -z ${__HOOKS_REGISTERED+x} ]]; then declare -g -A __HOOKS_REGISTERED; fi

# declare global associative array for middleware functions (internal)
# stores hook_name -> middleware function name
if [[ -z ${__HOOKS_MIDDLEWARE+x} ]]; then declare -g -A __HOOKS_MIDDLEWARE; fi

# declare global arrays for execution mode pattern registration (internal)
if [[ -z ${__HOOKS_SOURCE_PATTERNS+x} ]]; then declare -g -a __HOOKS_SOURCE_PATTERNS=(); fi
if [[ -z ${__HOOKS_SCRIPT_PATTERNS+x} ]]; then declare -g -a __HOOKS_SCRIPT_PATTERNS=(); fi

# declare sequence counter for capture arrays (internal)
if [[ -z ${__HOOKS_CAPTURE_SEQ+x} ]]; then declare -g __HOOKS_CAPTURE_SEQ=0; fi
if [[ -z ${__HOOKS_END_TRAP_INSTALLED+x} ]]; then declare -g __HOOKS_END_TRAP_INSTALLED="false"; fi

# default hooks directory (can be overridden)
if [[ -z ${HOOKS_DIR+x} ]]; then declare -g HOOKS_DIR="ci-cd"; fi

# default hooks function prefix
if [[ -z ${HOOKS_PREFIX+x} ]]; then declare -g HOOKS_PREFIX="hook:"; fi

# default hooks execution mode: "exec" or "source"
# exec - execute script directly (default, runs in subprocess)
# source - source script and call hook:run function (runs in current shell)
if [[ -z ${HOOKS_EXEC_MODE+x} ]]; then declare -g HOOKS_EXEC_MODE="exec"; fi
if [[ -z ${HOOKS_AUTO_TRAP+x} ]]; then declare -g HOOKS_AUTO_TRAP="true"; fi

##
## Declare available hook names for the script
##
## Parameters:
## - @ - Hook names to declare, string array, variadic
##
## Globals:
## - reads/listen: BASH_SOURCE, __HOOKS_DEFINED, __HOOKS_CONTEXTS
## - mutate/publish: __HOOKS_DEFINED, __HOOKS_CONTEXTS
##
## Side effects:
## - Registers hook names as available
## - Tracks calling context for nested/composed scripts
##
## Usage:
## - hooks:declare begin end validate process
## - hooks:declare custom_hook another_hook
##
## Returns:
## - 0 on success, 1 on invalid hook name
##
function hooks:declare() {
  local hook_name

  # Get the calling script context (the script that called hooks:declare)
  # BASH_SOURCE[0] = _hooks.sh, BASH_SOURCE[1] = calling script
  local caller_context="${BASH_SOURCE[1]:-main}"

  # Normalize context path (remove ./ prefix and resolve to absolute path if possible)
  if [[ "$caller_context" != "main" && -f "$caller_context" ]]; then
    caller_context="$(cd "$(dirname "$caller_context")" && pwd)/$(basename "$caller_context")"
  fi

  echo:Hooks "Defining hooks from context: $caller_context"
  echo:Hooks "  hooks: $*"

  # validate and register each hook
  for hook_name in "$@"; do
    # validate hook name (alphanumeric, underscore, dash only)
    if ! [[ "$hook_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      echo:Error "invalid hook name '$hook_name'. Only alphanumeric, underscore, and dash allowed."
      return 1
    fi

    # check if hook already exists from a different context
    if [[ -n ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
      # hook already defined - check contexts
      local existing_contexts="${__HOOKS_CONTEXTS[$hook_name]}"

      # check if this context already registered this hook
      if [[ "|${existing_contexts}|" == *"|${caller_context}|"* ]]; then
        echo:Hooks "  ℹ Hook '$hook_name' already registered from this context, skipping"
        continue
      fi

      # different context - warn about potential conflict
      printf "${cl_yellow}[hooks]${cl_reset} " >&2
      echo "⚠ Warning: Hook '$hook_name' is being defined from multiple contexts:" >&2
      echo "    Existing: $existing_contexts" >&2
      echo "    New:      $caller_context" >&2
      echo "  This is supported for nested/composed scripts, but verify it's intentional." >&2

      # append new context to existing list
      __HOOKS_CONTEXTS[$hook_name]="${existing_contexts}|${caller_context}"
    else
      # first time defining this hook
      __HOOKS_CONTEXTS[$hook_name]="$caller_context"
    fi

    # register the hook
    __HOOKS_DEFINED[$hook_name]=1
    echo:Hooks "  🟢 Registered hook: $hook_name (context: $caller_context)"
  done

  return 0
}

##
## Bootstrap default hooks and install EXIT trap for end hook
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: HOOKS_AUTO_TRAP
## - mutate/publish: __HOOKS_DEFINED, __HOOKS_END_TRAP_INSTALLED
##
## Side effects:
## - Declares begin/end hooks
## - Installs EXIT trap if HOOKS_AUTO_TRAP=true
##
## Usage:
## - hooks:bootstrap
##
function hooks:bootstrap() {
  hooks:declare begin end

  if [[ "${HOOKS_AUTO_TRAP:-true}" == "true" ]]; then
    _hooks:trap:end
  fi

  return 0
}

##
## Exit handler that executes the end hook
##
## Parameters:
## - exit_code - Exit code from script, integer (automatic from EXIT trap)
##
## Globals:
## - reads/listen: none
## - mutate/publish: none (calls hooks:do)
##
## Usage:
## - _hooks:on_exit $?    # typically called from EXIT trap
##
function _hooks:on_exit() {
  local exit_code=$?
  hooks:do end "$exit_code"
  return "$exit_code"
}

##
## Install EXIT trap for end hook (idempotent)
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __HOOKS_END_TRAP_INSTALLED
## - mutate/publish: __HOOKS_END_TRAP_INSTALLED
##
## Side effects:
## - Installs trap:on _hooks:on_exit EXIT
##
## Usage:
## - _hooks:trap:end
##
function _hooks:trap:end() {
  if [[ "${__HOOKS_END_TRAP_INSTALLED:-}" == "true" ]]; then
    return 0
  fi

  __HOOKS_END_TRAP_INSTALLED="true"
  trap:on _hooks:on_exit EXIT

  return 0
}

##
## Register file patterns to always execute in sourced mode
##
## Parameters:
## - @ - File patterns (wildcards supported), string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: __HOOKS_SOURCE_PATTERNS
##
## Usage:
## - hooks:pattern:source "begin-*-init.sh"
## - hooks:pattern:source "env-*.sh" "config-*.sh"
##
function hooks:pattern:source() {
  local pattern

  for pattern in "$@"; do
    __HOOKS_SOURCE_PATTERNS+=("$pattern")
    echo:Hooks "Registered pattern for sourced execution: $pattern"
  done

  return 0
}

##
## Register file patterns to always execute as scripts (not sourced)
##
## Parameters:
## - @ - File patterns (wildcards supported), string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: __HOOKS_SCRIPT_PATTERNS
##
## Usage:
## - hooks:pattern:script "end-datadog.sh"
## - hooks:pattern:script "notify-*.sh"
##
function hooks:pattern:script() {
  local pattern

  for pattern in "$@"; do
    __HOOKS_SCRIPT_PATTERNS+=("$pattern")
    echo:Hooks "Registered pattern for script execution: $pattern"
  done

  return 0
}

##
## Register a function to be executed as part of a hook
##
## Parameters:
## - hook_name - Hook name to register for, string, required
## - friendly_name - Sort key for ordering (e.g. "10-backup"), string, required
## - function_name - Function to execute, string, required
##
## Globals:
## - reads/listen: __HOOKS_DEFINED, __HOOKS_REGISTERED
## - mutate/publish: __HOOKS_REGISTERED
##
## Usage:
## - hooks:register deploy "10-backup" backup_database
## - hooks:register deploy "20-update" update_code
##
## Returns:
## - 0 on success, 1 on invalid parameters or missing function
##
function hooks:register() {
  local hook_name="$1"
  local friendly_name="$2"
  local function_name="$3"

  # Validate parameters
  if [[ -z "$hook_name" || -z "$friendly_name" || -z "$function_name" ]]; then
    echo:Error "hooks:register requires three parameters: <hook_name> <friendly_name> <function_name>"
    return 1
  fi

  # Validate function exists
  if ! declare -F "$function_name" >/dev/null 2>&1; then
    echo:Error "function '$function_name' does not exist"
    return 1
  fi

  # Check if hook is defined (optional - register anyway but warn)
  if [[ -z ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
    echo:Hooks "⚠ Registering function for undefined hook '$hook_name' (hook should be defined first)"
  fi

  # Get existing registrations for this hook
  local existing="${__HOOKS_REGISTERED[$hook_name]}"

  # Check if friendly name already exists for this hook
  if [[ -n "$existing" && "|${existing}|" == *"|${friendly_name}:"* ]]; then
    echo:Error "friendly name '$friendly_name' already registered for hook '$hook_name'"
    return 1
  fi

  # Add the new registration
  if [[ -z "$existing" ]]; then
    __HOOKS_REGISTERED[$hook_name]="${friendly_name}:${function_name}"
  else
    __HOOKS_REGISTERED[$hook_name]="${existing}|${friendly_name}:${function_name}"
  fi

  echo:Hooks "Registered function '${function_name}' as '${friendly_name}' for hook '${hook_name}'"
  return 0
}

##
## Register middleware function for a hook
##
## Parameters:
## - hook_name - Hook name for middleware, string, required
## - middleware_fn - Middleware function name (empty to reset), string, optional
##
## Globals:
## - reads/listen: __HOOKS_MIDDLEWARE
## - mutate/publish: __HOOKS_MIDDLEWARE
##
## Usage:
## - hooks:middleware begin my_middleware
## - hooks:middleware begin          # reset to default
##
## Returns:
## - 0 on success, 1 on invalid parameters or missing function
##
function hooks:middleware() {
  local hook_name="$1"
  local middleware_fn="${2:-}"

  if [[ -z "$hook_name" ]]; then
    echo:Error "hooks:middleware requires <hook> [function]"
    return 1
  fi

  if [[ -z "$middleware_fn" ]]; then
    unset "__HOOKS_MIDDLEWARE[$hook_name]"
    echo:Hooks "Reset middleware for hook '$hook_name' to default"
    return 0
  fi

  if ! declare -F "$middleware_fn" >/dev/null 2>&1; then
    echo:Error "middleware function '$middleware_fn' does not exist"
    return 1
  fi

  __HOOKS_MIDDLEWARE["$hook_name"]="$middleware_fn"
  echo:Hooks "Registered middleware '${middleware_fn}' for hook '${hook_name}'"
  return 0
}

##
## Unregister a function from a hook
##
## Parameters:
## - hook_name - Hook name, string, required
## - friendly_name - Friendly name of registration to remove, string, required
##
## Globals:
## - reads/listen: __HOOKS_REGISTERED
## - mutate/publish: __HOOKS_REGISTERED
##
## Usage:
## - hooks:unregister deploy "10-backup"
## - hooks:unregister build "metrics"
##
## Returns:
## - 0 on success, 1 on invalid parameters or not found
##
function hooks:unregister() {
  local hook_name="$1"
  local friendly_name="$2"

  # Validate parameters
  if [[ -z "$hook_name" || -z "$friendly_name" ]]; then
    echo:Error "hooks:unregister requires two parameters: <hook_name> <friendly_name>"
    return 1
  fi

  # Get existing registrations
  local existing="${__HOOKS_REGISTERED[$hook_name]}"

  if [[ -z "$existing" ]]; then
    echo:Error "no registrations found for hook '$hook_name'"
    return 1
  fi

  # Check if friendly name exists
  if [[ "|${existing}|" != *"|${friendly_name}:"* ]]; then
    echo:Error "registration '$friendly_name' not found for hook '$hook_name'"
    return 1
  fi

  # Remove the registration
  local new_registrations=""
  local entry
  IFS='|' read -ra entries <<< "$existing"
  for entry in "${entries[@]}"; do
    local entry_friendly="${entry%%:*}"
    if [[ "$entry_friendly" != "$friendly_name" ]]; then
      if [[ -z "$new_registrations" ]]; then
        new_registrations="$entry"
      else
        new_registrations="${new_registrations}|${entry}"
      fi
    fi
  done

  # Update or remove the entry
  if [[ -z "$new_registrations" ]]; then
    unset "__HOOKS_REGISTERED[$hook_name]"
  else
    __HOOKS_REGISTERED[$hook_name]="$new_registrations"
  fi

  echo:Hooks "Unregistered '${friendly_name}' from hook '${hook_name}'"
  return 0
}

##
## Determine execution mode for a specific script
##
## Parameters:
## - script_name - Script basename to check, string, required
##
## Globals:
## - reads/listen: HOOKS_EXEC_MODE, __HOOKS_SOURCE_PATTERNS, __HOOKS_SCRIPT_PATTERNS
## - mutate/publish: none
##
## Returns:
## - Echoes "source" or "exec"
##
## Usage:
## - mode=$(hooks:exec:mode "begin-init.sh")
##
function hooks:exec:mode() {
  local script_name="$1"
  local pattern

  # Check source patterns first (higher priority)
  for pattern in "${__HOOKS_SOURCE_PATTERNS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$script_name" == $pattern ]]; then
      echo "source"
      return 0
    fi
  done

  # Check script patterns
  for pattern in "${__HOOKS_SCRIPT_PATTERNS[@]}"; do
    # shellcheck disable=SC2053
    if [[ "$script_name" == $pattern ]]; then
      echo "exec"
      return 0
    fi
  done

  # Fall back to global mode
  echo "$HOOKS_EXEC_MODE"
  return 0
}

#
# Execute hook implementation with stdout/stderr capture (internal)
##
## Execute hook implementation with stdout/stderr capture (internal)
##
## Parameters:
## - hook_name - Hook name being executed, string, required
## - capture_var_name - Variable name to store capture array, string, required
## - @ - Command and arguments to execute, variadic
##
## Globals:
## - reads/listen: __HOOKS_CAPTURE_SEQ
## - mutate/publish: __HOOKS_CAPTURE_SEQ, creates global array "${hook_slug}_${seq}"
##
## External Dependencies:
## - to:slug() from _commons.sh - Generate filesystem-safe slug from hook name
##
## Side effects:
## - Creates temp files and FIFOs for capture
## - Creates background sed processes
## - Declares global array with captured output
##
## Usage:
## - _hooks:capture:run "begin" "capture_var" my_function "arg1" "arg2"
##
## Returns:
## - Exit code from executed command
##
function _hooks:capture:run() {
  local hook_name="$1"
  local capture_var_name="$2"
  shift 2

  local hook_slug
  hook_slug="$(to:slug "$hook_name" "_" 40)"
  __HOOKS_CAPTURE_SEQ=$((__HOOKS_CAPTURE_SEQ + 1))
  local capture_name="__${hook_slug}_${__HOOKS_CAPTURE_SEQ}"

  local capture_file
  capture_file="$(mktemp)" || {
    echo:Error "failed to create temp file for hook capture"
    return 1
  }

  local stdout_fifo
  local stderr_fifo
  stdout_fifo="$(mktemp)" && rm -f "$stdout_fifo" && mkfifo "$stdout_fifo" || {
    echo:Error "failed to create stdout FIFO"
    rm -f "$capture_file"
    return 1
  }
  stderr_fifo="$(mktemp)" && rm -f "$stderr_fifo" && mkfifo "$stderr_fifo" || {
    echo:Error "failed to create stderr FIFO"
    rm -f "$capture_file" "$stdout_fifo"
    return 1
  }

  sed 's/^/1: /' < "$stdout_fifo" >> "$capture_file" &
  local stdout_pid=$!
  sed 's/^/2: /' < "$stderr_fifo" >> "$capture_file" &
  local stderr_pid=$!

  "$@" > "$stdout_fifo" 2> "$stderr_fifo"
  local exit_code=$?

  wait "$stdout_pid" "$stderr_pid" || {
    echo:Error "warning: capture background processes failed"
  }
  rm -f "$stdout_fifo" "$stderr_fifo"

  declare -g -a "$capture_name"
  local -n capture_ref="$capture_name"
  capture_ref=()
  mapfile -t capture_ref < "$capture_file"
  rm -f "$capture_file"

  printf -v "$capture_var_name" '%s' "$capture_name"
  return "$exit_code"
}

##
## Default middleware for hook implementations (internal)
##
## Usage:
##   _hooks:middleware:default <hook_name> <exit_code> <capture_var> -- <hook_args...>
##
## Returns:
##   Exit code from implementation
##
function _hooks:middleware:default() {
  local hook_name="$1"
  local exit_code="$2"
  local capture_var="$3"
  shift 3

  if [[ "${1:-}" != "--" ]]; then
    echo:Error "hooks middleware expects '--' separator"
    return 1
  fi
  shift

  local -n capture_ref="$capture_var"
  local line
  for line in "${capture_ref[@]}"; do
    case "$line" in
      "1: "*) printf '%s\n' "${line#1: }" ;;
      "2: "*) printf '%s\n' "${line#2: }" >&2 ;;
      *) printf '%s\n' "$line" ;;
    esac
  done

  return "$exit_code"
}

##
## Apply contract env directive
##
## Supported forms:
##   NAME=VALUE
##   NAME+=VALUE (append)
##   NAME^=VALUE (prepend)
##   NAME-=VALUE (remove segment)
##
function _hooks:env:apply() {
  local expr="$1"
  local name op value

  if [[ "$expr" == *"+="* ]]; then
    name="${expr%%+=*}"
    value="${expr#*+=}"
    op="+="
  elif [[ "$expr" == *"^="* ]]; then
    name="${expr%%^=*}"
    value="${expr#*^=}"
    op="^="
  elif [[ "$expr" == *"-="* ]]; then
    name="${expr%%-=*}"
    value="${expr#*-=}"
    op="-="
  elif [[ "$expr" == *"="* ]]; then
    name="${expr%%=*}"
    value="${expr#*=}"
    op="="
  else
    echo:Error "invalid contract env directive '${expr}'"
    return 1
  fi

  if ! [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo:Error "invalid env var name '${name}' in contract"
    return 1
  fi

  local current="${!name-}"
  local next=""

  case "$op" in
    "=")
      next="$value"
      ;;
    "+=")
      if [[ -z "$current" ]]; then
        next="$value"
      else
        next="${current}:$value"
      fi
      ;;
    "^=")
      if [[ -z "$current" ]]; then
        next="$value"
      else
        next="${value}:$current"
      fi
      ;;
    "-=")
      if [[ -z "$current" ]]; then
        next=""
      else
        local filtered=""
        local part
        local -a _hooks_parts=()
        IFS=':' read -r -a _hooks_parts <<< "$current"
        for part in "${_hooks_parts[@]}"; do
          [[ "$part" == "$value" ]] && continue
          if [[ -z "$filtered" ]]; then
            filtered="$part"
          else
            filtered="${filtered}:$part"
          fi
        done
        next="$filtered"
      fi
      ;;
  esac

  export "${name}=${next}"

  if [[ "$name" == "DEBUG" ]]; then
    _hooks:logger:refresh
  fi

  return 0
}

##
## Refresh logger tags after DEBUG changes
##
## Called when the DEBUG environment variable is modified to reconfigure
## all registered logger tags. Iterates through TAGS associative array
## and calls config:logger:{Tag} functions if they exist.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: TAGS (associative array of registered tags)
## - mutate/publish: none (calls config functions that may modify logger state)
##
## Side effects:
## - Calls config:logger:{Tag} functions for each registered tag
##
## Usage:
## - _hooks:logger:refresh    # typically after modifying DEBUG
##
## Returns:
## - 0
##
function _hooks:logger:refresh() {
  local tag
  for tag in "${!TAGS[@]}"; do
    local suffix="${tag^}"
    if declare -F "config:logger:${suffix}" >/dev/null 2>&1; then
      "config:logger:${suffix}" 2>/dev/null
    fi
  done
}

##
## Middleware: contract-based modes and flow directives (internal)
##
## Processes hook implementation output to extract and execute contract directives.
## Supports environment variable modification, routing, and exit directives.
##
## Parameters:
## - hook_name - Hook name being executed, string, required
## - exit_code - Exit code from implementation, integer, required
## - capture_var - Name of array variable containing captured output, string, required
## - -- - Separator (required literal), string, required
## - @ - Hook arguments (ignored), variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: __HOOKS_FLOW_ROUTE, __HOOKS_FLOW_TERMINATE, __HOOKS_FLOW_EXIT_CODE
##
## Contract Directives (output from hook implementations):
## - contract:env:NAME=VALUE - Set environment variable
## - contract:env:NAME+=VALUE - Append to PATH-like variable
## - contract:env:NAME^=VALUE - Prepend to PATH-like variable
## - contract:env:NAME-=VALUE - Remove segment from PATH-like variable
## - contract:route:/path/to/script - Route execution to another script
## - contract:exit:42 - Exit with specified code
##
## Usage:
## - _hooks:middleware:modes "deploy" 0 "capture_var" -- "$@"
##
## Returns:
## - Original exit code from implementation
##
## See Also:
## - _hooks:env:apply - Environment variable contract implementation
## - hooks:flow:apply - Executes flow directives set by this middleware
##
function _hooks:middleware:modes() {
  local hook_name="$1"
  local exit_code="$2"
  local capture_var="$3"

  # we ignore all other arguments, they are not used
  echo:Hooks "middleware is processing hook: '${hook_name}'"

  # shellcheck disable=SC2178
  local -n capture_ref="$capture_var"
  echo:Hooks "total captured lines for '${hook_name}': ${#capture_ref[@]}"

  local line payload
  for line in "${capture_ref[@]}"; do
    payload=""
    case "$line" in
      "1: "*)
        # payload allowed only from STDOUT stream
        payload="${line#1: }"
        printf '%s\n' "$payload"
        ;;
      # stderr we just re-print as is, just remove the prefix `2: `
      "2: "*) printf '%s\n' "${line#2: }" >&2 ;;
    esac

    if [[ "$payload" == contract:* ]]; then
      case "$payload" in
        # modify env variable one per line
        contract:env:*)
          _hooks:env:apply "${payload#contract:env:}"
          ;;
        # route execution to another script
        contract:route:*)
          export __HOOKS_FLOW_ROUTE="${payload#contract:route:}"
          export __HOOKS_FLOW_TERMINATE="true"
          ;;
        # exit with specified code
        contract:exit:*)
          export __HOOKS_FLOW_EXIT_CODE="${payload#contract:exit:}"
          export __HOOKS_FLOW_TERMINATE="true"
          ;;
        # unknown directive, show error for user
        *)
          echo:Error "unknown contract directive '${payload}'"
          ;;
      esac
    fi
  done

  return "$exit_code"
}

##
## Apply flow directives from middleware (route, exit)
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __HOOKS_FLOW_TERMINATE, __HOOKS_FLOW_ROUTE, __HOOKS_FLOW_EXIT_CODE
## - mutate/publish: none (may exit or source route script)
##
## Side effects:
## - May exit with code if __HOOKS_FLOW_TERMINATE=true
## - May source route script if __HOOKS_FLOW_ROUTE set
##
## Usage:
## - hooks:flow:apply    # call after hook execution
##
function hooks:flow:apply() {
  if [[ "${__HOOKS_FLOW_TERMINATE:-}" != "true" ]]; then
    return 0
  fi

  if [[ -n "${__HOOKS_FLOW_ROUTE:-}" ]]; then
    # TODO: should it be source or script run mode?

    # shellcheck disable=SC1090
    source "${__HOOKS_FLOW_ROUTE}"
  fi

  exit "${__HOOKS_FLOW_EXIT_CODE:-0}"
}

##
## Execute a hook and all its implementations
##
## Parameters:
## - hook_name - Hook name to execute, string, required
## - @ - Additional parameters to pass to implementations, variadic
##
## Globals:
## - reads/listen: __HOOKS_DEFINED, __HOOKS_REGISTERED, HOOKS_DIR,
##                 HOOKS_PREFIX, HOOKS_EXEC_MODE, __HOOKS_SOURCE_PATTERNS,
##                 __HOOKS_SCRIPT_PATTERNS, __HOOKS_MIDDLEWARE
## - mutate/publish: none (calls hook implementations)
##
## Side effects:
## - Executes hook:hook_name function if exists
## - Executes all registered functions in alphabetical order
## - Executes all matching scripts in HOOKS_DIR
## - Calls middleware for output processing
##
## Execution order:
## 1. Check if hook is defined via hooks:declare
## 2. Execute function hook:{name} if it exists
## 3. Execute registered functions (hooks:register) in alphabetical order
## 4. Find and execute matching scripts in HOOKS_DIR/{hook_name}-*.sh or {hook_name}_*.sh
## 5. Scripts execute in alphabetical order
##
## Script naming patterns:
## - {hook_name}-{purpose}.sh
## - {hook_name}_{NN}_{purpose}.sh (recommended for ordered execution)
##
## Execution modes (controlled by HOOKS_EXEC_MODE):
## - "exec" (default): Scripts execute in subprocess
## - "source": Scripts sourced, hook:run function called
##
## Logging:
## - Enable with DEBUG=hooks or DEBUG=* to see execution flow
##
## Usage:
## - hooks:do begin
## - hooks:do decide param1 param2
## - result=$(hooks:do decide "question")
##
## Returns:
## - Last hook's exit code or 0 if not implemented
##
function hooks:do() {
  local hook_name="$1"
  shift

  local last_exit_code=0
  local impl_count=0

  # check if hook is defined
  if [[ -z ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
    echo:Hooks "Hook '$hook_name' not defined, skipping"
    return 0
  fi

  echo:Hooks "Executing hook: $hook_name"
  local middleware_fn="${__HOOKS_MIDDLEWARE[$hook_name]:-_hooks:middleware:default}"
  echo:Hooks "  Using middleware: $middleware_fn"

  # execute function implementation first: hook:{name}
  local func_name="${HOOKS_PREFIX}${hook_name}"
  if declare -F "$func_name" >/dev/null 2>&1; then
    echo:Hooks "  → [function] ${func_name}"
    local capture_var=""
    _hooks:capture:run "$hook_name" capture_var "$func_name" "$@"
    local capture_exit=$?
    "$middleware_fn" "$hook_name" "$capture_exit" "$capture_var" -- "$@"
    last_exit_code=$?
    echo:Hooks "    ↳ exit code: $last_exit_code"
    ((impl_count++))
  fi

  # execute registered functions and scripts in a single alphabetical sequence
  local registered="${__HOOKS_REGISTERED[$hook_name]}"
  local -a merged_impls=()
  local reg_count=0
  local script_count=0

  if [[ -n "$registered" ]]; then
    local entry
    IFS='|' read -ra entries <<< "$registered"
    reg_count=${#entries[@]}
    echo:Hooks "  Found ${reg_count} registered function(s) for hook '$hook_name'"
    for entry in "${entries[@]}"; do
      local friendly="${entry%%:*}"
      local func="${entry#*:}"
      merged_impls+=("${friendly}|registered|${func}|${friendly}")
    done
  fi

  if [[ -d "$HOOKS_DIR" ]]; then
    local -a hook_scripts=()

    while IFS= read -r -d '' script; do
      if [[ -x "$script" ]]; then
        hook_scripts+=("$script")
      fi
    done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -print0 2>/dev/null | sort -z)

    script_count=${#hook_scripts[@]}
    if [[ $script_count -gt 0 ]]; then
      echo:Hooks "  Found ${script_count} script(s) for hook '$hook_name'"
      for script in "${hook_scripts[@]}"; do
        local script_name
        local sort_key
        script_name=$(basename "$script")
        sort_key="$script_name"
        if [[ "$script_name" == "${hook_name}-"* ]]; then
          sort_key="${script_name#${hook_name}-}"
        elif [[ "$script_name" == "${hook_name}_"* ]]; then
          sort_key="${script_name#${hook_name}_}"
        fi
        sort_key="${sort_key%.sh}"
        merged_impls+=("${sort_key}|script|${script}|${script_name}")
      done
    fi
  fi

  if [[ ${#merged_impls[@]} -gt 0 ]]; then
    IFS=$'\n' merged_impls=($(sort <<<"${merged_impls[*]}"))
    unset IFS

    local reg_num=0
    local script_num=0
    for entry in "${merged_impls[@]}"; do
      local sort_key
      local impl_type
      local target
      local label
      IFS='|' read -r sort_key impl_type target label <<< "$entry"

      if [[ "$impl_type" == "registered" ]]; then
        ((reg_num++))
        if declare -F "$target" >/dev/null 2>&1; then
          echo:Hooks "  → [registered $reg_num/$reg_count] ${label} → ${target}()"
          local capture_var=""
          _hooks:capture:run "$hook_name" capture_var "$target" "$@"
          local capture_exit=$?
          "$middleware_fn" "$hook_name" "$capture_exit" "$capture_var" -- "$@"
          last_exit_code=$?
          echo:Hooks "    ↳ exit code: $last_exit_code"
          ((impl_count++))
        else
          echo:Hooks "  ⚠ [registered $reg_num/$reg_count] ${label} → function ${target}() not found, skipping"
        fi
        continue
      fi

      ((script_num++))
      local exec_mode
      exec_mode=$(hooks:exec:mode "$label")

      if [[ "$exec_mode" == "source" ]]; then
        echo:Hooks "  → [script $script_num/${script_count}] ${label} (sourced mode)"
        # shellcheck disable=SC1090
        source "$target"
        if declare -F "hook:run" >/dev/null 2>&1; then
          hook:run "$@"
          last_exit_code=$?
        else
          echo:Hooks "    ⚠ No hook:run function found in ${label}, skipping"
          last_exit_code=0
        fi
      else
        echo:Hooks "  → [script $script_num/${script_count}] ${label} (exec mode)"
        local capture_var=""
        _hooks:capture:run "$hook_name" capture_var "$target" "$@"
        local capture_exit=$?
        "$middleware_fn" "$hook_name" "$capture_exit" "$capture_var" -- "$@"
        last_exit_code=$?
      fi

      echo:Hooks "    ↳ exit code: $last_exit_code"
      ((impl_count++))
    done
  fi

  if [[ $impl_count -eq 0 ]]; then
    echo:Hooks "  ⚪ No implementations found for hook '$hook_name'"
  else
    echo:Hooks "  🟢 Completed hook '$hook_name' (${impl_count} implementation(s), final exit code: $last_exit_code)"
  fi

  return $last_exit_code
}

##
## Execute a hook with forced sourced mode (overrides HOOKS_EXEC_MODE)
##
## Parameters:
## - hook_name - Hook name to execute, string, required
## - @ - Additional parameters, variadic
##
## Globals:
## - reads/listen: HOOKS_EXEC_MODE
## - mutate/publish: HOOKS_EXEC_MODE (temporarily sets to "source")
##
## Usage:
## - hooks:do:source begin
## - hooks:do:source deploy param1 param2
##
## Returns:
## - Last hook's exit code or 0 if not implemented
##
function hooks:do:source() {
  local saved_mode="$HOOKS_EXEC_MODE"
  HOOKS_EXEC_MODE="source"

  echo:Hooks "Call-level override: forcing sourced mode for this hook execution"
  hooks:do "$@"
  local exit_code=$?

  HOOKS_EXEC_MODE="$saved_mode"
  return $exit_code
}

##
## Execute a hook with forced exec mode (overrides HOOKS_EXEC_MODE)
##
## Parameters:
## - hook_name - Hook name to execute, string, required
## - @ - Additional parameters, variadic
##
## Globals:
## - reads/listen: HOOKS_EXEC_MODE
## - mutate/publish: HOOKS_EXEC_MODE (temporarily sets to "exec")
##
## Usage:
## - hooks:do:script end
## - hooks:do:script notify url status
##
## Returns:
## - Last hook's exit code or 0 if not implemented
##
function hooks:do:script() {
  local saved_mode="$HOOKS_EXEC_MODE"
  HOOKS_EXEC_MODE="exec"

  echo:Hooks "Call-level override: forcing exec mode for this hook execution"
  hooks:do "$@"
  local exit_code=$?

  HOOKS_EXEC_MODE="$saved_mode"
  return $exit_code
}

##
## List all defined hooks and their implementations
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __HOOKS_DEFINED, __HOOKS_REGISTERED,
##                 HOOKS_PREFIX, HOOKS_DIR
## - mutate/publish: none
##
## Usage:
## - hooks:list
##
## Returns:
## - 0, prints hooks and implementations to stdout
##
function hooks:list() {
  local hook_name

  if [[ ${#__HOOKS_DEFINED[@]} -eq 0 ]]; then
    echo "No hooks defined"
    return 0
  fi

  echo "Defined hooks:"
  for hook_name in "${!__HOOKS_DEFINED[@]}"; do
    local implementations=()

    # check if implemented as function
    local func_name="${HOOKS_PREFIX}${hook_name}"
    if declare -F "$func_name" >/dev/null 2>&1; then
      implementations+=("function")
    fi

    # check for registered functions
    local registered="${__HOOKS_REGISTERED[$hook_name]}"
    if [[ -n "$registered" ]]; then
      local reg_count=$(echo "$registered" | tr '|' '\n' | wc -l | tr -d ' ')
      implementations+=("${reg_count} registered")
    fi

    # check for script implementations
    if [[ -d "$HOOKS_DIR" ]]; then
      local script_count=0
      while IFS= read -r -d '' script; do
        if [[ -x "$script" ]]; then
          ((script_count++))
        fi
      done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -print0 2>/dev/null)

      if [[ $script_count -gt 0 ]]; then
        implementations+=("${script_count} script(s)")
      fi
    fi

    # get context info
    local contexts="${__HOOKS_CONTEXTS[$hook_name]:-unknown}"
    local context_count=$(echo "$contexts" | tr '|' '\n' | wc -l | tr -d ' ')

    # format output
    if [[ ${#implementations[@]} -eq 0 ]]; then
      echo "  - $hook_name: not implemented"
    else
      local impl_str=$(IFS=', '; echo "${implementations[*]}")
      echo "  - $hook_name: implemented ($impl_str)"
    fi

    # show context info if multiple contexts
    if [[ $context_count -gt 1 ]]; then
      echo "      ${cl_yellow}⚠ defined in $context_count contexts${cl_reset}"
    fi
  done

  return 0
}

##
## Check if a hook is defined
##
## Parameters:
## - hook_name - Hook name to check, string, required
##
## Globals:
## - reads/listen: __HOOKS_DEFINED
## - mutate/publish: none
##
## Usage:
## - if hooks:known begin; then echo "begin hook defined"; fi
##
## Returns:
## - 0 if hook is defined, 1 otherwise
##
function hooks:known() {
  local hook_name="$1"

  if [[ -n ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
    return 0
  fi

  return 1
}

##
## Check if a hook has any implementation (function or script)
##
## Parameters:
## - hook_name - Hook name to check, string, required
##
## Globals:
## - reads/listen: HOOKS_PREFIX, HOOKS_DIR, __HOOKS_REGISTERED
## - mutate/publish: none
##
## Usage:
## - if hooks:runnable begin; then echo "has implementation"; fi
##
## Returns:
## - 0 if hook has implementation, 1 otherwise
##
function hooks:runnable() {
  local hook_name="$1"

  # check for function implementation
  local func_name="${HOOKS_PREFIX}${hook_name}"
  if declare -F "$func_name" >/dev/null 2>&1; then
    return 0
  fi

  # check for script implementations (any matching pattern)
  if [[ -d "$HOOKS_DIR" ]]; then
    local script_count=0
    while IFS= read -r -d '' script; do
      if [[ -x "$script" ]]; then
        ((script_count++))
        break  # found at least one, no need to count all
      fi
    done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -print0 2>/dev/null)

    if [[ $script_count -gt 0 ]]; then
      return 0
    fi
  fi

  return 1
}

##
## Reset all hooks module state (for testing)
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: none
## - mutate/publish: __HOOKS_DEFINED, __HOOKS_CONTEXTS, __HOOKS_REGISTERED,
##                  __HOOKS_MIDDLEWARE, __HOOKS_SOURCE_PATTERNS,
##                  __HOOKS_SCRIPT_PATTERNS, __HOOKS_CAPTURE_SEQ,
##                  __HOOKS_END_TRAP_INSTALLED, HOOKS_DIR, HOOKS_PREFIX,
##                  HOOKS_EXEC_MODE, HOOKS_AUTO_TRAP
##
## Side effects:
## - Unsets and redeclares all global arrays/variables
## - Resets to default values
##
## Usage:
## - hooks:reset    # typically in test teardown
##
function hooks:reset() {
  # Properly unset and re-declare arrays to ensure correct types
  unset __HOOKS_DEFINED
  unset __HOOKS_CONTEXTS
  unset __HOOKS_REGISTERED
  unset __HOOKS_MIDDLEWARE
  unset __HOOKS_SOURCE_PATTERNS
  unset __HOOKS_SCRIPT_PATTERNS
  unset __HOOKS_CAPTURE_SEQ
  unset __HOOKS_END_TRAP_INSTALLED
  
  # Re-declare as associative arrays
  declare -g -A __HOOKS_DEFINED
  declare -g -A __HOOKS_CONTEXTS
  declare -g -A __HOOKS_REGISTERED
  declare -g -A __HOOKS_MIDDLEWARE
  declare -g __HOOKS_CAPTURE_SEQ=0
  declare -g __HOOKS_END_TRAP_INSTALLED="false"
  
  # Re-declare as indexed arrays
  declare -g -a __HOOKS_SOURCE_PATTERNS=()
  declare -g -a __HOOKS_SCRIPT_PATTERNS=()
  
  # Reset configuration to defaults
  HOOKS_DIR="ci-cd"
  HOOKS_PREFIX="hook:"
  HOOKS_EXEC_MODE="exec"
  HOOKS_AUTO_TRAP="true"
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
# DO NOT allow execution of code below this line in shellspec tests
${__SOURCED__:+return}

# Initialize logger for hooks (disabled by default, enable with DEBUG=hooks or DEBUG=*)
# Output to stderr for traceability (user output goes to stdout, logging to stderr)
logger:init hooks "${cl_grey}[hooks]${cl_reset} " ">&2"

# Initialize logger for modes (disabled by default, enable with DEBUG=modes or DEBUG=*)
logger:init modes "${cl_yellow}[modes]${cl_reset} " ">&2"

# initialize error logger early (used by error paths)
logger:init error "${cl_red}[error]${cl_reset} " ">&2"

hooks:bootstrap

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

: # Ensure successful exit code (echo:Loader returns 1 when debug disabled)

##
## Module: Extensibility and Lifecycle Hooks System
##
## This module provides a declarative hooks system for script extension points.
##
## References:
## - demo: demo.hooks.sh, demo.hooks-logging.sh, demo.hooks-nested.sh,
##        demo.hooks-registration.sh, ci-mode/demo.ci-modes.sh,
##        ci-mode/ci-10-compile.sh, ci-mode/ci-20-compile.sh
## - bin: npm.versions.sh (uses hooks for extensibility)
## - documentation: docs/public/hooks.md
## - tests: spec/hooks_spec.sh
##
## External Dependencies:
## - _traps.sh - trap:on for EXIT trap installation
## - _commons.sh - to:slug() for creating filesystem-safe slugs
##
## Globals:
## - E_BASH - Path to .scripts directory
## - DEBUG - Always includes "error" when this module loads
## - HOOKS_DIR - Hooks scripts directory, default: "ci-cd"
## - HOOKS_PREFIX - Hook function prefix, default: "hook:"
## - HOOKS_EXEC_MODE - Execution mode ("exec" or "source"), default: "exec"
## - HOOKS_AUTO_TRAP - Auto-install EXIT trap, default: "true"
## - __HOOKS_DEFINED - Associative array: hook name -> existence
## - __HOOKS_CONTEXTS - Associative array: hook name -> pipe-separated contexts
## - __HOOKS_REGISTERED - Associative array: hook name -> "friendly:func|friendly2:func2"
## - __HOOKS_MIDDLEWARE - Associative array: hook name -> middleware function
## - __HOOKS_SOURCE_PATTERNS - Array of patterns for forced sourced mode
## - __HOOKS_SCRIPT_PATTERNS - Array of patterns for forced exec mode
## - __HOOKS_CAPTURE_SEQ - Counter for capture array naming
## - __HOOKS_END_TRAP_INSTALLED - Whether EXIT trap for end hook is installed
## - __HOOKS_FLOW_ROUTE - Routing directive from middleware
## - __HOOKS_FLOW_TERMINATE - Whether to terminate execution
## - __HOOKS_FLOW_EXIT_CODE - Exit code directive
##
## Hook Implementation Types:
## 1. Function: hook:hook_name() - direct function implementation
## 2. Registered: hooks:register hook_name "friendly" function_name
## 3. Script: HOOKS_DIR/{hook_name}-*.sh or {hook_name}_*.sh
##
## Script Naming:
## - {hook_name}-{purpose}.sh - basic script
## - {hook_name}_{NN}_{purpose}.sh - ordered script (recommended)
## - Scripts must be executable (+x)
##
## Contract Directives (output from hooks to middleware):
## - contract:env:NAME=VALUE - Set environment variable
## - contract:env:NAME+=VALUE - Append to PATH-like variable
## - contract:env:NAME^=VALUE - Prepend to PATH-like variable
## - contract:env:NAME-=VALUE - Remove segment from PATH-like variable
## - contract:route:/path/to/script.sh - Route to another script
## - contract:exit:42 - Exit with code
##