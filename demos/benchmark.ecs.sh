#!/usr/bin/env bash
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-22
## Version: 2.7.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# =============================================================================
# Benchmark: ECS JSON Logging Approaches (All 13 from demo)
# =============================================================================
# Usage:
#   ./benchmark.ecs.sh              # Run full benchmark with hyperfine
#   ./benchmark.ecs.sh --approach1  # Run specific approach (for hyperfine)
#   ./benchmark.ecs.sh --verify     # Verify all approaches produce valid output
#   ./benchmark.ecs.sh --help       # Show help
#
# Approaches (matching demos/demo.ecs-json-logging.sh):
#   1.  Pure Bash formatter (ecs:format)
#   1b. Context/Metadata Support (ecs:format:ctx with MDC)
#   2.  Redirect with pipe formatter (_ecs:pipe_formatter)
#   3.  Dedicated ECS functions via compose (logger:compose:ecs)
#   4.  Logger initialization helper (logger:ecs)
#   5.  Context via associative arrays (ecs:format:context)
#   6.  Pipe mode for ECS (ecslog:Tag)
#   7.  Log level filtering (ecs:log with _ecs:should_log)
#   8.  Error logging with ECS error fields (ecs:error)
#   9.  Convenience aliases (ecs:info, ecs:debug, etc.)
#   10. Output destinations (ecs:emit)
#   11. Formatter configuration pattern (logger:emit)
#   12. Integration via redirect (logger:format:ecs)
#   13. Pipe-based ecs:format with prefix level (RECOMMENDED)
# =============================================================================

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || {
  _src=${BASH_SOURCE:-$0}
  E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts)
  readonly E_BASH
}
#shellcheck source=../.scripts/_gnu.sh
. "$E_BASH/_gnu.sh"
PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck disable=SC1090 source=../.scripts/_dependencies.sh
source "$E_BASH/_dependencies.sh"

dependency "hyperfine" "1.20.*" "brew install hyperfine" --exec

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Configuration
ITERATIONS="${BENCHMARK_ITERATIONS:-100}"
WARMUP="${BENCHMARK_WARMUP:-3}"
RUNS="${BENCHMARK_RUNS:-10}"
REPORT_DIR="${BENCHMARK_REPORT_DIR:-$SCRIPT_DIR/../docs/benchmarks}"
ECS_VERSION="8.11"
ECS_SERVICE_NAME="benchmark"
ECS_MIN_LEVEL="DEBUG"

# =============================================================================
# Helper Functions (shared across approaches)
# =============================================================================

_ecs:escape_json() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  str="${str//$'\r'/\\r}"
  str="${str//$'\t'/\\t}"
  echo "$str"
}

_ecs:timestamp() {
  local ts="${1:-$EPOCHREALTIME}"
  local sec=${ts%.*}
  local usec=${ts#*.}
  [[ "$ts" == *.* ]] || usec=0
  usec=${usec:0:6}
  while ((${#usec} < 6)); do usec="${usec}0"; done
  usec=$((10#$usec))

  local s=$((sec))
  local days=$((s / 86400))
  local sod=$((s % 86400))

  local hh=$((sod / 3600))
  local mm=$(((sod % 3600) / 60))
  local ss=$((sod % 60))

  local z=$((days + 719468))
  local era=$(((z >= 0 ? z : z - 146096) / 146097))
  local doe=$((z - era * 146097))
  local yoe=$(((doe - doe / 1460 + doe / 36524 - doe / 146096) / 365))
  local y=$((yoe + era * 400))
  local doy=$((doe - (365 * yoe + yoe / 4 - yoe / 100)))
  local mp=$(((5 * doy + 2) / 153))
  local d=$((doy - (153 * mp + 2) / 5 + 1))
  local m=$((mp + (mp < 10 ? 3 : -9)))
  y=$((y + (m <= 2 ? 1 : 0)))

  printf "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ" "$y" "$m" "$d" "$hh" "$mm" "$ss" "$usec"
}

# Bootstrap e-bash (only for approaches that need logger)
bootstrap_logger() {
  [ "${E_BASH:-}" ] || { E_BASH=$(cd "$SCRIPT_DIR/../.scripts" 2>&- && pwd); }
  export DEBUG=bench,bench3,bench13,ecs,myapp
  source "$E_BASH/_logger.sh" 2>/dev/null || true
}

# =============================================================================
# APPROACH 1: Pure Bash JSON Formatter (no jq dependency)
# Elegance: 44/45 | Performance: Fastest
# =============================================================================
approach1_setup() { :; }
approach1_log() {
  local level="INFO" message="$1"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION"
}
approach1_run() {
  approach1_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach1_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# APPROACH 1b: Context/Metadata Support (MDC-style)
# Elegance: 42/45 | Performance: Slightly slower (context iteration)
# =============================================================================
declare -g -A _ECS_CONTEXT=()

_ecs:context:json() {
  local fragment=""
  for key in "${!_ECS_CONTEXT[@]}"; do
    local escaped_val=$(_ecs:escape_json "${_ECS_CONTEXT[$key]}")
    fragment+=",\"${key}\":\"${escaped_val}\""
  done
  echo "$fragment"
}

approach1b_setup() {
  _ECS_CONTEXT=([correlation.id]="req-12345" [service.name]="benchmark")
}
approach1b_log() {
  local level="INFO" message="$1"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context=$(_ecs:context:json)
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"%s}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION" "$context"
}
approach1b_run() {
  approach1b_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach1b_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# APPROACH 2: Using Redirect with Formatter Pipe
# Elegance: 28/45 | Performance: Slower (pipe overhead)
# =============================================================================
_approach2_formatter() {
  while IFS= read -r line; do
    local ts=$(_ecs:timestamp)
    local escaped_msg=$(_ecs:escape_json "$line")
    printf '{"@timestamp":"%s","log.level":"INFO","message":"%s","ecs.version":"%s"}\n' \
      "$ts" "$escaped_msg" "$ECS_VERSION"
  done
}
approach2_setup() {
  bootstrap_logger
  logger bench "$@"
  export -f _approach2_formatter _ecs:timestamp _ecs:escape_json
  export ECS_VERSION
  logger:redirect "bench" "| _approach2_formatter"
}
approach2_log() {
  echo:Bench "$1"
}
approach2_run() {
  approach2_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach2_log "Test message $i" >/dev/null 2>&1
  done
}

# =============================================================================
# APPROACH 3: Dedicated ECS Functions via Compose Pattern
# Elegance: 26/45 | Performance: Fast (no pipe)
# =============================================================================
approach3_setup() {
  bootstrap_logger
  logger bench3 "$@"
  eval "
    function ecs:Bench3() {
      if [[ \"\${TAGS[bench3]}\" == \"1\" ]]; then
        local ts=\$(_ecs:timestamp)
        local escaped_msg=\$(_ecs:escape_json \"\$*\")
        printf '{\"@timestamp\":\"%s\",\"log.level\":\"INFO\",\"message\":\"%s\",\"ecs.version\":\"%s\"}\n' \
          \"\$ts\" \"\$escaped_msg\" \"$ECS_VERSION\"
      fi
    }
  "
}
approach3_log() {
  ecs:Bench3 "$1"
}
approach3_run() {
  approach3_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach3_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# APPROACH 4: Logger Initialization Helper
# Elegance: 35/45 | Performance: Fast (uses compose)
# =============================================================================
approach4_setup() {
  bootstrap_logger
  logger myapp "$@"
  local tag="myapp" suffix="Myapp" level="INFO"
  eval "
    function ecs:${suffix}() {
      if [[ \"\${TAGS[$tag]}\" == \"1\" ]]; then
        local ts=\$(_ecs:timestamp)
        local escaped_msg=\$(_ecs:escape_json \"\$*\")
        printf '{\"@timestamp\":\"%s\",\"log.level\":\"$level\",\"message\":\"%s\",\"ecs.version\":\"%s\",\"log.logger\":\"$tag\"}\n' \
          \"\$ts\" \"\$escaped_msg\" \"$ECS_VERSION\"
      fi
    }
  "
}
approach4_log() {
  ecs:Myapp "$1"
}
approach4_run() {
  approach4_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach4_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# APPROACH 5: Context/Metadata Support via Associative Arrays (per-tag)
# Elegance: 30/45 | Performance: Moderate
# =============================================================================
declare -g -A TAGS_ECS_CONTEXT=()

approach5_setup() {
  TAGS_ECS_CONTEXT[myapp]="\"user.name\":\"john_doe\",\"http.method\":\"POST\""
}
approach5_log() {
  local tag="myapp" level="INFO" message="$1"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context="${TAGS_ECS_CONTEXT[$tag]:-}"
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION"
  [[ -n "$context" ]] && printf ',%s' "$context"
  printf '}\n'
}
approach5_run() {
  approach5_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach5_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# APPROACH 6: Pipe Mode for ECS (like log:Tag)
# Elegance: 38/45 | Performance: Moderate (pipe check overhead)
# =============================================================================
approach6_setup() {
  bootstrap_logger
  logger ecs "$@"
}
approach6_log() {
  local level="INFO"
  local message="$1"
  if [[ "${TAGS[ecs]:-0}" == "1" ]]; then
    local ts=$(_ecs:timestamp)
    local escaped_msg=$(_ecs:escape_json "$message")
    printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"}\n' \
      "$ts" "$level" "$escaped_msg" "$ECS_VERSION"
  fi
}
approach6_run() {
  approach6_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach6_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# USE CASE 7: Log Level Filtering
# Elegance: 40/45 | Performance: Slightly slower (level check)
# =============================================================================
declare -g -A _ECS_LEVELS=([TRACE]=0 [DEBUG]=1 [INFO]=2 [WARN]=3 [ERROR]=4 [FATAL]=5)

_ecs:should_log() {
  local level="$1"
  local min_val="${_ECS_LEVELS[$ECS_MIN_LEVEL]:-2}"
  local level_val="${_ECS_LEVELS[$level]:-2}"
  [[ $level_val -ge $min_val ]]
}

approach7_setup() { :; }
approach7_log() {
  local level="INFO" message="$1"
  _ecs:should_log "$level" || return 0
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context=$(_ecs:context:json)
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"%s}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION" "$context"
}
approach7_run() {
  approach7_setup
  _ECS_CONTEXT=()
  for ((i = 0; i < ITERATIONS; i++)); do
    approach7_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# USE CASE 8: Error Logging with ECS Error Fields
# Elegance: 36/45 | Performance: Moderate
# =============================================================================
approach8_setup() { :; }
approach8_log() {
  local message="$1"
  local error_type="RuntimeError"
  local error_code="E001"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  printf '{"@timestamp":"%s","log.level":"ERROR","message":"%s","ecs.version":"%s"' \
    "$ts" "$escaped_msg" "$ECS_VERSION"
  printf ',"error.type":"%s","error.code":"%s"' "$error_type" "$error_code"
  printf '}\n'
}
approach8_run() {
  approach8_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach8_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# USE CASE 9: Convenience Aliases (ecs:info, ecs:debug, ecs:warn, ecs:error)
# Elegance: 39/45 | Performance: Same as approach 7 (wrapper overhead)
# =============================================================================
approach9_setup() { _ECS_CONTEXT=(); }
_ecs:log() {
  local level="${1:-INFO}" message="${2:-}"
  _ecs:should_log "$level" || return 0
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION"
}
_ecs:info() { _ecs:log "INFO" "$*"; }
approach9_log() {
  _ecs:info "$1"
}
approach9_run() {
  approach9_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach9_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# USE CASE 10: Output Destinations
# Elegance: 37/45 | Performance: Moderate (redirection overhead)
# =============================================================================
ECS_OUTPUT="/dev/stdout"
approach10_setup() { :; }
approach10_log() {
  local level="INFO" message="$1"
  _ecs:should_log "$level" || return 0
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION" >>"$ECS_OUTPUT"
}
approach10_run() {
  approach10_setup
  ECS_OUTPUT="/dev/null"
  for ((i = 0; i < ITERATIONS; i++)); do
    approach10_log "Test message $i"
  done
}

# =============================================================================
# USE CASE 11: Formatter Configuration Pattern (RECOMMENDED)
# Elegance: 41/45 | Performance: Moderate (formatter lookup)
# =============================================================================
declare -g -A _LOGGER_FORMATTERS=([text]="_fmt:text" [json]="_fmt:json" [ecs]="_fmt:ecs")
LOGGER_FORMAT="ecs"

_fmt:text() { echo "$3"; }
_fmt:json() {
  local level="$1" tag="$2" message="$3"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  printf '{"timestamp":"%s","level":"%s","tag":"%s","message":"%s"}\n' \
    "$ts" "$level" "$tag" "$escaped_msg"
}
_fmt:ecs() {
  local level="$1" tag="$2" message="$3"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  printf '{"@timestamp":"%s","log.level":"%s","log.logger":"%s","message":"%s","ecs.version":"%s"}\n' \
    "$ts" "$level" "$tag" "$escaped_msg" "$ECS_VERSION"
}

approach11_setup() { LOGGER_FORMAT="ecs"; }
approach11_log() {
  local level="INFO" tag="myapp"
  shift 0
  local message="$1"
  local formatter="${_LOGGER_FORMATTERS[$LOGGER_FORMAT]:-_fmt:text}"
  "$formatter" "$level" "$tag" "$message"
}
approach11_run() {
  approach11_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach11_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# USE CASE 12: Integration with Existing Logger via Redirect
# Elegance: 40/45 | Performance: Slower (pipe overhead)
# =============================================================================
_ecs:formatter:pipe() {
  local tag="${1:-unknown}"
  while IFS= read -r message; do
    local ts=$(_ecs:timestamp)
    local escaped_msg=$(_ecs:escape_json "$message")
    printf '{"@timestamp":"%s","log.level":"INFO","log.logger":"%s","message":"%s","ecs.version":"%s"}\n' \
      "$ts" "$tag" "$escaped_msg" "$ECS_VERSION"
  done
}
approach12_setup() {
  bootstrap_logger
  logger ecs "$@"
  export -f _ecs:formatter:pipe _ecs:timestamp _ecs:escape_json
  export ECS_VERSION
  logger:redirect "ecs" "| _ecs:formatter:pipe ecs"
}
approach12_log() {
  echo:Ecs "$1"
}
approach12_run() {
  approach12_setup
  for ((i = 0; i < ITERATIONS; i++)); do
    approach12_log "Test message $i" >/dev/null 2>&1
  done
}

# =============================================================================
# USE CASE 13: Pipe-based ecs:format with Prefix-encoded Level (RECOMMENDED)
# Elegance: 43/45 | Performance: Slower (pipe overhead, but best integration)
# =============================================================================
ecs:format:bench13() {
  while IFS= read -r line; do
    local level="INFO" message="$line"
    if [[ "$line" =~ ^::([A-Z]+)::[[:space:]]*(.*) ]]; then
      level="${BASH_REMATCH[1]}"
      message="${BASH_REMATCH[2]}"
      if [[ "$message" =~ ^::([A-Z]+)::[[:space:]]*(.*) ]]; then
        level="${BASH_REMATCH[1]}"
        message="${BASH_REMATCH[2]}"
      fi
    fi
    local ts=$(_ecs:timestamp)
    local escaped_msg=$(_ecs:escape_json "$message")
    printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"}\n' \
      "$ts" "$level" "$escaped_msg" "$ECS_VERSION"
  done
}
approach13_setup() {
  bootstrap_logger
  logger bench13 "$@"
  logger:prefix "bench13" "::INFO:: "
  export -f ecs:format:bench13 _ecs:timestamp _ecs:escape_json
  export ECS_VERSION
  logger:redirect "bench13" "| ecs:format:bench13"
}
approach13_log() {
  echo:Bench13 "$1"
}
approach13_run() {
  approach13_setup "$@"
  for ((i = 0; i < ITERATIONS; i++)); do
    approach13_log "Test message $i" >/dev/null 2>&1
  done
}

# =============================================================================
# Verification: Check all approaches produce valid JSON
# =============================================================================
verify_approaches() {
  echo "=== Verifying ECS JSON Output ==="
  echo ""

  local approaches=(
    "1:Pure Bash formatter:approach1"
    "1b:Context/MDC support:approach1b"
    "2:Redirect pipe:approach2"
    "3:Dedicated eval functions:approach3"
    "4:Logger init helper:approach4"
    "5:Per-tag context:approach5"
    "6:Pipe mode:approach6"
    "7:Level filtering:approach7"
    "8:Error fields:approach8"
    "9:Convenience aliases:approach9"
    "10:Output destinations:approach10"
    "11:Formatter config:approach11"
    "12:Logger redirect:approach12"
    "13:Prefix level (RECOMMENDED):approach13"
  )

  for entry in "${approaches[@]}"; do
    IFS=':' read -r num name prefix <<<"$entry"
    echo "Approach $num ($name):"
    "${prefix}_setup" 2>/dev/null
    local out=$("${prefix}_log" "Test message" 2>&1)
    echo "  $out"
    if echo "$out" | jq -e . >/dev/null 2>&1; then
      echo "  ✓ Valid JSON"
    else
      echo "  ✗ Invalid JSON"
    fi
    echo ""
  done
}

# =============================================================================
# Run Benchmark with Hyperfine
# =============================================================================
run_benchmark() {
  if ! command -v hyperfine &>/dev/null; then
    echo "Error: hyperfine is not installed."
    echo "Install with: cargo install hyperfine"
    exit 1
  fi

  mkdir -p "$REPORT_DIR"

  local report_file="$REPORT_DIR/ecs-benchmark-$(date +%Y%m%d-%H%M%S).md"
  local json_file="${report_file%.md}.json"

  echo "=== ECS JSON Logging Benchmark (All 13 Approaches) ==="
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
    -n "01: Pure Bash formatter" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach1" \
    -n "1b: Context/MDC support" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach1b" \
    -n "02: Redirect pipe" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach2" \
    -n "03: Eval functions" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach3" \
    -n "04: Logger init helper" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach4" \
    -n "05: Per-tag context" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach5" \
    -n "06: Pipe mode" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach6" \
    -n "07: Level filtering" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach7" \
    -n "08: Error fields" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach8" \
    -n "09: Convenience aliases" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach9" \
    -n "10: Output destinations" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach10" \
    -n "11: Formatter config" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach11" \
    -n "12: Logger redirect" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach12" \
    -n "13: Prefix level (RECOMMENDED)" \
    "$SCRIPT_DIR/$SCRIPT_NAME --approach13"

  {
    echo "# ECS JSON Logging Benchmark (All 13 Approaches)"
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
    echo "| # | Approach | Elegance | Description |"
    echo "|---|----------|----------|-------------|"
    echo "| 1 | Pure Bash formatter | 44/45 | Direct printf, no logger integration |"
    echo "| 1b | Context/MDC support | 42/45 | Global context array (MDC-style) |"
    echo "| 2 | Redirect pipe | 28/45 | Uses logger:redirect with pipe |"
    echo "| 3 | Eval functions | 26/45 | Dynamic function via logger:compose:ecs |"
    echo "| 4 | Logger init helper | 35/45 | logger:ecs wrapper function |"
    echo "| 5 | Per-tag context | 30/45 | TAGS_ECS_CONTEXT per-tag storage |"
    echo "| 6 | Pipe mode | 38/45 | ecslog:Tag pattern (like log:Tag) |"
    echo "| 7 | Level filtering | 40/45 | ecs:log with _ecs:should_log |"
    echo "| 8 | Error fields | 36/45 | ECS error.type, error.code fields |"
    echo "| 9 | Convenience aliases | 39/45 | ecs:info, ecs:debug shorthand |"
    echo "| 10 | Output destinations | 37/45 | Configurable ECS_OUTPUT target |"
    echo "| 11 | Formatter config | 41/45 | logger:emit with format registry |"
    echo "| 12 | Logger redirect | 40/45 | logger:format:ecs helper |"
    echo "| 13 | Prefix level | 43/45 | **RECOMMENDED** - Best integration |"
    echo ""
    echo "## Recommendation"
    echo ""
    echo "- **For maximum performance:** Use Approach 1 (Pure Bash formatter)"
    echo "- **For logger integration:** Use Approach 13 (Pipe-based ecs:format with prefix level)"
    echo "- **For context/correlation:** Use Approach 1b or 13 with context support"
    echo ""
    echo "The pipe overhead (~2-6x slower) is acceptable for most logging scenarios."
  } >"${report_file}.tmp"
  mv "${report_file}.tmp" "$report_file"

  echo ""
  echo "Report saved to: $report_file"
  echo "JSON data saved to: $json_file"
}

# =============================================================================
# Help
# =============================================================================
show_help() {
  cat <<EOF
ECS JSON Logging Benchmark (All 13 Approaches)

Usage:
  $SCRIPT_NAME              Run full benchmark with hyperfine
  $SCRIPT_NAME --verify     Verify all approaches produce valid JSON
  $SCRIPT_NAME --approach1  Run approach 1 (Pure Bash formatter)
  $SCRIPT_NAME --approach1b Run approach 1b (Context/MDC)
  $SCRIPT_NAME --approach2  Run approach 2 (Redirect pipe)
  $SCRIPT_NAME --approach3  Run approach 3 (Eval functions)
  $SCRIPT_NAME --approach4  Run approach 4 (Logger init helper)
  $SCRIPT_NAME --approach5  Run approach 5 (Per-tag context)
  $SCRIPT_NAME --approach6  Run approach 6 (Pipe mode)
  $SCRIPT_NAME --approach7  Run approach 7 (Level filtering)
  $SCRIPT_NAME --approach8  Run approach 8 (Error fields)
  $SCRIPT_NAME --approach9  Run approach 9 (Convenience aliases)
  $SCRIPT_NAME --approach10 Run approach 10 (Output destinations)
  $SCRIPT_NAME --approach11 Run approach 11 (Formatter config)
  $SCRIPT_NAME --approach12 Run approach 12 (Logger redirect)
  $SCRIPT_NAME --approach13 Run approach 13 (Prefix level) [RECOMMENDED]
  $SCRIPT_NAME --help       Show this help

Environment Variables:
  BENCHMARK_ITERATIONS  Number of log calls per run (default: 100)
  BENCHMARK_WARMUP      Hyperfine warmup runs (default: 3)
  BENCHMARK_RUNS        Hyperfine benchmark runs (default: 10)
  BENCHMARK_REPORT_DIR  Directory for reports (default: docs/benchmarks)

Approaches:
  1.  Pure Bash formatter    - Direct printf, no logger (Elegance: 44/45)
  1b. Context/MDC support    - Global context array (Elegance: 42/45)
  2.  Redirect pipe          - Uses logger:redirect (Elegance: 28/45)
  3.  Eval functions         - Dynamic via eval (Elegance: 26/45)
  4.  Logger init helper     - logger:ecs wrapper (Elegance: 35/45)
  5.  Per-tag context        - TAGS_ECS_CONTEXT (Elegance: 30/45)
  6.  Pipe mode              - ecslog:Tag pattern (Elegance: 38/45)
  7.  Level filtering        - _ecs:should_log (Elegance: 40/45)
  8.  Error fields           - ECS error fields (Elegance: 36/45)
  9.  Convenience aliases    - ecs:info, etc. (Elegance: 39/45)
  10. Output destinations    - ECS_OUTPUT config (Elegance: 37/45)
  11. Formatter config       - Format registry (Elegance: 41/45)
  12. Logger redirect        - logger:format:ecs (Elegance: 40/45)
  13. Prefix level           - RECOMMENDED (Elegance: 43/45)

EOF
}

# =============================================================================
# Main
# =============================================================================
case "${1:-}" in
--approach1) approach1_run ;;
--approach1b) approach1b_run ;;
--approach2) approach2_run ;;
--approach3) approach3_run ;;
--approach4) approach4_run ;;
--approach5) approach5_run ;;
--approach6) approach6_run ;;
--approach7) approach7_run ;;
--approach8) approach8_run ;;
--approach9) approach9_run ;;
--approach10) approach10_run ;;
--approach11) approach11_run ;;
--approach12) approach12_run ;;
--approach13) approach13_run "$@" ;;
--verify) verify_approaches ;;
--help | -h) show_help ;;
"") run_benchmark ;;
*)
  echo "Unknown option: $1"
  echo "Use --help for usage information"
  exit 1
  ;;
esac
