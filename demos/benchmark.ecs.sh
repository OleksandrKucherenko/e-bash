#!/usr/bin/env bash
## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-22
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# =============================================================================
# Benchmark: ECS JSON Logging Approaches
# =============================================================================
# Usage:
#   ./benchmark.ecs.sh              # Run full benchmark with hyperfine
#   ./benchmark.ecs.sh --approach1  # Run approach 1 only (for hyperfine)
#   ./benchmark.ecs.sh --verify     # Verify all approaches produce valid output
#   ./benchmark.ecs.sh --help       # Show help
#
# Approaches:
#   1. Pure Bash formatter (direct call, no logger integration)
#   2. Redirect with pipe formatter (uses logger:redirect)
#   3. Dedicated ECS functions via eval/compose
#   4. Pipe-based ecs:format with prefix level (RECOMMENDED)
#   5. Pipe-based with inline level override
# =============================================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Configuration
ITERATIONS="${BENCHMARK_ITERATIONS:-100}"
WARMUP="${BENCHMARK_WARMUP:-3}"
RUNS="${BENCHMARK_RUNS:-10}"
REPORT_DIR="${BENCHMARK_REPORT_DIR:-$SCRIPT_DIR/../docs/benchmarks}"
ECS_VERSION="8.11"

# Bootstrap e-bash (only for approaches that need logger)
bootstrap_logger() {
  [ "${E_BASH:-}" ] || { E_BASH=$(cd "$SCRIPT_DIR/../.scripts" 2>&- && pwd); }
  export DEBUG=bench,bench3,bench13
  source "$E_BASH/_logger.sh" 2>/dev/null || true
}

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
  usec=$(( 10#$usec ))
  while (( ${#usec} < 6 )); do usec="${usec}0"; done

  local s=$(( sec ))
  local days=$(( s / 86400 ))
  local sod=$(( s % 86400 ))

  local hh=$(( sod / 3600 ))
  local mm=$(( (sod % 3600) / 60 ))
  local ss=$(( sod % 60 ))

  local z=$(( days + 719468 ))
  local era=$(( (z >= 0 ? z : z - 146096) / 146097 ))
  local doe=$(( z - era*146097 ))
  local yoe=$(( (doe - doe/1460 + doe/36524 - doe/146096) / 365 ))
  local y=$(( yoe + era*400 ))
  local doy=$(( doe - (365*yoe + yoe/4 - yoe/100) ))
  local mp=$(( (5*doy + 2) / 153 ))
  local d=$(( doy - (153*mp + 2)/5 + 1 ))
  local m=$(( mp + (mp < 10 ? 3 : -9) ))
  y=$(( y + (m <= 2 ? 1 : 0) ))

  printf "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ" "$y" "$m" "$d" "$hh" "$mm" "$ss" "$usec"
}

# =============================================================================
# Approach 1: Pure Bash Formatter (direct call, no logger)
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
  for ((i=0; i<ITERATIONS; i++)); do
    approach1_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# Approach 2: Redirect with Pipe Formatter
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
  # Export functions and variables for pipe subshell
  export -f _approach2_formatter _ecs:timestamp _ecs:escape_json
  export ECS_VERSION
  logger:redirect "bench" "| _approach2_formatter"
}
approach2_log() {
  echo:Bench "$1"
}
approach2_run() {
  approach2_setup
  for ((i=0; i<ITERATIONS; i++)); do
    approach2_log "Test message $i" >/dev/null 2>&1
  done
}

# =============================================================================
# Approach 3: Dedicated ECS Functions via eval/compose
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
  for ((i=0; i<ITERATIONS; i++)); do
    approach3_log "Test message $i" >/dev/null
  done
}

# =============================================================================
# Approach 4: Pipe-based ecs:format with Prefix Level (RECOMMENDED)
# Elegance: 43/45 | Performance: Slower (pipe overhead, but best integration)
# =============================================================================
ecs:format:bench() {
  while IFS= read -r line; do
    local level="INFO" message="$line"
    if [[ "$line" =~ ^::([A-Z]+)::[[:space:]]*(.*) ]]; then
      level="${BASH_REMATCH[1]}"
      message="${BASH_REMATCH[2]}"
      # Check for inline level override
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
approach4_setup() {
  bootstrap_logger
  logger bench13 "$@"
  logger:prefix "bench13" "::INFO:: "
  # Export functions and variables for pipe subshell
  export -f ecs:format:bench _ecs:timestamp _ecs:escape_json
  export ECS_VERSION
  logger:redirect "bench13" "| ecs:format:bench"
}
approach4_log() {
  echo:Bench13 "$1"
}
approach4_run() {
  approach4_setup
  for ((i=0; i<ITERATIONS; i++)); do
    approach4_log "Test message $i" >/dev/null 2>&1
  done
}

# =============================================================================
# Approach 5: Pipe-based with Inline Level Override
# Elegance: 43/45 | Performance: Same as Approach 4
# =============================================================================
approach5_setup() {
  approach4_setup "$@"
}
approach5_log() {
  echo:Bench13 "::ERROR:: $1"
}
approach5_run() {
  approach5_setup
  for ((i=0; i<ITERATIONS; i++)); do
    approach5_log "Test message $i" >/dev/null 2>&1
  done
}

# =============================================================================
# Verification: Check all approaches produce valid JSON
# =============================================================================
verify_approaches() {
  echo "=== Verifying ECS JSON Output ==="
  echo ""

  echo "Approach 1 (Pure Bash formatter):"
  approach1_setup
  local out1=$(approach1_log "Test message")
  echo "  $out1"
  echo "$out1" | jq -e . >/dev/null 2>&1 && echo "  ✓ Valid JSON" || echo "  ✗ Invalid JSON"
  echo ""

  echo "Approach 2 (Redirect pipe):"
  approach2_setup
  local out2=$(approach2_log "Test message" 2>&1)
  echo "  $out2"
  echo "$out2" | jq -e . >/dev/null 2>&1 && echo "  ✓ Valid JSON" || echo "  ✗ Invalid JSON"
  echo ""

  echo "Approach 3 (Dedicated eval functions):"
  approach3_setup
  local out3=$(approach3_log "Test message")
  echo "  $out3"
  echo "$out3" | jq -e . >/dev/null 2>&1 && echo "  ✓ Valid JSON" || echo "  ✗ Invalid JSON"
  echo ""

  echo "Approach 4 (Pipe-based ecs:format - RECOMMENDED):"
  approach4_setup
  local out4=$(approach4_log "Test message" 2>&1)
  echo "  $out4"
  echo "$out4" | jq -e . >/dev/null 2>&1 && echo "  ✓ Valid JSON" || echo "  ✗ Invalid JSON"
  echo ""

  echo "Approach 5 (Pipe-based + inline level override):"
  approach5_setup
  local out5=$(approach5_log "Test message" 2>&1)
  echo "  $out5"
  echo "$out5" | jq -e . >/dev/null 2>&1 && echo "  ✓ Valid JSON" || echo "  ✗ Invalid JSON"
  echo ""
}

# =============================================================================
# Run Benchmark with Hyperfine
# =============================================================================
run_benchmark() {
  # Check for hyperfine
  if ! command -v hyperfine &>/dev/null; then
    echo "Error: hyperfine is not installed."
    echo "Install with: cargo install hyperfine"
    exit 1
  fi

  # Create report directory
  mkdir -p "$REPORT_DIR"

  local report_file="$REPORT_DIR/ecs-benchmark-$(date +%Y%m%d-%H%M%S).md"
  local json_file="${report_file%.md}.json"

  echo "=== ECS JSON Logging Benchmark ==="
  echo ""
  echo "Configuration:"
  echo "  Iterations per run: $ITERATIONS"
  echo "  Warmup runs: $WARMUP"
  echo "  Benchmark runs: $RUNS"
  echo "  Report: $report_file"
  echo ""

  # Run hyperfine
  hyperfine \
    --warmup "$WARMUP" \
    --runs "$RUNS" \
    --export-markdown "$report_file" \
    --export-json "$json_file" \
    -n "Approach 1: Pure Bash (fastest)" \
      "$SCRIPT_DIR/$SCRIPT_NAME --approach1" \
    -n "Approach 2: Redirect pipe" \
      "$SCRIPT_DIR/$SCRIPT_NAME --approach2" \
    -n "Approach 3: Eval functions" \
      "$SCRIPT_DIR/$SCRIPT_NAME --approach3" \
    -n "Approach 4: Pipe ecs:format (recommended)" \
      "$SCRIPT_DIR/$SCRIPT_NAME --approach4" \
    -n "Approach 5: Pipe + level override" \
      "$SCRIPT_DIR/$SCRIPT_NAME --approach5"

  # Add header to report
  {
    echo "# ECS JSON Logging Benchmark"
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
    echo "| 2 | Redirect pipe | 28/45 | Uses logger:redirect with pipe |"
    echo "| 3 | Eval functions | 26/45 | Dynamic function generation via eval |"
    echo "| 4 | Pipe ecs:format | 43/45 | **RECOMMENDED** - Best integration |"
    echo "| 5 | Pipe + level override | 43/45 | Same as #4, with inline level |"
    echo ""
    echo "## Recommendation"
    echo ""
    echo "- **For maximum performance:** Use Approach 1 (Pure Bash formatter)"
    echo "- **For logger integration:** Use Approach 4 (Pipe-based ecs:format)"
    echo ""
    echo "The pipe overhead (~2x slower) is acceptable for most logging scenarios."
  } > "${report_file}.tmp"
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
ECS JSON Logging Benchmark

Usage:
  $SCRIPT_NAME              Run full benchmark with hyperfine
  $SCRIPT_NAME --verify     Verify all approaches produce valid JSON
  $SCRIPT_NAME --approach1  Run approach 1 (Pure Bash formatter)
  $SCRIPT_NAME --approach2  Run approach 2 (Redirect pipe)
  $SCRIPT_NAME --approach3  Run approach 3 (Eval functions)
  $SCRIPT_NAME --approach4  Run approach 4 (Pipe ecs:format) [RECOMMENDED]
  $SCRIPT_NAME --approach5  Run approach 5 (Pipe + level override)
  $SCRIPT_NAME --help       Show this help

Environment Variables:
  BENCHMARK_ITERATIONS  Number of log calls per run (default: 100)
  BENCHMARK_WARMUP      Hyperfine warmup runs (default: 3)
  BENCHMARK_RUNS        Hyperfine benchmark runs (default: 10)
  BENCHMARK_REPORT_DIR  Directory for reports (default: docs/benchmarks)

Approaches:
  1. Pure Bash formatter    - Direct printf, no logger (Elegance: 44/45)
  2. Redirect pipe          - Uses logger:redirect (Elegance: 28/45)
  3. Eval functions         - Dynamic via eval (Elegance: 26/45)
  4. Pipe ecs:format        - RECOMMENDED (Elegance: 43/45)
  5. Pipe + level override  - Inline ::LEVEL:: (Elegance: 43/45)

EOF
}

# =============================================================================
# Main
# =============================================================================
case "${1:-}" in
  --approach1) approach1_run ;;
  --approach2) approach2_run ;;
  --approach3) approach3_run ;;
  --approach4) approach4_run ;;
  --approach5) approach5_run ;;
  --verify)    verify_approaches ;;
  --help|-h)   show_help ;;
  "")          run_benchmark ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information"
    exit 1
    ;;
esac
