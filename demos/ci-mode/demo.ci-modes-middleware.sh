#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

## Demo runner: shows all CI script modes via middleware contract

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CI_SCRIPT="${SCRIPT_DIR}/ci-20-compile.sh"

[ -z "$E_BASH" ] && readonly E_BASH="$(cd "${SCRIPT_DIR}" && cd ../../.scripts && pwd)"

# shellcheck disable=SC1090 source=../../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

echo ""
echo "${cl_lblue}${st_b}╔═══════════════════════════════════════════════════════════╗${st_no_b}${cl_reset}"
echo "${cl_lblue}${st_b}║   CI Script Middleware Demo - e-bash Integration          ║${st_no_b}${cl_reset}"
echo "${cl_lblue}${st_b}╚═══════════════════════════════════════════════════════════╝${st_no_b}${cl_reset}"
echo ""

divider() {
  echo ""
  echo "${cl_grey}───────────────────────────────────────────────────${cl_reset}"
  echo ""
}

echo "${cl_cyan}${st_b}▶ Mode 1: EXEC (default - normal execution)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=EXEC ./ci-20-compile.sh${cl_reset}"
divider
HOOKS_FLOW_MODE=EXEC "$CI_SCRIPT"
divider

echo "${cl_cyan}${st_b}▶ Mode 2: DRY (dry-run - preview commands)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=DRY ./ci-20-compile.sh${cl_reset}"
divider
HOOKS_FLOW_MODE=DRY "$CI_SCRIPT"
divider

echo "${cl_cyan}${st_b}▶ Mode 3: OK (no-op - immediate success)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=OK ./ci-20-compile.sh${cl_reset}"
divider
HOOKS_FLOW_MODE=OK "$CI_SCRIPT"
echo "${cl_green}  Exit code: $?${cl_reset}"
divider

echo "${cl_cyan}${st_b}▶ Mode 4: ERROR (fail with code)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=ERROR HOOKS_FLOW_ERROR_CODE=42 ./ci-20-compile.sh${cl_reset}"
divider
HOOKS_FLOW_MODE=ERROR HOOKS_FLOW_ERROR_CODE=42 "$CI_SCRIPT" || true
echo "${cl_red}  Exit code: $?${cl_reset}"
divider

echo "${cl_cyan}${st_b}▶ Mode 5: SKIP (disabled step)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=SKIP ./ci-20-compile.sh${cl_reset}"
divider
HOOKS_FLOW_MODE=SKIP "$CI_SCRIPT"
echo "${cl_yellow}  Exit code: $?${cl_reset}"
divider

echo "${cl_cyan}${st_b}▶ Mode 6: TIMEOUT (fail after N seconds)${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE=TIMEOUT:2 ./ci-20-compile.sh${cl_reset}"
echo "${cl_yellow}  Note: The script will print dots and exit after timeout${cl_reset}"
divider
HOOKS_FLOW_MODE="TIMEOUT:2" "$CI_SCRIPT" || true
echo "${cl_red}  Exit code: $?${cl_reset}"
divider

echo "${cl_cyan}${st_b}▶ Mode 7: Per-script override${st_no_b}${cl_reset}"
echo "${cl_grey}  Command: HOOKS_FLOW_MODE_ci_20_compile=DRY HOOKS_FLOW_MODE=EXEC ./ci-20-compile.sh${cl_reset}"
echo "${cl_yellow}  Note: Script-specific mode (DRY) overrides global (EXEC)${cl_reset}"
divider
HOOKS_FLOW_MODE_ci_20_compile=DRY HOOKS_FLOW_MODE=EXEC "$CI_SCRIPT"
divider

echo "${cl_cyan}${st_b}▶ Mode 8: TEST (mock script)${st_no_b}${cl_reset}"
MOCK_SCRIPT=$(mktemp)
cat >"$MOCK_SCRIPT" <<'EOF'
echo "[mocks] This is a test mock script"
echo "[mocks] Simulating successful build..."
echo "[mocks] Build artifacts: dist/app.js"
__HOOKS_FLOW_EXIT_CODE=0
EOF

echo "${cl_grey}  Command: HOOKS_FLOW_MODE=${MOCK_SCRIPT} ./ci-20-compile.sh${cl_reset}"
divider
HOOKS_FLOW_MODE="$MOCK_SCRIPT" "$CI_SCRIPT"
echo "${cl_green}  Exit code: $?${cl_reset}"

rm -f "$MOCK_SCRIPT"
divider

echo ""
echo "${cl_lblue}${st_b}Demo complete!${st_no_b}${cl_reset}"
echo ""
echo "Key takeaways:"
echo "  ${cl_green}✓${cl_reset} Modes are resolved via middleware contract lines"
echo "  ${cl_green}✓${cl_reset} Exec-mode hooks communicate through stdout/stderr"
echo "  ${cl_green}✓${cl_reset} Middleware applies side effects in the parent shell"
echo ""
