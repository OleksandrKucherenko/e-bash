#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-14
## Version: 1.0.0
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
