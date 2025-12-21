#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-22
## Version: 1.16.2
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Demo runner: shows all CI script modes in action

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CI_SCRIPT="${SCRIPT_DIR}/ci-10-compile.sh"

# Resolve E_BASH
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "${SCRIPT_DIR}" && cd ../../.scripts && pwd)"

# shellcheck disable=SC1090
source "$E_BASH/_colors.sh"

echo ""
echo "${cl_lblue}${st_b}╔═══════════════════════════════════════════════════════════╗${st_no_b}${cl_reset}"
echo "${cl_lblue}${st_b}║       CI Script Mode Demo - e-bash Integration            ║${st_no_b}${cl_reset}"
echo "${cl_lblue}${st_b}╚═══════════════════════════════════════════════════════════╝${st_no_b}${cl_reset}"
echo ""

divider() {
  echo ""
  echo "${cl_grey}───────────────────────────────────────────────────${cl_reset}"
  echo ""
}

#region Mode 1: EXEC (Default)
echo "${cl_cyan}${st_b}▶ Mode 1: EXEC (default - normal execution)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=EXEC ./ci-10-compile.sh${cl_reset}"
divider

HOOKS_FLOW_MODE=EXEC "$CI_SCRIPT"

divider
#endregion

#region Mode 2: DRY
echo "${cl_cyan}${st_b}▶ Mode 2: DRY (dry-run - preview commands)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=DRY ./ci-10-compile.sh${cl_reset}"
divider

HOOKS_FLOW_MODE=DRY "$CI_SCRIPT"

divider
#endregion

#region Mode 3: OK
echo "${cl_cyan}${st_b}▶ Mode 3: OK (no-op - immediate success)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=OK ./ci-10-compile.sh${cl_reset}"
divider

HOOKS_FLOW_MODE=OK "$CI_SCRIPT"
echo "${cl_green}  Exit code: $?${cl_reset}"

divider
#endregion

#region Mode 4: ERROR
echo "${cl_cyan}${st_b}▶ Mode 4: ERROR (fail with code)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=ERROR HOOKS_FLOW_ERROR_CODE=42 ./ci-10-compile.sh${cl_reset}"
divider

HOOKS_FLOW_MODE=ERROR HOOKS_FLOW_ERROR_CODE=42 "$CI_SCRIPT" || true
echo "${cl_red}  Exit code: $?${cl_reset}"

divider
#endregion

#region Mode 5: SKIP
echo "${cl_cyan}${st_b}▶ Mode 5: SKIP (disabled step)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=SKIP ./ci-10-compile.sh${cl_reset}"
divider

HOOKS_FLOW_MODE=SKIP "$CI_SCRIPT"
echo "${cl_yellow}  Exit code: $?${cl_reset}"

divider
#endregion

#region Mode 6: TIMEOUT
echo "${cl_cyan}${st_b}▶ Mode 6: TIMEOUT (fail after N seconds)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=TIMEOUT:2 ./ci-10-compile.sh${cl_reset}"
echo "${cl_yellow}  Note: This would timeout after 2s if script took longer${cl_reset}"
divider

HOOKS_FLOW_MODE="TIMEOUT:60" "$CI_SCRIPT"  # Using 60s to not actually timeout
echo "${cl_green}  Completed before timeout. Exit code: $?${cl_reset}"

divider
#endregion

#region Mode 7: Per-script override
echo "${cl_cyan}${st_b}▶ Mode 7: Per-script override${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE_ci_10_compile=DRY HOOKS_FLOW_MODE=EXEC ./ci-10-compile.sh${cl_reset}"
echo "${cl_yellow}  Note: Script-specific mode (DRY) overrides global (EXEC)${cl_reset}"
divider

HOOKS_FLOW_MODE_ci_10_compile=DRY HOOKS_FLOW_MODE=EXEC "$CI_SCRIPT"

divider
#endregion

#region Mode 8: TEST (mock script)
echo "${cl_cyan}${st_b}▶ Mode 8: TEST (run mock script instead)${st_no_b}${cl_reset}"

# Create a temporary mock script
MOCK_SCRIPT=$(mktemp)
cat > "$MOCK_SCRIPT" << 'EOF'
echo "[mocks] This is a test mock script"
echo "[mocks] Simulating successful build..."
echo "[mocks] Build artifacts: dist/app.js"
__HOOKS_FLOW_EXIT_CODE=0
EOF

echo "${cl_grey}  Command: HOOKS_FLOW_MODE=${MOCK_SCRIPT} ./ci-10-compile.sh${cl_reset}"
divider

HOOKS_FLOW_MODE="$MOCK_SCRIPT" "$CI_SCRIPT"
echo "${cl_green}  Exit code: $?${cl_reset}"

rm -f "$MOCK_SCRIPT"

divider
#endregion

echo ""
echo "${cl_lblue}${st_b}Demo complete!${st_no_b}${cl_reset}"
echo ""
echo "Key takeaways:"
echo "  ${cl_green}🟢${cl_reset} All modes handled via begin hook (${cl_cyan}begin_00_mode-intercept.sh${cl_reset})"
echo "  ${cl_green}🟢${cl_reset} Scripts use e-bash modules: dryrun, hooks, logger"
echo "  ${cl_green}🟢${cl_reset} Per-script overrides: HOOKS_FLOW_MODE_{script_name}"
echo "  ${cl_green}🟢${cl_reset} Decision hooks support conditional execution"
echo "  ${cl_green}🟢${cl_reset} Rollback registration for UNDO mode"
echo ""
