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

DEBUG=ecs,loader,myapp,test13,app # enable debug mode

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

# ISO 8601 timestamp with microseconds - PURE BASH (no subprocess!)
# Uses Howard Hinnant's civil_from_days algorithm for date conversion
function _ecs:timestamp() {
  local ts="${1:-$EPOCHREALTIME}"

  # Handle integer vs float timestamps
  local sec=${ts%.*}
  local usec=${ts#*.}
  [[ "$ts" == *.* ]] || usec=0
  usec=${usec:0:6}
  usec=$(( 10#$usec ))
  while (( ${#usec} < 6 )); do usec="${usec}0"; done

  # Time of day calculation
  local s=$(( sec ))
  local days=$(( s / 86400 ))
  local sod=$(( s % 86400 ))   # seconds of day

  local hh=$(( sod / 3600 ))
  local mm=$(( (sod % 3600) / 60 ))
  local ss=$(( sod % 60 ))

  # civil_from_days (Howard Hinnant), with days since 1970-01-01
  local z=$(( days + 719468 ))
  local era=$(( (z >= 0 ? z : z - 146096) / 146097 ))
  local doe=$(( z - era*146097 ))                       # [0, 146096]
  local yoe=$(( (doe - doe/1460 + doe/36524 - doe/146096) / 365 ))  # [0, 399]
  local y=$(( yoe + era*400 ))
  local doy=$(( doe - (365*yoe + yoe/4 - yoe/100) ))    # [0, 365]
  local mp=$(( (5*doy + 2) / 153 ))                     # [0, 11]
  local d=$(( doy - (153*mp + 2)/5 + 1 ))               # [1, 31]
  local m=$(( mp + (mp < 10 ? 3 : -9) ))                # [1, 12]
  y=$(( y + (m <= 2 ? 1 : 0) ))

  printf "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ\n" \
    "$y" "$m" "$d" "$hh" "$mm" "$ss" "$usec"
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
# APPROACH 1b: Context/Metadata Support (MDC-style)
# =============================================================================
# EXTENDS: Approach 1 with shared context for correlation IDs, etc.
# ELEGANCE: 42/45 (adds 3 functions, 1 global array - acceptable trade-off)
# =============================================================================

echo "--- APPROACH 1b: Context/Metadata Support ---"

# Global context array (MDC - Mapped Diagnostic Context)
# Why single array: Minimizes global state while enabling cross-cutting concerns
declare -g -A _ECS_CONTEXT=()

# Set context field (applies to all subsequent logs)
function ecs:set() {
  local key="$1" value="$2"
  _ECS_CONTEXT["$key"]="$value"
}

# Unset context field
function ecs:unset() {
  unset '_ECS_CONTEXT[$1]'
}

# Clear all context
function ecs:clear() {
  _ECS_CONTEXT=()
}

# Internal: render context as JSON fragment
function _ecs:context:json() {
  local fragment=""
  for key in "${!_ECS_CONTEXT[@]}"; do
    local escaped_val=$(_ecs:escape_json "${_ECS_CONTEXT[$key]}")
    fragment+=",\"${key}\":\"${escaped_val}\""
  done
  echo "$fragment"
}

# Updated format function WITH context support
function ecs:format:ctx() {
  local level="${1:-INFO}"
  local message="${2:-}"

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context=$(_ecs:context:json)

  # ECS format with injected context
  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"%s}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION" "$context"
}

# Test context support
echo "Test 1b.1 - Set correlation ID and service context:"
ecs:set "correlation.id" "req-$(date +%s)-$$"
ecs:set "service.name" "order-processor"
ecs:set "environment" "development"

ecs:format:ctx "INFO" "Starting request processing"

echo ""
echo "Test 1b.2 - Add request-specific context:"
ecs:set "user.id" "user-12345"
ecs:set "http.request.method" "POST"

ecs:format:ctx "DEBUG" "Validating user permissions"
ecs:format:ctx "INFO" "User authorized"

echo ""
echo "Test 1b.3 - Unset specific field:"
ecs:unset "http.request.method"
ecs:format:ctx "INFO" "Method field removed"

echo ""
echo "Test 1b.4 - Clear all context:"
ecs:clear
ecs:format:ctx "WARN" "Context cleared - minimal output"

echo ""

# =============================================================================
# USE CASE EXPLORATION: When is context needed?
# =============================================================================
echo "--- Use Case Exploration ---"
echo ""
echo "USE CASES FOR CONTEXT (ecs:set):"
echo "  1. Correlation ID - trace requests across services"
echo "  2. User ID - who triggered the action"
echo "  3. Request ID - unique per HTTP request"
echo "  4. Environment - dev/staging/prod"
echo "  5. Service name - which microservice"
echo "  6. Transaction ID - database/business transaction"
echo ""
echo "PATTERNS OBSERVED:"
echo "  - Context is typically set ONCE at script start"
echo "  - Additional context added as processing progresses"
echo "  - Rarely need to unset individual fields"
echo "  - Clear at end or between independent operations"
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
# USE CASE 7: Log Level Filtering
# =============================================================================
# Question: Should ECS logger filter by level like traditional loggers?
# =============================================================================

echo "--- USE CASE 7: Log Level Filtering ---"

# Log level hierarchy (numeric for comparison)
declare -g -A _ECS_LEVELS=(
  [TRACE]=0 [DEBUG]=1 [INFO]=2 [WARN]=3 [ERROR]=4 [FATAL]=5
)

# Minimum log level (configurable)
declare -g ECS_MIN_LEVEL="${ECS_MIN_LEVEL:-DEBUG}"

# Check if level should be logged
function _ecs:should_log() {
  local level="$1"
  local min_val="${_ECS_LEVELS[$ECS_MIN_LEVEL]:-2}"
  local level_val="${_ECS_LEVELS[$level]:-2}"
  [[ $level_val -ge $min_val ]]
}

# Format with level filtering
function ecs:log() {
  local level="${1:-INFO}"
  local message="${2:-}"

  # Skip if below minimum level
  _ecs:should_log "$level" || return 0

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context=$(_ecs:context:json)

  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"%s}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION" "$context"
}

echo "Test 7.1 - With ECS_MIN_LEVEL=DEBUG (default):"
ecs:log "DEBUG" "This debug message appears"
ecs:log "INFO" "This info message appears"
ecs:log "TRACE" "This trace message is filtered out"

echo ""
echo "Test 7.2 - With ECS_MIN_LEVEL=WARN:"
ECS_MIN_LEVEL=WARN
ecs:log "DEBUG" "This debug is filtered"
ecs:log "INFO" "This info is filtered"
ecs:log "WARN" "This warning appears"
ecs:log "ERROR" "This error appears"
ECS_MIN_LEVEL=DEBUG  # Reset

echo ""

# =============================================================================
# USE CASE 8: Error Logging with ECS Error Fields
# =============================================================================
# ECS defines: error.code, error.message, error.stack_trace, error.type
# =============================================================================

echo "--- USE CASE 8: Error Logging with ECS Error Fields ---"

# Log error with ECS error fields
function ecs:error() {
  local message="$1"
  local error_type="${2:-}"
  local error_code="${3:-}"

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context=$(_ecs:context:json)

  printf '{"@timestamp":"%s","log.level":"ERROR","message":"%s","ecs.version":"%s"' \
    "$ts" "$escaped_msg" "$ECS_VERSION"

  # Add ECS error fields if provided
  [[ -n "$error_type" ]] && printf ',"error.type":"%s"' "$error_type"
  [[ -n "$error_code" ]] && printf ',"error.code":"%s"' "$error_code"

  # Add context
  [[ -n "$context" ]] && printf '%s' "$context"

  printf '}\n'
}

# Capture and log bash error with stack trace
function ecs:error:trace() {
  local message="$1"
  local error_code="${2:-1}"

  # Capture bash call stack
  local stack=""
  local frame=0
  while caller $frame >/dev/null 2>&1; do
    local info=($(caller $frame))
    stack+="at ${info[1]}:${info[0]} in ${info[2]:-main}\\n"
    ((frame++))
  done

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local escaped_stack=$(_ecs:escape_json "$stack")
  local context=$(_ecs:context:json)

  printf '{"@timestamp":"%s","log.level":"ERROR","message":"%s","ecs.version":"%s","error.code":"%s","error.stack_trace":"%s"%s}\n' \
    "$ts" "$escaped_msg" "$ECS_VERSION" "$error_code" "$escaped_stack" "$context"
}

echo "Test 8.1 - Simple error:"
ecs:error "Database connection failed" "ConnectionError" "DB001"

echo ""
echo "Test 8.2 - Error with stack trace:"
function inner_function() { ecs:error:trace "Something went wrong" "42"; }
function outer_function() { inner_function; }
outer_function

echo ""

# =============================================================================
# USE CASE 9: Convenience Aliases (ecs:info, ecs:debug, ecs:warn, ecs:error)
# =============================================================================
# Question: Should we provide shorthand functions?
# =============================================================================

echo "--- USE CASE 9: Convenience Aliases ---"

# Shorthand functions for common levels
function ecs:trace() { ecs:log "TRACE" "$*"; }
function ecs:debug() { ecs:log "DEBUG" "$*"; }
function ecs:info()  { ecs:log "INFO" "$*"; }
function ecs:warn()  { ecs:log "WARN" "$*"; }
function ecs:fatal() { ecs:log "FATAL" "$*"; }
# Note: ecs:error already defined with extended signature

echo "Test 9.1 - Using shorthand functions:"
ecs:set "request.id" "req-999"
ecs:info "Processing started"
ecs:debug "Loading configuration"
ecs:warn "Deprecated API called"
ecs:clear

echo ""
echo "CONVENIENCE ALIAS TRADE-OFF:"
echo "  PRO: Familiar API (like log4j, winston, etc.)"
echo "  PRO: Less typing: ecs:info vs ecs:log INFO"
echo "  CON: More functions to maintain (6 vs 1)"
echo "  CON: ecs:error has different signature (extended)"
echo ""

# =============================================================================
# USE CASE 10: Output Destinations
# =============================================================================
# Question: How to handle stdout vs stderr vs file?
# =============================================================================

echo "--- USE CASE 10: Output Destinations ---"

# Global output destination
declare -g ECS_OUTPUT="${ECS_OUTPUT:-/dev/stderr}"

# Format with configurable output
function ecs:emit() {
  local level="${1:-INFO}"
  local message="${2:-}"

  _ecs:should_log "$level" || return 0

  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context=$(_ecs:context:json)

  printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"%s}\n' \
    "$ts" "$level" "$escaped_msg" "$ECS_VERSION" "$context" >> "$ECS_OUTPUT"
}

echo "Test 10.1 - Output to stderr (default):"
ECS_OUTPUT=/dev/stderr ecs:emit "INFO" "This goes to stderr" 2>&1

echo ""
echo "Test 10.2 - Output to file:"
ECS_OUTPUT=/tmp/ecs-test.json ecs:emit "INFO" "This goes to file"
echo "File contents:"
cat /tmp/ecs-test.json
rm -f /tmp/ecs-test.json

echo ""
echo "OUTPUT DESTINATION PATTERNS:"
echo "  1. /dev/stderr - Default, visible in terminal"
echo "  2. /dev/stdout - For piping to other tools"
echo "  3. /path/file.json - For log aggregation"
echo "  4. | jq . - Pretty print for debugging"
echo ""

# =============================================================================
# USE CASE 11: Formatter Configuration Pattern (RECOMMENDED)
# =============================================================================
# INSIGHT: Most logging libraries configure output FORMAT, not separate API
# Examples: log4j PatternLayout, winston format, logback encoder
#
# GOAL: Keep same API (echo:Tag), change output format via configuration
# =============================================================================

echo "--- USE CASE 11: Formatter Configuration Pattern ---"
echo ""
echo "INSIGHT: Separate API (ecs:log) vs Configured Format (echo:Tag + formatter)"
echo ""

# Global formatter setting
declare -g LOGGER_FORMAT="${LOGGER_FORMAT:-text}"  # text, json, ecs

# Formatter registry - maps format name to formatter function
declare -g -A _LOGGER_FORMATTERS=(
  [text]="_fmt:text"
  [json]="_fmt:json"
  [ecs]="_fmt:ecs"
)

# Text formatter (default) - just passes through
function _fmt:text() {
  local level="$1" tag="$2" message="$3"
  echo "$message"
}

# Simple JSON formatter
function _fmt:json() {
  local level="$1" tag="$2" message="$3"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  printf '{"timestamp":"%s","level":"%s","tag":"%s","message":"%s"}\n' \
    "$ts" "$level" "$tag" "$escaped_msg"
}

# ECS formatter (full)
function _fmt:ecs() {
  local level="$1" tag="$2" message="$3"
  local ts=$(_ecs:timestamp)
  local escaped_msg=$(_ecs:escape_json "$message")
  local context=$(_ecs:context:json)

  printf '{"@timestamp":"%s","log.level":"%s","log.logger":"%s","message":"%s","ecs.version":"%s"%s}\n' \
    "$ts" "$level" "$tag" "$escaped_msg" "$ECS_VERSION" "$context"
}

# Universal log function that uses configured formatter
function logger:emit() {
  local level="$1" tag="$2"; shift 2
  local message="$*"

  # Get formatter function
  local formatter="${_LOGGER_FORMATTERS[$LOGGER_FORMAT]:-_fmt:text}"

  # Call formatter
  "$formatter" "$level" "$tag" "$message"
}

# Example: Wrapper that keeps familiar echo:Tag API
function logger:format:set() {
  local tag="$1"
  local format="$2"

  # Store format preference per tag
  eval "
    function echo:${tag^}:formatted() {
      logger:emit INFO $tag \"\$*\"
    }
  "
}

echo "Test 11.1 - Same message, different formats:"
echo ""
echo "LOGGER_FORMAT=text:"
LOGGER_FORMAT=text logger:emit "INFO" "myapp" "User logged in"

echo ""
echo "LOGGER_FORMAT=json:"
LOGGER_FORMAT=json logger:emit "INFO" "myapp" "User logged in"

echo ""
echo "LOGGER_FORMAT=ecs (with context):"
ecs:set "user.id" "12345"
ecs:set "correlation.id" "req-abc"
LOGGER_FORMAT=ecs logger:emit "INFO" "myapp" "User logged in"
ecs:clear

echo ""
echo "KEY INSIGHT:"
echo "  Instead of: ecs:info('message')     # New API"
echo "  Prefer:     echo:Tag 'message'      # Same API, configured format"
echo "              LOGGER_FORMAT=ecs       # Configuration controls output"
echo ""
echo "BENEFITS:"
echo "  1. Single API to learn (echo:Tag, printf:Tag)"
echo "  2. Format is configuration, not code change"
echo "  3. Easy to switch formats per environment"
echo "  4. Context (ecs:set) works with any formatter"
echo ""
echo "IMPLEMENTATION OPTIONS:"
echo "  A. logger:redirect with formatter pipe (current approach)"
echo "  B. Override echo:Tag to call formatter (invasive)"
echo "  C. New logger:emit that wraps formatters (cleanest)"
echo ""

# =============================================================================
# USE CASE 12: Integration with Existing Logger via Redirect
# =============================================================================
# REALIZATION: logger:redirect already provides this capability!
# =============================================================================

echo "--- USE CASE 12: Formatter via Existing Redirect ---"
echo ""

# ECS formatter for pipe usage
function _ecs:formatter:pipe() {
  local tag="${1:-unknown}"
  while IFS= read -r message; do
    local ts=$(_ecs:timestamp)
    local escaped_msg=$(_ecs:escape_json "$message")
    local context=$(_ecs:context:json)
    printf '{"@timestamp":"%s","log.level":"INFO","log.logger":"%s","message":"%s","ecs.version":"%s"%s}\n' \
      "$ts" "$tag" "$escaped_msg" "$ECS_VERSION" "$context"
  done
}

# Helper to enable ECS format for a tag
function logger:format:ecs() {
  local tag="$1"
  # Use existing redirect mechanism!
  logger:redirect "$tag" "| _ecs:formatter:pipe $tag"
}

# Helper to disable ECS format (back to text)
function logger:format:text() {
  local tag="$1"
  logger:redirect "$tag" ""
}

echo "Test 12.1 - Enable ECS format for existing 'ecs' logger:"
ecs:set "env" "production"
logger:format:ecs "ecs"

echo:Ecs "This uses existing echo:Tag API"
echo:Ecs "But outputs ECS JSON format"

echo ""
echo "Test 12.2 - Disable ECS, back to text:"
logger:format:text "ecs"
echo:Ecs "Back to plain text output"
ecs:clear

echo ""
echo "CONCLUSION:"
echo "  The MOST ELEGANT solution uses existing infrastructure:"
echo "    1. logger:redirect already supports pipe formatters"
echo "    2. Just need to provide ECS formatter function"
echo "    3. Keep same API (echo:Tag), configuration switches format"
echo ""

# =============================================================================
# USE CASE 13: Pipe-based ecs:format with Prefix-encoded Level
# =============================================================================
# IDEA: Use logger:init prefix to encode log level, pipe to ecs:format
# This is the MOST elegant approach - minimal new concepts
#
# Pattern:
#   logger:init test "::INFO:: " "| ecs:format 'ECS_CONTEXT'"
#   ecs:set "key" "value"
#   log:Test "message" → outputs ECS JSON
#
# INSIGHT: Level can be overridden IN the message itself!
#   echo:Tag "::ERROR:: something went wrong"
#   → extracts ERROR level, strips prefix from message
# =============================================================================

echo "--- USE CASE 13: Pipe-based ecs:format with Prefix Level ---"
echo ""

# ECS formatter that reads from stdin pipe
# - Extracts log level from prefix pattern ::LEVEL:: (can be in prefix OR message)
# - Reads message from stdin
# - Injects context from named associative array
function ecs:format() {
  local context_array="${1:-}"
  local default_level="${2:-INFO}"

  while IFS= read -r line; do
    local level="$default_level"
    local message="$line"

    # Extract level from prefix pattern ::LEVEL:: (at start of line)
    # This handles prefix-based default level
    if [[ "$line" =~ ^::([A-Z]+)::[[:space:]]*(.*) ]]; then
      level="${BASH_REMATCH[1]}"
      message="${BASH_REMATCH[2]}"

      # Check if message ALSO starts with ::LEVEL:: (inline override)
      # This allows: prefix "::INFO:: " + message "::ERROR:: something"
      if [[ "$message" =~ ^::([A-Z]+)::[[:space:]]*(.*) ]]; then
        level="${BASH_REMATCH[1]}"
        message="${BASH_REMATCH[2]}"
      fi
    fi

    # Build JSON
    local ts=$(_ecs:timestamp)
    local escaped_msg=$(_ecs:escape_json "$message")

    printf '{"@timestamp":"%s","log.level":"%s","message":"%s","ecs.version":"%s"' \
      "$ts" "$level" "$escaped_msg" "$ECS_VERSION"

    # Inject context from named array if provided
    if [[ -n "$context_array" ]]; then
      # Use nameref (Bash 4.3+) for clean array access
      local -n ctx_ref="$context_array" 2>/dev/null || true
      if [[ ${#ctx_ref[@]} -gt 0 ]]; then
        for key in "${!ctx_ref[@]}"; do
          local escaped_val=$(_ecs:escape_json "${ctx_ref[$key]}")
          printf ',"%s":"%s"' "$key" "$escaped_val"
        done
      fi
    fi

    printf '}\n'
  done
}

# Test: Setup context array
declare -g -A ECS_CONTEXT=(
  [service.name]="my-service"
  [environment]="production"
)

echo "Test 13.1 - Initialize with default INFO level in prefix:"
# Initialize logger with ECS format pipe (default level in prefix)
logger test13 "$@"
logger:prefix "test13" "::INFO:: "
logger:redirect "test13" "| ecs:format ECS_CONTEXT"

echo:Test13 "This message uses default INFO level"

echo ""
echo "Test 13.2 - Override level INLINE in the message:"
echo:Test13 "::ERROR:: This overrides to ERROR level"
echo:Test13 "::DEBUG:: This overrides to DEBUG level"
echo:Test13 "::WARN:: This overrides to WARN level"
echo:Test13 "Back to default INFO (no override)"

echo ""
echo "Test 13.3 - Update context dynamically:"
ECS_CONTEXT[correlation.id]="req-$(date +%s)"
ECS_CONTEXT[user.id]="user-42"
echo:Test13 "Message with updated context"
echo:Test13 "::ERROR:: Error with context"

echo ""
echo "Test 13.4 - Using log:Tag pipe mode:"
echo "Piped content" | log:Test13
echo "::FATAL:: Piped fatal error" | log:Test13

echo ""
echo "ELEGANCE INSIGHT:"
echo "  Level override is INLINE - no configuration change needed!"
echo "  echo:Tag '::ERROR:: message'  → ERROR level"
echo "  echo:Tag 'message'            → default INFO level"
echo ""

# =============================================================================
# USE CASE 13b: Simplified helpers (optional)
# =============================================================================

echo "--- USE CASE 13b: Optional helpers ---"

# Helper to initialize ECS logging for a tag
function ecs:init() {
  local tag="$1"
  local context_array="${2:-ECS_CONTEXT}"
  local default_level="${3:-INFO}"

  logger "$tag" "${@:4}"
  logger:prefix "$tag" "::${default_level}:: "
  logger:redirect "$tag" "| ecs:format '$context_array'"
}

echo "Test 13b.1 - Using ecs:init helper:"
ecs:init "app" "ECS_CONTEXT" "INFO"

echo:App "Application initialized"
echo:App "::DEBUG:: Debug details here"
echo:App "::ERROR:: Something went wrong"
echo:App "Normal info message"

echo ""
echo "FINAL ELEGANCE ANALYSIS:"
echo ""
echo "  WHAT'S ELEGANT:"
echo "    1. Uses EXISTING logger:init/prefix/redirect - no new infrastructure"
echo "    2. Single ecs:format function handles all JSON formatting"
echo "    3. Level can be: default (from prefix) OR inline override (in message)"
echo "    4. Context via named array - explicit, testable"
echo "    5. Works with echo:Tag, printf:Tag, log:Tag - all existing APIs"
echo ""
echo "  MINIMAL API:"
echo "    - ecs:format <context_array> [default_level]  # The pipe formatter"
echo "    - ecs:init <tag> [context_array] [level]      # Optional helper"
echo ""
echo "  USAGE PATTERNS:"
echo "    echo:Tag 'message'              # Uses default level"
echo "    echo:Tag '::ERROR:: message'    # Override to ERROR"
echo "    echo:Tag '::DEBUG:: message'    # Override to DEBUG"
echo ""
echo "  NO LONGER NEEDED:"
echo "    - ecs:level helper (level is inline!)"
echo "    - Multiple prefix changes"
echo "    - Level-specific functions (ecs:error, ecs:info)"
echo ""

# =============================================================================
# UPDATED FINDINGS SUMMARY
# =============================================================================

echo "=============================================="
echo "FINDINGS SUMMARY"
echo "=============================================="
echo ""
echo "RECOMMENDED APPROACH (USE CASE 13 - Pipe-based ecs:format):"
echo "  Pattern:"
echo "    logger:init tag '::INFO:: ' '| ecs:format ECS_CONTEXT'"
echo "    ecs:set 'key' 'value'    # Update context"
echo "    echo:Tag 'message'       # Outputs ECS JSON"
echo ""
echo "WHY THIS IS MOST ELEGANT:"
echo "  1. Uses EXISTING infrastructure - logger:init, prefix, redirect"
echo "  2. Single ecs:format function - reads stdin, outputs JSON"
echo "  3. Level encoded in prefix ::LEVEL:: - no new mechanism"
echo "  4. Context via named array - explicit, testable, global"
echo "  5. Works with ALL existing APIs - echo:Tag, printf:Tag, log:Tag"
echo ""
echo "MINIMAL NEW CODE (can be in separate _ecs.sh):"
echo "  - ecs:format <ctx_array> [level]  # Pipe formatter (required)"
echo "  - _ecs:timestamp                  # ISO 8601 helper (required)"
echo "  - _ecs:escape_json <str>          # JSON escaping (required)"
echo "  - ecs:init <tag> [ctx] [level]    # Convenience helper (optional)"
echo "  - ecs:level <tag> <level>         # Level switcher (optional)"
echo "  - ecs:set <key> <value>           # Context setter (optional)"
echo ""
echo "ELEGANCE SCORE: 43/45"
echo "  - Correctness: 5 (valid JSON, handles escaping)"
echo "  - Clarity: 5 (single function, clear purpose)"
echo "  - Simplicity: 4 (uses existing infra, one new concept)"
echo "  - Cohesion: 5 (formatter does one thing)"
echo "  - Coupling: 4 (depends on logger:redirect)"
echo "  - Predictability: 5 (input→JSON, no magic)"
echo "  - Efficiency: 4 (pipe overhead acceptable)"
echo "  - Idiomatic: 5 (follows existing patterns)"
echo "  - Testability: 5 (pure function, easy to test)"
echo ""
echo "ALTERNATIVE APPROACHES EXPLORED:"
echo "  1. Pure Bash formatter (standalone) - 44/45 (no integration)"
echo "  2-6. Various wrappers - 26-34/45 (more complex)"
echo "  11-12. Formatter config - 42/45 (close second)"
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
