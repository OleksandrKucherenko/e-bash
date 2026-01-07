#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-07
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# Enable hooks logging to see execution order (respects existing DEBUG value)
export DEBUG=${DEBUG:-"hooks"}

# shellcheck disable=SC1090 source=../.scripts/_hooks.sh
source "$E_BASH/_hooks.sh"

# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

echo "${cl_cyan}═══════════════════════════════════════════════════════════${cl_reset}"
echo "${cl_cyan}  Hooks System - Function Registration Demo${cl_reset}"
echo "${cl_cyan}═══════════════════════════════════════════════════════════${cl_reset}"
echo

#
# Example 1: Basic Function Registration
#
echo "${cl_green}Example 1: Basic Function Registration${cl_reset}"
echo

# Define some functions
metrics_tracker() {
  echo "  📊 [Metrics] Tracking deployment to ${1:-production}"
  echo "  📊 [Metrics] Recording timestamp: $(date +%s)"
}

notification_sender() {
  echo "  📢 [Notify] Sending notification to team"
  echo "  📢 [Notify] Deployment environment: ${1:-production}"
}

# Define hook and register functions
hooks:declare deploy

echo "Registering functions for 'deploy' hook..."
hooks:register deploy "10-metrics" metrics_tracker
hooks:register deploy "20-notify" notification_sender
echo

echo "${cl_yellow}→ Executing deploy hook:${cl_reset}"
hooks:do deploy "production"
echo

#
# Example 2: Alphabetical Execution Order
#
echo "${cl_green}Example 2: Alphabetical Execution Order${cl_reset}"
echo "Functions execute in order by friendly name, not registration order..."
echo

func_charlie() { echo "  → Charlie (30)"; }
func_alpha() { echo "  → Alpha (10)"; }
func_bravo() { echo "  → Bravo (20)"; }

hooks:declare test

# Register out of order
echo "Registering: charlie (30), alpha (10), bravo (20)..."
hooks:register test "30-charlie" func_charlie
hooks:register test "10-alpha" func_alpha
hooks:register test "20-bravo" func_bravo
echo

echo "${cl_yellow}→ Execution order (alphabetical by friendly name):${cl_reset}"
hooks:do test
echo

#
# Example 3: Forwarding to External Scripts
#
echo "${cl_green}Example 3: Forwarding to External Scripts${cl_reset}"
echo

# Create temporary external scripts
cat > /tmp/datadog-notify.sh <<'EOF'
#!/usr/bin/env bash
echo "  🐕 [Datadog] Sending metrics: event=$1, version=$2"
exit 0
EOF
chmod +x /tmp/datadog-notify.sh

cat > /tmp/slack-notify.sh <<'EOF'
#!/usr/bin/env bash
echo "  💬 [Slack] Posting to #deployments: $*"
exit 0
EOF
chmod +x /tmp/slack-notify.sh

# Create forwarding functions
forward_to_datadog() {
  /tmp/datadog-notify.sh "$@"
}

forward_to_slack() {
  /tmp/slack-notify.sh "$@"
}

hooks:declare notify

echo "Registering external script forwarders..."
hooks:register notify "datadog" forward_to_datadog
hooks:register notify "slack" forward_to_slack
echo

echo "${cl_yellow}→ Executing notify hook with parameters:${cl_reset}"
hooks:do notify "deploy_success" "v1.2.3"
echo

#
# Example 4: Combined with hook:{name} Function
#
echo "${cl_green}Example 4: Execution Order: Function + Registered + Scripts${cl_reset}"
echo

# Define traditional hook:{name} function
hook:build() {
  echo "  🔧 [hook:build] Main build logic"
}

# Register additional functions
pre_build_check() {
  echo "  🟢 [Registered] Pre-build validation"
}

post_build_metrics() {
  echo "  📊 [Registered] Collecting build metrics"
}

hooks:declare build
hooks:register build "00-pre" pre_build_check
hooks:register build "99-post" post_build_metrics

echo "Execution order:"
echo "  1. hook:build() function"
echo "  2. Registered functions (alphabetical)"
echo "  3. External scripts (if any)"
echo

echo "${cl_yellow}→ Executing build hook:${cl_reset}"
hooks:do build
echo

#
# Example 5: Dynamic Registration Based on Environment
#
echo "${cl_green}Example 5: Dynamic Registration (Environment-Based)${cl_reset}"
echo

# Environment-specific functions
production_checks() {
  echo "  🔒 [Prod] Running production safety checks"
  echo "  🔒 [Prod] Verifying rollback plan"
}

development_shortcuts() {
  echo "  ⚡ [Dev] Skipping slow checks"
  echo "  ⚡ [Dev] Using dev credentials"
}

hooks:declare validate

# Register functions based on environment
ENVIRONMENT="${ENVIRONMENT:-development}"
echo "Current environment: ${ENVIRONMENT}"

if [[ "$ENVIRONMENT" == "production" ]]; then
  hooks:register validate "prod-checks" production_checks
else
  hooks:register validate "dev-shortcuts" development_shortcuts
fi
echo

echo "${cl_yellow}→ Executing validate hook:${cl_reset}"
hooks:do validate
echo

#
# Example 6: Unregistering Functions
#
echo "${cl_green}Example 6: Unregistering Functions${cl_reset}"
echo

temporary_function() {
  echo "  ⏰ [Temporary] This won't run after unregister"
}

permanent_function() {
  echo "  🟢 [Permanent] This will always run"
}

hooks:declare cleanup
hooks:register cleanup "temp" temporary_function
hooks:register cleanup "perm" permanent_function

echo "Before unregister:"
hooks:do cleanup
echo

echo "Unregistering 'temp' function..."
hooks:unregister cleanup "temp"
echo

echo "After unregister:"
hooks:do cleanup
echo

#
# Example 7: Listing Registered Functions
#
echo "${cl_green}Example 7: Listing Hooks with Registrations${cl_reset}"
echo

hooks:declare final
hooks:register final "10-first" metrics_tracker
hooks:register final "20-second" notification_sender
hooks:register final "30-third" forward_to_datadog

echo "${cl_yellow}→ Hooks list shows registration count:${cl_reset}"
hooks:list
echo

#
# Example 8: Use Case - Adding Observability
#
echo "${cl_green}Example 8: Real-World Use Case - Adding Observability${cl_reset}"
echo

# Function to add timing to any hook
add_timing() {
  local hook_name="$1"

  # Create timing function dynamically
  local timing_func="${hook_name}_timing"
  eval "${timing_func}() {
    echo \"  ⏱️  [Timing] Hook '${hook_name}' started at \$(date +%H:%M:%S)\"
  }"

  # Register it to run first (00- prefix)
  hooks:register "$hook_name" "00-timing" "$timing_func"
}

hooks:declare process
add_timing process

# Add main logic
hook:process() {
  echo "  ⚙️  [Main] Processing data..."
  sleep 1  # Simulate work
  echo "  ⚙️  [Main] Processing complete"
}

echo "Added timing observability to 'process' hook"
echo

echo "${cl_yellow}→ Executing process hook with timing:${cl_reset}"
hooks:do process
echo

#
# Cleanup
#
echo "${cl_cyan}═══════════════════════════════════════════════════════════${cl_reset}"
echo "Cleaning up temporary files..."
rm -f /tmp/datadog-notify.sh /tmp/slack-notify.sh
echo "${cl_green}Demo complete!${cl_reset}"
echo
echo "Key Takeaways:"
echo "  • hooks:register <hook> <friendly_name> <function>"
echo "  • Functions execute in alphabetical order by friendly_name"
echo "  • Perfect for metrics, logging, and external integrations"
echo "  • Can be registered/unregistered dynamically"
echo "  • Execution order: hook:xxx() → registered → scripts"
