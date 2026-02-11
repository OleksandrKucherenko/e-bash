#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2034,SC2059,SC2154,SC1090

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-02-11
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# is allowed to use macOS extensions (script can be executed in *nix second)
if [[ -z "${use_macos_extensions+x}" ]]; then
  use_macos_extensions=false
  if [[ "$OSTYPE" == "darwin"* ]]; then use_macos_extensions=true; fi
fi

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1090 source=./_colors.sh
source "$E_BASH/_colors.sh"

# shellcheck disable=SC1090 source=./_logger.sh
source "$E_BASH/_logger.sh"

# Shared TUI keybindings. Override via environment if needed.
: "${TUI_KEY_UP:=$'\E[A'}"
: "${TUI_KEY_DOWN:=$'\E[B'}"
: "${TUI_KEY_RIGHT:=$'\E[C'}"
: "${TUI_KEY_LEFT:=$'\E[D'}"
: "${TUI_KEY_HOME:=$'\E[H'}"
: "${TUI_KEY_HOME_ALT:=$'\EOH'}"
: "${TUI_KEY_END:=$'\E[F'}"
: "${TUI_KEY_END_ALT:=$'\EOF'}"
: "${TUI_KEY_PGUP:=$'\E[5~'}"
: "${TUI_KEY_PGDN:=$'\E[6~'}"
: "${TUI_KEY_ESC:=$'\E'}"
: "${TUI_KEY_ENTER:=$'\n'}"
: "${TUI_KEY_ENTER_ALT:=$'\r'}"
: "${TUI_KEY_BACKSPACE:=$'\x7f'}"
: "${TUI_KEY_BACKSPACE_ALT:=$'\x08'}"
: "${TUI_KEY_TAB:=$'\t'}"
: "${TUI_KEY_CTRL_D:=$'\x04'}"
: "${TUI_KEY_CTRL_W:=$'\x17'}"
: "${TUI_KEY_CTRL_U:=$'\x15'}"
: "${TUI_KEY_CTRL_V:=$'\x16'}"
: "${TUI_KEY_PASTE_START:=$'\E[200~'}"
: "${TUI_KEY_PASTE_END:=$'\E[201~'}"

# Module-internal state for box drawing canvas and modal layers.
declare -gA __TUI_BOX_MASKS=()
declare -gA __TUI_BOX_STYLES=()
declare -gA __TUI_BOX_LAYER_META=()
declare -gA __TUI_BOX_LAYER_SNAPSHOT=()
declare -g -a __TUI_BOX_LAYER_STACK=()
declare -g -i __TUI_BOX_LAYER_SEQ=0
declare -g -i __TUI_BOX_LAST_LAYER=0

##
## Decode raw input bytes into normalized key event
##
## Parameters:
## - raw - Raw key bytes, string, required
##
## Returns:
## - Echoes normalized event name or event with payload:
##   - up, down, left, right, home, end, page_up, page_down
##   - esc, enter, backspace, tab, ctrl_d, ctrl_w, ctrl_u, ctrl_v
##   - char<TAB>value, unknown, eof
##
function _tui:key:decode() {
  local raw=${1-}

  case "$raw" in
  "$TUI_KEY_UP") printf "up" ;;
  "$TUI_KEY_DOWN") printf "down" ;;
  "$TUI_KEY_RIGHT") printf "right" ;;
  "$TUI_KEY_LEFT") printf "left" ;;
  "$TUI_KEY_HOME" | "$TUI_KEY_HOME_ALT") printf "home" ;;
  "$TUI_KEY_END" | "$TUI_KEY_END_ALT") printf "end" ;;
  "$TUI_KEY_PGUP") printf "page_up" ;;
  "$TUI_KEY_PGDN") printf "page_down" ;;
  "$TUI_KEY_ESC") printf "esc" ;;
  "$TUI_KEY_ENTER" | "$TUI_KEY_ENTER_ALT") printf "enter" ;;
  "$TUI_KEY_BACKSPACE" | "$TUI_KEY_BACKSPACE_ALT") printf "backspace" ;;
  "$TUI_KEY_TAB") printf "tab" ;;
  "$TUI_KEY_CTRL_D") printf "ctrl_d" ;;
  "$TUI_KEY_CTRL_W") printf "ctrl_w" ;;
  "$TUI_KEY_CTRL_U") printf "ctrl_u" ;;
  "$TUI_KEY_CTRL_V") printf "ctrl_v" ;;
  "") printf "eof" ;;
  *)
    if [[ "$raw" =~ [[:print:]] ]]; then
      printf "char\t%s" "$raw"
    else
      printf "unknown"
    fi
    ;;
  esac
}

##
## Read one key event from terminal and normalize it
##
## Returns:
## - Echoes key event, see _tui:key:decode
## - Echoes paste<TAB>payload when bracketed paste is detected
##
function _tui:key:read() {
  local first="" next="" seq=""

  IFS= read -rsn1 first || true
  [[ -z "$first" ]] && { printf "eof"; return 0; }

  if [[ "$first" == "$TUI_KEY_ESC" ]]; then
    seq="$first"

    while IFS= read -rsn1 -t 0.0005 next; do
      seq+="$next"
      [[ "$seq" == "$TUI_KEY_PASTE_START" ]] && break
    done

    if [[ "$seq" == "$TUI_KEY_PASTE_START" ]]; then
      local payload="" ch=""
      while IFS= read -rsn1 ch; do
        payload+="$ch"
        if [[ ${#payload} -ge ${#TUI_KEY_PASTE_END} ]] &&
          [[ "${payload: -${#TUI_KEY_PASTE_END}}" == "$TUI_KEY_PASTE_END" ]]; then
          payload="${payload:0:$(( ${#payload} - ${#TUI_KEY_PASTE_END} ))}"
          printf "paste\t%s" "$payload"
          return 0
        fi
      done
      printf "paste\t%s" "$payload"
      return 0
    fi

    _tui:key:decode "$seq"
    return 0
  fi

  _tui:key:decode "$first"
}

##
## Extract key event name from normalized event
##
## Parameters:
## - event - Normalized event string, string, required
##
## Returns:
## - Echoes event name
##
function _tui:key:event:name() {
  local event=${1-}
  printf "%s" "${event%%$'\t'*}"
}

##
## Extract key event payload from normalized event
##
## Parameters:
## - event - Normalized event string, string, required
##
## Returns:
## - Echoes payload for char/paste events
##
function _tui:key:event:data() {
  local event=${1-}
  [[ "$event" == *$'\t'* ]] && printf "%s" "${event#*$'\t'}"
}

##
## Convert raw key sequence to uppercase hex bytes
##
## Parameters:
## - raw - Raw key sequence, string, required
##
## Returns:
## - Echoes hex bytes separated by spaces, e.g. "1B 5B 41"
##
function _tui:key:format:hex() {
  local raw=${1-}
  local out="" i=0 char="" byte=""

  LC_ALL=C
  for ((i = 0; i < ${#raw}; i++)); do
    char="${raw:i:1}"
    printf -v byte "%02X" "'$char"
    out+="${out:+ }${byte}"
  done

  printf "%s" "$out"
}

##
## Convert raw key sequence to escaped ASCII representation
##
## Parameters:
## - raw - Raw key sequence, string, required
##
## Returns:
## - Echoes escaped ASCII string, e.g. "\\e[A", "\\t", "a"
##
function _tui:key:format:ascii() {
  local raw=${1-}
  local out="" i=0 char="" code=""

  LC_ALL=C
  for ((i = 0; i < ${#raw}; i++)); do
    char="${raw:i:1}"
    printf -v code "%d" "'$char"

    case "$code" in
    27) out+="\\e" ;;
    13) out+="\\r" ;;
    10) out+="\\n" ;;
    9) out+="\\t" ;;
    92) out+="\\\\" ;; # backslash
    *)
      if [[ "$code" -ge 32 && "$code" -le 126 ]]; then
        out+="$char"
      else
        printf -v out "%s\\x%02X" "$out" "$code"
      fi
      ;;
    esac
  done

  printf "%s" "$out"
}

##
## Map xterm modifier number to human-readable string
##
## Parameters:
## - mod - Modifier code (2-8), integer, required
##
## Returns:
## - Echoes modifier string like "Ctrl+Shift"
##
function _tui:key:modifier:name() {
  local mod=${1-}

  case "$mod" in
  2) printf "Shift" ;;
  3) printf "Alt" ;;
  4) printf "Alt+Shift" ;;
  5) printf "Ctrl" ;;
  6) printf "Ctrl+Shift" ;;
  7) printf "Ctrl+Alt" ;;
  8) printf "Ctrl+Alt+Shift" ;;
  *) printf "" ;;
  esac
}

##
## Convert raw key sequence to human-readable key name
##
## Parameters:
## - raw - Raw key sequence, string, required
##
## Returns:
## - Echoes human-readable key description
##
function _tui:key:format:human() {
  local raw=${1-}
  local code=0 ctrl_char="" csi_code="" mod_code="" csi_final="" modifier="" key_name=""
  local csi_with_mod_regex=""

  case "$raw" in
  "$TUI_KEY_UP") printf "Up"; return 0 ;;
  "$TUI_KEY_DOWN") printf "Down"; return 0 ;;
  "$TUI_KEY_RIGHT") printf "Right"; return 0 ;;
  "$TUI_KEY_LEFT") printf "Left"; return 0 ;;
  "$TUI_KEY_HOME" | "$TUI_KEY_HOME_ALT") printf "Home"; return 0 ;;
  "$TUI_KEY_END" | "$TUI_KEY_END_ALT") printf "End"; return 0 ;;
  "$TUI_KEY_PGUP") printf "PageUp"; return 0 ;;
  "$TUI_KEY_PGDN") printf "PageDown"; return 0 ;;
  "$TUI_KEY_ESC") printf "Esc"; return 0 ;;
  "$TUI_KEY_ENTER" | "$TUI_KEY_ENTER_ALT") printf "Enter"; return 0 ;;
  "$TUI_KEY_BACKSPACE" | "$TUI_KEY_BACKSPACE_ALT") printf "Backspace"; return 0 ;;
  "$TUI_KEY_TAB") printf "Tab"; return 0 ;;
  "$TUI_KEY_CTRL_D") printf "Ctrl+D"; return 0 ;;
  "$TUI_KEY_CTRL_W") printf "Ctrl+W"; return 0 ;;
  "$TUI_KEY_CTRL_U") printf "Ctrl+U"; return 0 ;;
  "$TUI_KEY_CTRL_V") printf "Ctrl+V"; return 0 ;;
  "$TUI_KEY_PASTE_START") printf "PasteStart"; return 0 ;;
  "$TUI_KEY_PASTE_END") printf "PasteEnd"; return 0 ;;
  esac

  csi_with_mod_regex=$'^\033\\[([0-9]+);([2-8])([~A-Za-z])$'
  if [[ "$raw" =~ $csi_with_mod_regex ]]; then
    csi_code=${BASH_REMATCH[1]}
    mod_code=${BASH_REMATCH[2]}
    csi_final=${BASH_REMATCH[3]}
    modifier=$(_tui:key:modifier:name "$mod_code")

    case "${csi_code}${csi_final}" in
    1A) key_name="Up" ;;
    1B) key_name="Down" ;;
    1C) key_name="Right" ;;
    1D) key_name="Left" ;;
    1H) key_name="Home" ;;
    1F) key_name="End" ;;
    5~) key_name="PageUp" ;;
    6~) key_name="PageDown" ;;
    2~) key_name="Insert" ;;
    3~) key_name="Delete" ;;
    esac

    if [[ -n "$modifier" && -n "$key_name" ]]; then
      printf "%s+%s" "$modifier" "$key_name"
      return 0
    fi
  fi

  # Alt+<char> is commonly encoded as ESC prefix + printable char.
  if [[ "${raw:0:1}" == $'\x1b' && ${#raw} -eq 2 ]]; then
    key_name="${raw:1:1}"
    if [[ "$key_name" =~ [[:print:]] ]]; then
      printf "Alt+%s" "$key_name"
      return 0
    fi
  fi

  if [[ ${#raw} -eq 1 ]]; then
    printf -v code "%d" "'$raw"
    if [[ "$raw" =~ [[:print:]] ]]; then
      printf "%s" "$raw"
      return 0
    fi
    if [[ "$code" -ge 1 && "$code" -le 26 ]]; then
      printf -v ctrl_char "\\$(printf "%03o" "$((code + 64))")"
      printf "Ctrl+%s" "$ctrl_char"
      return 0
    fi
  fi

  printf "Unknown"
}

##
## Read one raw key sequence (single key press)
##
## Parameters:
## - timeout - Follow-up byte timeout in seconds, float, default: 0.0005
##
## Returns:
## - Echoes raw key sequence bytes
##
function _tui:key:read:raw() {
  local timeout=${1:-0.0005}
  local first="" next="" raw=""

  IFS= read -rsn1 first || true
  [[ -z "$first" ]] && { printf ""; return 0; }

  raw="$first"
  [[ "$first" != "$TUI_KEY_ESC" ]] && { printf "%s" "$raw"; return 0; }

  while IFS= read -rsn1 -t "$timeout" next; do
    raw+="$next"
  done

  printf "%s" "$raw"
}

##
## Print key sequence description in raw/hex/human formats
##
## Parameters:
## - raw - Raw key sequence, string, required
## - binding_name - Optional env var name for export snippet, string, default: ""
##
## Returns:
## - Echoes formatted lines:
##   RAW=..., HEX=..., EVENT=..., HUMAN=...
##   optional: EXPORT=export <binding_name>=...
##
function tui:key:describe() {
  local raw=${1-}
  local binding_name=${2-}
  local ascii="" hex="" event="" human="" raw_bash=""

  ascii=$(_tui:key:format:ascii "$raw")
  hex=$(_tui:key:format:hex "$raw")
  event=$(_tui:key:decode "$raw")
  human=$(_tui:key:format:human "$raw")
  printf -v raw_bash "%q" "$raw"

  echo "RAW=${raw_bash}"
  echo "ASCII=${ascii}"
  echo "HEX=${hex}"
  echo "EVENT=${event}"
  echo "HUMAN=${human}"
  if [[ -n "$binding_name" ]]; then
    echo "EXPORT=export ${binding_name}=${raw_bash}"
  fi
}

##
## Capture one key press from terminal and print sequence formats
##
## Parameters:
## - binding_name - Optional env var name for export snippet, string, default: ""
##
## Side effects:
## - Switches terminal to raw mode briefly
##
## Returns:
## - 0 on success
## - Echoes key description lines from tui:key:describe
##
## Usage:
## - tui:key:capture
## - tui:key:capture TUI_KEY_UP
##
function tui:key:capture() {
  local binding_name=${1-}
  local saved_stty="" raw=""

  saved_stty=$(stty -g)
  stty raw -echo

  # shellcheck disable=SC2064
  trap 'stty "$saved_stty"' INT TERM
  raw=$(_tui:key:read:raw)
  stty "$saved_stty"
  trap - INT TERM

  tui:key:describe "$raw" "$binding_name"
}

##
## Reset TUI box canvas and modal layer state
##
## Parameters:
## - none
##
## Globals:
## - reads/listen: none
## - mutate/publish: __TUI_BOX_MASKS, __TUI_BOX_STYLES, __TUI_BOX_LAYER_META,
##   __TUI_BOX_LAYER_SNAPSHOT, __TUI_BOX_LAYER_STACK, __TUI_BOX_LAYER_SEQ
##
## Returns:
## - 0 on success
##
function _tui:box:reset() {
  __TUI_BOX_MASKS=()
  __TUI_BOX_STYLES=()
  __TUI_BOX_LAYER_META=()
  __TUI_BOX_LAYER_SNAPSHOT=()
  __TUI_BOX_LAYER_STACK=()
  __TUI_BOX_LAYER_SEQ=0
  __TUI_BOX_LAST_LAYER=0
  return 0
}

##
## Normalize box drawing style name
##
## Parameters:
## - style - Style name or alias, string, default: "single"
##
## Returns:
## - Echoes canonical style:
##   single | double | single_h_double_v | double_h_single_v
##
function _tui:box:style:normalize() {
  local style=${1:-single}

  case "$style" in
  single | light | 1) printf "single" ;;
  double | 2) printf "double" ;;
  single_h_double_v | single-h-double-v | mixed-v | 3) printf "single_h_double_v" ;;
  double_h_single_v | double-h-single-v | mixed-h | 4) printf "double_h_single_v" ;;
  *) printf "single" ;;
  esac
}

##
## Parse box draw arguments
##
## Parameters:
## - args - Command-line args: -x, -y, -w, -h, -s/--style
##
## Returns:
## - Echoes "x;y;width;height;style"
##
function _tui:box:args() {
  local pos_x=0 pos_y=0 width=2 height=2 style="single"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
    -x)
      pos_x="${2:-0}"
      shift 2
      continue
      ;;
    -y)
      pos_y="${2:-0}"
      shift 2
      continue
      ;;
    -w | --width)
      width="${2:-2}"
      shift 2
      continue
      ;;
    -h | --height)
      height="${2:-2}"
      shift 2
      continue
      ;;
    -s | --style)
      style="${2:-single}"
      shift 2
      continue
      ;;
    *)
      shift
      ;;
    esac
  done

  [[ "$pos_x" =~ ^[0-9]+$ ]] || pos_x=0
  [[ "$pos_y" =~ ^[0-9]+$ ]] || pos_y=0
  [[ "$width" =~ ^[0-9]+$ ]] || width=2
  [[ "$height" =~ ^[0-9]+$ ]] || height=2

  [[ "$width" -lt 2 ]] && width=2
  [[ "$height" -lt 2 ]] && height=2

  style=$(_tui:box:style:normalize "$style")
  printf "%s;%s;%s;%s;%s" "$pos_x" "$pos_y" "$width" "$height" "$style"
}

##
## Map segment mask to box-drawing glyph for style
##
## Parameters:
## - style - Canonical/alias style name, string, required
## - mask - Segment bitmask (N=1,E=2,S=4,W=8), integer, required
##
## Returns:
## - Echoes a single box-drawing character
##
function _tui:box:char() {
  local style=${1:-single} mask=${2:-0}
  local h="" v="" tl="" tr="" bl="" br="" tee_down="" tee_up="" tee_right="" tee_left="" cross=""

  style=$(_tui:box:style:normalize "$style")
  [[ "$mask" =~ ^[0-9]+$ ]] || mask=0

  case "$style" in
  double)
    h="═"
    v="║"
    tl="╔"
    tr="╗"
    bl="╚"
    br="╝"
    tee_down="╦"
    tee_up="╩"
    tee_right="╠"
    tee_left="╣"
    cross="╬"
    ;;
  single_h_double_v)
    h="─"
    v="║"
    tl="╓"
    tr="╖"
    bl="╙"
    br="╜"
    tee_down="╥"
    tee_up="╨"
    tee_right="╟"
    tee_left="╢"
    cross="╫"
    ;;
  double_h_single_v)
    h="═"
    v="│"
    tl="╒"
    tr="╕"
    bl="╘"
    br="╛"
    tee_down="╤"
    tee_up="╧"
    tee_right="╞"
    tee_left="╡"
    cross="╪"
    ;;
  *)
    h="─"
    v="│"
    tl="┌"
    tr="┐"
    bl="└"
    br="┘"
    tee_down="┬"
    tee_up="┴"
    tee_right="├"
    tee_left="┤"
    cross="┼"
    ;;
  esac

  case "$mask" in
  0) printf " " ;;
  1 | 4 | 5) printf "%s" "$v" ;;
  2 | 8 | 10) printf "%s" "$h" ;;
  3) printf "%s" "$bl" ;;
  6) printf "%s" "$tl" ;;
  9) printf "%s" "$br" ;;
  12) printf "%s" "$tr" ;;
  7) printf "%s" "$tee_right" ;;
  11) printf "%s" "$tee_up" ;;
  13) printf "%s" "$tee_left" ;;
  14) printf "%s" "$tee_down" ;;
  15) printf "%s" "$cross" ;;
  *) printf "%s" "$cross" ;;
  esac
}

##
## Read box cell mask at row/column
##
## Parameters:
## - row - Zero-based row, integer, required
## - col - Zero-based column, integer, required
##
## Returns:
## - Echoes cell mask, defaults to 0
##
function _tui:box:cell:mask() {
  local row=${1:-0} col=${2:-0} key=""

  key="${row},${col}"
  printf "%s" "${__TUI_BOX_MASKS[$key]:-0}"
}

##
## Read box cell style at row/column
##
## Parameters:
## - row - Zero-based row, integer, required
## - col - Zero-based column, integer, required
##
## Returns:
## - Echoes cell style, defaults to "single"
##
function _tui:box:cell:style() {
  local row=${1:-0} col=${2:-0} key=""

  key="${row},${col}"
  printf "%s" "${__TUI_BOX_STYLES[$key]:-single}"
}

##
## Read rendered glyph for cell at row/column
##
## Parameters:
## - row - Zero-based row, integer, required
## - col - Zero-based column, integer, required
##
## Returns:
## - Echoes rendered glyph for cell
##
function _tui:box:cell:char() {
  local row=${1:-0} col=${2:-0} mask=0 style=""

  mask=$(_tui:box:cell:mask "$row" "$col")
  style=$(_tui:box:cell:style "$row" "$col")
  _tui:box:char "$style" "$mask"
}

##
## Merge segment bits into one box cell
##
## Parameters:
## - row - Zero-based row, integer, required
## - col - Zero-based column, integer, required
## - bits - Segment bits to merge, integer, required
## - style - Style to assign to touched cell, string, required
##
## Returns:
## - 0 on success
##
function _tui:box:cell:merge() {
  local row=${1:-0} col=${2:-0} bits=${3:-0} style=${4:-single}
  local key="" current_mask=0 merged_mask=0

  key="${row},${col}"
  current_mask=${__TUI_BOX_MASKS[$key]:-0}
  merged_mask=$((current_mask | bits))

  __TUI_BOX_MASKS[$key]=$merged_mask
  __TUI_BOX_STYLES[$key]=$style
  return 0
}

##
## Apply a box border into internal canvas
##
## Parameters:
## - pos_x - Zero-based left position, integer, required
## - pos_y - Zero-based top position, integer, required
## - width - Box width, integer, required
## - height - Box height, integer, required
## - style - Box style, string, required
##
## Returns:
## - 0 on success
##
function _tui:box:apply() {
  local pos_x=${1:-0} pos_y=${2:-0} width=${3:-2} height=${4:-2} style=${5:-single}
  local left=0 top=0 right=0 bottom=0 row=0 col=0

  left=$pos_x
  top=$pos_y
  right=$((pos_x + width - 1))
  bottom=$((pos_y + height - 1))

  _tui:box:cell:merge "$top" "$left" 6 "$style"
  _tui:box:cell:merge "$top" "$right" 12 "$style"
  _tui:box:cell:merge "$bottom" "$left" 3 "$style"
  _tui:box:cell:merge "$bottom" "$right" 9 "$style"

  for ((col = left + 1; col < right; col++)); do
    _tui:box:cell:merge "$top" "$col" 10 "$style"
    _tui:box:cell:merge "$bottom" "$col" 10 "$style"
  done

  for ((row = top + 1; row < bottom; row++)); do
    _tui:box:cell:merge "$row" "$left" 5 "$style"
    _tui:box:cell:merge "$row" "$right" 5 "$style"
  done

  return 0
}

##
## Render box canvas region to terminal
##
## Parameters:
## - pos_x - Zero-based left position, integer, required
## - pos_y - Zero-based top position, integer, required
## - width - Region width, integer, required
## - height - Region height, integer, required
##
## Side effects:
## - Writes ANSI cursor movement and rendered glyphs to stderr
##
## Returns:
## - 0 on success
##
function _tui:box:render-region() {
  local pos_x=${1:-0} pos_y=${2:-0} width=${3:-2} height=${4:-2}
  local row=0 col=0 line="" glyph=""

  printf "\033[0m" >&2

  for ((row = pos_y; row < pos_y + height; row++)); do
    line=""
    for ((col = pos_x; col < pos_x + width; col++)); do
      glyph=$(_tui:box:cell:char "$row" "$col")
      line+="$glyph"
    done
    printf "\033[%d;%dH%s" "$((row + 1))" "$((pos_x + 1))" "$line" >&2
  done

  return 0
}

##
## Capture box canvas state for a rectangular region
##
## Parameters:
## - pos_x - Zero-based left position, integer, required
## - pos_y - Zero-based top position, integer, required
## - width - Region width, integer, required
## - height - Region height, integer, required
##
## Returns:
## - Echoes snapshot entries: "row,col|mask|style" per line
##
function _tui:box:region:capture() {
  local pos_x=${1:-0} pos_y=${2:-0} width=${3:-2} height=${4:-2}
  local row=0 col=0 key="" out="" mask="" style=""

  for ((row = pos_y; row < pos_y + height; row++)); do
    for ((col = pos_x; col < pos_x + width; col++)); do
      key="${row},${col}"
      if [[ -n "${__TUI_BOX_MASKS[$key]+x}" ]]; then
        mask="${__TUI_BOX_MASKS[$key]}"
        style="${__TUI_BOX_STYLES[$key]:-single}"
        out+="${out:+$'\n'}${key}|${mask}|${style}"
      fi
    done
  done

  printf "%s" "$out"
}

##
## Draw a pseudographics box at specified location and size
##
## Parameters:
## - -x pos_x - Zero-based left position, integer, default: 0
## - -y pos_y - Zero-based top position, integer, default: 0
## - -w width - Box width, integer, default: 2
## - -h height - Box height, integer, default: 2
## - -s style - Box style (single|double|single_h_double_v|double_h_single_v), default: single
##
## Side effects:
## - Mutates internal box canvas and renders updated region to stderr
##
## Returns:
## - 0 on success
##
function tui:box:draw() {
  local args="" pos_x=0 pos_y=0 width=2 height=2 style="single"

  args=$(_tui:box:args "$@")
  IFS=';' read -r pos_x pos_y width height style <<< "$args"

  _tui:box:apply "$pos_x" "$pos_y" "$width" "$height" "$style"
  _tui:box:render-region "$pos_x" "$pos_y" "$width" "$height"
  return 0
}

##
## Draw modal box and capture previous canvas state for restoration
##
## Parameters:
## - same as tui:box:draw
##
## Returns:
## - Echoes modal layer id
##
function tui:box:open() {
  local output_var="" args="" pos_x=0 pos_y=0 width=2 height=2 style="single"
  local layer_token=0 snapshot=""

  if [[ "$#" -gt 0 ]] && [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    output_var="$1"
    shift
  fi

  args=$(_tui:box:args "$@")
  IFS=';' read -r pos_x pos_y width height style <<< "$args"

  snapshot=$(_tui:box:region:capture "$pos_x" "$pos_y" "$width" "$height")
  __TUI_BOX_LAYER_SEQ=$((__TUI_BOX_LAYER_SEQ + 1))
  layer_token=$__TUI_BOX_LAYER_SEQ

  __TUI_BOX_LAYER_META[$layer_token]="${pos_x}:${pos_y}:${width}:${height}"
  __TUI_BOX_LAYER_SNAPSHOT[$layer_token]="$snapshot"
  __TUI_BOX_LAYER_STACK+=("$layer_token")
  __TUI_BOX_LAST_LAYER=$layer_token

  _tui:box:apply "$pos_x" "$pos_y" "$width" "$height" "$style"
  _tui:box:render-region "$pos_x" "$pos_y" "$width" "$height"

  if [[ -n "$output_var" ]]; then
    printf -v "$output_var" "%s" "$layer_token"
  fi

  printf "%s" "$layer_token"
}

##
## Restore the last modal box layer and redraw affected region
##
## Parameters:
## - layer_id - Layer id returned by tui:box:open, integer, required
##
## Returns:
## - 0 on success
## - 1 when layer is unknown or not topmost
##
function tui:box:close() {
  local layer_id=${1:-} stack_size=0 top_id="" meta="" snapshot=""
  local pos_x=0 pos_y=0 width=2 height=2 row=0 col=0 key=""
  local snap_key="" snap_mask="" snap_style=""

  [[ "$layer_id" =~ ^[0-9]+$ ]] || return 1

  stack_size=${#__TUI_BOX_LAYER_STACK[@]}
  [[ "$stack_size" -gt 0 ]] || return 1
  top_id="${__TUI_BOX_LAYER_STACK[$((stack_size - 1))]}"
  [[ "$top_id" == "$layer_id" ]] || return 1

  meta="${__TUI_BOX_LAYER_META[$layer_id]-}"
  [[ -n "$meta" ]] || return 1
  IFS=':' read -r pos_x pos_y width height <<< "$meta"

  for ((row = pos_y; row < pos_y + height; row++)); do
    for ((col = pos_x; col < pos_x + width; col++)); do
      key="${row},${col}"
      unset "__TUI_BOX_MASKS[$key]"
      unset "__TUI_BOX_STYLES[$key]"
    done
  done

  snapshot="${__TUI_BOX_LAYER_SNAPSHOT[$layer_id]-}"
  if [[ -n "$snapshot" ]]; then
    while IFS='|' read -r snap_key snap_mask snap_style; do
      [[ -n "$snap_key" ]] || continue
      __TUI_BOX_MASKS[$snap_key]="$snap_mask"
      __TUI_BOX_STYLES[$snap_key]="$snap_style"
    done <<< "$snapshot"
  fi

  unset "__TUI_BOX_LAYER_STACK[$((stack_size - 1))]"
  __TUI_BOX_LAYER_STACK=("${__TUI_BOX_LAYER_STACK[@]}")
  unset "__TUI_BOX_LAYER_META[$layer_id]"
  unset "__TUI_BOX_LAYER_SNAPSHOT[$layer_id]"

  _tui:box:render-region "$pos_x" "$pos_y" "$width" "$height"
  return 0
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

  local key_event="" key_name="" key_data=""

  while :; do
    echo:Common "- $PWORD,$pos"
    key_event=$(_tui:key:read)
    key_name=$(_tui:key:event:name "$key_event")
    key_data=$(_tui:key:event:data "$key_event")

    case "$key_name" in
    up) home ;;
    down) endline ;;
    right) right ;;
    left) left ;;
    esc) reset ;;
    enter | eof) break ;;
    backspace) delete ;;
    ctrl_u) reset ;;
    paste)
      key_data="${key_data//$'\n'/}"
      key_data="${key_data//$'\r'/}"
      [[ -n "$key_data" ]] && add "$key_data"
      ;;
    char) add "$key_data" ;;
    *) ;; # Ignore unsupported control keys
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

# --- Multi-line Input: Internal State ---

# Module-internal state for multi-line editor
declare -g -a __ML_LINES=("")
declare -g -i __ML_ROW=0
declare -g -i __ML_COL=0
declare -g -i __ML_SCROLL=0
declare -g -i __ML_WIDTH=80
declare -g -i __ML_HEIGHT=24

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
  elif [[ $__ML_ROW -gt 0 ]]; then
    # Join with previous line
    local current_line="${__ML_LINES[$__ML_ROW]}"
    unset "__ML_LINES[$__ML_ROW]"
    __ML_LINES=("${__ML_LINES[@]}") # Re-index
    __ML_ROW=$((__ML_ROW - 1))
    local prev_line="${__ML_LINES[$__ML_ROW]}"
    __ML_COL=${#prev_line}
    __ML_LINES[$__ML_ROW]="${prev_line}${current_line}"
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
  # Scroll down
  if [[ $__ML_ROW -ge $((__ML_SCROLL + __ML_HEIGHT)) ]]; then
    __ML_SCROLL=$((__ML_ROW - __ML_HEIGHT + 1))
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
}

##
## Normalize stream mode height
##
## Parameters:
## - requested_height - Requested height, integer, required
##
## Returns:
## - Echoes normalized height (>=1)
##
function _input:ml:stream:fit-height() {
  local requested_height=${1:-1}
  [[ "$requested_height" =~ ^[0-9]+$ ]] || requested_height=1
  [[ "$requested_height" -lt 1 ]] && requested_height=1

  printf "%s" "$requested_height"
  return 0
}

##
## Read cursor row and column with timeout (stream mode)
##
## Parameters:
## - timeout_seconds - Read timeout, float, default: 0.15
##
## Returns:
## - Echoes "row;col", defaults to "1;1" when unavailable
##
function _input:ml:stream:cursor() {
  local timeout_seconds=${1:-0.15}
  local row=1 col=1 prefix=""

  if IFS=';' read -rsdR -t "$timeout_seconds" -p $'\E[6n' prefix col 2>/dev/null; then
    row=${prefix#*[}
    [[ "$row" =~ ^[0-9]+$ ]] || row=1
    [[ "$col" =~ ^[0-9]+$ ]] || col=1
  fi

  printf "%s;%s" "$row" "$col"
  return 0
}

##
## Allocate stream editor lines from anchor row
##
## Parameters:
## - anchor_row - Row where stream starts, integer, required
## - line_count - Number of lines to allocate, integer, required
## - terminal_height - Total terminal rows, integer, required
##
## Side effects:
## - Writes new lines to stderr when stream would overflow the bottom
##
## Returns:
## - 0 on success
## - Echoes adjusted anchor row for rendering
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
    while [[ "$i" -lt "$overflow" ]]; do
      printf "\n" >&2
      i=$((i + 1))
    done
  fi

  printf "%s" "$adjusted_row"
  return 0
}

##
## Restore stream editor lines at anchor row
##
## Parameters:
## - anchor_row - Row where stream starts, integer, required
## - anchor_col - Column where output should continue, integer, required
##
## Side effects:
## - Moves cursor to reusable output location
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
## Restore terminal screen after multi-line editor closes
##
## Parameters:
## - pos_x - Left offset, integer, default: 0
## - pos_y - Top offset, integer, default: 0
## - mode - Rendering mode: "box" or "stream", string, default: "box"
## - stream_row - Original stream anchor row, integer, default: 0
## - stream_col - Original stream anchor col, integer, default: 1
##
## Globals:
## - reads/listen: __ML_WIDTH, __ML_HEIGHT
## - mutate/publish: none
##
## Side effects:
## - Writes ANSI escape sequences to stderr
##
## Returns:
## - 0 on success
##
function _input:ml:restore-screen() {
  local pos_x=${1:-0} pos_y=${2:-0} mode=${3:-box} stream_row=${4:-0} stream_col=${5:-1}
  local i
  [[ "$stream_row" =~ ^[0-9]+$ ]] || stream_row=0
  [[ "$stream_col" =~ ^[0-9]+$ ]] || stream_col=1
  [[ "$stream_col" -lt 1 ]] && stream_col=1

  printf "\033[0m\033[?25h\033[?7h\033[?2004l" >&2

  # Clear editor area to remove modal artifacts without touching the rest of the screen.
  for ((i = 0; i < __ML_HEIGHT; i++)); do
    printf "\033[%d;%dH%*s" "$((pos_y + i + 1))" "$((pos_x + 1))" "$__ML_WIDTH" "" >&2
  done

  if [[ "$mode" == "stream" && "$stream_row" -gt 0 ]]; then
    _input:ml:stream:restore "$stream_row" "$stream_col"
    return 0
  fi

  printf "\033[%d;1H\n" "$((pos_y + __ML_HEIGHT + 1))" >&2
  return 0
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

  # Hide cursor and disable line-wrap while drawing full-width lines.
  printf "\033[?25l\033[?7l" >&2

  local i buf_idx line_content padding
  for ((i = 0; i < __ML_HEIGHT; i++)); do
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

    # Draw at position
    printf "\033[%d;%dH" "$((pos_y + i + 1))" "$((pos_x + 1))" >&2
    printf "\033[44m\033[37m%s\033[0m" "$line_content" >&2
  done

  # Show cursor at correct position
  local visual_row=$((__ML_ROW - __ML_SCROLL))
  local visual_col=$__ML_COL
  [[ $visual_col -ge $__ML_WIDTH ]] && visual_col=$((__ML_WIDTH - 1))

  printf "\033[%d;%dH" "$((pos_y + visual_row + 1))" "$((pos_x + visual_col + 1))" >&2
  printf "\033[?7h\033[?25h" >&2
}

##
## Interactive multi-line text editor in terminal
##
## Opens a modal text editor at specified position with configurable dimensions.
## Supports arrow key navigation, backspace, word delete, newline, tab, paste.
## Press Ctrl+D to save and exit, Esc to cancel.
##
## Parameters:
## - -x pos_x - Left offset, integer, default: 0
## - -y pos_y - Top offset, integer, default: 0
## - -m mode - Render mode: "box" or "stream", string, default: "box"
## - -w width - Editor width, integer, default: terminal width
## - -h height - Editor height, integer, default: terminal height in box mode, 5 in stream mode
##
## Globals:
## - reads/listen: TERM, cl_grey, cl_reset
## - mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL
##
## Side effects:
## - Saves/restores terminal state (stty)
## - Traps INT/TERM for cleanup
## - Reads raw keyboard input
## - Renders to terminal via ANSI escape sequences
## - Clears editor rectangle on exit
## - In stream mode emits extra lines to make room near terminal bottom
##
## Returns:
## - 0 on save (Ctrl+D), 1 on cancel (Esc)
## - Echoes captured text to stdout
##
## Usage:
## - text=$(input:multi-line)
## - text=$(input:multi-line -w 60 -h 10 -x 5 -y 2)
## - text=$(input:multi-line -m stream -h 5)
##
function input:multi-line() {
  local pos_x=0 pos_y=0 width="" height="" mode="box"
  local term_width=80 term_height=24
  local max_width=0 max_height=0
  local height_is_explicit=0
  local stream_row=0 stream_col=1
  local stream_pos=""

  # Detect terminal dimensions
  term_width=$(tput cols 2>/dev/null || echo 80)
  term_height=$(tput lines 2>/dev/null || echo 24)
  [[ "$term_width" =~ ^[0-9]+$ ]] || term_width=80
  [[ "$term_height" =~ ^[0-9]+$ ]] || term_height=24
  [[ "$term_width" -lt 1 ]] && term_width=1
  [[ "$term_height" -lt 1 ]] && term_height=1

  # Parse arguments
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -x) pos_x="$2"; shift ;;
    -y) pos_y="$2"; shift ;;
    -m|--mode) mode="$2"; shift ;;
    -w) width="$2"; shift ;;
    -h)
      height="$2"
      height_is_explicit=1
      shift
      ;;
    *) shift; continue ;;
    esac
    shift
  done

  if [[ "$mode" != "box" && "$mode" != "stream" ]]; then
    mode="box"
  fi

  [[ "$pos_x" =~ ^[0-9]+$ ]] || pos_x=0
  [[ "$pos_y" =~ ^[0-9]+$ ]] || pos_y=0
  [[ "$pos_x" -lt 0 ]] && pos_x=0
  [[ "$pos_y" -lt 0 ]] && pos_y=0

  [[ -n "$width" ]] || width="$term_width"
  [[ "$width" =~ ^[0-9]+$ ]] || width="$term_width"
  [[ "$width" -lt 1 ]] && width=1

  if [[ "$mode" == "stream" ]]; then
    stream_pos=$(_input:ml:stream:cursor)
    stream_row="${stream_pos%;*}"
    stream_col="${stream_pos#*;}"
    [[ "$stream_row" =~ ^[0-9]+$ ]] || stream_row=1
    [[ "$stream_col" =~ ^[0-9]+$ ]] || stream_col=1
    [[ "$stream_col" -lt 1 ]] && stream_col=1

    [[ "$height_is_explicit" -eq 0 ]] && height=5
    height=$(_input:ml:stream:fit-height "$height")
    [[ "$height" -gt "$term_height" ]] && height="$term_height"
    width="$term_width"
    pos_x=0
  else
    [[ -n "$height" ]] || height="$term_height"
    [[ "$height" =~ ^[0-9]+$ ]] || height="$term_height"
    [[ "$height" -lt 1 ]] && height=1
    [[ "$pos_x" -ge "$term_width" ]] && pos_x=$((term_width - 1))
    [[ "$pos_y" -ge "$term_height" ]] && pos_y=$((term_height - 1))

    max_width=$((term_width - pos_x))
    [[ "$max_width" -lt 1 ]] && max_width=1
    [[ "$width" -gt "$max_width" ]] && width="$max_width"

    max_height=$((term_height - pos_y))
    [[ "$max_height" -lt 1 ]] && max_height=1
    [[ "$height" -gt "$max_height" ]] && height="$max_height"
  fi

  _input:ml:init "$width" "$height"

  if [[ "$mode" == "stream" ]]; then
    stream_row=$(_input:ml:stream:allocate "$stream_row" "$__ML_HEIGHT" "$term_height")
    [[ "$stream_row" =~ ^[0-9]+$ ]] || stream_row=1
    [[ "$stream_row" -lt 1 ]] && stream_row=1
    pos_y=$((stream_row - 1))
  fi

  # Save terminal state
  local saved_stty
  saved_stty=$(stty -g)
  stty raw -echo
  printf "\033[?2004h" >&2

  # Cleanup on exit
  local __ml_cancelled=0
  function _input:ml:cleanup() {
    stty "$saved_stty"
    _input:ml:restore-screen "$pos_x" "$pos_y" "$mode" "$stream_row" "$stream_col"
  }
  trap '_input:ml:cleanup; exit' INT TERM

  local key_event="" key_name="" key_data=""

  while true; do
    _input:ml:render "$pos_x" "$pos_y"
    key_event=$(_tui:key:read)
    key_name=$(_tui:key:event:name "$key_event")
    key_data=$(_tui:key:event:data "$key_event")

    case "$key_name" in
    up) _input:ml:move-up ;;
    down) _input:ml:move-down ;;
    right) _input:ml:move-right ;;
    left) _input:ml:move-left ;;
    home) _input:ml:move-home ;;
    end) _input:ml:move-end ;;
    esc) __ml_cancelled=1; break ;;  # Esc (cancel)
    ctrl_d | eof) break ;;            # Ctrl+D (save)
    backspace) _input:ml:delete-char ;;
    ctrl_w) _input:ml:delete-word ;;
    ctrl_u) _input:ml:delete-line ;;
    enter) _input:ml:insert-newline ;;
    tab) _input:ml:insert-tab ;;
    paste)
      [[ -n "$key_data" ]] && _input:ml:paste "$key_data"
      ;;
    char) _input:ml:insert-char "$key_data" ;;
    *) ;; # ignore unsupported keys
    esac
  done

  # Restore terminal
  _input:ml:cleanup
  trap - INT TERM

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

  local key_event="" key_name="" key_data=""

  while :; do
    echo:Common "- $pos"
    key_event=$(_tui:key:read)
    key_name=$(_tui:key:event:name "$key_event")
    key_data=$(_tui:key:event:data "$key_event")

    case "$key_name" in
    right) right ;;
    left) left ;;
    esc) reset ;;
    enter | eof) break ;;
    char) search "$key_data" ;;
    paste)
      key_data=${key_data//$'\r'/}
      key_data=${key_data//$'\n'/}
      [[ -n "$key_data" ]] && search "${key_data:0:1}"
      ;;
    *) ;; # Ignore unsupported control keys
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

echo:Loader "loaded: ${cl_grey}${BASH_SOURCE[0]}${cl_reset}"
