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
## Purpose: Provide the `hooks:declare` helper for hooks declare operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: Z0, __HOOKS_CONTEXTS, __HOOKS_DEFINED.
## 
## Usage:
## - hooks:declare "$@"
## - # Conditional usage pattern
## - if hooks:declare "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:bootstrap` helper for hooks bootstrap operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: HOOKS_AUTO_TRAP.
## 
## Usage:
## - hooks:bootstrap "$@"
## - # Conditional usage pattern
## - if hooks:bootstrap "$@"; then :; fi
## 
## 
function hooks:bootstrap() {
  hooks:declare begin end

  if [[ "${HOOKS_AUTO_TRAP:-true}" == "true" ]]; then
    _hooks:trap:end
  fi

  return 0
}

## 
## Purpose: Provide the `_hooks:on_exit` helper for  hooks on exit operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: no module globals detected.
## 
## Usage:
## - _hooks:on_exit "$@"
## - # Conditional usage pattern
## - if _hooks:on_exit "$@"; then :; fi
## 
## 
function _hooks:on_exit() {
  local exit_code=$?
  hooks:do end "$exit_code"
  return "$exit_code"
}

## 
## Purpose: Provide the `_hooks:trap:end` helper for  hooks trap end operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: EXIT, __HOOKS_END_TRAP_INSTALLED.
## 
## Usage:
## - _hooks:trap:end "$@"
## - # Conditional usage pattern
## - if _hooks:trap:end "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:pattern:source` helper for hooks pattern source operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: __HOOKS_SOURCE_PATTERNS.
## 
## Usage:
## - hooks:pattern:source "$@"
## - # Conditional usage pattern
## - if hooks:pattern:source "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:pattern:script` helper for hooks pattern script operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: __HOOKS_SCRIPT_PATTERNS.
## 
## Usage:
## - hooks:pattern:script "$@"
## - # Conditional usage pattern
## - if hooks:pattern:script "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:register` helper for hooks register operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## - $2 - secondary argument.
## - $3 - tertiary argument.
## 
## Globals:
## - Reads and mutates: __HOOKS_DEFINED, __HOOKS_REGISTERED.
## 
## Usage:
## - hooks:register "$@"
## - # Conditional usage pattern
## - if hooks:register "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:middleware` helper for hooks middleware operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: __HOOKS_MIDDLEWARE.
## 
## Usage:
## - hooks:middleware "$@"
## - # Conditional usage pattern
## - if hooks:middleware "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:unregister` helper for hooks unregister operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## - $2 - secondary argument.
## 
## Globals:
## - Reads and mutates: __HOOKS_REGISTERED.
## 
## Usage:
## - hooks:unregister "$@"
## - # Conditional usage pattern
## - if hooks:unregister "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:exec:mode` helper for hooks exec mode operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: HOOKS_EXEC_MODE, __HOOKS_SCRIPT_PATTERNS, __HOOKS_SOURCE_PATTERNS.
## 
## Usage:
## - hooks:exec:mode "$@"
## - # Conditional usage pattern
## - if hooks:exec:mode "$@"; then :; fi
## 
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

## 
## Purpose: Provide the `_hooks:capture:run` helper for  hooks capture run operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## - $2 - secondary argument.
## 
## Globals:
## - Reads and mutates: FIFO, __HOOKS_CAPTURE_SEQ.
## 
## Usage:
## - _hooks:capture:run "$@"
## - # Conditional usage pattern
## - if _hooks:capture:run "$@"; then :; fi
## 
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
## Purpose: Provide the `_hooks:middleware:default` helper for  hooks middleware default operations within this module.
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
## - _hooks:middleware:default "$@"
## - # Conditional usage pattern
## - if _hooks:middleware:default "$@"; then :; fi
## 
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
## Purpose: Provide the `_hooks:env:apply` helper for  hooks env apply operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: DEBUG.
## 
## Usage:
## - _hooks:env:apply "$@"
## - # Conditional usage pattern
## - if _hooks:env:apply "$@"; then :; fi
## 
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
## Purpose: Provide the `_hooks:logger:refresh` helper for  hooks logger refresh operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: TAGS.
## 
## Usage:
## - _hooks:logger:refresh "$@"
## - # Conditional usage pattern
## - if _hooks:logger:refresh "$@"; then :; fi
## 
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
## Purpose: Provide the `_hooks:middleware:modes` helper for  hooks middleware modes operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## - $2 - secondary argument.
## - $3 - tertiary argument.
## 
## Globals:
## - Reads and mutates: STDOUT, __HOOKS_FLOW_EXIT_CODE, __HOOKS_FLOW_ROUTE, __HOOKS_FLOW_TERMINATE.
## 
## Usage:
## - _hooks:middleware:modes "$@"
## - # Conditional usage pattern
## - if _hooks:middleware:modes "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:flow:apply` helper for hooks flow apply operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: __HOOKS_FLOW_EXIT_CODE, __HOOKS_FLOW_ROUTE, __HOOKS_FLOW_TERMINATE.
## 
## Usage:
## - hooks:flow:apply "$@"
## - # Conditional usage pattern
## - if hooks:flow:apply "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:do` helper for hooks do operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: HOOKS_DIR, HOOKS_PREFIX, __HOOKS_DEFINED, __HOOKS_MIDDLEWARE, __HOOKS_REGISTERED.
## 
## Usage:
## - hooks:do "$@"
## - # Conditional usage pattern
## - if hooks:do "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:do:source` helper for hooks do source operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: HOOKS_EXEC_MODE.
## 
## Usage:
## - hooks:do:source "$@"
## - # Conditional usage pattern
## - if hooks:do:source "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:do:script` helper for hooks do script operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: HOOKS_EXEC_MODE.
## 
## Usage:
## - hooks:do:script "$@"
## - # Conditional usage pattern
## - if hooks:do:script "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:list` helper for hooks list operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: HOOKS_DIR, HOOKS_PREFIX, __HOOKS_CONTEXTS, __HOOKS_DEFINED, __HOOKS_REGISTERED.
## 
## Usage:
## - hooks:list "$@"
## - # Conditional usage pattern
## - if hooks:list "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:known` helper for hooks known operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: __HOOKS_DEFINED.
## 
## Usage:
## - hooks:known "$@"
## - # Conditional usage pattern
## - if hooks:known "$@"; then :; fi
## 
## 
function hooks:known() {
  local hook_name="$1"

  if [[ -n ${__HOOKS_DEFINED[$hook_name]+x} ]]; then
    return 0
  fi

  return 1
}

## 
## Purpose: Provide the `hooks:runnable` helper for hooks runnable operations within this module.
## 
## Parameters:
## - $1 - primary argument (see usage samples).
## 
## Globals:
## - Reads and mutates: HOOKS_DIR, HOOKS_PREFIX.
## 
## Usage:
## - hooks:runnable "$@"
## - # Conditional usage pattern
## - if hooks:runnable "$@"; then :; fi
## 
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
## Purpose: Provide the `hooks:reset` helper for hooks reset operations within this module.
## 
## Parameters:
## - (varargs) - forwards all arguments to internal helpers.
## 
## Globals:
## - Reads and mutates: HOOKS_AUTO_TRAP, HOOKS_DIR, HOOKS_EXEC_MODE, HOOKS_PREFIX, __HOOKS_CAPTURE_SEQ,
##   __HOOKS_CONTEXTS, __HOOKS_DEFINED, __HOOKS_END_TRAP_INSTALLED, __HOOKS_MIDDLEWARE, __HOOKS_REGISTERED,
##   __HOOKS_SCRIPT_PATTERNS, __HOOKS_SOURCE_PATTERNS.
__HOOKS_CONTEXTS, __HOOKS_DEFINED, __HOOKS_END_TRAP_INSTALLED, ....
## 
## Usage:
## - hooks:reset "$@"
## - # Conditional usage pattern
## - if hooks:reset "$@"; then :; fi
## 
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


## Module notes: global variables, docs, and usage references.
## Links:
## - docs/public/hooks.md.
## - demos/demo.hooks-nested.sh.
## - README.md (Hooks section).
## - docs/public/functions-docgen.md.
