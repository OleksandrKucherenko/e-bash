#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-24
## Version: 2.7.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# =============================================================================
# Demo: Color Template Approaches - Proof of Concept
# =============================================================================
# This file demonstrates different methods for declaring color variables
# and resolving color template strings like: "{{red}}error:{{nc}} message"
#
# Usage:
#   ./demo.colors.sh              # Run visual demo (default)
#   ./demo.colors.sh --palette    # Show 256-color palette only
#   ./demo.colors.sh --rgb        # Show RGB to ANSI conversion demo
#   ./demo.colors.sh --help       # Show help
#
# Approaches:
#   1. Direct Pattern Substitution (Bash built-in)
#   2. Associative Array + Regex Loop
#   3. Variable Indirection (Dynamic names)
#   4. sed-based (External command)
#   5. Wrapper Functions (Subshell per call)
#
# For benchmarking, use: ./benchmark.colors.sh
# =============================================================================

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Template for demonstration
TEMPLATE='{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues in {{bold}}{{blue}}main.sh{{nc}}'

#=============================================================================
# APPROACH 1: Direct Pattern Substitution (Bash built-in)
#=============================================================================
# Pros: Fast, no loops, pure bash
# Cons: Verbose, needs explicit pattern for each color

function color:v1() {
  local input
  
  # Support both pipe mode and argument mode
  if [[ -n "$1" ]]; then
    input="$1"
  elif [[ ! -t 0 ]]; then
    read -r input
  else
    return 0
  fi
  
  # Colors
  input="${input//\{\{red\}\}/${cl_red}}"
  input="${input//\{\{green\}\}/${cl_green}}"
  input="${input//\{\{yellow\}\}/${cl_yellow}}"
  input="${input//\{\{blue\}\}/${cl_blue}}"
  input="${input//\{\{purple\}\}/${cl_purple}}"
  input="${input//\{\{cyan\}\}/${cl_cyan}}"
  input="${input//\{\{white\}\}/${cl_white}}"
  input="${input//\{\{grey\}\}/${cl_grey}}"
  input="${input//\{\{gray\}\}/${cl_grey}}"
  
  # Light variants
  input="${input//\{\{lred\}\}/${cl_lred}}"
  input="${input//\{\{lgreen\}\}/${cl_lgreen}}"
  input="${input//\{\{lyellow\}\}/${cl_lyellow}}"
  input="${input//\{\{lblue\}\}/${cl_lblue}}"
  input="${input//\{\{lpurple\}\}/${cl_lpurple}}"
  input="${input//\{\{lcyan\}\}/${cl_lcyan}}"
  input="${input//\{\{lwhite\}\}/${cl_lwhite}}"
  
  # Styles
  input="${input//\{\{bold\}\}/${st_bold}}"
  input="${input//\{\{b\}\}/${st_bold}}"
  input="${input//\{\{italic\}\}/${st_italic}}"
  input="${input//\{\{i\}\}/${st_italic}}"
  input="${input//\{\{underline\}\}/${st_underline}}"
  input="${input//\{\{u\}\}/${st_underline}}"
  
  # Reset aliases
  input="${input//\{\{nc\}\}/${cl_reset}}"
  input="${input//\{\{reset\}\}/${cl_reset}}"
  input="${input//\{\{\/_\}\}/${cl_reset}}"
  
  # Semantic
  input="${input//\{\{error\}\}/${cl_red}}"
  input="${input//\{\{warn\}\}/${cl_yellow}}"
  input="${input//\{\{success\}\}/${cl_green}}"
  input="${input//\{\{info\}\}/${cl_cyan}}"
  input="${input//\{\{muted\}\}/${cl_grey}}"
  
  echo "$input"
}

#=============================================================================
# APPROACH 2: Associative Array + While Loop (Regex extraction)
#=============================================================================
# Pros: Extensible, DRY, users can add custom colors
# Cons: Bash 4+ only, regex in loop can be slower

declare -gA CLR_MAP=(
  # Primary colors
  [red]="${cl_red}" [green]="${cl_green}" [yellow]="${cl_yellow}"
  [blue]="${cl_blue}" [purple]="${cl_purple}" [cyan]="${cl_cyan}"
  [white]="${cl_white}" [grey]="${cl_grey}" [gray]="${cl_grey}"
  # Light variants
  [lred]="${cl_lred}" [lgreen]="${cl_lgreen}" [lyellow]="${cl_lyellow}"
  [lblue]="${cl_lblue}" [lpurple]="${cl_lpurple}" [lcyan]="${cl_lcyan}"
  [lwhite]="${cl_lwhite}"
  # Styles
  [bold]="${st_bold}" [b]="${st_bold}"
  [italic]="${st_italic}" [i]="${st_italic}"
  [underline]="${st_underline}" [u]="${st_underline}"
  # Reset
  [nc]="${cl_reset}" [reset]="${cl_reset}" [_]="${cl_reset}"
  # Semantic
  [error]="${cl_red}" [warn]="${cl_yellow}"
  [success]="${cl_green}" [info]="${cl_cyan}" [muted]="${cl_grey}"
)

function color:v2() {
  local input name
  
  # Support both pipe mode and argument mode
  if [[ -n "$1" ]]; then
    input="$1"
  elif [[ ! -t 0 ]]; then
    read -r input
  else
    return 0
  fi
  
  # Match {{name}} pattern and replace with mapped value
  while [[ "$input" =~ \{\{\ *([a-zA-Z_]+)\ *\}\} ]]; do
    name="${BASH_REMATCH[1]}"
    input="${input//${BASH_REMATCH[0]}/${CLR_MAP[$name]:-}}"
  done
  
  echo "$input"
}

#=============================================================================
# APPROACH 3: Variable Indirection (Dynamic variable names)
#=============================================================================
# Pros: Uses existing cl_* variables, no extra data structure
# Cons: Limited to existing variable names, indirect expansion overhead

function color:v3() {
  local input name var_name value
  
  # Support both pipe mode and argument mode
  if [[ -n "$1" ]]; then
    input="$1"
  elif [[ ! -t 0 ]]; then
    read -r input
  else
    return 0
  fi
  
  while [[ "$input" =~ \{\{\ *([a-zA-Z_]+)\ *\}\} ]]; do
    name="${BASH_REMATCH[1]}"
    
    # Try cl_<name>, then st_<name>, then special cases
    case "$name" in
      nc|reset|_) value="${cl_reset}" ;;
      b) value="${st_bold}" ;;
      i) value="${st_italic}" ;;
      u) value="${st_underline}" ;;
      error) value="${cl_red}" ;;
      warn) value="${cl_yellow}" ;;
      success) value="${cl_green}" ;;
      info) value="${cl_cyan}" ;;
      muted) value="${cl_grey}" ;;
      bold|italic|underline)
        var_name="st_${name}"
        value="${!var_name:-}"
        ;;
      *)
        var_name="cl_${name}"
        value="${!var_name:-}"
        ;;
    esac
    
    input="${input//${BASH_REMATCH[0]}/${value}}"
  done
  
  echo "$input"
}

#=============================================================================
# APPROACH 4: sed-based (External command)
#=============================================================================
# Pros: Handles complex patterns, familiar to Unix users
# Cons: Spawns subshell, slower, needs escaping

function color:v4() {
  local input
  
  # Support both pipe mode and argument mode
  if [[ -n "$1" ]]; then
    input="$1"
  elif [[ ! -t 0 ]]; then
    read -r input
  else
    return 0
  fi
  
  echo "$input" | sed \
    -e "s/{{red}}/${cl_red}/g" \
    -e "s/{{green}}/${cl_green}/g" \
    -e "s/{{yellow}}/${cl_yellow}/g" \
    -e "s/{{blue}}/${cl_blue}/g" \
    -e "s/{{purple}}/${cl_purple}/g" \
    -e "s/{{cyan}}/${cl_cyan}/g" \
    -e "s/{{grey}}/${cl_grey}/g" \
    -e "s/{{gray}}/${cl_grey}/g" \
    -e "s/{{bold}}/${st_bold}/g" \
    -e "s/{{nc}}/${cl_reset}/g" \
    -e "s/{{reset}}/${cl_reset}/g" \
    -e "s/{{error}}/${cl_red}/g" \
    -e "s/{{warn}}/${cl_yellow}/g" \
    -e "s/{{success}}/${cl_green}/g" \
    -e "s/{{info}}/${cl_cyan}/g"
}

#=============================================================================
# APPROACH 5: Wrapper Functions (Subshell per call)
#=============================================================================
# Pros: Most readable in usage, self-documenting
# Cons: Spawns subshell for each use in $()

red()     { printf '%s%s%s' "$cl_red"     "$*" "$cl_reset"; }
green()   { printf '%s%s%s' "$cl_green"   "$*" "$cl_reset"; }
yellow()  { printf '%s%s%s' "$cl_yellow"  "$*" "$cl_reset"; }
blue()    { printf '%s%s%s' "$cl_blue"    "$*" "$cl_reset"; }
purple()  { printf '%s%s%s' "$cl_purple"  "$*" "$cl_reset"; }
cyan()    { printf '%s%s%s' "$cl_cyan"    "$*" "$cl_reset"; }
grey()    { printf '%s%s%s' "$cl_grey"    "$*" "$cl_reset"; }
bold()    { printf '%s%s%s' "$st_bold"    "$*" "$cl_reset"; }

# Semantic wrappers
error()   { printf '%s%s%s' "$cl_red"     "$*" "$cl_reset"; }
warn()    { printf '%s%s%s' "$cl_yellow"  "$*" "$cl_reset"; }
success() { printf '%s%s%s' "$cl_green"   "$*" "$cl_reset"; }
info()    { printf '%s%s%s' "$cl_cyan"    "$*" "$cl_reset"; }

#=============================================================================
# RGB/RGBA TO ANSI 256-COLOR CONVERSION
#=============================================================================
# Converts RGB(A) values to closest terminal 256-color code
# Supports: rgb(r,g,b), rgba(r,g,b,a), #RRGGBB, #RGB, r g b

declare -ga ANSI_RGB=()

# Initialize the ANSI RGB palette
_init_ansi_palette() {
  [[ ${#ANSI_RGB[@]} -gt 0 ]] && return
  
  # Standard 16 colors
  ANSI_RGB=(
    "0 0 0" "128 0 0" "0 128 0" "128 128 0"
    "0 0 128" "128 0 128" "0 128 128" "192 192 192"
    "128 128 128" "255 0 0" "0 255 0" "255 255 0"
    "0 0 255" "255 0 255" "0 255 255" "255 255 255"
  )
  
  # 6x6x6 color cube (colors 16-231)
  local cube_values=(0 95 135 175 215 255)
  local r g b
  for ((r = 0; r < 6; r++)); do
    for ((g = 0; g < 6; g++)); do
      for ((b = 0; b < 6; b++)); do
        ANSI_RGB+=("${cube_values[r]} ${cube_values[g]} ${cube_values[b]}")
      done
    done
  done
  
  # Grayscale (colors 232-255)
  local gray
  for ((gray = 8; gray <= 238; gray += 10)); do
    ANSI_RGB+=("$gray $gray $gray")
  done
}

color:parse() {
  local color="$1"
  local r g b a
  
  color="${color// /}"
  
  if [[ "$color" =~ ^rgba?\(([0-9]+),([0-9]+),([0-9]+)(,([0-9.]+))?\)$ ]]; then
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[5]:-1}"
    return
  fi
  
  if [[ "$color" =~ ^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})?$ ]]; then
    r=$((16#${BASH_REMATCH[1]}))
    g=$((16#${BASH_REMATCH[2]}))
    b=$((16#${BASH_REMATCH[3]}))
    if [[ -n "${BASH_REMATCH[4]}" ]]; then
      a=$(awk "BEGIN {printf \"%.2f\", $((16#${BASH_REMATCH[4]})) / 255}")
    else
      a="1"
    fi
    echo "$r $g $b $a"
    return
  fi
  
  if [[ "$color" =~ ^#([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$ ]]; then
    r=$((16#${BASH_REMATCH[1]}${BASH_REMATCH[1]}))
    g=$((16#${BASH_REMATCH[2]}${BASH_REMATCH[2]}))
    b=$((16#${BASH_REMATCH[3]}${BASH_REMATCH[3]}))
    echo "$r $g $b 1"
    return
  fi
  
  if [[ "$color" =~ ^([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+)([[:space:]]+([0-9.]+))?$ ]]; then
    echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[5]:-1}"
    return
  fi
  
  echo "0 0 0 1"
}

color:blend() {
  local r=$1 g=$2 b=$3 a=$4
  local bg_r=${5:-0} bg_g=${6:-0} bg_b=${7:-0}
  
  local out_r out_g out_b
  out_r=$(awk "BEGIN {printf \"%d\", $r * $a + $bg_r * (1 - $a)}")
  out_g=$(awk "BEGIN {printf \"%d\", $g * $a + $bg_g * (1 - $a)}")
  out_b=$(awk "BEGIN {printf \"%d\", $b * $a + $bg_b * (1 - $a)}")
  
  echo "$out_r $out_g $out_b"
}

color:distance() {
  local r1=$1 g1=$2 b1=$3 r2=$4 g2=$5 b2=$6
  local dr=$((r1 - r2)) dg=$((g1 - g2)) db=$((b1 - b2))
  echo $(awk "BEGIN {printf \"%d\", sqrt(2*$dr*$dr + 4*$dg*$dg + 3*$db*$db)}")
}

rgb:to:ansi() {
  local color="$1"
  local bg="${2:-0 0 0}"
  
  _init_ansi_palette
  
  local r g b a
  read -r r g b a <<< "$(color:parse "$color")"
  
  if [[ "$a" != "1" ]] && [[ "$a" != "1.00" ]]; then
    read -r bg_r bg_g bg_b <<< "$bg"
    read -r r g b <<< "$(color:blend "$r" "$g" "$b" "$a" "$bg_r" "$bg_g" "$bg_b")"
  fi
  
  local best_code=0 best_dist=999999 i dist pr pg pb
  
  for ((i = 0; i < 256; i++)); do
    read -r pr pg pb <<< "${ANSI_RGB[i]}"
    dist=$(color:distance "$r" "$g" "$b" "$pr" "$pg" "$pb")
    if ((dist < best_dist)); then
      best_dist=$dist
      best_code=$i
    fi
  done
  
  echo "$best_code"
}

rgb:ansi() {
  local color="$1"
  local mode="${2:-fg}"
  local code
  code=$(rgb:to:ansi "$color")
  
  if [[ "$mode" == "bg" ]]; then
    printf '\033[48;5;%dm' "$code"
  else
    printf '\033[38;5;%dm' "$code"
  fi
}

#=============================================================================
# 256-COLOR PALETTE
#=============================================================================

function report:colors() {
  local contrast=0 reset="" nl=""
  local i=0

  reset=$(printf "\033[0m")

  for ((i = 0; i < 256; i++)); do
    local mod8=$(((i + 1) % 8))
    local mod6=$(((i - 15) % 6))
    local c1=$((i > 231 && i < 244))
    local c2=$((i < 17 && i % 8 < 2))
    local c3=$((i > 16 && i < 232))
    local c4=$(((i - 16) % 6 < (i < 100 ? 3 : 2)))
    local c5=$(((i - 16) % 36 < 15))

    contrast=16 && nl=""
    if [[ $c1 -eq 1 || $c2 -eq 1 ]] || [[ $c3 -eq 1 && $c4 -eq 1 && $c5 -eq 1 ]]; then contrast=7; fi

    if [ $i -lt 16 ] || [ $i -gt 231 ]; then
      [ $mod8 -eq 0 ] && nl=$'\n'
    else
      [ $mod6 -eq 0 ] && nl=$'\n'
    fi

    printf "  \033[48;5;%dm\033[38;5;%dm C %03d %s%s" $i $contrast $i "$reset" "$nl"
  done
}

#=============================================================================
# VISUAL DEMO
#=============================================================================

run_demo() {
  echo ""
  echo "╔═══════════════════════════════════════════════════════════════════════╗"
  echo "║           COLOR TEMPLATE APPROACHES - COMPARISON DEMO                 ║"
  echo "╚═══════════════════════════════════════════════════════════════════════╝"
  echo ""

  echo "┌─────────────────────────────────────────────────────────────────────┐"
  echo "│ STYLE COMPARISON                                                    │"
  echo "└─────────────────────────────────────────────────────────────────────┘"
  echo ""

  echo "Template: '${TEMPLATE}'"
  echo ""

  echo "Approach 1 (Direct substitution):"
  echo '  Pattern: color:v1 "{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues..."'
  echo "  Output:  $(color:v1 "$TEMPLATE")"
  echo ""

  echo "Approach 2 (Associative array):"
  echo '  Pattern: color:v2 "{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues..."'
  echo "  Output:  $(color:v2 "$TEMPLATE")"
  echo ""

  echo "Approach 3 (Variable indirection):"
  echo '  Pattern: color:v3 "{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues..."'
  echo "  Output:  $(color:v3 "$TEMPLATE")"
  echo ""

  echo "Approach 4 (sed-based):"
  echo '  Pattern: color:v4 "{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues..."'
  echo "  Output:  $(color:v4 "$TEMPLATE")"
  echo ""

  echo "Approach 5 (Wrapper functions) - different syntax:"
  echo '  Pattern: $(error '\''error:'\'') found $(yellow '\''3'\'') issues in $(bold "$(blue '\''main.sh'\'')")'
  echo "  Output:  $(error 'error:') found $(yellow '3') issues in $(bold "$(blue 'main.sh')")"
  echo ""

  echo "┌─────────────────────────────────────────────────────────────────────┐"
  echo "│ USAGE PATTERNS                                                      │"
  echo "└─────────────────────────────────────────────────────────────────────┘"
  echo ""

  echo "Current style (direct variables):"
  echo '  echo "${cl_red}error:${cl_reset} found ${cl_yellow}3${cl_reset} issues"'
  echo "  ${cl_red}error:${cl_reset} found ${cl_yellow}3${cl_reset} issues"
  echo ""

  echo "Template style (Approaches 1-4):"
  echo '  echo "$(color:v1 '\''{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues'\'')"'
  echo "  $(color:v1 '{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues')"
  echo ""

  echo "Wrapper style (Approach 5):"
  echo '  echo "$(error '\''error:'\'') found $(yellow '\''3'\'') issues"'
  echo "  $(error 'error:') found $(yellow '3') issues"
  echo ""

  echo "Pipe mode (Approaches 1-4 support pipe input):"
  echo '  echo "{{red}}error:{{nc}} message" | color:v1'
  printf "  "; echo "{{red}}error:{{nc}} message" | color:v1
  echo ""
  echo '  cat template.txt | color:v2'
  echo '  generate_message | color:v3 | tee output.log'
  echo ""

  echo "Semantic examples:"
  echo "  $(color:v1 '{{success}}✓{{nc}} All tests passed')"
  echo "  $(color:v1 '{{warn}}⚠{{nc}} Deprecated function used')"
  echo "  $(color:v1 '{{error}}✗{{nc}} Build failed')"
  echo "  $(color:v1 '{{info}}ℹ{{nc}} Running in debug mode')"
  echo "  $(color:v1 '{{muted}}# comment{{nc}}')"
  echo ""

  echo "┌─────────────────────────────────────────────────────────────────────┐"
  echo "│ RGB/RGBA TO ANSI CONVERSION                                         │"
  echo "└─────────────────────────────────────────────────────────────────────┘"
  echo ""
  
  echo "Supported input formats:"
  echo "  #RGB         → #F00, #0F0, #00F"
  echo "  #RRGGBB      → #FF5500, #8B4513"
  echo "  #RRGGBBAA    → #FF550080 (with alpha)"
  echo "  rgb(r,g,b)   → rgb(255,85,0)"
  echo "  rgba(r,g,b,a)→ rgba(255,0,0,0.5)"
  echo "  r g b        → 255 85 0"
  echo ""
  
  echo "Conversion examples:"
  local demo_colors=("#FF5500" "#8B4513" "#FFD700" "#4B0082" "rgb(100,149,237)")
  local c code
  for c in "${demo_colors[@]}"; do
    code=$(rgb:to:ansi "$c")
    printf "  %-20s → ANSI %3d  \033[48;5;%dm    \033[0m\n" "$c" "$code" "$code"
  done
  echo ""
  
  echo "RGBA with alpha blending (on black background):"
  local alpha_colors=("rgba(255,0,0,1.0)" "rgba(255,0,0,0.75)" "rgba(255,0,0,0.5)" "rgba(255,0,0,0.25)")
  for c in "${alpha_colors[@]}"; do
    code=$(rgb:to:ansi "$c")
    printf "  %-22s → ANSI %3d  \033[48;5;%dm    \033[0m\n" "$c" "$code" "$code"
  done
  echo ""
  
  echo "Usage in scripts:"
  echo '  # Get ANSI code'
  echo '  code=$(rgb:to:ansi "#FF5500")  # Returns: 202'
  echo ""
  echo '  # Get escape sequence and use directly'
  echo '  echo "$(rgb:ansi "#FF5500")Orange text${cl_reset}"'
  printf "  → $(rgb:ansi '#FF5500')Orange text${cl_reset}\n"
  echo ""
  echo '  # Parse color to RGB values'
  echo '  read -r r g b a <<< "$(color:parse "#FF5500")"'
  echo "  → $(color:parse '#FF5500')"
  echo ""
}

demo:rgb() {
  echo ""
  echo "┌─────────────────────────────────────────────────────────────────────┐"
  echo "│ RGB/RGBA TO ANSI CONVERSION DEMO                                    │"
  echo "└─────────────────────────────────────────────────────────────────────┘"
  echo ""
  
  local colors=(
    "#FF0000:Pure Red"
    "#00FF00:Pure Green"
    "#0000FF:Pure Blue"
    "#FF5500:Orange"
    "#8B4513:Saddle Brown"
    "#FFD700:Gold"
    "#FF69B4:Hot Pink"
    "#4B0082:Indigo"
    "#00CED1:Dark Turquoise"
    "#808080:Gray"
    "rgb(100,149,237):Cornflower Blue"
    "rgba(255,0,0,0.5):Red 50% alpha (on black)"
  )
  
  local entry color name code
  for entry in "${colors[@]}"; do
    color="${entry%%:*}"
    name="${entry#*:}"
    code=$(rgb:to:ansi "$color")
    
    printf "  %-30s -> ANSI %3d  " "$name ($color)" "$code"
    printf "\033[48;5;%dm    \033[0m " "$code"
    printf "(palette match)\n"
  done
  
  echo ""
  echo "  Usage:"
  echo '    code=$(rgb:to:ansi "#FF5500")'
  echo '    echo "$(rgb:ansi "#FF5500")Orange text${cl_reset}"'
  echo ""
}

#=============================================================================
# HELP
#=============================================================================

show_help() {
  cat <<EOF
Color Template Approaches - Demo & Proof of Concept

Usage:
  $SCRIPT_NAME              Run visual demo (default)
  $SCRIPT_NAME --demo       Run visual demo
  $SCRIPT_NAME --palette    Show 256-color palette only
  $SCRIPT_NAME --rgb        Show RGB to ANSI conversion demo
  $SCRIPT_NAME --help       Show this help

For benchmarking, use: ./benchmark.colors.sh

Approaches:
  1. Direct Pattern Substitution - Fastest, uses \${input//pattern/value}
  2. Associative Array + Regex   - Extensible, uses CLR_MAP array
  3. Variable Indirection        - Uses existing cl_* variables via \${!var}
  4. sed-based                   - External command, spawns subshell
  5. Wrapper Functions           - Most readable: \$(red 'text')

RGB Conversion Functions:
  rgb:to:ansi "#FF5500"         Convert hex/rgb/rgba to ANSI 256 code
  rgb:ansi "#FF5500"            Get ANSI escape sequence for color
  color:parse "#FF5500"         Parse color to "r g b a" values

Examples:
  # Quick visual demo
  $SCRIPT_NAME

  # Show 256-color palette
  $SCRIPT_NAME --palette

  # RGB to ANSI demo
  $SCRIPT_NAME --rgb

EOF
}

#=============================================================================
# MAIN
#=============================================================================

case "${1:-}" in
  --rgb) demo:rgb ;;
  --palette)
    echo ""
    echo "256-COLOR PALETTE:"
    echo ""
    report:colors
    echo ""
    echo "Hints:"
    echo "  - use command 'tput setab [0-255]' to change background color"
    echo "  - use command 'tput setaf [0-255]' to change foreground color"
    echo "  - use command 'tput op' to reset colors"
    echo ""
    ;;
  --demo | "")
    run_demo
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│ 256-COLOR PALETTE REFERENCE                                         │"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo ""
    report:colors
    echo ""
    echo "Hints:"
    echo "  - use command 'tput setab [0-255]' to change background color"
    echo "  - use command 'tput setaf [0-255]' to change foreground color"
    echo "  - use command 'tput op' to reset colors"
    echo ""
    echo "Run './benchmark.colors.sh' for performance comparison."
    ;;
  --help | -h) show_help ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information"
    exit 1
    ;;
esac
