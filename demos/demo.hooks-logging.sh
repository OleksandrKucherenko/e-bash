#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-18
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# shellcheck disable=SC2155
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd ../.scripts && pwd)"

# Enable hooks logging to see traceability
export DEBUG="hooks"

# shellcheck disable=SC1090 source=../.scripts/_hooks.sh
source "$E_BASH/_hooks.sh"

# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

echo "${cl_lblue}${st_b}=== e-bash Hooks Logging & Execution Modes Demo ===${st_no_b}${cl_reset}"
echo ""
echo "This demo shows hooks traceability with DEBUG=hooks enabled"
echo ""

# ============================================================================
# Example 1: Basic Logging
# ============================================================================
echo "${cl_cyan}${st_b}Example 1: Hook Definition and Execution Logging${st_no_b}${cl_reset}"
echo "----------------------------------------"
echo ""

hooks:define begin process end

echo ""
echo "${cl_grey}# Implementing function hooks${cl_reset}"
hook:begin() {
  echo "  ${cl_green}[User Output] Begin: Initializing${cl_reset}"
}

hook:end() {
  echo "  ${cl_green}[User Output] End: Completed${cl_reset}"
}

echo ""
echo "${cl_grey}# Executing hooks${cl_reset}"
on:hook begin
echo "  ${cl_green}[User Output] Main logic here...${cl_reset}"
on:hook end

echo ""

# ============================================================================
# Example 2: Multiple Scripts with Execution Order Logging
# ============================================================================
echo "${cl_cyan}${st_b}Example 2: Multiple Scripts - Execution Order Traceability${st_no_b}${cl_reset}"
echo "----------------------------------------"
echo ""

DEMO_DIR="/tmp/demo_hooks_logging_$$"
mkdir -p "$DEMO_DIR"
export HOOKS_DIR="$DEMO_DIR"

# Create multiple scripts
cat > "$DEMO_DIR/process_01_validate.sh" <<'EOF'
#!/usr/bin/env bash
echo "  [User Output] Step 1: Validating input"
exit 0
EOF

cat > "$DEMO_DIR/process_02_transform.sh" <<'EOF'
#!/usr/bin/env bash
echo "  [User Output] Step 2: Transforming data"
exit 0
EOF

cat > "$DEMO_DIR/process_03_save.sh" <<'EOF'
#!/usr/bin/env bash
echo "  [User Output] Step 3: Saving results"
exit 0
EOF

chmod +x "$DEMO_DIR"/*.sh

echo "${cl_grey}# Notice the logging shows:${cl_reset}"
echo "${cl_grey}#  - Scripts discovered${cl_reset}"
echo "${cl_grey}#  - Execution order (1/3, 2/3, 3/3)${cl_reset}"
echo "${cl_grey}#  - Exit codes for each script${cl_reset}"
echo ""

on:hook process

rm -rf "$DEMO_DIR"

echo ""

# ============================================================================
# Example 3: Sourced Execution Mode
# ============================================================================
echo "${cl_cyan}${st_b}Example 3: Sourced Execution Mode (hook:run function)${st_no_b}${cl_reset}"
echo "----------------------------------------"
echo ""

export HOOKS_EXEC_MODE="source"
echo "${cl_yellow}HOOKS_EXEC_MODE=\"source\"${cl_reset} - Scripts are sourced, not executed"
echo ""

hooks:define deploy

DEMO_SOURCE_DIR="/tmp/demo_hooks_source_$$"
mkdir -p "$DEMO_SOURCE_DIR"
export HOOKS_DIR="$DEMO_SOURCE_DIR"

# Create a script with hook:run function
cat > "$DEMO_SOURCE_DIR/deploy-update.sh" <<'EOF'
#!/usr/bin/env bash

# When sourced, this function will be called
function hook:run() {
  echo "  [User Output] Deploying application"
  echo "  [User Output] Can modify parent shell variables"
  echo "  [User Output] Received params: $*"

  # This variable will be available in parent shell
  DEPLOY_STATUS="completed"
}
EOF

chmod +x "$DEMO_SOURCE_DIR/deploy-update.sh"

echo "${cl_grey}# Script contains hook:run function${cl_reset}"
echo "${cl_grey}# Logging shows '(sourced mode)' indicator${cl_reset}"
echo ""

on:hook deploy "v1.2.3"

echo ""
echo "${cl_green}After sourced execution, variables are accessible:${cl_reset}"
echo "  DEPLOY_STATUS=${DEPLOY_STATUS}"

rm -rf "$DEMO_SOURCE_DIR"

# Reset to default exec mode
export HOOKS_EXEC_MODE="exec"

echo ""

# ============================================================================
# Example 4: Failed Hook Detection
# ============================================================================
echo "${cl_cyan}${st_b}Example 4: Failed Hook with Exit Code Logging${st_no_b}${cl_reset}"
echo "----------------------------------------"
echo ""

hooks:define validate

DEMO_FAIL_DIR="/tmp/demo_hooks_fail_$$"
mkdir -p "$DEMO_FAIL_DIR"
export HOOKS_DIR="$DEMO_FAIL_DIR"

cat > "$DEMO_FAIL_DIR/validate-check.sh" <<'EOF'
#!/usr/bin/env bash
echo "  [User Output] Validation failed!"
exit 42
EOF

chmod +x "$DEMO_FAIL_DIR/validate-check.sh"

echo "${cl_grey}# Exit code is logged for debugging${cl_reset}"
echo ""

if on:hook validate; then
  echo "  ${cl_green}Validation passed${cl_reset}"
else
  EXIT_CODE=$?
  echo "  ${cl_red}Validation failed with exit code: $EXIT_CODE${cl_reset}"
fi

rm -rf "$DEMO_FAIL_DIR"

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "${cl_lblue}${st_b}=== Summary ===${st_no_b}${cl_reset}"
echo ""
echo "Logging benefits (DEBUG=hooks):"
echo "  • ${cl_green}Hook registration visibility${cl_reset} - see what hooks are defined"
echo "  • ${cl_green}Execution flow traceability${cl_reset} - know exactly what's running"
echo "  • ${cl_green}Script discovery${cl_reset} - see which scripts were found"
echo "  • ${cl_green}Execution order${cl_reset} - verify scripts run in correct sequence"
echo "  • ${cl_green}Exit code tracking${cl_reset} - debug failures easily"
echo "  • ${cl_green}Mode indicators${cl_reset} - know if scripts are exec'd or sourced"
echo ""
echo "Execution modes:"
echo "  • ${cl_cyan}exec${cl_reset} (default) - Scripts run in subprocess, isolated"
echo "  • ${cl_cyan}source${cl_reset} - Scripts sourced, can modify parent shell"
echo ""
echo "Enable logging:"
echo "  ${cl_yellow}export DEBUG=hooks${cl_reset}     # Enable hooks logging only"
echo "  ${cl_yellow}export DEBUG=*${cl_reset}         # Enable all logging"
echo "  ${cl_yellow}export DEBUG=-${cl_reset}         # Disable all logging"
echo ""
echo "For more information, see: ${cl_yellow}docs/public/hooks.md${cl_reset}"
echo ""
