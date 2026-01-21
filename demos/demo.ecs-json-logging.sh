#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-21
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# =============================================================================
# PROTOTYPE: ECS JSON Logging for e-bash
# =============================================================================
# This prototype explores different approaches to add Elastic Common Schema
# (ECS) JSON logging support to the _logger.sh module.
#
# ECS Reference: https://www.elastic.co/guide/en/ecs/current/index.html
#
# Target format:
# {"@timestamp":"2024-07-30T08:41:10.561Z","log.level":"INFO","message":"...","ecs.version":"8.11"}
#
# Goals:
# 1. Identify what works with existing _logger.sh implementation
# 2. Identify what changes are CRITICAL to _logger.sh
# 3. Explore Bash 5 features for JSON formatting
# 4. Keep jq as optional (pure Bash fallback)
#
# =============================================================================
# PROTOTYPE FINDINGS
# =============================================================================
#
# WHAT WORKS WITH EXISTING _logger.sh (NO CHANGES NEEDED):
# --------------------------------------------------------
# 1. Pure Bash JSON formatter as standalone functions
#    - Can be used independently without modifying logger
#    - Performance: ~0.017s per call
#
# 2. Redirect mechanism with pipe formatter
#    - Uses existing logger:redirect to pipe through ECS formatter
#    - Example: logger:redirect ecs "| _ecs:pipe_formatter INFO ecs"
#    - Performance: ~0.026s per call (slower due to subshell)
#
# 3. Tag-based filtering via DEBUG environment variable
#    - ECS functions respect existing TAGS[$tag] checks
#    - Works with wildcards: DEBUG=* and negation: DEBUG=*,-loader
#
# 4. Pipe mode pattern (like log:Tag)
#    - Can create ecslog:Tag functions following same pattern
#    - Supports: echo "msg" | ecslog:Tag "INFO"
#
# WHAT REQUIRES CHANGES TO _logger.sh (CRITICAL):
# -----------------------------------------------
# 1. logger:compose:ecs() - Generate ecs:Tag and ecsf:Tag functions
#    - Similar to logger:compose() but outputs JSON
#    - Creates: ecs:Tag (fixed level) and ecsf:Tag (custom level)
#
# 2. Helper functions need to be defined:
#    - _ecs:escape_json() - Escape special chars for JSON strings
#    - _ecs:timestamp() - ISO 8601 timestamp with microseconds
#
# 3. Global configuration variables:
#    - ECS_VERSION - ECS schema version (default: "8.11")
#    - ECS_SERVICE_NAME - Service name for logs
#
# OPTIONAL ENHANCEMENTS (NICE TO HAVE):
# -------------------------------------
# 1. TAGS_ECS_CONTEXT array - Per-tag custom ECS fields
# 2. TAGS_ECS_LEVEL array - Per-tag default log level
# 3. logger:ecs() helper - Initialize logger with ECS output
# 4. logger:ecs:context() - Add custom fields to tag's context
#
# PERFORMANCE RESULTS (10 iterations):
# ------------------------------------
# Approach 1 (Direct formatter):  ~0.17s
# Approach 2 (Redirect pipe):     ~0.26s (50% slower)
# Approach 3 (Dedicated ecs:Tag): ~0.17s
#
# RECOMMENDATION: Use Approach 3 (dedicated functions) for production
#
# BASH 5 FEATURES UTILIZED:
# -------------------------
# - $EPOCHREALTIME - High-precision timestamps (microseconds)
# - Associative arrays - Context storage, configuration
# - Parameter expansion - JSON string escaping
#
# =============================================================================

DEBUG=ecs,loader,myapp # enable debug mode

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || { _src=${BASH_SOURCE:-$0}; E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts); readonly E_BASH; }
. "$E_BASH/_gnu.sh"; PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck disable=SC1090 source=../.scripts/_logger.sh
source "$E_BASH/_logger.sh"

echo "=============================================="
echo "ECS JSON Logging Prototype"
echo "=============================================="
echo ""

# =============================================================================
# APPROACH 1: Pure Bash JSON Formatter (no jq dependency)
# =============================================================================
# WORKS WITH: Existing implementation (standalone helper functions)
# =============================================================================

echo "--- APPROACH 1: Pure Bash JSON Formatter ---"

# ECS version for all logs
declare -g ECS_VERSION="8.11"

# Service name (configurable)
declare -g ECS_SERVICE_NAME="${ECS_SERVICE_NAME:-e-bash-demo}"

# JSON escape function - handles special characters
# This is CRITICAL for proper JSON output
function _ecs:escape_json() {
  local str="$1"
  # Escape backslash first, then other special chars
  str="${str//\\/\\\\}"     # backslash
  str="${str//\"/\\\"}"     # double quote
  str="${str//$'\n'/\\n}"   # newline
  str="${str//$'\r'/\\r}"   # carriage return
  str="${str//$'\t'/\\t}"   # tab
  echo "$str"
}

# ISO 8601 timestamp with microseconds (Bash 5 feature: $EPOCHREALTIME)
function _ecs:timestamp() {
  # $EPOCHREALTIME gives us: 1706612470.123456
  # We need: 2024-01-30T12:34:30.123456Z
  if [[ -n "$EPOCHREALTIME" ]]; then
    # Bash 5.0+ - high precision
    local epoch_sec="${EPOCHREALTIME%.*}"
    local micro="${EPOCHREALTIME#*.}"
    # Use printf for date formatting (GNU date)
    date -u -d "@${epoch_sec}" "+%Y-%m-%dT%H:%M:%S.${micro:0:6}Z" 2>/dev/null || \
      date -u "+%Y-%m-%dT%H:%M:%S.000000Z"
  else
    # Fallback for older Bash
    date -u "+%Y-%m-%dT%H:%M:%S.000000Z"
  fi
}

# Core ECS JSON formatter - minimal fields
function ecs:format() {
  local level="${1:-INFO}"
  local message="${2:-}"

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")

  # Minimal ECS format
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION"
}

# Extended ECS JSON formatter - with optional fields
function ecs:format:full() {
  local level="${1:-INFO}"
  local message="${2:-}"
  local logger_name="${3:-}"

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local pid="$$"

  # Full ECS format with process info
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s","process.pid":%d,"service.name":"%s"' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION" "$pid" "$ECS_SERVICE_NAME"

  # Add optional logger name
  [[ -n "$logger_name" ]] && printf ',"log.logger":"%s"' "$logger_name"

  # Add trace.id from __SESSION if available
  [[ -n "$__SESSION" ]] && printf ',"trace.id":"%s"' "$__SESSION"

  printf '}\n'
}

# Test Approach 1
echo "Test 1.1 - Minimal format:"
ecs:format "INFO" "Hello, ECS JSON logging!"

echo ""
echo "Test 1.2 - Full format with metadata:"
ecs:format:full "DEBUG" "Detailed message with context" "demo.ecs"

echo ""
echo "Test 1.3 - Message with special characters:"
ecs:format "WARN" "Message with \"quotes\" and\nnewlines"

echo ""

# =============================================================================
# APPROACH 2: Using Redirect with Formatter Pipe
# =============================================================================
# WORKS WITH: Existing logger:redirect mechanism
# LIMITATION: Each log line creates a subshell (performance overhead)
# =============================================================================

echo "--- APPROACH 2: Redirect with Formatter Pipe ---"

# Formatter that reads from stdin and outputs ECS JSON
function _ecs:pipe_formatter() {
  local level="${1:-INFO}"
  local logger_name="${2:-}"

  while IFS= read -r line; do
    if [[ -n "$logger_name" ]]; then
      ecs:format:full "$level" "$line" "$logger_name"
    else
      ecs:format "$level" "$line"
    fi
  done
}

# Initialize logger with ECS JSON redirect
logger ecs "$@"

# Store original redirect
original_redirect="${TAGS_REDIRECT[ecs]:-}"

# Configure redirect to pipe through ECS formatter
# NOTE: This WORKS but has performance overhead due to subshell per log
logger:redirect ecs "| _ecs:pipe_formatter INFO ecs"

echo "Test 2.1 - Logger with ECS redirect:"
echo:Ecs "This message goes through ECS formatter via redirect"

echo ""
echo "Test 2.2 - Multiple messages:"
echo:Ecs "First log message"
echo:Ecs "Second log message"

# Reset redirect
logger:redirect ecs "$original_redirect"
echo ""

# =============================================================================
# APPROACH 3: Dedicated ECS Functions via Compose Pattern
# =============================================================================
# REQUIRES: Changes to _logger.sh OR separate module
# This is the most performant approach
# =============================================================================

echo "--- APPROACH 3: Dedicated ECS Functions (Prototype) ---"

# This function generates ecs:Tag functions similar to echo:Tag
# FINDING: This could be added to _logger.sh as logger:compose:ecs
function logger:compose:ecs() {
  local tag=${1}
  local suffix=${2}
  local level=${3:-INFO}

  cat <<EOF
  function ecs:${suffix}() {
    if [[ "\${TAGS[$tag]}" == "1" ]]; then
      local msg="\$*"
      local ts=\$(_ecs:timestamp)
      local escaped_msg=\$(_ecs:escape_json "\$msg")
      printf '{"@timestamp":"%s","log.level":"$level","message":"%s","ecs.version":"%s","log.logger":"$tag"}\n' \\
        "\$ts" "\$escaped_msg" "\$ECS_VERSION" ${TAGS_REDIRECT[$tag]}
    fi
  }
  function ecsf:${suffix}() {
    if [[ "\${TAGS[$tag]}" == "1" ]]; then
      local level=\${1:-INFO} && shift
      local msg="\$*"
      local ts=\$(_ecs:timestamp)
      local escaped_msg=\$(_ecs:escape_json "\$msg")
      printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s","log.logger":"$tag","process.pid":%d,"trace.id":"%s"}\n' \\
        "\$ts" "\$level" "\$escaped_msg" "\$ECS_VERSION" "\$\$" "\$__SESSION" ${TAGS_REDIRECT[$tag]}
    fi
  }
EOF
}

# Generate ECS functions for 'ecs' tag
eval "$(logger:compose:ecs "ecs" "Ecs" "INFO")"

echo "Test 3.1 - Dedicated ecs:Tag function:"
ecs:Ecs "This is a dedicated ECS log function"

echo ""
echo "Test 3.2 - With custom level (ecsf:Tag):"
ecsf:Ecs "ERROR" "This is an error message with full context"
ecsf:Ecs "DEBUG" "Debug message"
ecsf:Ecs "WARN" "Warning message"

echo ""

# =============================================================================
# APPROACH 4: Logger Initialization Helper
# =============================================================================
# WORKS WITH: Existing implementation (wrapper function)
# Best balance of usability and compatibility
# =============================================================================

echo "--- APPROACH 4: Logger Initialization Helper ---"

# Helper to initialize a logger with ECS JSON output
# This combines logger creation with ECS function generation
function logger:ecs() {
  local tag="${1}"
  local level="${2:-INFO}"
  local service="${3:-$ECS_SERVICE_NAME}"
  local redirect="${4:->&2}"

  # Initialize standard logger
  logger "$tag" "${@:5}"

  local suffix="${tag^}"  # capitalize first letter

  # Set redirect for ECS output
  TAGS_REDIRECT[$tag]="$redirect"

  # Generate ECS-specific functions
  eval "$(logger:compose:ecs "$tag" "$suffix" "$level")"

  echo "# Initialized ECS logger: tag=$tag, level=$level, service=$service" >&2
}

# Test new logger
logger:ecs "myapp" "INFO" "my-service" ">&2"

echo "Test 4.1 - Using logger:ecs helper:"
ecs:Myapp "Application started successfully"
ecsf:Myapp "DEBUG" "Configuration loaded"

echo ""

# =============================================================================
# APPROACH 5: Context/Metadata Support via Associative Arrays
# =============================================================================
# REQUIRES: New global array TAGS_ECS_CONTEXT in _logger.sh
# Allows adding custom ECS fields per logger
# =============================================================================

echo "--- APPROACH 5: Context/Metadata Support ---"

# Global array for ECS context (would go in _logger.sh)
declare -g -A TAGS_ECS_CONTEXT

# Set context for a tag
function logger:ecs:context() {
  local tag="$1"
  local key="$2"
  local value="$3"

  # Store as JSON fragment: "key":"value"
  local current="${TAGS_ECS_CONTEXT[$tag]:-}"
  if [[ -n "$current" ]]; then
    TAGS_ECS_CONTEXT[$tag]="${current},\"${key}\":\"${value}\""
  else
    TAGS_ECS_CONTEXT[$tag]="\"${key}\":\"${value}\""
  fi
}

# Enhanced formatter with context
function ecs:format:context() {
  local tag="${1}"
  local level="${2:-INFO}"
  local message="${3:-}"

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context="${TAGS_ECS_CONTEXT[$tag]:-}"

  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION"

  # Add context if present
  [[ -n "$context" ]] && printf ',%s' "$context"

  printf '}\n'
}

# Test context support
logger:ecs:context "myapp" "user.name" "john_doe"
logger:ecs:context "myapp" "http.request.method" "POST"

echo "Test 5.1 - With custom context:"
ecs:format:context "myapp" "INFO" "User performed action"

echo ""

# =============================================================================
# APPROACH 6: Pipe Mode for ECS (like log:Tag)
# =============================================================================
# WORKS WITH: Existing pattern from log:Tag
# =============================================================================

echo "--- APPROACH 6: Pipe Mode for ECS ---"

# Pipe mode ECS formatter (similar to log:Tag pattern)
function ecslog:Ecs() {
  local level="${1:-INFO}"

  if [[ "${TAGS[ecs]}" == "1" ]]; then
    if [ -t 0 ]; then
      # Not a pipe, direct call
      shift
      ecs:format "$level" "$*"
    else
      # Pipe mode - read from stdin
      while IFS= read -r line; do
        ecs:format "$level" "$line"
      done
    fi
  fi
}

echo "Test 6.1 - Pipe mode:"
echo "Piped message through ECS formatter" | ecslog:Ecs "INFO"

echo ""
echo "Test 6.2 - Multiple piped lines:"
{
  echo "Line 1 from pipe"
  echo "Line 2 from pipe"
} | ecslog:Ecs "DEBUG"

echo ""

# =============================================================================
# PERFORMANCE COMPARISON
# =============================================================================

echo "--- Performance Comparison (10 iterations) ---"

# Approach 1: Direct formatter
start=$(date +%s.%N)
for i in {1..10}; do
  ecs:format "INFO" "Performance test message $i" >/dev/null
done
end=$(date +%s.%N)
echo "Approach 1 (Direct): $(echo "$end - $start" | bc)s"

# Approach 2: Redirect pipe (would be slower due to subshell)
logger:redirect ecs "| _ecs:pipe_formatter INFO ecs"
start=$(date +%s.%N)
for i in {1..10}; do
  echo:Ecs "Performance test message $i" >/dev/null 2>&1
done
end=$(date +%s.%N)
echo "Approach 2 (Redirect): $(echo "$end - $start" | bc)s"
logger:redirect ecs ""

# Approach 3: Dedicated function
start=$(date +%s.%N)
for i in {1..10}; do
  ecs:Ecs "Performance test message $i" >/dev/null
done
end=$(date +%s.%N)
echo "Approach 3 (Dedicated): $(echo "$end - $start" | bc)s"

echo ""

# =============================================================================
# FINDINGS SUMMARY
# =============================================================================

echo "=============================================="
echo "FINDINGS SUMMARY"
echo "=============================================="
echo ""
echo "WORKS WITH EXISTING IMPLEMENTATION:"
echo "  1. Pure Bash JSON formatter functions (standalone)"
echo "  2. Redirect mechanism with pipe formatter"
echo "  3. Wrapper functions (logger:ecs helper)"
echo "  4. Pipe mode pattern (like log:Tag)"
echo ""
echo "CRITICAL CHANGES NEEDED IN _logger.sh:"
echo "  1. Add logger:compose:ecs() function for generating ecs:Tag functions"
echo "  2. Add TAGS_ECS_CONTEXT global array for per-tag metadata"
echo "  3. Export helper functions: _ecs:timestamp, _ecs:escape_json"
echo ""
echo "OPTIONAL ENHANCEMENTS:"
echo "  1. Add TAGS_ECS_LEVEL array for per-tag default log levels"
echo "  2. Add logger:ecs() initialization helper"
echo "  3. Add logger:ecs:context() for setting custom ECS fields"
echo "  4. Support jq for validation (optional dependency)"
echo ""
echo "RECOMMENDED APPROACH:"
echo "  - Use Approach 3 (dedicated functions) for best performance"
echo "  - Combine with Approach 4 (helper) for ease of use"
echo "  - Add Approach 5 (context) for metadata support"
echo ""
echo "BASH 5 FEATURES USED:"
echo "  - \$EPOCHREALTIME for high-precision timestamps"
echo "  - Associative arrays for context storage"
echo "  - Parameter expansion for JSON escaping"
echo ""
echo "=============================================="

# Validate JSON output with jq if available
if command -v jq &>/dev/null; then
  echo ""
  echo "--- JSON Validation (jq available) ---"
  test_json=$(ecs:format:full "INFO" "Validation test" "validator")
  if echo "$test_json" | jq . >/dev/null 2>&1; then
    echo "JSON validation: PASSED"
    echo "Pretty printed:"
    echo "$test_json" | jq .
  else
    echo "JSON validation: FAILED"
    echo "Raw output: $test_json"
  fi
else
  echo ""
  echo "Note: Install jq for JSON validation"
fi

echo ""
echo "All done!"
