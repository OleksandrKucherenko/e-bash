#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-30
## Version: 1.17.2
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

function time:now() {
  echo "$EPOCHREALTIME" # <~ bash 5.0
  #python -c 'import datetime; print datetime.datetime.now().strftime("%s.%f")'
}

# shellcheck disable=SC2155,SC2086
function time:diff() {
  local diff="$(time:now) - $1"
  bc <<<$diff
}

# ref: https://unix.stackexchange.com/questions/88296/get-vertical-cursor-position

# get cursor position in "row;col" format
function cursor:position() {
  local CURPOS
  read -sdR -p $'\E[6n' CURPOS
  CURPOS=${CURPOS#*[} # Strip decoration characters <ESC>[
  echo "${CURPOS}"    # Return position in "row;col" format
}

# get cursor position in row
function cursor:position:row() {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${ROW#*[}"
}

# get cursor position in column
function cursor:position:col() {
  local COL
  local ROW
  IFS=';' read -sdR -p $'\E[6n' ROW COL
  echo "${COL}"
}

# ref: https://stackoverflow.com/questions/10679188/casing-arrow-keys-in-bash

## Read user input with masked input
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

  local c0 c1 c2 c3 c4 c5 code esc

  while :; do
    echo:Common "- $PWORD,$pos"
    # Note: a NULL will return a empty string; Ctrl + Alt + Shift + Key produce 6 chars
    IFS= read -r -n 1 -s c0
    IFS= read -r -n 1 -s -t 0.0001 c1
    IFS= read -r -n 1 -s -t 0.0001 c2
    IFS= read -r -n 1 -s -t 0.0001 c3
    IFS= read -r -n 1 -s -t 0.0001 c4
    IFS= read -r -n 1 -s -t 0.0001 c5

    # Convert users key press to hexadecimal character code
    code=$(printf '%02x' "'$c0") # EOL (empty c0) -> 00
    esc="$(printf '%02x%02x%02x' "'$c0" "'$c1" "'$c2")"
    printf:Common 'none: %02x%02x%02x%02x%02x%02x' "'$c0" "'$c1" "'$c2" "'$c3" "'$c4" "'$c5"

    case "$code" in
    # Escape sequence, read in two more chars
    1b)
      # reset input on single escape sequences
      if [ "$c1" == '' ]; then reset && continue; fi

      case "$esc" in
      1b5b41) home ;;    # up arrow
      1b5b42) endline ;; # down arrow
      1b5b43) right ;;   # right arrow
      1b5b44) left ;;    # left arrow
      *) ;;              # Ignore any other escape sequence
      esac
      ;;
    '' | 00 | 0a | 0d) break ;; # Exit EOF, Linefeed or Return
    08 | 7f) delete ;;          # backspace or delete
    15) reset ;;                # ^U or kill line
    [01]?) ;;                   # Ignore ALL other control characters
    # Note: insert from clipboard can be treated as many chars at once
    *) add "$c0$c1$c2$c3$c4$c5" ;;
    esac
  done
  # tput rc # Restore cursor position

  echo "${PWORD}"
}

# shellcheck disable=SC2086
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
function validate:input:yn() {
  # Prompts the user for a yes/no input and stores the result as a boolean value
  #
  # Arguments:
  #   $1 - variable: Name of the variable to store the result in (passed by reference)
  #   $2 - default: Default value to suggest to the user (optional)
  #   $3 - hint: Prompt text to display to the user (optional)
  #
  # Returns:
  #   Sets the variable named in $1 to 'true' for yes responses or 'false' for no/other responses
  #
  # Example:
  #   validate:input:yn result "y" "Do you want to continue?"
  #   if $result; then
  #     echo "User selected yes"
  #   else
  #     echo "User selected no"
  #   fi

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
function env:variable:or:secret:file() {
  #
  # Usage:
  #     env:variable:or:secret:file "new_value" \
  #       "GITLAB_CI_INTEGRATION_TEST" \
  #       ".secrets/gitlab_ci_integration_test" \
  #       "{user friendly message}"
  #
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
function env:variable:or:secret:file:optional() {
  #
  # Usage:
  #     env:variable:or:secret:file:optional "new_value" \
  #       "GITLAB_CI_INTEGRATION_TEST" \
  #       ".secrets/gitlab_ci_integration_test"
  #
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

function env:resolve() {
  # Resolve {{env.VAR_NAME}} patterns in a string to their environment variable values
  #
  # Arguments:
  #   $1 - input_string: The string containing {{env.*}} patterns to expand (optional in pipeline mode)
  #   $2 - array_name: Name of a globally defined associative array for custom variable resolution (optional)
  #
  # Pipeline mode (when stdin is not a terminal):
  #   echo "{{env.VAR}}" | env:resolve               # Read from stdin, use env vars
  #   cat file.txt | env:resolve "CUSTOM_VARS"       # Read from stdin, use custom array + env vars
  #
  # Direct mode:
  #   env:resolve "string"                           # Use env vars only
  #   env:resolve "string" "CUSTOM_VARS"             # Use custom array + env vars
  #
  # Returns:
  #   The string with all {{env.VAR_NAME}} patterns replaced with their values
  #   Resolution priority: associative array > environment variables
  #   If a variable is not found in either source, it will be replaced with an empty string
  #
  # Supports optional whitespace in patterns:
  #   {{env.VAR}}, {{ env.VAR }}, {{  env.VAR  }} are all valid
  #
  # Example:
  #   # Using environment variables
  #   export MY_PATH="/usr/local/bin"
  #   result=$(env:resolve "Path is: {{env.MY_PATH}}")  # Returns "Path is: /usr/local/bin"
  #
  #   # Using custom associative array
  #   declare -A CONFIG=([API_HOST]="api.example.com" [VERSION]="v2")
  #   result=$(env:resolve "https://{{env.API_HOST}}/{{env.VERSION}}" "CONFIG")
  #   # Returns "https://api.example.com/v2"
  #
  #   # Pipeline mode
  #   echo "Config: {{env.HOME}}/.config" | env:resolve
  #   cat template.txt | env:resolve "VARS"

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

# Internal helper function to resolve a single string
# Follows naming convention: _domain:purpose for internal functions
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
      return 1
    fi

    local var_name="${BASH_REMATCH[1]}"
    local var_value=""
    local matched_pattern="${BASH_REMATCH[0]}"

    # Priority 1: Check associative array if provided
    if [[ -n "$arr_name" ]]; then
      # Verify the array exists and is an associative array
      if declare -p "$arr_name" 2>/dev/null | grep -q "declare -A"; then
        # Use eval to access the associative array value
        # This works across different scopes and subshells
        local array_lookup
        array_lookup="echo \"\${${arr_name}[${var_name}]:-__NOTFOUND__}\""
        var_value=$(eval "$array_lookup")

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

    # Escape special characters in replacement value to avoid corruption
    # Bash ${var/pattern/replacement} treats '&' as "matched text" and '\' as escape
    # Replace '\' with '\\' (must be first to avoid double-escaping)
    # Replace '&' with '\&'
    local escaped_value="$var_value"
    escaped_value="${escaped_value//\\/\\\\}"  # Escape backslashes
    escaped_value="${escaped_value//&/\\&}"    # Escape ampersands

    # Store previous state to detect if replacement made progress
    local previous_string="$expanded_string"

    # Replace the full match (including any whitespace) with the escaped variable value
    expanded_string="${expanded_string/$matched_pattern/$escaped_value}"

    # Safety check: if no progress was made, break to prevent infinite loop
    # This handles cases where the value equals the pattern (self-reference)
    if [[ "$expanded_string" == "$previous_string" ]]; then
      echo "$expanded_string" >&2
      echo "ERROR: env:resolve detected self-referential pattern for variable '$var_name'" >&2
      echo "Variable value contains the same placeholder pattern: $matched_pattern" >&2
      return 1
    fi
  done

  echo "$expanded_string"
}

function confirm:by:input() {
  local hint=$1
  local variable=$2
  local fallback=$3
  local top=$4
  local second=$5
  local third=$6
  local masked=$7

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

function var:l0() {
  # Use variable name value, otherwise fallback to default
  #
  # Arguments:
  #   $1 - variable_name: Name of the variable to check
  #   $2 - default: Default value to use if variable is empty or unset
  #
  # Returns:
  #   The value of the variable if set and non-empty, otherwise the default value
  #
  # Example:
  #   MY_VAR="hello"
  #   result=$(var:l0 "MY_VAR" "default_value")  # Returns "hello"
  #   result=$(var:l0 "UNSET_VAR" "default_value")  # Returns "default_value"

  local variable_name=$1
  local default=$2
  local value="${!variable_name}"

  if [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

function var:l1() {
  # Try var1 variable value, otherwise fallback to var2 value, otherwise fallback to default
  #
  # Arguments:
  #   $1 - var1: Name of the first variable to check
  #   $2 - var2: Name of the second variable to check
  #   $3 - default: Default value to use if both variables are empty or unset
  #
  # Returns:
  #   The value of var1 if set and non-empty, otherwise var2 if set and non-empty, otherwise default
  #
  # Example:
  #   VAR1="first"
  #   VAR2="second"
  #   result=$(var:l1 "VAR1" "VAR2" "default")  # Returns "first"
  #   result=$(var:l1 "UNSET" "VAR2" "default")  # Returns "second"
  #   result=$(var:l1 "UNSET1" "UNSET2" "default")  # Returns "default"

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

function val:l0() {
  # Try value, fallback to default
  #
  # Arguments:
  #   $1 - value: The value to check
  #   $2 - default: Default value to use if value is empty
  #
  # Returns:
  #   The value if non-empty, otherwise the default
  #
  # Example:
  #   result=$(val:l0 "hello" "default")  # Returns "hello"
  #   result=$(val:l0 "" "default")  # Returns "default"

  local value=$1
  local default=$2

  if [ -n "$value" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

function val:l1() {
  # Try value1, otherwise try value, fallback to default
  #
  # Arguments:
  #   $1 - value1: The first value to check
  #   $2 - value: The second value to check
  #   $3 - default: Default value to use if both values are empty
  #
  # Returns:
  #   value1 if non-empty, otherwise value if non-empty, otherwise default
  #
  # Example:
  #   result=$(val:l1 "first" "second" "default")  # Returns "first"
  #   result=$(val:l1 "" "second" "default")  # Returns "second"
  #   result=$(val:l1 "" "" "default")  # Returns "default"

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

# Helper function for cross-platform hash generation (used by to:slug)
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

function to:slug() {
  # Convert any string to a filesystem-safe slug
  #
  # Arguments:
  #   $1 - string: The string to convert to slug
  #   $2 - separator: The separator to use (default: "_")
  #   $3 - trim: Maximum length OR strategy (default: 20)
  #       - number: Maximum length, add hash if exceeded
  #       - "always": Always append hash (for deterministic IDs)
  #
  # Returns:
  #   A filesystem-safe slug, trimmed to specified length with hash if needed
  #   If input contains only special characters, returns "__" + hash (7 chars)
  #
  # Example:
  #   result=$(to:slug "Hello World!" "_" 20)       # Returns "hello_world"
  #   result=$(to:slug "Hello World!" "_" "always") # Returns "hello_world_fc3ff98"
  #   result=$(to:slug "Very Long String" "_" 20)   # Returns "very_long_st_a1b2c3d"
  #   result=$(to:slug "Test__Multiple" "_" 50)     # Returns "test_multiple"
  #   result=$(to:slug '!@#$%^&*()' "_" 20)         # Returns "__a1b2c3d" (hash-only)

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

function args:isHelp() {
  local args=("$@")
  if [[ "${args[*]}" =~ "--help" ]]; then echo true; else echo false; fi
}

function git:root() {
  # Find the Git repository root folder from the current folder by searching upward for .git
  # Properly detects regular repos, worktrees, and submodules
  #
  # Arguments:
  #   $1 - start_path: Starting directory path (default: current directory)
  #   $2 - output_type: Type of output to return (default: "path")
  #       - "path": Return the root path
  #       - "type": Return the git repository type (regular|worktree|submodule|none)
  #       - "both": Return "type:path" format
  #       - "all": Return detailed info as "type:path:git_dir"
  #
  # Returns:
  #   0 if git root found, 1 otherwise
  #   STDOUT: Based on output_type parameter
  #
  # Example:
  #   root=$(git:root)                           # Returns "/path/to/repo"
  #   type=$(git:root "." "type")                # Returns "regular" or "worktree" or "submodule"
  #   info=$(git:root "." "both")                # Returns "regular:/path/to/repo"
  #   details=$(git:root "/some/path" "all")     # Returns "worktree:/path/to/repo:/path/to/.git/worktrees/name"

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

function config:hierarchy() {
  # Find hierarchy of configuration files by searching upward from current folder
  # Similar to c12 (https://www.npmjs.com/package/c12) but only for declarative config files
  #
  # Arguments:
  #   $1 - config_name: Base configuration file name(s), comma-separated (e.g., ".myrc,myconfig")
  #   $2 - start_path: Starting directory path (default: current directory)
  #   $3 - stop_at: Where to stop searching (default: "git")
  #       - "git": Stop at git repository root
  #       - "home": Stop at user home directory
  #       - "root": Stop at filesystem root /
  #       - "/custom/path": Stop at specific absolute path
  #   $4 - extensions: Comma-separated list of extensions to check (default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc")
  #       - Empty string "" means exact match only
  #       - List with extensions tries all combinations
  #
  # Returns:
  #   0 if at least one config file found, 1 otherwise
  #   STDOUT: List of config file paths, one per line, ordered from root to current (bottom-up)
  #
  # Example:
  #   config:hierarchy ".eslintrc"                          # Find .eslintrc* files up to git root
  #   config:hierarchy "package.json" "." "home"            # Find package.json up to home
  #   config:hierarchy ".config" "." "git" ".json,.yaml"    # Find .config.json and .config.yaml
  #   config:hierarchy "tsconfig.json,jsconfig.json"        # Find multiple config files

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
    # Absolute path provided
    stop_path="$stop_at"
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

function config:hierarchy:xdg() {
  # Find configuration files following XDG Base Directory Specification
  # Combines hierarchical search with XDG-compliant directories
  #
  # Arguments:
  #   $1 - app_name: Application name for XDG directories (e.g., "myapp" -> ~/.config/myapp/)
  #   $2 - config_name: Config file name(s), comma-separated (e.g., "config,.myapprc")
  #   $3 - start_path: Starting directory path (default: current directory)
  #   $4 - stop_at: Where to stop hierarchical search (default: "home")
  #   $5 - extensions: Comma-separated extensions (default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc")
  #
  # Returns:
  #   0 if at least one config file found, 1 otherwise
  #   STDOUT: List of config file paths, one per line, ordered by priority (highest to lowest)
  #
  # Search order (highest priority first):
  #   1. Hierarchical search from current_dir up to stop_path
  #   2. $XDG_CONFIG_HOME/<app_name>/ (if XDG_CONFIG_HOME is set)
  #   3. ~/.config/<app_name>/ (XDG default user config)
  #   4. /etc/xdg/<app_name>/ (XDG system-wide config)
  #   5. /etc/<app_name>/ (traditional system config)
  #
  # Example:
  #   config:hierarchy:xdg "myapp" "config"                    # Full XDG + hierarchy search
  #   config:hierarchy:xdg "nvim" "init.vim,.nvimrc"           # Find nvim configs
  #   config:hierarchy:xdg "git" "config" "." "home" ""        # Git config hierarchy

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

  local c0 c1 c2 c3 c4 c5 code esc

  while :; do
    echo:Common "- $pos"
    # Note: a NULL will return a empty string; Ctrl + Alt + Shift + Key produce 6 chars
    IFS= read -r -n 1 -s c0
    IFS= read -r -n 1 -s -t 0.0001 c1
    IFS= read -r -n 1 -s -t 0.0001 c2
    IFS= read -r -n 1 -s -t 0.0001 c3
    IFS= read -r -n 1 -s -t 0.0001 c4
    IFS= read -r -n 1 -s -t 0.0001 c5

    # Convert users key press to hexadecimal character code
    code=$(printf '%02x' "'$c0") # EOL (empty c0) -> 00
    esc="$(printf '%02x%02x%02x' "'$c0" "'$c1" "'$c2")"
    printf:Common 'none: %02x%02x%02x%02x%02x%02x' "'$c0" "'$c1" "'$c2" "'$c3" "'$c4" "'$c5"

    case "$code" in
    # Escape sequence, read in two more chars
    1b)
      # reset input on single escape sequences
      if [ "$c1" == '' ]; then reset && continue; fi

      case "$esc" in
      1b5b43) right ;; # right arrow
      1b5b44) left ;;  # left arrow
      *) ;;            # Ignore any other escape sequence
      esac
      ;;
    '' | 00 | 0a | 0d) break ;; # Exit EOF, Linefeed or Return
    [01]?) ;;                   # Ignore ALL other control characters
    # Note: insert from clipboard can be treated as many chars at once
    *) search "$c0$c1$c2$c3$c4$c5" ;;
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
