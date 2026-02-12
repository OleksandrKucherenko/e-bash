#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-12
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2015 # one time initialization, CUID
[[ "${__TUI_LOADED__}" == "yes" ]] && return 0 || __TUI_LOADED__="yes"

# is allowed to use macOS extensions (script can be executed in *nix second)
use_macos_extensions=false
if [[ "$OSTYPE" == "darwin"* ]]; then use_macos_extensions=true; fi

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090  source=./_colors.sh
source "$E_BASH/_colors.sh"

# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

# --- Cursor Position Functions ---

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
  read -srdR -p $'\E[6n' CURPOS
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
  IFS=';' read -srdR -p $'\E[6n' ROW COL
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
  IFS=';' read -srdR -p $'\E[6n' ROW COL
  echo "${COL}"
}

# --- Password Input ---

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
    up | home) home ;;
    down | end) endline ;;
    right) right ;;
    left) left ;;
    enter) break ;;
    backspace) delete ;;
    escape) reset ;;
    ctrl-u) reset ;;
    char:*) add "${key#char:}" ;;
    *) ;; # Ignore all other keys
    esac
  done
  # tput rc # Restore cursor position

  echo "${PWORD}"
}

# --- Input Validation ---

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
## - Paste: paste:payload (bracketed paste - text pasted from clipboard)
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
    -t)
      timeout="$2"
      shift
      ;;
    --raw) use_raw=true ;;
    esac
    shift
  done

  local c0=""
  # First byte: blocking or with timeout
  if [[ -n "$timeout" ]]; then
    IFS= read -rsn1 -t "$timeout" c0 || {
      echo "timeout"
      return 1
    }
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
          break # final byte
        fi
      done

      local final="$byte"
      local modifier="" base_key=""

      # Bracketed paste: CSI 200 ~ ... CSI 201 ~
      if [[ "$final" == "~" && "$params" == "200" ]]; then
        local payload="" paste_ch="" paste_end=$'\x1b[201~'
        while IFS= read -rsn1 -d '' paste_ch; do
          payload+="$paste_ch"
          if [[ ${#payload} -ge ${#paste_end} ]] &&
            [[ "${payload: -${#paste_end}}" == "$paste_end" ]]; then
            payload="${payload:0:$((${#payload} - ${#paste_end}))}"
            break
          fi
        done
        if [[ "$use_raw" == "true" ]]; then
          __INPUT_RAW_CHARS="$raw_chars$payload"
          __INPUT_RAW_BYTES="paste"
        fi
        printf "paste:%s" "$payload"
        return 0
      fi

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
  01)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-a"
    ;; # Ctrl+A
  02)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-b"
    ;; # Ctrl+B
  03)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-c"
    ;; # Ctrl+C
  04)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-d"
    ;; # Ctrl+D
  05)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-e"
    ;; # Ctrl+E
  06)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-f"
    ;; # Ctrl+F
  07)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-g"
    ;; # Ctrl+G
  08)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "backspace"
    ;; # Ctrl+H / BS
  09)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "tab"
    ;; # Ctrl+I / Tab
  0a)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "enter"
    ;; # Ctrl+J / LF
  0b)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-k"
    ;; # Ctrl+K
  0c)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-l"
    ;; # Ctrl+L
  0d)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "enter"
    ;; # Ctrl+M / CR
  0e)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-n"
    ;; # Ctrl+N
  0f)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-o"
    ;; # Ctrl+O
  10)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-p"
    ;; # Ctrl+P
  11)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-q"
    ;; # Ctrl+Q
  12)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-r"
    ;; # Ctrl+R
  13)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-s"
    ;; # Ctrl+S
  14)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-t"
    ;; # Ctrl+T
  15)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-u"
    ;; # Ctrl+U
  16)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-v"
    ;; # Ctrl+V
  17)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-w"
    ;; # Ctrl+W
  18)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-x"
    ;; # Ctrl+X
  19)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-y"
    ;; # Ctrl+Y
  1a)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-z"
    ;; # Ctrl+Z
  7f)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "backspace"
    ;; # DEL (0x7f)
  00)
    _input:_raw "$use_raw" "$code" "$c0"
    echo "ctrl-space"
    ;; # Ctrl+Space / NUL
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
## - source "$E_BASH/_tui.sh" && _input:capture-key
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
  # Selection state
  __ML_SEL_ACTIVE=false
  __ML_SEL_ANCHOR_ROW=0
  __ML_SEL_ANCHOR_COL=0
}

##
## Start or extend text selection from current cursor position
##
## If selection is not active, sets the anchor to the current cursor position.
## Called before a shift+arrow movement so the anchor is fixed and the cursor
## (which represents the moving end of the selection) moves away from it.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_ROW, __ML_COL, __ML_SEL_ACTIVE
## - mutate/publish: __ML_SEL_ACTIVE, __ML_SEL_ANCHOR_ROW, __ML_SEL_ANCHOR_COL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:sel-start   # call before shift+arrow movement
##
function _input:ml:sel-start() {
  if [[ "$__ML_SEL_ACTIVE" != "true" ]]; then
    __ML_SEL_ACTIVE=true
    __ML_SEL_ANCHOR_ROW=$__ML_ROW
    __ML_SEL_ANCHOR_COL=$__ML_COL
  fi
}

##
## Clear text selection
##
## Deactivates the selection without modifying buffer content.
##
## Parameters:
## - none
##
## Globals:
## - mutate/publish: __ML_SEL_ACTIVE
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:sel-clear
##
function _input:ml:sel-clear() {
  __ML_SEL_ACTIVE=false
}

##
## Get normalized selection bounds (start <= end)
##
## Outputs "start_row;start_col;end_row;end_col" where start is
## always before or equal to end in document order. The anchor and
## cursor can be in either order depending on selection direction.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_SEL_ANCHOR_ROW, __ML_SEL_ANCHOR_COL, __ML_ROW, __ML_COL
##
## Returns:
## - 0 on success
## - Echoes "start_row;start_col;end_row;end_col"
##
## Usage:
## - local bounds; bounds=$(_input:ml:sel-bounds)
##
function _input:ml:sel-bounds() {
  local ar=$__ML_SEL_ANCHOR_ROW ac=$__ML_SEL_ANCHOR_COL
  local cr=$__ML_ROW cc=$__ML_COL
  if [[ $ar -lt $cr ]] || { [[ $ar -eq $cr ]] && [[ $ac -le $cc ]]; }; then
    echo "${ar};${ac};${cr};${cc}"
  else
    echo "${cr};${cc};${ar};${ac}"
  fi
}

##
## Get selected text from the buffer
##
## Extracts the text within the current selection bounds.
## Returns empty string if no selection is active.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_SEL_ACTIVE, __ML_LINES
##
## Returns:
## - 0 on success
## - Echoes selected text to stdout
##
## Usage:
## - local text; text=$(_input:ml:sel-get-text)
##
function _input:ml:sel-get-text() {
  [[ "$__ML_SEL_ACTIVE" != "true" ]] && return 0
  local bounds sr sc er ec
  bounds=$(_input:ml:sel-bounds)
  IFS=';' read -r sr sc er ec <<<"$bounds"
  if [[ $sr -eq $er ]]; then
    echo "${__ML_LINES[$sr]:$sc:$((ec - sc))}"
  else
    local result="${__ML_LINES[$sr]:$sc}"
    local i
    for ((i = sr + 1; i < er; i++)); do
      result+=$'\n'"${__ML_LINES[$i]}"
    done
    result+=$'\n'"${__ML_LINES[$er]:0:$ec}"
    echo "$result"
  fi
}

##
## Delete the selected text from the buffer
##
## Removes all characters within the selection bounds and positions
## the cursor at the start of the former selection. Clears the
## selection state afterward.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_SEL_ACTIVE, __ML_LINES
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL, __ML_MODIFIED, __ML_SEL_ACTIVE
##
## Returns:
## - 0 on success, 1 if no active selection
##
## Usage:
## - _input:ml:sel-delete
##
function _input:ml:sel-delete() {
  [[ "$__ML_SEL_ACTIVE" != "true" ]] && return 1
  local bounds sr sc er ec
  bounds=$(_input:ml:sel-bounds)
  IFS=';' read -r sr sc er ec <<<"$bounds"

  # Build the merged line: before-selection + after-selection
  local before="${__ML_LINES[$sr]:0:$sc}"
  local after="${__ML_LINES[$er]:$ec}"
  __ML_LINES[$sr]="${before}${after}"

  # Remove lines between sr+1 and er (inclusive)
  if [[ $er -gt $sr ]]; then
    local new_lines=("${__ML_LINES[@]:0:$((sr + 1))}" "${__ML_LINES[@]:$((er + 1))}")
    __ML_LINES=("${new_lines[@]}")
  fi

  __ML_ROW=$sr
  __ML_COL=$sc
  __ML_MODIFIED=true
  __ML_SEL_ACTIVE=false
  _input:ml:scroll
}

##
## Select all text in the buffer
##
## Sets anchor to start of document and cursor to end of document.
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: __ML_LINES
## - mutate/publish: __ML_SEL_ACTIVE, __ML_SEL_ANCHOR_ROW, __ML_SEL_ANCHOR_COL,
##                   __ML_ROW, __ML_COL, __ML_SCROLL
##
## Returns:
## - 0 on success
##
## Usage:
## - _input:ml:sel-all
##
function _input:ml:sel-all() {
  __ML_SEL_ACTIVE=true
  __ML_SEL_ANCHOR_ROW=0
  __ML_SEL_ANCHOR_COL=0
  local last=$((${#__ML_LINES[@]} - 1))
  __ML_ROW=$last
  __ML_COL=${#__ML_LINES[$last]}
  _input:ml:scroll
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
  # Replace selection with typed character if active
  [[ "$__ML_SEL_ACTIVE" == "true" ]] && _input:ml:sel-delete
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
  # Delete selection if active, then return
  if [[ "$__ML_SEL_ACTIVE" == "true" ]]; then
    _input:ml:sel-delete
    return 0
  fi
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
  # Replace selection with newline if active
  [[ "$__ML_SEL_ACTIVE" == "true" ]] && _input:ml:sel-delete
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
  local last=$((${#__ML_LINES[@]} - 1))
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
## Read cursor row and column with timeout (stream mode)
##
## Queries the terminal for cursor position using DSR (Device Status Report).
## Falls back to "1;1" if the terminal does not respond in time.
##
## Parameters:
## - timeout - Read timeout in seconds, float, default: 0.3
##
## Returns:
## - Echoes "row;col" (1-based), defaults to "1;1" when unavailable
##
## Usage:
## - pos=$(_input:ml:stream:cursor)
## - row="${pos%;*}" col="${pos#*;}"
##
function _input:ml:stream:cursor() {
  local timeout=${1:-0.3}
  local row=1 col=1 prefix=""

  # Try to query cursor position (ESC[6n) and read response (ESC[row;colR)
  # The read -p prompt goes to stderr, response is read from stdin
  # First attempt with specified timeout
  if IFS=';' read -rsdR -t "$timeout" -p $'\E[6n' prefix col; then
    # Strip ESC[ prefix from row (prefix contains "\E[row" before the semicolon)
    row=${prefix#*[}
    # Validate we got numbers
    if [[ "$row" =~ ^[0-9]+$ ]] && [[ "$col" =~ ^[0-9]+$ ]]; then
      printf "%s;%s" "$row" "$col"
      return 0
    fi
  fi

  # Second attempt with longer timeout if first failed (some terminals are slow)
  if [[ "$timeout" != "1.0" ]]; then
    if IFS=';' read -rsdR -t 1.0 -p $'\E[6n' prefix col; then
      row=${prefix#*[}
      if [[ "$row" =~ ^[0-9]+$ ]] && [[ "$col" =~ ^[0-9]+$ ]]; then
        printf "%s;%s" "$row" "$col"
        return 0
      fi
    fi
  fi

  # Fallback: return default position
  printf "%s;%s" "$row" "$col"
  return 0
}

##
## Normalize stream mode height
##
## Clamps to minimum 1 line.
##
## Parameters:
## - requested_height - Requested height, integer, required
##
## Returns:
## - Echoes normalized height (>= 1)
##
function _input:ml:stream:fit-height() {
  local requested_height=${1:-1}
  [[ "$requested_height" =~ ^[0-9]+$ ]] || requested_height=1
  [[ "$requested_height" -lt 1 ]] && requested_height=1

  printf "%s" "$requested_height"
  return 0
}

##
## Allocate stream editor lines from anchor row
##
## When the editor would overflow the bottom of the terminal,
## emits newlines to scroll the terminal up and returns an
## adjusted anchor row so rendering stays on-screen.
##
## Parameters:
## - anchor_row - Row where stream starts, integer, required
## - line_count - Number of lines to allocate, integer, required
## - terminal_height - Total terminal rows, integer, required
##
## Side effects:
## - Writes newlines to stderr when overflow occurs
##
## Returns:
## - 0 on success
## - Echoes adjusted anchor row
##
function _input:ml:stream:allocate() {
  local anchor_row=${1:-1} line_count=${2:-0} terminal_height=${3:-24}
  local overflow=0 adjusted_row=1 i=0

  [[ "$anchor_row" =~ ^[0-9]+$ ]] || anchor_row=1
  [[ "$line_count" =~ ^[0-9]+$ ]] || line_count=0
  [[ "$terminal_height" =~ ^[0-9]+$ ]] || terminal_height=24
  [[ "$anchor_row" -lt 1 ]] && anchor_row=1
  [[ "$line_count" -lt 1 ]] && line_count=1
  [[ "$terminal_height" -lt 1 ]] && terminal_height=1

  overflow=$((anchor_row + line_count - terminal_height - 1))
  [[ "$overflow" -lt 0 ]] && overflow=0
  adjusted_row=$((anchor_row - overflow))
  [[ "$adjusted_row" -lt 1 ]] && adjusted_row=1

  if [[ -t 2 ]]; then
    for ((i = 0; i < overflow; i++)); do
      printf "\n" >&2
    done
  fi

  printf "%s" "$adjusted_row"
  return 0
}

##
## Restore cursor position after stream editor closes
##
## Moves cursor to the original anchor position so that
## the lines occupied by the editor can be reused for output.
##
## Parameters:
## - anchor_row - Row where stream started, integer, required
## - anchor_col - Column where output continues, integer, default: 1
##
## Side effects:
## - Repositions cursor via ANSI escape
##
## Returns:
## - 0 on success
##
function _input:ml:stream:restore() {
  local anchor_row=${1:-1} anchor_col=${2:-1}

  [[ "$anchor_row" =~ ^[0-9]+$ ]] || anchor_row=1
  [[ "$anchor_col" =~ ^[0-9]+$ ]] || anchor_col=1
  [[ "$anchor_row" -lt 1 ]] && anchor_row=1
  [[ "$anchor_col" -lt 1 ]] && anchor_col=1

  printf "\033[%d;%dH" "$anchor_row" "$anchor_col" >&2
  return 0
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
  # Replace selection with pasted text if active
  [[ "$__ML_SEL_ACTIVE" == "true" ]] && _input:ml:sel-delete
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
    local last_idx=$((${#paste_lines[@]} - 1))
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
  printf "\033[?25h" >&2                  # Show cursor
  printf "\033[%d;1H\033[0m\033[K" "$line_y" >&2 # Position, reset colors, clear line

  # Display prompt with line number and current text
  local prompt="$(printf '%4s ' "$((__ML_ROW + 1))")"
  local initial_text="${__ML_LINES[$__ML_ROW]}"

  # Use readline for editing (full word movement, history, etc.)
  # Note: output goes directly to terminal (not redirected)
  local REPLY
  if read -rei "$initial_text" -p "$prompt"; then
    if [[ "$REPLY" != "$initial_text" ]]; then
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

  # Hide cursor and disable line-wrap during render (prevents glitches on full-width lines)
  printf "\033[?25l\033[?7l" >&2

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

  # Pre-compute selection bounds for render loop
  local sel_sr=-1 sel_sc=-1 sel_er=-1 sel_ec=-1
  if [[ "$__ML_SEL_ACTIVE" == "true" ]]; then
    local sel_bounds
    sel_bounds=$(_input:ml:sel-bounds)
    IFS=';' read -r sel_sr sel_sc sel_er sel_ec <<<"$sel_bounds"
  fi

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

    # Determine line colors: current-line highlight + selection overlay
    local line_fg="\033[37m" line_bg="\033[44m"
    [[ $buf_idx -eq $__ML_ROW ]] && line_fg="\033[97m"

    if [[ $sel_sr -ge 0 && $buf_idx -ge $sel_sr && $buf_idx -le $sel_er ]]; then
      # This line has selection — render in segments: before | selected | after
      local s_start=0 s_end=${#line_content}

      if [[ $buf_idx -eq $sel_sr ]]; then s_start=$sel_sc; fi
      if [[ $buf_idx -eq $sel_er ]]; then s_end=$sel_ec; fi

      # Clamp to line width
      [[ $s_start -gt ${#line_content} ]] && s_start=${#line_content}
      [[ $s_end -gt ${#line_content} ]] && s_end=${#line_content}

      local part_before="${line_content:0:$s_start}"
      local part_sel="${line_content:$s_start:$((s_end - s_start))}"
      local part_after="${line_content:$s_end}"

      printf "%b%b%s" "$line_bg" "$line_fg" "$part_before" >&2
      printf "%s%s" "$cl_selected" "$part_sel" >&2
      printf "\033[0m%b%b%s\033[0m" "$line_bg" "$line_fg" "$part_after" >&2
    else
      printf "%b%b%s\033[0m" "$line_bg" "$line_fg" "$line_content" >&2
    fi
  done

  # Show cursor at correct position
  local visual_row=$((__ML_ROW - __ML_SCROLL))
  local visual_col=$__ML_COL
  [[ $visual_col -ge $__ML_WIDTH ]] && visual_col=$((__ML_WIDTH - 1))

  printf "\033[%d;%dH" "$((pos_y + visual_row + 1 + render_start))" "$((pos_x + visual_col + 1))" >&2
  printf "\033[?7h\033[?25h" >&2 # Re-enable line-wrap, show cursor
}

##
## Interactive multi-line text editor in terminal
##
## Opens a modal text editor with two rendering modes:
##
## **Box mode** (default): Position and size the editor explicitly with
## -x, -y, -w, -h. Useful for modal dialog overlays. Supports --alt-buffer
## to preserve terminal scroll history.
##
## **Stream mode** (-m stream): Uses current cursor position, full terminal
## width, and a configurable height (default 5 lines). If the cursor is near
## the bottom of the terminal, emits newlines to scroll up and make room.
## On exit, repositions cursor to the editor area so output reuses those lines.
##
## Features inspired by the bed (bash editor) project:
## - Alternative terminal buffer (--alt-buffer, box mode only)
## - WINCH signal handling for terminal resize
## - Configurable keybindings via ML_KEY_* environment variables
## - Bracketed paste detection (paste from clipboard)
## - Text selection via Shift+arrow keys (highlighted with cl_selected)
## - Clipboard integration: Ctrl+C copy, Ctrl+X cut, Ctrl+V paste
## - Select all with Ctrl+A
## - Modified indicator in status bar
## - Readline-based line editing (Ctrl+E)
## - Status bar with position info and help hints
##
## Parameters:
## - -m mode - Rendering mode: "box" (default) or "stream"
## - -x pos_x - Left offset (box mode only), integer, default: 0
## - -y pos_y - Top offset (box mode only), integer, default: 0
## - -w width - Editor width, integer, default: terminal width
## - -h height - Editor height, integer, default: terminal height (box) or 5 (stream)
## - --alt-buffer - Use alternative terminal buffer (box mode only)
## - --no-status - Hide status bar
##
## Globals:
## - reads/listen: TERM, ML_KEY_SAVE, ML_KEY_EDIT, ML_KEY_DEL_WORD, ML_KEY_DEL_LINE,
##                 cl_selected
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL, __ML_MODIFIED,
##                   __ML_SEL_ACTIVE, __ML_SEL_ANCHOR_ROW, __ML_SEL_ANCHOR_COL
##
## Side effects:
## - Saves/restores terminal state (stty)
## - Traps INT/TERM/WINCH for cleanup and resize
## - Reads raw keyboard input
## - Renders to terminal via ANSI escape sequences
## - Enables/disables bracketed paste mode
##
## Returns:
## - 0 on save (Ctrl+D), 1 on cancel (Esc)
## - Echoes captured text to stdout
##
## Usage:
## - text=$(input:multi-line)                            # box mode, full screen
## - text=$(input:multi-line -w 60 -h 10 -x 5 -y 2)     # box mode, positioned
## - text=$(input:multi-line --alt-buffer)                # box mode, alt buffer
## - text=$(input:multi-line -m stream)                   # stream mode, 5 lines
## - text=$(input:multi-line -m stream -h 10)             # stream mode, 10 lines
## - ML_KEY_SAVE="ctrl-s" text=$(input:multi-line)        # custom save key
##
function input:multi-line() {
  local pos_x=0 pos_y=0 width="" height=""
  local mode="box" use_alt_buffer=false
  local height_is_explicit=0
  local term_width term_height
  local stream_row=0 stream_col=1

  # Detect terminal dimensions
  term_width=$(tput cols 2>/dev/null || echo 80)
  term_height=$(tput lines 2>/dev/null || echo 24)
  [[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80
  [[ "$term_height" =~ ^[0-9]+$ ]] || term_height=24
  __ML_STATUS_BAR=true

  # Parse arguments
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -x)
      pos_x="$2"
      shift
      ;;
    -y)
      pos_y="$2"
      shift
      ;;
    -m | --mode)
      mode="$2"
      shift
      ;;
    -w)
      width="$2"
      shift
      ;;
    -h)
      height="$2"
      height_is_explicit=1
      shift
      ;;
    --alt-buffer) use_alt_buffer=true ;;
    --no-status) __ML_STATUS_BAR=false ;;
    *)
      shift
      continue
      ;;
    esac
    shift
  done

  # Validate mode
  [[ "$mode" != "box" && "$mode" != "stream" ]] && mode="box"

  # Mode-specific dimension setup
  if [[ "$mode" == "stream" ]]; then
    # Stream mode: cursor position, terminal width, default height 5
    local stream_pos
    stream_pos=$(_input:ml:stream:cursor)
    stream_row="${stream_pos%;*}"
    stream_col="${stream_pos#*;}"
    [[ "$stream_row" =~ ^[0-9]+$ ]] || stream_row=1
    [[ "$stream_col" =~ ^[0-9]+$ ]] || stream_col=1

    [[ "$height_is_explicit" -eq 0 ]] && height=5
    height=$(_input:ml:stream:fit-height "$height")
    [[ "$height" -gt "$term_height" ]] && height="$term_height"
    width="$term_width"
    pos_x=0

    # Alt buffer not used in stream mode
    use_alt_buffer=false
  else
    # Box mode: explicit or full-terminal positioning
    [[ -n "$width" ]] || width="$term_width"
    [[ -n "$height" ]] || height="$term_height"
    [[ "$width" =~ ^[0-9]+$ ]] || width="$term_width"
    [[ "$height" =~ ^[0-9]+$ ]] || height="$term_height"
    [[ "$pos_x" =~ ^[0-9]+$ ]] || pos_x=0
    [[ "$pos_y" =~ ^[0-9]+$ ]] || pos_y=0

    # Clamp to terminal boundaries
    local max_width=$((term_width - pos_x))
    [[ "$max_width" -lt 1 ]] && max_width=1
    [[ "$width" -gt "$max_width" ]] && width="$max_width"
    local max_height=$((term_height - pos_y))
    [[ "$max_height" -lt 1 ]] && max_height=1
    [[ "$height" -gt "$max_height" ]] && height="$max_height"
  fi

  _input:ml:init "$width" "$height"

  # Stream mode: allocate lines (handles bottom-of-terminal scrolling)
  if [[ "$mode" == "stream" ]]; then
    stream_row=$(_input:ml:stream:allocate "$stream_row" "$__ML_HEIGHT" "$term_height")
    [[ "$stream_row" =~ ^[0-9]+$ ]] || stream_row=1
    [[ "$stream_row" -lt 1 ]] && stream_row=1
    pos_y=$((stream_row - 1))
  fi

  # Configurable keybindings as semantic tokens (use _input:capture-key to find tokens)
  local key_save=${ML_KEY_SAVE:-"ctrl-d"}
  local key_edit=${ML_KEY_EDIT:-"ctrl-e"}
  local key_del_word=${ML_KEY_DEL_WORD:-"ctrl-w"}
  local key_del_line=${ML_KEY_DEL_LINE:-"ctrl-u"}

  # Detect clipboard commands (read from / write to system clipboard)
  local paste_cmd="" clipboard_cmd=""
  if command -v xclip >/dev/null 2>&1; then
    paste_cmd="xclip -o -selection clipboard"
    clipboard_cmd="xclip -i -selection clipboard"
  elif command -v xsel >/dev/null 2>&1; then
    paste_cmd="xsel --clipboard --output"
    clipboard_cmd="xsel --clipboard --input"
  elif command -v pbpaste >/dev/null 2>&1; then
    paste_cmd="pbpaste"
    clipboard_cmd="pbcopy"
  fi

  # Save terminal state
  local saved_stty
  saved_stty=$(stty -g)
  stty raw -echo

  # Alternative buffer (preserves terminal scroll history, box mode only)
  [[ "$use_alt_buffer" == "true" ]] && printf "\033[?1049h" >&2

  # Enable bracketed paste mode (terminal sends ESC[200~ ... ESC[201~ around pastes)
  printf "\033[?2004h" >&2

  # Cleanup on exit
  local __ml_cancelled=0
  function _input:ml:cleanup() {
    printf "\033[?2004l" >&2 # Disable bracketed paste
    stty "$saved_stty"
    if [[ "$mode" == "stream" ]]; then
      # Clear editor lines in stream mode
      local i
      for ((i = 0; i < __ML_HEIGHT; i++)); do
        printf "\033[%d;1H\033[K" "$((stream_row + i))" >&2
      done
      # Restore cursor to original position
      _input:ml:stream:restore "$stream_row" "$stream_col"
    else
      # Box mode cleanup
      if [[ "$use_alt_buffer" == "true" ]]; then
        # Alt buffer: switch back restores previous terminal content
        printf "\033[?1049l" >&2
      else
        # No alt buffer: clear editor lines
        local i
        for ((i = 0; i < __ML_HEIGHT; i++)); do
          printf "\033[%d;1H\033[K" "$((pos_y + i + 1))" >&2
        done
        printf "\033[%d;1H" "$((pos_y + 1))" >&2
      fi
    fi
  }
  trap '_input:ml:cleanup; exit' INT TERM

  # WINCH handler: update dimensions on terminal resize
  function _input:ml:winch() {
    local new_w new_h
    new_w=$(tput cols 2>/dev/null || echo "$__ML_WIDTH")
    new_h=$(tput lines 2>/dev/null || echo "$__ML_HEIGHT")
    if [[ "$mode" == "stream" ]]; then
      __ML_WIDTH=$new_w # Stream mode uses full terminal width
    else
      __ML_WIDTH=$new_w
      __ML_HEIGHT=$new_h
    fi
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
    "$key_save") break ;;
    "$key_edit") _input:ml:sel-clear; _input:ml:edit-line "$saved_stty" "$pos_y" ;;
    "$key_del_word") _input:ml:sel-clear; _input:ml:delete-word ;;
    "$key_del_line") _input:ml:sel-clear; _input:ml:delete-line ;;
    # Selection: shift+arrow extends selection
    shift-up) _input:ml:sel-start; _input:ml:move-up ;;
    shift-down) _input:ml:sel-start; _input:ml:move-down ;;
    shift-left) _input:ml:sel-start; _input:ml:move-left ;;
    shift-right) _input:ml:sel-start; _input:ml:move-right ;;
    shift-home | ctrl-shift-left) _input:ml:sel-start; _input:ml:move-home ;;
    shift-end | ctrl-shift-right) _input:ml:sel-start; _input:ml:move-end ;;
    # Select all
    ctrl-a) _input:ml:sel-all ;;
    # Clipboard: copy / cut
    ctrl-c)
      if [[ "$__ML_SEL_ACTIVE" == "true" && -n "$clipboard_cmd" ]]; then
        _input:ml:sel-get-text | $clipboard_cmd 2>/dev/null
      fi
      ;;
    ctrl-x)
      if [[ "$__ML_SEL_ACTIVE" == "true" && -n "$clipboard_cmd" ]]; then
        _input:ml:sel-get-text | $clipboard_cmd 2>/dev/null
        _input:ml:sel-delete
      fi
      ;;
    # Paste from clipboard (explicit Ctrl+V)
    ctrl-v)
      if [[ -n "$paste_cmd" ]]; then
        local clipboard_text
        clipboard_text=$($paste_cmd 2>/dev/null)
        [[ -n "$clipboard_text" ]] && _input:ml:paste "$clipboard_text"
      fi
      ;;
    # Navigation (clears selection)
    up) _input:ml:sel-clear; _input:ml:move-up ;;
    down) _input:ml:sel-clear; _input:ml:move-down ;;
    left) _input:ml:sel-clear; _input:ml:move-left ;;
    right) _input:ml:sel-clear; _input:ml:move-right ;;
    home) _input:ml:sel-clear; _input:ml:move-home ;;
    end) _input:ml:sel-clear; _input:ml:move-end ;;
    page-up)
      _input:ml:sel-clear
      local i
      for ((i = 0; i < __ML_HEIGHT - 2; i++)); do _input:ml:move-up; done
      ;;
    page-down)
      _input:ml:sel-clear
      local i
      for ((i = 0; i < __ML_HEIGHT - 2; i++)); do _input:ml:move-down; done
      ;;
    # Editing
    escape)
      if [[ "$__ML_SEL_ACTIVE" == "true" ]]; then
        _input:ml:sel-clear
      else
        __ml_cancelled=1
        break
      fi
      ;;
    backspace) _input:ml:delete-char ;;
    enter) _input:ml:insert-newline ;;
    tab) _input:ml:insert-tab ;;
    paste:*) _input:ml:paste "${key#paste:}" ;;
    char:*) _input:ml:insert-char "${key#char:}" ;;
    *) ;; # Ignore unknown sequences
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
    right) right ;;
    left) left ;;
    enter) break ;;
    escape) reset && continue ;;
    char:*) search "${key#char:}" ;;
    *) ;; # Ignore all other keys
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

logger tui "$@"             # register own logger
logger:redirect "tui" ">&2" # redirect to STDERR

logger loader "$@" # initialize logger
echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"

# old version of function names (aliases for backward compatibility)
alias validate_input=validate:input
alias validate_yn_input=validate:input:yn

##
## Module: Terminal User Interface (TUI) Functions
##
## This module provides terminal user interface components including
## cursor positioning, password input, input validation, key input handling,
## multi-line text editing, and menu selection.
##
## References:
## - demo: demo.readpswd.sh, demo.selector.sh, demo.multi-line.sh, demo.capture-key.sh
## - bin: vhd.sh, git.sync-by-patches.sh
## - documentation: docs/public/tui.md
## - tests: spec/commons_spec.sh, spec/multi_line_input_spec.sh, spec/read_key_spec.sh
##
## Globals:
## - E_BASH - Path to .scripts directory
## - use_macos_extensions - Enable macOS-specific features, boolean, default: based on OSTYPE
##
## Categories:
##
## Cursor Position Functions:
## - cursor:position() - Get "row;col" position
## - cursor:position:row() - Get row number
## - cursor:position:col() - Get column number
##
## Input Functions:
## - input:readpwd() - Read password with masking and line editing
## - input:selector() - Interactive menu selector from array
## - input:multi-line() - Interactive multi-line text editor
##
## Input Validation Functions:
## - validate:input() - Generic input validation
## - validate:input:masked() - Masked input validation
## - validate:input:yn() - Yes/no input validation
## - confirm:by:input() - Cascading default confirmation
##
## Key Input Functions (Internal):
## - _input:read-key() - Read semantic key token
## - _input:_raw() - Set raw bytes helper
## - _input:capture-key() - Interactive key capture diagnostic
##
## Multi-line Editor Functions (Internal):
## - _input:ml:init() - Initialize editor state
## - _input:ml:insert-char() - Insert character
## - _input:ml:delete-char() - Delete character
## - _input:ml:delete-word() - Delete word backward
## - _input:ml:insert-newline() - Insert newline
## - _input:ml:move-up/down/left/right/home/end() - Cursor movement
## - _input:ml:scroll() - Adjust scroll offset
## - _input:ml:get-content() - Get buffer content
## - _input:ml:render() - Render editor to terminal
## - _input:ml:edit-line() - Readline-based line editing
## - _input:ml:paste() - Paste text
## - _input:ml:insert-tab() - Insert tab as spaces
## - _input:ml:delete-line() - Delete line content
## - _input:ml:sel-start() - Start/extend selection
## - _input:ml:sel-clear() - Clear selection
## - _input:ml:sel-bounds() - Get normalized selection bounds
## - _input:ml:sel-get-text() - Get selected text
## - _input:ml:sel-delete() - Delete selected text
## - _input:ml:sel-all() - Select all text
## - _input:ml:stream:*() - Stream mode helpers
##
## Global State:
## - __INPUT_MODIFIER_NAMES - Modifier name lookup table
## - __INPUT_CSI_KEYS - CSI key name lookup table
## - __INPUT_CSI_TILDE_KEYS - CSI tilde key lookup table
## - __INPUT_RAW_BYTES - Raw hex bytes from last key read
## - __INPUT_RAW_CHARS - Raw characters from last key read
## - __ML_LINES - Multi-line editor line buffer
## - __ML_ROW, __ML_COL - Cursor position
## - __ML_SCROLL - Scroll offset
## - __ML_WIDTH, __ML_HEIGHT - Editor dimensions
## - __ML_MODIFIED - Modified flag
## - __ML_SEL_ACTIVE - Selection active flag
## - __ML_SEL_ANCHOR_ROW, __ML_SEL_ANCHOR_COL - Selection anchor position
## - __ML_MESSAGE - Status message
## - __ML_STATUS_BAR - Status bar visibility
##
