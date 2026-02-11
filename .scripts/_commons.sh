#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# is allowed to use macOS extensions (script can be executed in *nix second)
use_macos_extensions=false
if [[ "$OSTYPE" == "darwin"* ]]; then use_macos_extensions=true; fi

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090  source=./_colors.sh
source "$E_BASH/_colors.sh"

# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

##
## Get current epoch timestamp with microsecond precision
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: EPOCHREALTIME
## - mutate/publish: none
##
## Returns:
## - Echoes timestamp string
##
## Usage:
## - start=$(time:now)
## - time:diff "$start"
##
function time:now() {
  echo "$EPOCHREALTIME" # <~ bash 5.0
  #python -c 'import datetime; print datetime.datetime.now().strftime("%s.%f")'
}

##
## Calculate time difference from given start timestamp
##
## Parameters:
## - start - Start timestamp from time:now, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes time difference in seconds
##
## Usage:
## - start=$(time:now); sleep 1; time:diff "$start"
##
function time:diff() {
  local diff="$(time:now) - $1"
  bc <<<$diff
}

# ref: https://unix.stackexchange.com/questions/88296/get-vertical-cursor-position

##
## Get cursor position in "row;col" format
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes "row;col" position
##
## Usage:
## - pos=$(cursor:position)
##
function cursor:position() {
  local CURPOS
  read -sdR -p $'\E[6n' CURPOS
  CURPOS=${CURPOS#*[} # Strip decoration characters <ESC>[
  echo "${CURPOS}"    # Return position in "row;col" format
}

##
## Get cursor row position
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes row number
##
## Usage:
## - row=$(cursor:position:row)
##
function cursor:position:row() {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${ROW#*[}"
}

##
## Get cursor column position
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes column number
##
## Usage:
## - col=$(cursor:position:col)
##
function cursor:position:col() {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${COL}"
}

# ref: https://stackoverflow.com/questions/10679188/casing-arrow-keys-in-bash

##
## Read user password input with masking and line editing
##
## Parameters:
## - none (interactive input from terminal)
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Side effects:
## - Reads from terminal with arrow key navigation
## - Masks input as asterisks
##
## Returns:
## - Echoes entered password
##
## Usage:
## - password=$(input:readpwd)
##
function input:readpwd() {
  # tput sc # Save cursor position
  local y_pos=$(cursor:position:row) x_pos=$(cursor:position:col) max_col=$(tput cols)
  local PWORD='' pos=0 max_length=0
  echo:Common "$x_pos;$y_pos"

  local hint="${cl_grey}(→,←,↑,↓,↵,Esc,⌫,^U)${cl_reset}"
  local distance=$((max_col - x_pos - ${#hint} - 4))
  local filler=$(printf ' %.0s' $(seq 1 $distance))

  function home() {
    tput cup $((y_pos - 1)) $((x_pos - 1)) 1>&2
    pos=0
  }
  function endline() {
    tput cup $((y_pos - 1)) $((x_pos + ${#PWORD} - 1)) 1>&2
    pos=${#PWORD}
  }
  function reprint() {
    tput cup $((y_pos - 1)) $((x_pos - 1)) 1>&2
    echo -n "$1" 1>&2
    tput cup $((y_pos - 1)) $((x_pos + pos - 1)) 1>&2
  }
  function add() {
    PWORD+="$1"
    echo -n "$(echo "$1" | sed 's/./\*/g')" 1>&2
    pos=$((pos + ${#1}))
  }
  function delete() {
    # pos is more than 0
    if [ "$pos" -gt 0 ]; then
      reprint "$filler$hint"
      # remove c0 at the specified position
      PWORD="${PWORD:0:pos-1}${PWORD:pos}" && pos=$((pos - 1))
      reprint "$(echo "$PWORD" | sed 's/./\*/g')"
    fi
  }
  function reset() {
    reprint "$filler$hint"
    PWORD='' && pos=0
    reprint "$(echo "$PWORD" | sed 's/./\*/g')"
  }
  function left() {
    if [ "$pos" -gt 0 ]; then
      pos=$((pos - 1))
      tput cub 1 1>&2
    fi
  }
  function right() {
    if [ "$pos" -lt "${#PWORD}" ]; then
      pos=$((pos + 1))
      tput cuf 1 1>&2
    fi
  }

  reprint "$filler$hint"

  local key
  while :; do
    echo:Common "- $PWORD,$pos"

    key=$(_input:read-key)
    echo:Common "key: $key"

    case "$key" in
    up | home)     home ;;
    down | end)    endline ;;
    right)         right ;;
    left)          left ;;
    enter)         break ;;
    backspace)     delete ;;
    escape)        reset ;;
    ctrl-u)        reset ;;
    char:*)        add "${key#char:}" ;;
    *)             ;; # Ignore all other keys
    esac
  done
  # tput rc # Restore cursor position

  echo "${PWORD}"
}

# shellcheck disable=SC2086
##
## Generic input validation with prompt and retry
##
## Parameters:
## - variable - Variable name to store result, string, required
## - default - Default value to suggest, string, default: ""
## - hint - Prompt text to display, string, default: ""
##
## Globals:
## - reads/listen: use_macos_extensions, cl_purple, cl_reset, cl_blue
## - mutate/publish: creates global variable named by first parameter
##
## Side effects:
## - Sets trap for SIGINT during read operation
##
## Returns:
## - 0 on success
## - Sets variable to user input or default value
##
## Usage:
## - validate:input result "default" "Enter value"
##
function validate:input() {
  local variable=$1
  local default=${2:-""}
  local hint=${3:-""}
  local user_in=""

  local ask="${cl_purple}? ${cl_reset}${hint}${cl_blue}"

  # Ctrl+C during read operation force error exit
  trap 'exit 1' SIGINT

  # execute at least once
  while :; do
    # allow macOs read command extension usage (default value -i)
    if $use_macos_extensions; then
      [[ -z "${hint// /}" ]] || read -r -e -i "${default}" -p "$ask" user_in
      [[ -n "${hint// /}" ]] || read -r -e -i "${default}" user_in
    else
      [[ -z "${hint// /}" ]] || echo "$ask"
      read -r user_in
    fi
    printf "${cl_reset}"
    [[ -z "${user_in// /}" ]] || break
  done

  local __resultvar=$variable
  eval $__resultvar="'$user_in'"
}

# shellcheck disable=SC2086
##
## Masked input validation (password-style prompt with asterisks)
##
## Parameters:
## - variable - Variable name to store result, string, required
## - default - Default value to suggest, string, default: ""
## - hint - Prompt text to display, string, default: ""
##
## Globals:
## - reads/listen: use_macos_extensions, cl_purple, cl_reset, cl_blue
## - mutate/publish: creates global variable named by first parameter
##
## Side effects:
## - Displays input as asterisks, supports arrow key navigation
##
## Returns:
## - 0 on success
## - Sets variable to user input (masked during entry)
##
## Usage:
## - validate:input:masked password "" "Enter password"
##
function validate:input:masked() {
  local variable=$1
  local default=${2:-""}
  local hint=${3:-""}
  local user_in=""

  local ask="${cl_purple}? ${cl_reset}${hint}${cl_blue}"

  while :; do
    [[ -z "${hint// /}" ]] || echo -n "$ask"
    local user_in=$(input:readpwd)
    printf "${cl_reset}\n"
    [[ -z "${user_in// /}" ]] || break
  done

  local __resultvar=$variable
  eval $__resultvar="'$user_in'"
}

# shellcheck disable=SC2086,SC2059
##
## Prompt user for yes/no input and store as boolean value
##
## Parameters:
## - variable - Variable name to store result (passed by reference), string, required
## - default - Default value to suggest, string, default: ""
## - hint - Prompt text to display, string, default: ""
##
## Globals:
## - reads/listen: use_macos_extensions
## - mutate/publish: creates global variable named by first parameter
##
## Returns:
## - 0 on success
## - Sets variable to 'true' for yes, 'false' for no/other
##
## Usage:
## - validate:input:yn result "y" "Continue?"
##
function validate:input:yn() {
  local variable=$1
  local default=${2:-""}
  local hint=${3:-""}
  local user_in=false

  while true; do
    if $use_macos_extensions; then
      [[ -z "${hint// /}" ]] || read -e -i "${default}" -p "${cl_purple}? ${cl_reset}${hint}${cl_blue}" -r yn
      [[ -n "${hint// /}" ]] || read -e -i "${default}" -r yn
    else
      [[ -z "${hint// /}" ]] || echo "${cl_purple}? ${cl_reset}${hint}${cl_blue}"
      read -r yn
    fi
    printf "${cl_reset}"
    case $yn in
    [Yy]*)
      user_in=true
      break
      ;;
    [Nn]*)
      user_in=false
      break
      ;;
    *)
      user_in=false
      break
      ;;
    esac
  done
  local __resultvar=$variable
  eval $__resultvar="$user_in"
}

# shellcheck disable=SC2086
##
## Get environment variable value or read from secret file (required)
##
## Parameters:
## - name - Variable name to store result, string, required
## - variable - Environment variable name to check, string, required
## - filepath - Path to secret file as fallback, string, required
## - fallback - User-friendly hint message, string, default: "No hints, check the documentation"
##
## Globals:
## - reads/listen: none
## - mutate/publish: creates global variable named by first parameter
##
## Returns:
## - 0 on success, 1 if neither env var nor file exists
##
## Usage:
## - env:variable:or:secret:file value "API_KEY" ".secrets/api_key" "Set your API key"
##
function env:variable:or:secret:file() {
  local name=$1
  local variable=$2
  local filepath=$3
  local fallback=${4:-"No hints, check the documentation"}
  local __result=$name

  if [[ -z "${!variable}" ]]; then
    if [[ ! -f "$filepath" ]]; then
      echo ""
      echo "${cl_red}ERROR:${cl_reset} bash env variable '\$$variable' or file '$filepath' should be provided"
      echo ""
      echo "Hint:"
      echo "  $fallback"
      echo ""
      echo:Common "Working Dir: $(pwd)"
      return 1
    else
      echo "Using file: ${cl_green}$filepath${cl_reset} ~> $name"
      eval $__result="'$(cat $filepath)'"
    fi
  else
    echo "Using var : ${cl_green}\$$variable${cl_reset} ~> $name"
    eval $__result="'${!variable}'"
  fi
}

# shellcheck disable=SC2086
##
## Get environment variable value or read from secret file (optional)
##
## Parameters:
## - name - Variable name to store result, string, required
## - variable - Environment variable name to check, string, required
## - filepath - Path to secret file as fallback, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: creates global variable named by first parameter
##
## Returns:
## - 0 on success, 1 if neither env var nor file exists
##
## Usage:
## - env:variable:or:secret:file:optional value "API_KEY" ".secrets/api_key"
##
function env:variable:or:secret:file:optional() {
  local name=$1
  local variable=$2
  local filepath=$3
  local __result=$name

  if [[ -z "${!variable}" ]]; then
    if [[ ! -f "$filepath" ]]; then
      # NO variable, NO file
      echo "${cl_yellow}Note:${cl_reset} bash env variable '\$$variable' or file '$filepath' can be provided."
      return 0
    else
      echo "Using file: ${cl_green}$filepath${cl_reset} ~> $name"
      eval $__result="'$(cat $filepath)'"

      # make unit test happy, they expect 0 exit code, otherwise variable preserve will not work
      ${__SOURCED__:+x} && return 0 || return 2
    fi
  else
    echo "Using var : ${cl_green}\$$variable${cl_reset} ~> $name"
    eval $__result="'${!variable}'"

    # make unit test happy, they expect 0 exit code, otherwise variable preserve will not work
    ${__SOURCED__:+x} && return 0 || return 1
  fi
}

##
## Resolve {{env.VAR_NAME}} patterns to environment variable values
##
## Parameters:
## - input_string - String with {{env.*}} patterns (optional if pipeline mode), string, default: stdin
## - array_name - Associative array name for custom vars, string, default: none (env vars only)
##
## Globals:
## - reads/listen: environment variables
## - mutate/publish: none
##
## Returns:
## - String with {{env.VAR_NAME}} patterns replaced
## - Resolution priority: associative array > environment variables
##
## Usage:
## - result=$(env:resolve "Path: {{env.HOME}}")
## - echo "{{env.HOME}}" | env:resolve
## - declare -A VARS=([x]="y"); result=$(env:resolve "{{env.x}}" "VARS")
##
function env:resolve() {
  local input_string="$1"
  local array_name="$2"

  # Detect pipeline mode:
  # - If $# is 0 (no arguments) AND stdin is not a terminal, OR
  # - If $# is 1 AND first arg matches array name pattern AND stdin is not a terminal
  # Then we're in pipeline mode
  local pipeline_mode=false

  if [[ $# -eq 0 ]] && [[ ! -t 0 ]]; then
    # No arguments, stdin available - pipeline mode without array
    pipeline_mode=true
  elif [[ $# -eq 1 ]] && [[ "$input_string" =~ ^[A-Z_][A-Z0-9_]*$ ]] && [[ ! -t 0 ]]; then
    # One argument that looks like an array name, stdin available - pipeline mode with array
    pipeline_mode=true
    array_name="$input_string"
    input_string=""
  fi

  if $pipeline_mode; then
    # Pipeline mode: read from stdin line by line
    while IFS= read -r line; do
      _env:resolve:string "$line" "$array_name"
    done
  else
    # Direct mode: resolve the input string
    if [[ -z "$input_string" ]]; then
      # No input string and no pipeline - return empty
      echo ""
      return 0
    fi

    _env:resolve:string "$input_string" "$array_name"
  fi
}

##
## Internal helper to resolve {{env.VAR}} patterns in a single string
##
## Parameters:
## - str - String containing {{env.*}} patterns, string, required
## - arr_name - Associative array name for custom vars, string, default: none
##
## Globals:
## - reads/listen: environment variables
## - mutate/publish: none
##
## Returns:
## - 0 on success, 1 on infinite loop detected
## - Echoes string with all {{env.VAR}} patterns replaced
##
## Usage:
## - _env:resolve:string "Path: {{env.HOME}}" "CUSTOM_VARS"
##
function _env:resolve:string() {
  local str="$1"
  local arr_name="$2"
  local expanded_string="$str"
  local max_iterations=10  # Safety limit to prevent infinite loops
  local iteration=0

  # Iterate while there are {{env.VAR_NAME}} patterns in the string
  # Pattern: {{env.\s*([A-Za-z_][A-Za-z0-9_]*)\s*}}
  # - Matches {{env. followed by optional whitespace
  # - Captures variable name (must start with letter or underscore, then alphanumeric or underscore)
  # - Followed by optional whitespace and }}
  while [[ "$expanded_string" =~ \{\{[[:space:]]*env\.[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\}\} ]]; do
    # Safety check: prevent infinite loops from self-referential patterns
    ((iteration++))
    if [[ $iteration -gt $max_iterations ]]; then
      echo "$expanded_string" >&2
      echo "ERROR: env:resolve exceeded maximum iterations ($max_iterations), possible infinite loop" >&2
      echo "This may be caused by self-referential patterns like: export VAR='{{env.VAR}}'" >&2
      echo:Common "Context: ...${expanded_string:0:80}..." >&2
      return 1
    fi

    local var_name="${BASH_REMATCH[1]}"
    local var_value=""
    local matched_pattern="${BASH_REMATCH[0]}"

    # Priority 1: Check associative array if provided
    if [[ -n "$arr_name" ]]; then
      # Verify the array exists and is an associative array
      if declare -p "$arr_name" 2>/dev/null | grep -q "declare -A"; then
        # Safer eval approach: validate array name contains only safe characters
        if [[ "$arr_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && [[ "$var_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
          # Use printf with eval for safer array access
          # This is safer than echo-based eval as it doesn't execute arbitrary commands
          local lookup_expr="\${${arr_name}[${var_name}]:-__NOTFOUND__}"
          var_value=$(eval "printf '%s' \"$lookup_expr\"" 2>/dev/null || echo "__NOTFOUND__")
        else
          var_value="__NOTFOUND__"
        fi

        # If not found in array, fall back to environment variable
        if [[ "$var_value" == "__NOTFOUND__" ]]; then
          var_value="${!var_name:-}"
        fi
      else
        # Array doesn't exist or isn't associative, fall back to environment variable
        var_value="${!var_name:-}"
      fi
    else
      # No array provided, use environment variable
      var_value="${!var_name:-}"
    fi

    # Store previous state to detect if replacement made progress
    local previous_string="$expanded_string"

    # Replace the matched pattern with the variable value using substring slicing
    # This approach is more portable than parameter expansion ${var/pattern/replacement}
    # which has inconsistent behavior with special characters across bash versions

    # Find the pattern using prefix removal
    local prefix="${expanded_string%%"$matched_pattern"*}"

    # Check if pattern was found
    if [[ "$prefix" != "$expanded_string" ]]; then
      # Calculate positions
      local pattern_len=${#matched_pattern}
      local prefix_len=${#prefix}

      # Extract suffix after the pattern
      local suffix="${expanded_string:$((prefix_len + pattern_len))}"

      # Concatenate: prefix + replacement + suffix
      # This preserves all special characters literally without escaping
      expanded_string="${prefix}${var_value}${suffix}"
    fi

    # Safety check: if no progress was made, break to prevent infinite loop
    # This handles cases where the value equals the pattern (self-reference)
    if [[ "$expanded_string" == "$previous_string" ]]; then
      echo "$expanded_string" >&2
      echo "ERROR: env:resolve detected self-referential pattern for variable '$var_name'" >&2
      echo "Variable value contains the same placeholder pattern: $matched_pattern" >&2
      echo:Common "Context: ...${expanded_string:0:80}..." >&2
      return 1
    fi
  done

  echo "$expanded_string"
}

##
## Cascading confirmation with fallback to input prompts
##
## Parameters:
## - hint - Prompt message, string, required
## - variable - Variable name to store result, string, required
## - fallback - Default value, string, required
## - top - First value to use, string, default: "" (triggers prompt)
## - second - Second value to use, string, default: "" (uses fallback)
## - third - Third value to use, string, default: "" (uses input prompt)
## - masked - Display value instead of prompting, string, default: ""
##
## Globals:
## - reads/listen: cl_purple, cl_reset, cl_blue
## - mutate/publish: creates global variable named by second parameter
##
## Returns:
## - 0 on success
## - Sets variable to: top if set, second if set, third if set, or prompts for input
##
## Usage:
## - confirm:by:input "Continue?" result "y" "" "" ""
##
function confirm:by:input() {
  local hint=$1
  local variable=$2
  local fallback=$3
  local top=$4
  local second=$5
  local third=$6
  local masked=$7

  ##
  ## Print confirmation prompt with value
  ##
  ## Parameters:
  ## - value - Value to display in prompt, string, required
  ##
  ## Globals:
  ## - reads/listen: hint, cl_purple, cl_reset, cl_blue
  ## - mutate/publish: none
  ##
  ## Side effects:
  ## - Outputs formatted prompt to stdout
  ##
  ## Returns:
  ## - None
  ##
  ## Usage:
  ## - print:confirmation "value"
  ##
  print:confirmation() { echo "${cl_purple}? ${cl_reset}${hint}${cl_blue}$1${cl_reset}"; }

  if [ -z "$top" ]; then
    if [ -z "$second" ]; then
      if [ -z "$third" ]; then
        if [ -n "$masked" ]; then
          validate:input:masked "$variable" "$fallback" "$hint"
        else
          validate:input "$variable" "$fallback" "$hint"
        fi
      else
        eval "$variable='$fallback'" # fallback to provided value
        print:confirmation "${masked:-$fallback}"
      fi
    else
      eval "$variable='$second'"
      print:confirmation "${masked:-$second}"
    fi
  else
    eval "$variable='$top'"
    print:confirmation "${masked:-$top}"
  fi
}

##
## Get variable value or fallback to default (variable coalescing level 0)
##
## Parameters:
## - variable_name - Name of variable to check, string, required
## - default - Default value if variable is empty/unset, string, required
##
## Globals:
## - reads/listen: variables by name
## - mutate/publish: none
##
## Returns:
## - Echoes variable value if set and non-empty, otherwise default
##
## Usage:
## - MY_VAR="hello"; result=$(var:l0 "MY_VAR" "default")
##
function var:l0() {
  local variable_name=$1
  local default=$2
  local value="${!variable_name}"

  if [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

##
## Get variable value from var1, var2, or default (variable coalescing level 1)
##
## Parameters:
## - var1 - Name of first variable to check, string, required
## - var2 - Name of second variable to check, string, required
## - default - Default value if both variables empty/unset, string, required
##
## Globals:
## - reads/listen: variables by name
## - mutate/publish: none
##
## Returns:
## - Echoes var1 if set, var2 if set, otherwise default
##
## Usage:
## - result=$(var:l1 "VAR1" "VAR2" "default")
##
function var:l1() {
  local var1=$1
  local var2=$2
  local default=$3
  local value1="${!var1}"
  local value2="${!var2}"

  if [ -n "$value1" ]; then
    echo "$value1"
  elif [ -n "$value2" ]; then
    echo "$value2"
  else
    echo "$default"
  fi
}

##
## Get value or fallback to default (value coalescing level 0)
##
## Parameters:
## - value - Value to check, string, required
## - default - Default value if value is empty, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes value if non-empty, otherwise default
##
## Usage:
## - result=$(val:l0 "hello" "default")
##
function val:l0() {
  local value=$1
  local default=$2

  if [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

##
## Get value from value1, value2, or default (value coalescing level 1)
##
## Parameters:
## - value1 - First value to check, string, required
## - value - Second value to check, string, required
## - default - Default value if both values empty, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes value1 if non-empty, value if non-empty, otherwise default
##
## Usage:
## - result=$(val:l1 "first" "second" "default")
##
function val:l1() {
  local value1=$1
  local value=$2
  local default=$3

  if [ -n "$value1" ]; then
    echo "$value1"
  elif [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

##
## Generate cross-platform hash for slug generation (internal helper)
##
## Parameters:
## - input - String to hash, string, required
## - length - Hash length to return, number, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes hash of specified length
##
## Usage:
## - hash=$(to:slug:hash "input" 7)
##
function to:slug:hash() {
  local input=$1
  local length=$2
  local hash=""

  # Try sha256sum (Linux), shasum -a 256 (macOS), then md5sum/md5
  if command -v sha256sum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | sha256sum 2>/dev/null | cut -d' ' -f1 | head -c "$length")
  elif command -v shasum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | shasum -a 256 2>/dev/null | cut -d' ' -f1 | head -c "$length")
  elif command -v md5sum >/dev/null 2>&1; then
    hash=$(echo -n "$input" | md5sum 2>/dev/null | cut -d' ' -f1 | head -c "$length")
  elif command -v md5 >/dev/null 2>&1; then
    hash=$(echo -n "$input" | md5 2>/dev/null | head -c "$length")
  fi

  echo "$hash"
}

##
## Convert string to filesystem-safe slug
##
## Parameters:
## - string - String to convert, string, required
## - separator - Separator character, string, default: "_"
## - trim - Maximum length or "always" for hash, string/number, default: 20
##   - Number: Max length, add hash if exceeded
##   - "always": Always append hash for deterministic IDs
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - Echoes filesystem-safe slug trimmed to length with optional hash
## - Returns "__" + hash (7 chars) if input only special characters
##
## Usage:
## - result=$(to:slug "Hello World!" "_" 20)
## - result=$(to:slug "Hello World!" "_" "always")
##
function to:slug() {
  local string=$1
  local separator=${2:-"_"}
  local trim_param=${3:-20}
  local strategy="length"
  local trim=20

  # Determine strategy: number (length limit) or "always" (force hash)
  if [[ "$trim_param" == "always" ]]; then
    strategy="always"
    trim=0  # No length limit when strategy is "always"
  elif [[ "$trim_param" =~ ^[0-9]+$ ]]; then
    strategy="length"
    trim=$trim_param
  else
    # Invalid parameter, default to 20
    strategy="length"
    trim=20
  fi

  # Convert to lowercase
  local slug=$(echo "$string" | tr '[:upper:]' '[:lower:]')

  # Replace all non-alphanumeric characters with the separator
  # and squeeze repeated separators into one
  slug=$(echo "$slug" | tr -cs '[:alnum:]' "$separator")

  # Trim leading and trailing separators
  slug="${slug#"${separator}"}"
  slug="${slug%"${separator}"}"

  # If slug is empty (input had only special characters), generate hash-based name
  if [ -z "$slug" ]; then
    # Generate 7-character hash from original input
    local hash=$(to:slug:hash "$string" 7)

    # Return "__" prefix + hash (9 chars total, or trimmed to max length)
    local hash_slug="__${hash}"
    if [ "$strategy" = "length" ] && [ ${#hash_slug} -gt "$trim" ]; then
      echo "${hash_slug:0:$trim}"
    else
      echo "$hash_slug"
    fi
    return
  fi

  # Strategy: always add hash
  if [ "$strategy" = "always" ]; then
    local hash=$(to:slug:hash "$slug" 7)
    echo "${slug}${separator}${hash}"
    return
  fi

  # Strategy: length-based trimming
  if [ ${#slug} -gt "$trim" ]; then
    # Generate 7-character hash
    local hash=$(to:slug:hash "$slug" 7)

    # Calculate prefix length (leave room for separator + 7-char hash)
    local prefix_len=$((trim - 8))

    if [ $prefix_len -gt 0 ]; then
      local prefix="${slug:0:$prefix_len}"
      # Remove trailing separator from prefix
      prefix="${prefix%"${separator}"}"
      slug="${prefix}${separator}${hash}"
    else
      # If trim is too small (<= 8), use hash of exact trim length
      local hash_only=$(to:slug:hash "$slug" "$trim")
      slug="$hash_only"
    fi
  fi

  echo "$slug"
}

##
## Check if --help flag is present in arguments
##
## Parameters:
## - args - Arguments to check, string array, variadic
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - "true" if --help present, "false" otherwise
##
## Usage:
## - if args:isHelp "$@"; then ...; fi
##
function args:isHelp() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--help" ]]; then echo true; else echo false; fi
}

##
## Find git repository root directory (handles regular repos, worktrees, submodules)
##
## Parameters:
## - start_path - Starting directory path, string, default: "."
## - output_type - Output format, string, default: "path"
##   - "path": Return the root path
##   - "type": Return repo type (regular|worktree|submodule)
##   - "both": Return "type:path" format
##   - "all": Return "type:path:git_dir" format
##
## Globals:
## - reads/listen: use_macos_extensions
## - mutate/publish: none
##
## Returns:
## - 0 if git root found, 1 otherwise
## - Echoes based on output_type
##
## Usage:
## - root=$(git:root)
## - type=$(git:root "." "type")  # "regular" or "worktree" or "submodule"
##
function git:root() {
  local start_path="${1:-.}"
  local output_type="${2:-path}"
  local current_dir git_type git_dir root_path

  # Resolve to absolute path
  current_dir=$(cd "$start_path" 2>/dev/null && pwd -P) || {
    echo ""
    return 1
  }

  # Navigate upward until we find .git (file or directory) or reach root
  local max_iterations=1000  # Safety limit to prevent infinite loops
  local iteration=0

  while true; do
    # Safety check: prevent infinite loops
    ((iteration++))
    if [[ $iteration -gt $max_iterations ]]; then
      echo "" >&2
      echo "WARNING: git:root exceeded maximum iterations ($max_iterations), possible infinite loop" >&2
      return 1
    fi

    if [[ -e "$current_dir/.git" ]]; then
      root_path="$current_dir"

      # Check if .git is a file (worktree or submodule) or directory (regular repo)
      if [[ -f "$current_dir/.git" ]]; then
        # Read the .git file content
        local git_file_content
        git_file_content=$(cat "$current_dir/.git" 2>/dev/null)

        # Worktree format: "gitdir: /path/to/.git/worktrees/name"
        # Submodule format: "gitdir: ../.git/modules/name"
        if [[ "$git_file_content" =~ ^gitdir:\ (.+)$ ]]; then
          git_dir="${BASH_REMATCH[1]}"

          # Convert relative path to absolute if needed
          if [[ ! "$git_dir" =~ ^/ ]]; then
            local abs_git_dir
            abs_git_dir=$(cd "$current_dir" && cd "$(dirname "$git_dir")" 2>/dev/null && pwd)
            if [[ -n "$abs_git_dir" ]]; then
              git_dir="$abs_git_dir/$(basename "$git_dir")"
            fi
            # If conversion fails, keep relative path as-is
          fi

          # Detect if it's a worktree or submodule
          # Worktrees: path contains "/worktrees/"
          # Submodules: path contains "/modules/" or is within superproject
          if [[ "$git_dir" =~ /worktrees/ ]]; then
            git_type="worktree"
          else
            git_type="submodule"
          fi
        else
          # Malformed .git file
          git_type="unknown"
          git_dir="$current_dir/.git"
        fi
      elif [[ -d "$current_dir/.git" ]]; then
        # Regular git repository
        git_type="regular"
        git_dir="$current_dir/.git"
      else
        # .git exists but is neither file nor directory
        git_type="unknown"
        git_dir="$current_dir/.git"
      fi

      # Output based on requested type
      case "$output_type" in
      type)
        echo "$git_type"
        ;;
      both)
        echo "$git_type:$root_path"
        ;;
      all)
        echo "$git_type:$root_path:$git_dir"
        ;;
      path | *)
        echo "$root_path"
        ;;
      esac

      return 0
    fi

    # Break if we've reached filesystem root
    if [[ "$current_dir" == "/" ]]; then
      break
    fi

    # Move up one directory
    local prev_dir="$current_dir"
    current_dir=$(dirname "$current_dir")

    # Safety check: if dirname returns same path, we're at root
    if [[ "$current_dir" == "$prev_dir" ]]; then
      break
    fi
  done

  # No .git found
  case "$output_type" in
  type)
    echo "none"
    ;;
  both)
    echo "none:"
    ;;
  all)
    echo "none::"
    ;;
  path | *)
    echo ""
    ;;
  esac

  return 1
}

##
## Find configuration file hierarchy by searching upward from current folder
##
## Parameters:
## - config_name - Config file name(s), comma-separated, string, default: ".config"
## - start_path - Starting directory, string, default: "."
## - stop_at - Where to stop searching, string, default: "git"
##   - "git": Stop at git repository root
##   - "home": Stop at user home directory
##   - "root": Stop at filesystem root
##   - "/path": Absolute path to stop at
## - extensions - Comma-separated extensions, string, default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc"
##   - Empty string "" means exact match only
##
## Globals:
## - reads/listen: HOME, git:root()
## - mutate/publish: none
##
## Returns:
## - 0 if at least one config file found, 1 otherwise
## - Echoes config paths, one per line, ordered root to current (bottom-up)
##
## Usage:
## - config:hierarchy ".eslintrc"
## - config:hierarchy "package.json" "." "home"
## - config:hierarchy ".config" "." "git" ".json,.yaml"
##
function config:hierarchy() {
  local config_names="${1:-.config}"
  local start_path="${2:-.}"
  local stop_at="${3:-git}"
  local extensions="${4-,.json,.yaml,.yml,.toml,.ini,.conf,.rc}"

  local current_dir stop_path found_files=()
  local -a name_list ext_list

  # Resolve to absolute path
  current_dir=$(cd "$start_path" 2>/dev/null && pwd -P) || {
    echo ""
    return 1
  }

  # Determine stop path
  case "$stop_at" in
  git)
    stop_path=$(git:root "$current_dir" "path")
    # If no git root found, stop at home
    [[ -z "$stop_path" ]] && stop_path="$HOME"
    ;;
  home)
    stop_path="$HOME"
    ;;
  root)
    stop_path="/"
    ;;
  /*)
    # Absolute path provided - resolve to physical path (like current_dir)
    stop_path=$(cd "$stop_at" 2>/dev/null && pwd -P) || {
      echo ""
      return 1
    }
    ;;
  *)
    # Relative path or invalid, fallback to git
    stop_path=$(git:root "$current_dir" "path")
    [[ -z "$stop_path" ]] && stop_path="$HOME"
    ;;
  esac

  # Parse config names (comma-separated)
  IFS=',' read -ra name_list <<<"$config_names"

  # Parse extensions (comma-separated)
  # Special case: if extensions is exactly "", treat as single empty extension (exact match)
  if [[ "$extensions" == "" ]]; then
    ext_list=("")
  else
    IFS=',' read -ra ext_list <<<"$extensions"
  fi

  # Search upward from current directory to stop path
  local search_dir="$current_dir"
  local max_iterations=1000  # Safety limit to prevent infinite loops
  local iteration=0

  while true; do
    # Safety check: prevent infinite loops
    ((iteration++))
    if [[ $iteration -gt $max_iterations ]]; then
      echo "" >&2
      echo "WARNING: config:hierarchy exceeded maximum iterations ($max_iterations), possible infinite loop" >&2
      return 1
    fi

    # Try each config name
    for name in "${name_list[@]}"; do
      name=$(echo "$name" | xargs) # Trim whitespace

      # Try each extension (including no extension if "" is in list)
      for ext in "${ext_list[@]}"; do
        ext=$(echo "$ext" | xargs) # Trim whitespace
        local candidate="$search_dir/${name}${ext}"

        if [[ -f "$candidate" ]]; then
          # Store found file (we'll reverse order later)
          found_files+=("$candidate")
        fi
      done
    done

    # Check if we've reached the stop path
    if [[ "$search_dir" == "$stop_path" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi

    # Move up one directory
    local prev_dir="$search_dir"
    search_dir=$(dirname "$search_dir")

    # Safety check: if dirname returns same path, we're at root
    if [[ "$search_dir" == "$prev_dir" ]]; then
      break
    fi
  done

  # Reverse array to get root-to-current order (bottom-up hierarchy)
  local -a reversed_files=()
  for ((i = ${#found_files[@]} - 1; i >= 0; i--)); do
    reversed_files+=("${found_files[i]}")
  done

  # Output results
  if [[ ${#reversed_files[@]} -gt 0 ]]; then
    printf '%s\n' "${reversed_files[@]}"
    return 0
  else
    echo ""
    return 1
  fi
}

##
## Find config files following XDG Base Directory Specification
##
## Parameters:
## - app_name - Application name for XDG dirs, string, required
## - config_name - Config file name(s), comma-separated, string, default: "config"
## - start_path - Starting directory, string, default: "."
## - stop_at - Where to stop hierarchical search, string, default: "home"
## - extensions - Comma-separated extensions, string, default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc"
##
## Globals:
## - reads/listen: HOME, XDG_CONFIG_HOME, XDG_CONFIG_DIRS
## - mutate/publish: none
##
## Returns:
## - 0 if at least one config file found, 1 otherwise
## - Echoes config paths, one per line, ordered by priority (highest to lowest)
##
## Search order:
## - 1. Hierarchical from current_dir to stop_path
## - 2. $XDG_CONFIG_HOME/<app_name>/
## - 3. ~/.config/<app_name>/
## - 4. /etc/xdg/<app_name>/
## - 5. /etc/<app_name>/
##
## Usage:
## - config:hierarchy:xdg "myapp" "config"
## - config:hierarchy:xdg "nvim" "init.vim,.nvimrc"
##
function config:hierarchy:xdg() {
  local app_name="${1}"
  local config_names="${2:-config}"
  local start_path="${3:-.}"
  local stop_at="${4:-home}"
  local extensions="${5-,.json,.yaml,.yml,.toml,.ini,.conf,.rc}"

  # Validate app_name is provided
  if [[ -z "$app_name" ]]; then
    echo "" >&2
    echo "ERROR: config:hierarchy:xdg requires app_name as first argument" >&2
    return 1
  fi

  local -a all_configs=()
  local -a xdg_paths=()

  # 1. First, do hierarchical search (highest priority)
  # config:hierarchy returns root-to-current order (for merging)
  # We need to reverse it to get current-to-root (priority order)
  local hierarchy_result
  hierarchy_result=$(config:hierarchy "$config_names" "$start_path" "$stop_at" "$extensions" 2>/dev/null)
  if [[ $? -eq 0 && -n "$hierarchy_result" ]]; then
    local -a hierarchy_files=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && hierarchy_files+=("$line")
    done <<<"$hierarchy_result"

    # Reverse the array to get highest priority first (current before root)
    for ((i=${#hierarchy_files[@]}-1; i>=0; i--)); do
      all_configs+=("${hierarchy_files[i]}")
    done
  fi

  # 2. Build XDG search paths (in priority order)
  # XDG_CONFIG_HOME (user override)
  if [[ -n "${XDG_CONFIG_HOME}" ]]; then
    xdg_paths+=("${XDG_CONFIG_HOME}/${app_name}")
  fi

  # ~/.config (XDG default)
  xdg_paths+=("${HOME}/.config/${app_name}")

  # XDG_CONFIG_DIRS (system-wide XDG, colon-separated)
  if [[ -n "${XDG_CONFIG_DIRS}" ]]; then
    local -a xdg_config_dirs=()
    IFS=':' read -ra xdg_config_dirs <<<"${XDG_CONFIG_DIRS}"
    for xdg_dir in "${xdg_config_dirs[@]}"; do
      [[ -n "$xdg_dir" ]] && xdg_paths+=("${xdg_dir%/}/${app_name}")
    done
  else
    xdg_paths+=("/etc/xdg/${app_name}")
  fi

  # /etc (traditional system config)
  local etc_root="${XDG_ETC_DIR:-/etc}"
  if [[ -n "$etc_root" ]]; then
    xdg_paths+=("${etc_root%/}/${app_name}")
  fi

  # 3. Search XDG directories for config files
  local -a name_list ext_list
  IFS=',' read -ra name_list <<<"$config_names"

  # Parse extensions (special case for empty string)
  if [[ "$extensions" == "" ]]; then
    ext_list=("")
  else
    IFS=',' read -ra ext_list <<<"$extensions"
  fi

  for xdg_dir in "${xdg_paths[@]}"; do
    if [[ -d "$xdg_dir" ]]; then
      for name in "${name_list[@]}"; do
        name=$(echo "$name" | xargs) # Trim whitespace

        for ext in "${ext_list[@]}"; do
          ext=$(echo "$ext" | xargs) # Trim whitespace
          local candidate="${xdg_dir}/${name}${ext}"

          if [[ -f "$candidate" ]]; then
            # Add to results if not already found in hierarchy
            local already_found=0
            for existing in "${all_configs[@]}"; do
              if [[ "$existing" == "$candidate" ]]; then
                already_found=1
                break
              fi
            done

            if [[ $already_found -eq 0 ]]; then
              all_configs+=("$candidate")
            fi
          fi
        done
      done
    fi
  done

  # Output results
  if [[ ${#all_configs[@]} -gt 0 ]]; then
    printf '%s\n' "${all_configs[@]}"
    return 0
  else
    echo ""
    return 1
  fi
}

# --- Unified Key Input ---

# xterm modifier encoding: modifier_code = 1 + sum(Shift=1, Alt=2, Ctrl=4, Meta=8)
# Reference: https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
declare -g -A __INPUT_MODIFIER_NAMES=(
  [1]="" [2]="shift" [3]="alt" [4]="shift-alt"
  [5]="ctrl" [6]="ctrl-shift" [7]="ctrl-alt" [8]="ctrl-alt-shift"
  [9]="meta" [10]="meta-shift" [11]="meta-alt" [12]="meta-alt-shift"
  [13]="meta-ctrl" [14]="meta-ctrl-shift" [15]="meta-ctrl-alt" [16]="meta-ctrl-alt-shift"
)

# CSI final byte → semantic key name mapping
declare -g -A __INPUT_CSI_KEYS=(
  [A]="up" [B]="down" [C]="right" [D]="left" [H]="home" [F]="end"
)
# CSI number ~ → semantic key name mapping
declare -g -A __INPUT_CSI_TILDE_KEYS=(
  [1]="home" [2]="insert" [3]="delete" [4]="end"
  [5]="page-up" [6]="page-down"
  [11]="f1" [12]="f2" [13]="f3" [14]="f4"
  [15]="f5" [17]="f6" [18]="f7" [19]="f8"
  [20]="f9" [21]="f10" [23]="f11" [24]="f12"
)

##
## Read one logical keypress and output a semantic token
##
## Reads raw bytes from the terminal, parses escape sequences
## (including xterm modifier encoding), and outputs a human-readable
## token like "ctrl-up", "shift-f5", "char:a", "enter", etc.
##
## Parameters:
## - -t timeout - Read timeout in seconds, float, default: (blocking)
## - --raw - Also set __INPUT_RAW_BYTES with hex representation
##
## Globals:
## - reads/listen: __INPUT_CSI_KEYS, __INPUT_CSI_TILDE_KEYS, __INPUT_MODIFIER_NAMES
## - mutate/publish: __INPUT_RAW_BYTES (when --raw), __INPUT_RAW_CHARS (when --raw)
##
## Side effects:
## - Reads from stdin/terminal (expects raw mode: stty raw -echo)
##
## Returns:
## - 0 on key read, 1 on timeout
## - Echoes semantic token to stdout
##
## Tokens:
## - Navigation: up, down, left, right, home, end, page-up, page-down
## - Modified: ctrl-up, shift-left, ctrl-alt-delete, etc.
## - Function: f1..f12, shift-f5, ctrl-f1, etc.
## - Control: enter, backspace, tab, escape
## - Named ctrl: ctrl-a..ctrl-z, ctrl-d, ctrl-u, ctrl-w, etc.
## - Printable: char:a, char:Z, char:1, char:!, char:é (multi-byte UTF-8)
## - Special: timeout (when -t used and no input)
##
## Usage:
## - key=$(_input:read-key)
## - key=$(_input:read-key -t 0.1) || continue  # with timeout
## - _input:read-key --raw; echo "$__INPUT_RAW_BYTES"
##
function _input:read-key() {
  local timeout="" use_raw=false

  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -t) timeout="$2"; shift ;;
    --raw) use_raw=true ;;
    esac
    shift
  done

  local c0=""
  # First byte: blocking or with timeout
  if [[ -n "$timeout" ]]; then
    IFS= read -rsn1 -t "$timeout" c0 || { echo "timeout"; return 1; }
  else
    IFS= read -rsn1 c0
  fi

  # Collect raw bytes for --raw mode
  local raw_chars="$c0"

  # Handle empty read (Enter/EOF - NULL becomes empty string)
  if [[ -z "$c0" ]]; then
    if [[ "$use_raw" == "true" ]]; then
      __INPUT_RAW_BYTES="0a"
      __INPUT_RAW_CHARS=""
    fi
    echo "enter"
    return 0
  fi

  local code
  code=$(printf '%02x' "'$c0")

  # --- Escape sequences ---
  if [[ "$code" == "1b" ]]; then
    local rest=""
    IFS= read -rsn1 -t 0.01 rest
    raw_chars+="$rest"

    # Bare escape (no followup byte within timeout)
    if [[ -z "$rest" ]]; then
      if [[ "$use_raw" == "true" ]]; then
        __INPUT_RAW_BYTES="1b"
        __INPUT_RAW_CHARS=$'\x1b'
      fi
      echo "escape"
      return 0
    fi

    # CSI sequence: ESC [
    if [[ "$rest" == "[" ]]; then
      # Read the parameter bytes and final byte
      # CSI format: ESC [ (params) (final_byte)
      # params: digits and semicolons
      # final_byte: 0x40-0x7E (letter or ~)
      local params="" byte=""
      while true; do
        IFS= read -rsn1 -t 0.05 byte
        raw_chars+="$byte"
        if [[ "$byte" =~ [0-9\;] ]]; then
          params+="$byte"
        else
          break  # final byte
        fi
      done

      local final="$byte"
      local modifier="" base_key=""

      if [[ "$final" == "~" ]]; then
        # Tilde-terminated: CSI number ; modifier ~
        local num="${params%%;*}"
        local mod_str="${params#*;}"
        [[ "$mod_str" == "$params" ]] && mod_str=""

        base_key="${__INPUT_CSI_TILDE_KEYS[$num]:-unknown}"

        if [[ -n "$mod_str" ]]; then
          modifier="${__INPUT_MODIFIER_NAMES[$mod_str]:-}"
        fi
      else
        # Letter-terminated: CSI 1 ; modifier letter  OR  CSI letter
        base_key="${__INPUT_CSI_KEYS[$final]:-unknown}"

        if [[ -n "$params" ]]; then
          local mod_str="${params#*;}"
          [[ "$mod_str" == "$params" ]] && mod_str=""
          if [[ -n "$mod_str" ]]; then
            modifier="${__INPUT_MODIFIER_NAMES[$mod_str]:-}"
          fi
        fi
      fi

      if [[ "$use_raw" == "true" ]]; then
        __INPUT_RAW_CHARS="$raw_chars"
        __INPUT_RAW_BYTES=""
        local i ch
        for ((i = 0; i < ${#raw_chars}; i++)); do
          ch="${raw_chars:$i:1}"
          __INPUT_RAW_BYTES+="$(printf '%02x' "'$ch")"
        done
      fi

      if [[ -n "$modifier" ]]; then
        echo "${modifier}-${base_key}"
      else
        echo "$base_key"
      fi
      return 0
    fi

    # SS3 sequence: ESC O (some terminals send this for arrow keys/F1-F4)
    if [[ "$rest" == "O" ]]; then
      local ss3_byte=""
      IFS= read -rsn1 -t 0.05 ss3_byte
      raw_chars+="$ss3_byte"

      if [[ "$use_raw" == "true" ]]; then
        __INPUT_RAW_CHARS="$raw_chars"
        __INPUT_RAW_BYTES=""
        local i ch
        for ((i = 0; i < ${#raw_chars}; i++)); do
          ch="${raw_chars:$i:1}"
          __INPUT_RAW_BYTES+="$(printf '%02x' "'$ch")"
        done
      fi

      case "$ss3_byte" in
      A) echo "up" ;; B) echo "down" ;; C) echo "right" ;; D) echo "left" ;;
      H) echo "home" ;; F) echo "end" ;;
      P) echo "f1" ;; Q) echo "f2" ;; R) echo "f3" ;; S) echo "f4" ;;
      *) echo "unknown" ;;
      esac
      return 0
    fi

    # Alt+key: ESC followed by printable character
    if [[ "$use_raw" == "true" ]]; then
      __INPUT_RAW_CHARS="$raw_chars"
      __INPUT_RAW_BYTES="$(printf '%02x' "'$c0")$(printf '%02x' "'$rest")"
    fi

    local rest_code
    rest_code=$(printf '%02x' "'$rest")
    # Alt + Ctrl combination (ESC + control char)
    if [[ "$rest_code" =~ ^0[1-9a-f]$ || "$rest_code" == "1[0-9a]" ]]; then
      local ctrl_num=$((16#$rest_code))
      local ctrl_letter
      ctrl_letter=$(printf '%02x' $((ctrl_num + 0x60)))
      echo "ctrl-alt-$(printf "\\x$ctrl_letter")"
      return 0
    fi
    echo "alt-${rest}"
    return 0
  fi

  # --- Control characters (0x01-0x1a except 0x1b=ESC already handled) ---
  case "$code" in
  01) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-a" ;; # Ctrl+A
  02) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-b" ;; # Ctrl+B
  03) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-c" ;; # Ctrl+C
  04) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-d" ;; # Ctrl+D
  05) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-e" ;; # Ctrl+E
  06) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-f" ;; # Ctrl+F
  07) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-g" ;; # Ctrl+G
  08) _input:_raw "$use_raw" "$code" "$c0"; echo "backspace" ;; # Ctrl+H / BS
  09) _input:_raw "$use_raw" "$code" "$c0"; echo "tab" ;;       # Ctrl+I / Tab
  0a) _input:_raw "$use_raw" "$code" "$c0"; echo "enter" ;;     # Ctrl+J / LF
  0b) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-k" ;; # Ctrl+K
  0c) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-l" ;; # Ctrl+L
  0d) _input:_raw "$use_raw" "$code" "$c0"; echo "enter" ;;     # Ctrl+M / CR
  0e) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-n" ;; # Ctrl+N
  0f) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-o" ;; # Ctrl+O
  10) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-p" ;; # Ctrl+P
  11) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-q" ;; # Ctrl+Q
  12) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-r" ;; # Ctrl+R
  13) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-s" ;; # Ctrl+S
  14) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-t" ;; # Ctrl+T
  15) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-u" ;; # Ctrl+U
  16) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-v" ;; # Ctrl+V
  17) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-w" ;; # Ctrl+W
  18) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-x" ;; # Ctrl+X
  19) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-y" ;; # Ctrl+Y
  1a) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-z" ;; # Ctrl+Z
  7f) _input:_raw "$use_raw" "$code" "$c0"; echo "backspace" ;; # DEL (0x7f)
  00) _input:_raw "$use_raw" "$code" "$c0"; echo "ctrl-space" ;; # Ctrl+Space / NUL
  *)
    # --- Printable character (possibly multi-byte UTF-8) ---
    local first_byte=$((16#$code))
    local extra_bytes=0 full_char="$c0"

    # UTF-8 leading byte detection
    if ((first_byte >= 0xC0 && first_byte <= 0xDF)); then
      extra_bytes=1
    elif ((first_byte >= 0xE0 && first_byte <= 0xEF)); then
      extra_bytes=2
    elif ((first_byte >= 0xF0 && first_byte <= 0xF7)); then
      extra_bytes=3
    fi

    if ((extra_bytes > 0)); then
      local utf_rest=""
      IFS= read -rsn"$extra_bytes" -t 0.01 utf_rest
      full_char+="$utf_rest"
    fi

    if [[ "$use_raw" == "true" ]]; then
      __INPUT_RAW_CHARS="$full_char"
      __INPUT_RAW_BYTES=""
      local i ch
      for ((i = 0; i < ${#full_char}; i++)); do
        ch="${full_char:$i:1}"
        __INPUT_RAW_BYTES+="$(printf '%02x' "'$ch")"
      done
    fi

    echo "char:${full_char}"
    ;;
  esac
  return 0
}

## Helper: set __INPUT_RAW_BYTES and __INPUT_RAW_CHARS for --raw mode
function _input:_raw() {
  [[ "$1" == "true" ]] || return 0
  __INPUT_RAW_BYTES="$2"
  __INPUT_RAW_CHARS="$3"
}

##
## Interactive key capture diagnostic tool
##
## Displays every keypress with its semantic token, hex bytes,
## and human-readable modifier breakdown. Useful for discovering
## the exact byte sequence your terminal sends for any key combo,
## which simplifies ML_KEY_* keybinding configuration.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __INPUT_RAW_BYTES, __INPUT_RAW_CHARS
## - mutate/publish: none
##
## Side effects:
## - Saves/restores terminal state (stty raw -echo)
## - Traps INT/TERM for cleanup
## - Reads raw keyboard input
## - Outputs key info to stderr
##
## Returns:
## - 0 on exit (Ctrl+C or Ctrl+D)
##
## Output format per keypress:
##   Key: ctrl-up    Hex: 1b5b313b3541    Bash: $'\x1b[1;5A'
##
## Usage:
## - _input:capture-key
## - source "$E_BASH/_commons.sh" && _input:capture-key
##
function _input:capture-key() {
  local saved_stty
  saved_stty=$(stty -g)
  stty raw -echo

  function __capture_cleanup() {
    stty "$saved_stty"
    printf "\r\n" >&2
  }
  trap '__capture_cleanup; return 0' INT TERM

  printf "Press keys to see their sequences. Ctrl+D to exit.\r\n" >&2
  printf "%-24s %-24s %-30s\r\n" "Token" "Hex" "Bash literal" >&2
  printf "%-24s %-24s %-30s\r\n" "------------------------" "------------------------" "------------------------------" >&2

  while true; do
    local key
    key=$(_input:read-key --raw)

    [[ "$key" == "ctrl-d" ]] && break
    [[ "$key" == "ctrl-c" ]] && break

    # Build bash literal string: $'\xHH\xHH...'
    local bash_literal="" hex="$__INPUT_RAW_BYTES"
    local i
    for ((i = 0; i < ${#hex}; i += 2)); do
      bash_literal+="\x${hex:$i:2}"
    done
    [[ -n "$bash_literal" ]] && bash_literal="\$'${bash_literal}'"

    printf "%-24s %-24s %-30s\r\n" "$key" "$hex" "$bash_literal" >&2
  done

  __capture_cleanup
  trap - INT TERM
}

# --- Multi-line Input: Internal State ---

# Module-internal state for multi-line editor
declare -g -a __ML_LINES=("")
declare -g -i __ML_ROW=0
declare -g -i __ML_COL=0
declare -g -i __ML_SCROLL=0
declare -g -i __ML_WIDTH=80
declare -g -i __ML_HEIGHT=24
declare -g __ML_MODIFIED=false
declare -g __ML_MESSAGE=""
declare -g __ML_STATUS_BAR=true

##
## Initialize multi-line editor state
##
## Parameters:
## - width - Editor width in columns, integer, default: 80
## - height - Editor height in rows, integer, default: 24
##
## Globals:
## - reads/listen: none
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL, __ML_WIDTH, __ML_HEIGHT
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:init 80 24
##
function _input:ml:init() {
  __ML_WIDTH=${1:-80}
  __ML_HEIGHT=${2:-24}
  __ML_ROW=0
  __ML_COL=0
  __ML_SCROLL=0
  __ML_LINES=("")
  __ML_MODIFIED=false
  __ML_MESSAGE=""
}

##
## Insert a character at current cursor position
##
## Parameters:
## - char - Character to insert, string, required
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES
## - mutate/publish: __ML_LINES, __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:insert-char "a"
##
function _input:ml:insert-char() {
  local char="$1"
  local line="${__ML_LINES[$__ML_ROW]}"
  __ML_LINES[$__ML_ROW]="${line:0:$__ML_COL}${char}${line:$__ML_COL}"
  __ML_COL=$((__ML_COL + 1))
  __ML_MODIFIED=true
}

##
## Delete character before cursor (backspace behavior)
##
## When cursor is at column 0 and not on the first line,
## joins the current line with the previous line.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES, __ML_HEIGHT
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:delete-char
##
function _input:ml:delete-char() {
  if [[ $__ML_COL -gt 0 ]]; then
    local line="${__ML_LINES[$__ML_ROW]}"
    __ML_LINES[$__ML_ROW]="${line:0:$((__ML_COL - 1))}${line:$__ML_COL}"
    __ML_COL=$((__ML_COL - 1))
    __ML_MODIFIED=true
  elif [[ $__ML_ROW -gt 0 ]]; then
    # Join with previous line
    local current_line="${__ML_LINES[$__ML_ROW]}"
    unset "__ML_LINES[$__ML_ROW]"
    __ML_LINES=("${__ML_LINES[@]}") # Re-index
    __ML_ROW=$((__ML_ROW - 1))
    local prev_line="${__ML_LINES[$__ML_ROW]}"
    __ML_COL=${#prev_line}
    __ML_LINES[$__ML_ROW]="${prev_line}${current_line}"
    __ML_MODIFIED=true
    _input:ml:scroll
  fi
}

##
## Delete word backward from cursor position
##
## Deletes characters backward until a space boundary or beginning of line.
## Deletes trailing spaces first, then the word.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES
## - mutate/publish: __ML_LINES, __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:delete-word
##
function _input:ml:delete-word() {
  [[ $__ML_COL -eq 0 ]] && return 0
  local line="${__ML_LINES[$__ML_ROW]}"
  # Delete trailing spaces first
  while [[ $__ML_COL -gt 0 && "${line:$((__ML_COL - 1)):1}" == " " ]]; do
    line="${line:0:$((__ML_COL - 1))}${line:$__ML_COL}"
    __ML_COL=$((__ML_COL - 1))
  done
  # Delete word characters
  while [[ $__ML_COL -gt 0 && "${line:$((__ML_COL - 1)):1}" != " " ]]; do
    line="${line:0:$((__ML_COL - 1))}${line:$__ML_COL}"
    __ML_COL=$((__ML_COL - 1))
  done
  __ML_LINES[$__ML_ROW]="$line"
  __ML_MODIFIED=true
}

##
## Insert newline at cursor position (split current line)
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES, __ML_HEIGHT
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:insert-newline
##
function _input:ml:insert-newline() {
  local line="${__ML_LINES[$__ML_ROW]}"
  local before="${line:0:$__ML_COL}"
  local after="${line:$__ML_COL}"
  __ML_LINES[$__ML_ROW]="$before"
  __ML_LINES=("${__ML_LINES[@]:0:$((__ML_ROW + 1))}" "$after" "${__ML_LINES[@]:$((__ML_ROW + 1))}")
  __ML_ROW=$((__ML_ROW + 1))
  __ML_COL=0
  __ML_MODIFIED=true
  _input:ml:scroll
}

##
## Move cursor up one line
##
## Clamps column to target line length if shorter.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES
## - mutate/publish: __ML_ROW, __ML_COL, __ML_SCROLL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:move-up
##
function _input:ml:move-up() {
  [[ $__ML_ROW -le 0 ]] && return 0
  ((__ML_ROW--))
  local len=${#__ML_LINES[$__ML_ROW]}
  [[ $__ML_COL -gt $len ]] && __ML_COL=$len
  _input:ml:scroll
}

##
## Move cursor down one line
##
## Clamps column to target line length if shorter.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES
## - mutate/publish: __ML_ROW, __ML_COL, __ML_SCROLL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:move-down
##
function _input:ml:move-down() {
  local last=$(( ${#__ML_LINES[@]} - 1 ))
  [[ $__ML_ROW -ge $last ]] && return 0
  __ML_ROW=$((__ML_ROW + 1))
  local len=${#__ML_LINES[$__ML_ROW]}
  [[ $__ML_COL -gt $len ]] && __ML_COL=$len
  _input:ml:scroll
}

##
## Move cursor left one column
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_COL
## - mutate/publish: __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:move-left
##
function _input:ml:move-left() {
  [[ $__ML_COL -gt 0 ]] && __ML_COL=$((__ML_COL - 1))
  return 0
}

##
## Move cursor right one column
##
## Clamps to end of current line.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_COL, __ML_ROW, __ML_LINES
## - mutate/publish: __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:move-right
##
function _input:ml:move-right() {
  local len=${#__ML_LINES[$__ML_ROW]}
  [[ $__ML_COL -lt $len ]] && __ML_COL=$((__ML_COL + 1))
  return 0
}

##
## Move cursor to beginning of current line
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: none
## - mutate/publish: __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:move-home
##
function _input:ml:move-home() {
  __ML_COL=0
}

##
## Move cursor to end of current line
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_LINES
## - mutate/publish: __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:move-end
##
function _input:ml:move-end() {
  __ML_COL=${#__ML_LINES[$__ML_ROW]}
}

##
## Adjust scroll offset to keep cursor visible
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_HEIGHT, __ML_SCROLL
## - mutate/publish: __ML_SCROLL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:scroll
##
function _input:ml:scroll() {
  local content_height=$__ML_HEIGHT
  [[ "$__ML_STATUS_BAR" == "true" ]] && content_height=$((__ML_HEIGHT - 1))
  # Scroll down
  if [[ $__ML_ROW -ge $((__ML_SCROLL + content_height)) ]]; then
    __ML_SCROLL=$((__ML_ROW - content_height + 1))
  fi
  # Scroll up
  if [[ $__ML_ROW -lt $__ML_SCROLL ]]; then
    __ML_SCROLL=$__ML_ROW
  fi
}

##
## Get buffer content as multi-line string
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_LINES
## - mutate/publish: none
##
## Returns:
## - Echoes all lines joined by newlines
##
## Usage:
## - content=$(_input:ml:get-content)
##
function _input:ml:get-content() {
  local i
  for ((i = 0; i < ${#__ML_LINES[@]}; i++)); do
    if [[ $i -gt 0 ]]; then
      printf '\n'
    fi
    printf '%s' "${__ML_LINES[$i]}"
  done
  printf '\n'
}

##
## Insert tab as spaces at cursor position
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES
## - mutate/publish: __ML_LINES, __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:insert-tab
##
function _input:ml:insert-tab() {
  _input:ml:insert-char " "
  _input:ml:insert-char " "
}

##
## Paste text at cursor position (handles multi-line)
##
## Parameters:
## - text - Text to paste (may contain newlines), string, required
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_LINES
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:paste "Hello\nWorld"
##
function _input:ml:paste() {
  local text="$1"
  local -a paste_lines
  local line

  # Split text by newlines
  while IFS= read -r line; do
    paste_lines+=("$line")
  done <<<"$text"

  # Insert first line at cursor position
  if [[ ${#paste_lines[@]} -eq 1 ]]; then
    # Single line paste - insert characters
    local chars="${paste_lines[0]}"
    local current="${__ML_LINES[$__ML_ROW]}"
    __ML_LINES[$__ML_ROW]="${current:0:$__ML_COL}${chars}${current:$__ML_COL}"
    __ML_COL=$((__ML_COL + ${#chars}))
  else
    # Multi-line paste
    local current="${__ML_LINES[$__ML_ROW]}"
    local before="${current:0:$__ML_COL}"
    local after="${current:$__ML_COL}"

    # First line: append to current position
    __ML_LINES[$__ML_ROW]="${before}${paste_lines[0]}"

    # Middle lines: insert after current row
    local i
    for ((i = 1; i < ${#paste_lines[@]} - 1; i++)); do
      __ML_LINES=("${__ML_LINES[@]:0:$((__ML_ROW + i))}" "${paste_lines[$i]}" "${__ML_LINES[@]:$((__ML_ROW + i))}")
    done

    # Last line: prepend remaining content
    local last_idx=$(( ${#paste_lines[@]} - 1 ))
    local last_line="${paste_lines[$last_idx]}"
    __ML_LINES=("${__ML_LINES[@]:0:$((__ML_ROW + last_idx))}" "${last_line}${after}" "${__ML_LINES[@]:$((__ML_ROW + last_idx))}")

    __ML_ROW=$((__ML_ROW + last_idx))
    __ML_COL=${#last_line}
  fi
  __ML_MODIFIED=true
}

##
## Delete current line content (Ctrl+U behavior)
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW
## - mutate/publish: __ML_LINES, __ML_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:delete-line
##
function _input:ml:delete-line() {
  __ML_LINES[$__ML_ROW]=""
  __ML_COL=0
  __ML_MODIFIED=true
}

##
## Edit current line using readline (full line-editing support)
##
## Temporarily restores terminal to cooked mode and uses `read -rei`
## to provide full readline editing (history, word movement, etc.)
## for the current line. Inspired by the bed editor pattern.
##
## Parameters:
## - saved_stty - Saved stty state to restore for readline, string, required
## - pos_y - Top offset for cursor positioning, integer, default: 0
##
## Globals:
## - reads/listen: __ML_ROW, __ML_LINES, __ML_HEIGHT, __ML_SCROLL
## - mutate/publish: __ML_LINES, __ML_COL, __ML_MODIFIED
##
## Side effects:
## - Temporarily changes terminal mode
## - Shows cursor for readline editing
## - Reads from terminal
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:edit-line "$saved_stty" "$pos_y"
##
function _input:ml:edit-line() {
  local saved_stty="$1" pos_y=${2:-0}
  local visual_row=$((__ML_ROW - __ML_SCROLL))
  local line_y=$((pos_y + visual_row + 1))

  # Restore terminal for readline
  stty "$saved_stty"
  printf "\033[?25h" >&2  # Show cursor
  printf "\033[%d;1H\033[K" "$line_y" >&2  # Position and clear line

  # Use readline for editing (full word movement, history, etc.)
  local REPLY
  if read -rei "${__ML_LINES[$__ML_ROW]}" -p "$(printf '%4s ' "$((__ML_ROW + 1))")" 2>&1; then
    if [[ "$REPLY" != "${__ML_LINES[$__ML_ROW]}" ]]; then
      __ML_LINES[$__ML_ROW]="$REPLY"
      __ML_MODIFIED=true
    fi
    __ML_COL=${#REPLY}
  fi

  # Return to raw mode
  stty raw -echo
}

##
## Render the multi-line editor to terminal
##
## Parameters:
## - pos_x - Left offset, integer, default: 0
## - pos_y - Top offset, integer, default: 0
##
## Globals:
## - reads/listen: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL, __ML_WIDTH, __ML_HEIGHT
## - mutate/publish: none
##
## Side effects:
## - Writes ANSI escape sequences to stderr
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:render 0 0
##
function _input:ml:render() {
  local pos_x=${1:-0} pos_y=${2:-0}

  # Hide cursor during render
  printf "\033[?25l" >&2

  # Status bar (line 0) - inspired by bed editor
  if [[ "$__ML_STATUS_BAR" == "true" ]]; then
    local status_modified=""
    [[ "$__ML_MODIFIED" == "true" ]] && status_modified="[+] "
    local status_info="L$((__ML_ROW + 1)):C$((__ML_COL + 1)) ${status_modified}${#__ML_LINES[@]}L"
    local status_msg="${__ML_MESSAGE:-Ctrl+D save | Esc cancel | Ctrl+E edit line}"
    local status_text=" ${status_msg}"
    local status_right=" ${status_info} "
    local status_pad=$((__ML_WIDTH - ${#status_text} - ${#status_right}))
    [[ $status_pad -lt 0 ]] && status_pad=0

    printf "\033[%d;%dH" "$((pos_y + 1))" "$((pos_x + 1))" >&2
    printf "\033[100m\033[37m%s%*s%s\033[0m" "$status_text" "$status_pad" "" "$status_right" >&2
  fi

  local render_start=0
  [[ "$__ML_STATUS_BAR" == "true" ]] && render_start=1

  local i buf_idx line_content padding
  local content_height=$((__ML_HEIGHT))
  [[ "$__ML_STATUS_BAR" == "true" ]] && content_height=$((__ML_HEIGHT - 1))

  for ((i = 0; i < content_height; i++)); do
    buf_idx=$((i + __ML_SCROLL))
    line_content=""

    if [[ $buf_idx -lt ${#__ML_LINES[@]} ]]; then
      line_content="${__ML_LINES[$buf_idx]}"
    elif [[ $buf_idx -eq ${#__ML_LINES[@]} ]]; then
      line_content="~"
    fi

    # Truncate to fit width
    if [[ ${#line_content} -gt $__ML_WIDTH ]]; then
      line_content="${line_content:0:$__ML_WIDTH}"
    fi

    # Pad with spaces
    padding=$((__ML_WIDTH - ${#line_content}))
    if [[ $padding -gt 0 ]]; then
      line_content="${line_content}$(printf '%*s' "$padding" "")"
    fi

    # Draw at position (offset by status bar)
    printf "\033[%d;%dH" "$((pos_y + i + 1 + render_start))" "$((pos_x + 1))" >&2

    # Highlight current line with slightly different background
    if [[ $buf_idx -eq $__ML_ROW ]]; then
      printf "\033[44m\033[97m%s\033[0m" "$line_content" >&2
    else
      printf "\033[44m\033[37m%s\033[0m" "$line_content" >&2
    fi
  done

  # Show cursor at correct position
  local visual_row=$((__ML_ROW - __ML_SCROLL))
  local visual_col=$__ML_COL
  [[ $visual_col -ge $__ML_WIDTH ]] && visual_col=$((__ML_WIDTH - 1))

  printf "\033[%d;%dH" "$((pos_y + visual_row + 1 + render_start))" "$((pos_x + visual_col + 1))" >&2
  printf "\033[?25h" >&2
}

##
## Interactive multi-line text editor in terminal
##
## Opens a modal text editor at specified position with configurable dimensions.
## Supports arrow key navigation, backspace, word delete, newline, tab, paste.
## Press Ctrl+D to save and exit, Esc to cancel.
## Press Ctrl+E for readline-based editing of current line (full word movement).
##
## Features inspired by the bed (bash editor) project:
## - Alternative terminal buffer (--alt-buffer) to preserve scroll history
## - WINCH signal handling for terminal resize
## - Configurable keybindings via ML_KEY_* environment variables
## - Modified indicator in status bar
## - Readline-based line editing (Ctrl+E)
## - Status bar with position info and help hints
##
## Parameters:
## - -x pos_x - Left offset, integer, default: 0
## - -y pos_y - Top offset, integer, default: 0
## - -w width - Editor width, integer, default: terminal width
## - -h height - Editor height, integer, default: terminal height
## - --alt-buffer - Use alternative terminal buffer (preserves scroll history)
## - --no-status - Hide status bar
##
## Globals:
## - reads/listen: TERM, ML_KEY_SAVE, ML_KEY_CANCEL, ML_KEY_EDIT, ML_KEY_PASTE,
##                 ML_KEY_DEL_WORD, ML_KEY_DEL_LINE
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL, __ML_MODIFIED
##
## Side effects:
## - Saves/restores terminal state (stty)
## - Traps INT/TERM/WINCH for cleanup and resize
## - Reads raw keyboard input
## - Renders to terminal via ANSI escape sequences
##
## Returns:
## - 0 on save (Ctrl+D), 1 on cancel (Esc)
## - Echoes captured text to stdout
##
## Usage:
## - text=$(input:multi-line)
## - text=$(input:multi-line -w 60 -h 10 -x 5 -y 2)
## - text=$(input:multi-line --alt-buffer)
## - ML_KEY_SAVE=$'\x13' text=$(input:multi-line)  # Ctrl+S to save
##
function input:multi-line() {
  local pos_x=0 pos_y=0 width height
  local use_alt_buffer=false

  # Detect terminal dimensions
  width=$(tput cols 2>/dev/null || echo 80)
  height=$(tput lines 2>/dev/null || echo 24)
  __ML_STATUS_BAR=true

  # Parse arguments
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -x) pos_x="$2"; shift ;;
    -y) pos_y="$2"; shift ;;
    -w) width="$2"; shift ;;
    -h) height="$2"; shift ;;
    --alt-buffer) use_alt_buffer=true ;;
    --no-status) __ML_STATUS_BAR=false ;;
    *) shift; continue ;;
    esac
    shift
  done

  _input:ml:init "$width" "$height"

  # Configurable keybindings as semantic tokens (use _input:capture-key to find tokens)
  local key_save=${ML_KEY_SAVE:-"ctrl-d"}
  local key_edit=${ML_KEY_EDIT:-"ctrl-e"}
  local key_paste=${ML_KEY_PASTE:-"ctrl-v"}
  local key_del_word=${ML_KEY_DEL_WORD:-"ctrl-w"}
  local key_del_line=${ML_KEY_DEL_LINE:-"ctrl-u"}

  # Detect clipboard paste command
  local paste_cmd=""
  if command -v xclip >/dev/null 2>&1; then
    paste_cmd="xclip -o -selection clipboard"
  elif command -v pbpaste >/dev/null 2>&1; then
    paste_cmd="pbpaste"
  fi

  # Save terminal state
  local saved_stty
  saved_stty=$(stty -g)
  stty raw -echo

  # Alternative buffer (preserves terminal scroll history)
  [[ "$use_alt_buffer" == "true" ]] && printf "\033[?1049h" >&2

  # Cleanup on exit
  local __ml_cancelled=0
  function _input:ml:cleanup() {
    stty "$saved_stty"
    [[ "$use_alt_buffer" == "true" ]] && printf "\033[?1049l" >&2
    printf "\033[%d;0H\n" "$((pos_y + __ML_HEIGHT + 1))" >&2
  }
  trap '_input:ml:cleanup; exit' INT TERM

  # WINCH handler: update dimensions on terminal resize
  function _input:ml:winch() {
    local new_w new_h
    new_w=$(tput cols 2>/dev/null || echo "$__ML_WIDTH")
    new_h=$(tput lines 2>/dev/null || echo "$__ML_HEIGHT")
    __ML_WIDTH=$new_w
    __ML_HEIGHT=$new_h
    _input:ml:scroll
  }
  trap '_input:ml:winch' WINCH

  local key

  while true; do
    _input:ml:render "$pos_x" "$pos_y"

    # Read with timeout for responsive WINCH handling (bed pattern)
    key=$(_input:read-key -t 0.1) || continue

    case "$key" in
    # Configurable action keys
    "$key_save")    break ;;
    "$key_edit")    _input:ml:edit-line "$saved_stty" "$pos_y" ;;
    "$key_paste")
      if [[ -n "$paste_cmd" ]]; then
        local clipboard_text
        clipboard_text=$($paste_cmd 2>/dev/null)
        [[ -n "$clipboard_text" ]] && _input:ml:paste "$clipboard_text"
      fi ;;
    "$key_del_word")  _input:ml:delete-word ;;
    "$key_del_line")  _input:ml:delete-line ;;
    # Navigation
    up)        _input:ml:move-up ;;
    down)      _input:ml:move-down ;;
    left)      _input:ml:move-left ;;
    right)     _input:ml:move-right ;;
    home)      _input:ml:move-home ;;
    end)       _input:ml:move-end ;;
    page-up)   local i; for ((i = 0; i < __ML_HEIGHT - 2; i++)); do _input:ml:move-up; done ;;
    page-down) local i; for ((i = 0; i < __ML_HEIGHT - 2; i++)); do _input:ml:move-down; done ;;
    # Editing
    escape)    __ml_cancelled=1; break ;;
    backspace) _input:ml:delete-char ;;
    enter)     _input:ml:insert-newline ;;
    tab)       _input:ml:insert-tab ;;
    char:*)    _input:ml:insert-char "${key#char:}" ;;
    *)         ;; # Ignore unknown sequences
    esac
  done

  # Restore terminal
  _input:ml:cleanup
  trap - INT TERM WINCH

  if [[ $__ml_cancelled -eq 1 ]]; then
    return 1
  fi

  _input:ml:get-content
}

##
## Interactive menu selector from associative array
##
## Parameters:
## - sourceVariableName - Name of associative array to read from, string, required
## - keyOrValue - Return "key" or "value" from array, string, default: "key"
##
## Globals:
## - reads/listen: cursor:position:row, cursor:position:col
## - mutate/publish: none
##
## Side effects:
## - Hides/shows cursor during selection
##
## Returns:
## - 0 on success, 1 on escape/abort
## - Echoes selected key or value from array
##
## Usage:
## - declare -A MENU=([1]="Option 1" [2]="Option 2")
## - selected=$(input:selector "MENU" "value")
##
function input:selector() {
  local sourceVariableName=$1
  local keyOrValue=${2:-"key"}

  tput civis >&2 # hide cursor
  local pos=0 max=-1 keys=() && declare -A items
  local y_pos=$(cursor:position:row) x_pos=$(cursor:position:col) max_col=$(tput cols)
  local _keys=$(eval "echo \"\${!${sourceVariableName}[@]}\"")
  for key in $_keys; do max=$((max + 1)) && keys+=("$key"); done
  for key in "${keys[@]}"; do items[$key]="$(eval "echo \"\${${sourceVariableName}[\"$key\"]}\"")"; done

  local hint="${cl_grey}(←,→,↵,Esc)${cl_reset}"
  local distance=$((max_col - x_pos - ${#hint} - 4))
  local filler=$(printf ' %.0s' $(seq 1 $distance))
  local eraser=$(printf ' %.0s' $(seq 1 $((max_col - x_pos - 1))))

  function selections() {
    local highlight=${1:-""}
    local output="" bg="" seperator="" counter=0 value=""
    for key in "${keys[@]}"; do
      if [ "$counter" -eq "$pos" ]; then bg="$cl_selected"; else bg=""; fi
      if [ "$counter" -eq "$pos" ]; then value="${items[$key]}"; else value="${items[$key]}"; fi
      output+="${separator}${bg} ${value}${bg} ${cl_reset}"
      counter=$((counter + 1))
      separator=" | "
    done
    echo "$output"
  }
  function reprint() {
    tput cup $((y_pos - 1)) $((x_pos - 1)) 1>&2
    echo -n -e "$1" 1>&2
    tput cup $((y_pos - 1)) $((x_pos + pos - 1)) 1>&2
  }
  function reset() {
    reprint "$filler$hint"
    pos=0
    reprint "$(selections)"
  }
  function left() {
    if [ "$pos" -gt 0 ]; then
      pos=$((pos - 1))
      reprint "$(selections)"
    fi
  }
  function right() {
    if [ "$pos" -lt "$max" ]; then
      pos=$((pos + 1))
      reprint "$(selections)"
    fi
  }
  function search() {
    # find first value that contains the search char
    local search=$1 index=0
    for key in "${keys[@]}"; do
      if [[ "${items[$key]}" == *"$search"* ]]; then
        pos=$index
        reprint "$(selections "$search")"
        break
      fi
      index=$((index + 1))
    done
  }

  reset

  local key
  while :; do
    echo:Common "- $pos"

    key=$(_input:read-key)
    echo:Common "key: $key"

    case "$key" in
    right)   right ;;
    left)    left ;;
    enter)   break ;;
    escape)  reset && continue ;;
    char:*)  search "${key#char:}" ;;
    *)       ;; # Ignore all other keys
    esac
  done

  # echo "items: $sourceVariableName" "${items[*]}" "|" "${keys[@]}" "|" "${!items[@]}" >&2

  tput cnorm >&2 # show cursor
  reprint "$eraser"

  if [ "$keyOrValue" = "key" ]; then
    # return KEY part of the KEY-VALUE pair
    [ "$pos" -gt "$max" ] && echo "" || echo "${keys[$pos]}"
  else
    # return VALUE part of the KEY-VALUE pair
    [ "$pos" -gt "$max" ] && echo "" || echo "${items[${keys[$pos]}]}"
  fi
}

# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

logger common "$@"             # register own logger
logger:redirect "common" ">&2" # redirect to STDERR

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

# old version of function names
alias now='time:now'
alias print_time_diff=time:diff
alias validate_input=validate:input
alias validate_yn_input=validate:input:yn
alias env_variable_or_secret_file=env:variable:or:secret:file
alias optional_env_variable_or_secret_file=env:variable:or:secret:file:optional
alias isHelp=args:isHelp

##
## Module: Common Utilities and Helper Functions
##
## This module provides a collection of frequently used utility functions
## for time handling, cursor position, input validation, git operations,
## config file discovery, and user interaction.
#
## References:
## - demo: demo.readpswd.sh, demo.selector.sh, demo.multi-line.sh, demo.capture-key.sh
## - bin: git.semantic-version.sh, ci.validate-envrc.sh
## - documentation: docs/public/commons.md
## - tests: spec/commons_spec.sh, spec/multi_line_input_spec.sh
##
## Globals:
## - E_BASH - Path to .scripts directory
## - use_macos_extensions - Enable macOS-specific features, boolean, default: based on OSTYPE
##
## Categories:
##
## Time Functions:
## - time:now() - Get current epoch timestamp with microseconds
## - time:diff(start) - Calculate time difference
##
## Cursor/Position Functions:
## - cursor:position() - Get "row;col" position
## - cursor:position:row() - Get row number
## - cursor:position:col() - Get column number
##
## Input Functions:
## - input:readpwd() - Read password with masking and line editing
## - input:selector() - Interactive menu selector from array
## - input:multi-line() - Interactive multi-line text editor
## - validate:input() - Generic input validation
## - validate:input:masked() - Masked input validation
## - validate:input:yn() - Yes/no input validation
## - confirm:by:input() - Cascading default confirmation
##
## Environment Functions:
## - env:variable:or:secret:file() - Get env var or read from secret file
## - env:variable:or:secret:file:optional() - Optional version
## - env:resolve() - Expand {{env.VAR}} templates
##
## Value Coalescing Functions:
## - var:l0() - Get variable or default
## - var:l1() - Try var1, var2, or default
## - val:l0() - Try value or default
## - val:l1() - Try value1, value2, or default
##
## String/Slug Functions:
## - to:slug:hash() - Generate hash for slug
## - to:slug() - Convert string to filesystem-safe slug
##
## Git Functions:
## - git:root() - Find git repository root (handles worktrees, submodules)
## - args:isHelp() - Check if --help flag present
##
## Config Discovery Functions:
## - config:hierarchy() - Find config files upward in directory tree
## - config:hierarchy:xdg() - XDG-compliant config discovery
##