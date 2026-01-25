#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-24
## Version: 2.7.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# =============================================================================
# Benchmark: Color Template Approaches
# =============================================================================
# Usage:
#   ./benchmark.colors.sh              # Run full benchmark with hyperfine
#   ./benchmark.colors.sh --simple     # Run simple benchmark (no hyperfine)
#   ./benchmark.colors.sh --approach1  # Run specific approach (for hyperfine)
#   ./benchmark.colors.sh --verify     # Verify all approaches produce same output
#   ./benchmark.colors.sh --help       # Show help
#
# Approaches:
#   1. Direct Pattern Substitution (Bash built-in)
#   2. Associative Array + Regex Loop
#   3. Variable Indirection (Dynamic names)
#   4. sed-based (External command)
#   5. Wrapper Functions (Subshell per call)
#
# For visual demo, use: ./demo.colors.sh
# =============================================================================

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"

dependency "hyperfine" "1.20.*" "brew install hyperfine" --exec

# shellcheck source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Configuration
ITERATIONS="${BENCHMARK_ITERATIONS:-1000}"
WARMUP="${BENCHMARK_WARMUP:-3}"
RUNS="${BENCHMARK_RUNS:-10}"
REPORT_DIR="${BENCHMARK_REPORT_DIR:-$SCRIPT_DIR/../docs/benchmarks}"

# Template for benchmarking
TEMPLATE='{{red}}error:{{nc}} found {{yellow}}3{{nc}} issues in {{bold}}{{blue}}main.sh{{nc}}'

#=============================================================================
# APPROACH 1: Direct Pattern Substitution
#=============================================================================

function color:v1() {
  local input="$1"
  
  input="${input//\{\{red\}\}/${cl_red}}"
  input="${input//\{\{green\}\}/${cl_green}}"
  input="${input//\{\{yellow\}\}/${cl_yellow}}"
  input="${input//\{\{blue\}\}/${cl_blue}}"
  input="${input//\{\{purple\}\}/${cl_purple}}"
  input="${input//\{\{cyan\}\}/${cl_cyan}}"
  input="${input//\{\{white\}\}/${cl_white}}"
  input="${input//\{\{grey\}\}/${cl_grey}}"
  input="${input//\{\{gray\}\}/${cl_grey}}"
  input="${input//\{\{lred\}\}/${cl_lred}}"
  input="${input//\{\{lgreen\}\}/${cl_lgreen}}"
  input="${input//\{\{lyellow\}\}/${cl_lyellow}}"
  input="${input//\{\{lblue\}\}/${cl_lblue}}"
  input="${input//\{\{lpurple\}\}/${cl_lpurple}}"
  input="${input//\{\{lcyan\}\}/${cl_lcyan}}"
  input="${input//\{\{lwhite\}\}/${cl_lwhite}}"
  input="${input//\{\{bold\}\}/${st_bold}}"
  input="${input//\{\{b\}\}/${st_bold}}"
  input="${input//\{\{italic\}\}/${st_italic}}"
  input="${input//\{\{i\}\}/${st_italic}}"
  input="${input//\{\{underline\}\}/${st_underline}}"
  input="${input//\{\{u\}\}/${st_underline}}"
  input="${input//\{\{nc\}\}/${cl_reset}}"
  input="${input//\{\{reset\}\}/${cl_reset}}"
  input="${input//\{\{\/_\}\}/${cl_reset}}"
  input="${input//\{\{error\}\}/${cl_red}}"
  input="${input//\{\{warn\}\}/${cl_yellow}}"
  input="${input//\{\{success\}\}/${cl_green}}"
  input="${input//\{\{info\}\}/${cl_cyan}}"
  input="${input//\{\{muted\}\}/${cl_grey}}"
  
  echo "$input"
}

approach1_run() {
  for ((i = 0; i < ITERATIONS; i++)); do
    color:v1 "$TEMPLATE" >/dev/null
  done
}

#=============================================================================
# APPROACH 2: Associative Array + Regex Loop
#=============================================================================

declare -gA CLR_MAP=(
  [red]="${cl_red}" [green]="${cl_green}" [yellow]="${cl_yellow}"
  [blue]="${cl_blue}" [purple]="${cl_purple}" [cyan]="${cl_cyan}"
  [white]="${cl_white}" [grey]="${cl_grey}" [gray]="${cl_grey}"
  [lred]="${cl_lred}" [lgreen]="${cl_lgreen}" [lyellow]="${cl_lyellow}"
  [lblue]="${cl_lblue}" [lpurple]="${cl_lpurple}" [lcyan]="${cl_lcyan}"
  [lwhite]="${cl_lwhite}"
  [bold]="${st_bold}" [b]="${st_bold}"
  [italic]="${st_italic}" [i]="${st_italic}"
  [underline]="${st_underline}" [u]="${st_underline}"
  [nc]="${cl_reset}" [reset]="${cl_reset}" [_]="${cl_reset}"
  [error]="${cl_red}" [warn]="${cl_yellow}"
  [success]="${cl_green}" [info]="${cl_cyan}" [muted]="${cl_grey}"
)

function color:v2() {
  local input="$1"
  local name
  
  while [[ "$input" =~ \{\{\ *([a-zA-Z_]+)\ *\}\} ]]; do
    name="${BASH_REMATCH[1]}"
    input="${input//${BASH_REMATCH[0]}/${CLR_MAP[$name]:-}}"
  done
  
  echo "$input"
}

approach2_run() {
  for ((i = 0; i < ITERATIONS; i++)); do
    color:v2 "$TEMPLATE" >/dev/null
  done
}

#=============================================================================
# APPROACH 3: Variable Indirection
#=============================================================================

function color:v3() {
  local input="$1"
  local name var_name value
  
  while [[ "$input" =~ \{\{\ *([a-zA-Z_]+)\ *\}\} ]]; do
    name="${BASH_REMATCH[1]}"
    
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

approach3_run() {
  for ((i = 0; i < ITERATIONS; i++)); do
    color:v3 "$TEMPLATE" >/dev/null
  done
}

#=============================================================================
# APPROACH 4: sed-based
#=============================================================================

function color:v4() {
  local input="$1"
  
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

approach4_run() {
  for ((i = 0; i < ITERATIONS; i++)); do
    color:v4 "$TEMPLATE" >/dev/null
  done
}

#=============================================================================
# APPROACH 5: Wrapper Functions
#=============================================================================

red()     { printf '%s%s%s' "$cl_red"     "$*" "$cl_reset"; }
green()   { printf '%s%s%s' "$cl_green"   "$*" "$cl_reset"; }
yellow()  { printf '%s%s%s' "$cl_yellow"  "$*" "$cl_reset"; }
blue()    { printf '%s%s%s' "$cl_blue"    "$*" "$cl_reset"; }
purple()  { printf '%s%s%s' "$cl_purple"  "$*" "$cl_reset"; }
cyan()    { printf '%s%s%s' "$cl_cyan"    "$*" "$cl_reset"; }
grey()    { printf '%s%s%s' "$cl_grey"    "$*" "$cl_reset"; }
bold()    { printf '%s%s%s' "$st_bold"    "$*" "$cl_reset"; }

error()   { printf '%s%s%s' "$cl_red"     "$*" "$cl_reset"; }
warn()    { printf '%s%s%s' "$cl_yellow"  "$*" "$cl_reset"; }
success() { printf '%s%s%s' "$cl_green"   "$*" "$cl_reset"; }
info()    { printf '%s%s%s' "$cl_cyan"    "$*" "$cl_reset"; }

approach5_run() {
  for ((i = 0; i < ITERATIONS; i++)); do
    msg="$(error 'error:') found $(yellow '3') issues in $(bold "$(blue 'main.sh')")"
  done
}

#=============================================================================
# VERIFICATION
#=============================================================================

verify_approaches() {
  echo "=== Verifying Color Template Approaches ==="
  echo ""
  echo "Template: '$TEMPLATE'"
  echo ""
  
  local out1 out2 out3 out4 out5
  out1=$(color:v1 "$TEMPLATE")
  out2=$(color:v2 "$TEMPLATE")
  out3=$(color:v3 "$TEMPLATE")
  out4=$(color:v4 "$TEMPLATE")
  out5="$(error 'error:') found $(yellow '3') issues in $(bold "$(blue 'main.sh')")"
  
  echo "Approach 1 (Direct substitution):"
  echo "  $out1"
  echo ""
  
  echo "Approach 2 (Associative array):"
  echo "  $out2"
  echo ""
  
  echo "Approach 3 (Variable indirection):"
  echo "  $out3"
  echo ""
  
  echo "Approach 4 (sed-based):"
  echo "  $out4"
  echo ""
  
  echo "Approach 5 (Wrapper functions):"
  echo "  $out5"
  echo ""
  
  # Compare outputs (all should produce same visual result)
  if [[ "$out1" == "$out2" ]] && [[ "$out2" == "$out3" ]] && [[ "$out3" == "$out4" ]]; then
    echo "✓ Approaches 1-4 produce identical output"
  else
    echo "✗ Approaches 1-4 produce different output!"
  fi
  
  echo ""
}

#=============================================================================
# BENCHMARK WITH HYPERFINE
#=============================================================================

run_benchmark() {
  if ! command -v hyperfine &>/dev/null; then
    echo "Error: hyperfine is not installed."
    echo "Install with: cargo install hyperfine OR brew install hyperfine"
    echo ""
    echo "Falling back to simple benchmark..."
    run_simple_benchmark
    return
  fi

  mkdir -p "$REPORT_DIR"

  local report_file="$REPORT_DIR/colors-benchmark-$(date +%Y%m%d-%H%M%S).md"
  local json_file="${report_file%.md}.json"

  echo "=== Color Template Benchmark (All 5 Approaches) ==="
  echo ""
  echo "Configuration:"
  echo "  Iterations per run: $ITERATIONS"
  echo "  Warmup runs: $WARMUP"
  echo "  Benchmark runs: $RUNS"
  echo "  Report: $report_file"
  echo ""

  hyperfine \
    --warmup "$WARMUP" \
    --runs "$RUNS" \
    --export-markdown "$report_file" \
    --export-json "$json_file" \
    -n "1: Direct substitution" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach1" \
    -n "2: Associative array" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach2" \
    -n "3: Variable indirection" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach3" \
    -n "4: sed-based" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach4" \
    -n "5: Wrapper functions" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach5"

  {
    echo "# Color Template Benchmark (All 5 Approaches)"
    echo ""
    echo "**Date:** $(date -Iseconds)"
    echo "**Iterations per run:** $ITERATIONS"
    echo "**Warmup runs:** $WARMUP"
    echo "**Benchmark runs:** $RUNS"
    echo ""
    echo "## Results"
    echo ""
    cat "$report_file"
    echo ""
    echo "## Approaches"
    echo ""
    echo "| # | Approach | Pros | Cons |"
    echo "|---|----------|------|------|"
    echo "| 1 | Direct substitution | Fastest, pure bash | Verbose, rigid |"
    echo "| 2 | Associative array | Extensible, DRY | Bash 4+, regex loop |"
    echo "| 3 | Variable indirection | Uses existing vars | Case statement overhead |"
    echo "| 4 | sed-based | Familiar to Unix users | Spawns subshell |"
    echo "| 5 | Wrapper functions | Most readable syntax | Many subshells |"
    echo ""
    echo "## Recommendation"
    echo ""
    echo "- **For maximum performance:** Use Approach 1 (Direct substitution)"
    echo "- **For extensibility:** Use Approach 2 (Associative array)"
    echo "- **For readability:** Use Approach 5 (Wrapper functions)"
    echo ""
  } >"${report_file}.tmp"
  mv "${report_file}.tmp" "$report_file"

  echo ""
  echo "Report saved to: $report_file"
  echo "JSON data saved to: $json_file"
}

run_simple_benchmark() {
  echo "┌─────────────────────────────────────────────────────────────────────┐"
  echo "│ SIMPLE BENCHMARK ($ITERATIONS iterations)                           │"
  echo "└─────────────────────────────────────────────────────────────────────┘"
  echo ""

  benchmark() {
    local name="$1"
    shift
    local start end elapsed
    
    start=$(date +%s%N)
    "$@"
    end=$(date +%s%N)
    
    elapsed=$(( (end - start) / 1000000 ))
    printf "  %-35s %6d ms\n" "$name:" "$elapsed"
  }

  benchmark "Approach 1 (Direct substitution)" approach1_run
  benchmark "Approach 2 (Associative array)" approach2_run
  benchmark "Approach 3 (Variable indirection)" approach3_run
  benchmark "Approach 4 (sed-based)" approach4_run
  benchmark "Approach 5 (Wrapper functions)" approach5_run
  echo ""
  
  echo "Recommendation:"
  echo "  - For maximum performance: Use Approach 1 (Direct substitution)"
  echo "  - For extensibility: Use Approach 2 (Associative array)"
  echo "  - For readability: Use Approach 5 (Wrapper functions)"
  echo ""
}

#=============================================================================
# HELP
#=============================================================================

show_help() {
  cat <<EOF
Color Template Approaches - Benchmark

Usage:
  $SCRIPT_NAME              Run full benchmark with hyperfine (default)
  $SCRIPT_NAME --simple     Run simple benchmark (no hyperfine)
  $SCRIPT_NAME --verify     Verify all approaches produce same output
  $SCRIPT_NAME --approach1  Run approach 1 ($ITERATIONS iterations)
  $SCRIPT_NAME --approach2  Run approach 2 ($ITERATIONS iterations)
  $SCRIPT_NAME --approach3  Run approach 3 ($ITERATIONS iterations)
  $SCRIPT_NAME --approach4  Run approach 4 ($ITERATIONS iterations)
  $SCRIPT_NAME --approach5  Run approach 5 ($ITERATIONS iterations)
  $SCRIPT_NAME --help       Show this help

For visual demo, use: ./demo.colors.sh

Environment Variables:
  BENCHMARK_ITERATIONS  Number of template resolutions per run (default: 1000)
  BENCHMARK_WARMUP      Hyperfine warmup runs (default: 3)
  BENCHMARK_RUNS        Hyperfine benchmark runs (default: 10)
  BENCHMARK_REPORT_DIR  Directory for reports (default: docs/benchmarks)

Approaches:
  1. Direct Pattern Substitution - Fastest, uses \${input//pattern/value}
  2. Associative Array + Regex   - Extensible, uses CLR_MAP array
  3. Variable Indirection        - Uses existing cl_* variables via \${!var}
  4. sed-based                   - External command, spawns subshell
  5. Wrapper Functions           - Most readable: \$(red 'text')

Examples:
  # Full benchmark with hyperfine
  $SCRIPT_NAME

  # Quick benchmark without hyperfine
  $SCRIPT_NAME --simple

  # Verify all approaches produce same output
  $SCRIPT_NAME --verify

EOF
}

#=============================================================================
# MAIN
#=============================================================================

case "${1:-}" in
  --approach1) approach1_run ;;
  --approach2) approach2_run ;;
  --approach3) approach3_run ;;
  --approach4) approach4_run ;;
  --approach5) approach5_run ;;
  --simple) run_simple_benchmark ;;
  --verify) verify_approaches ;;
  --help | -h) show_help ;;
  "" | --benchmark) run_benchmark ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information"
    exit 1
    ;;
esac
