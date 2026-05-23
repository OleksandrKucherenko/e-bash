#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-05-23
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

# =============================================================================
# Demo: logs.sh - capture logs from multiple services at once
# =============================================================================
# Spins up three fake "services" that emit a mix of plain text, JSON and
# ERROR/WARN lines, captures them in parallel for a few seconds, and then shows
# the files left on disk. Bounded by `timeout`, so it always exits cleanly.
#
# Usage:
#   ./demo.logs.capture.sh         # run the capture demo (default)
#   ./demo.logs.capture.sh --help  # show this help
# =============================================================================

# Bootstrap: 1) E_BASH discovery (only if not set), 2) gnubin setup (always)
[ "$E_BASH" ] || {
  _src=${BASH_SOURCE:-$0}
  E_BASH=$(cd "${_src%/*}/../.scripts" 2>&- && pwd || echo ~/.e-bash/.scripts)
  readonly E_BASH
}
. "$E_BASH/_gnu.sh"
PATH="$(cd "$E_BASH/../bin/gnubin" 2>&- && pwd):$PATH"

# shellcheck disable=SC1090 source=../.scripts/_colors.sh
source "$E_BASH/_colors.sh"

readonly LOGS="$(cd "$E_BASH/../bin" && pwd)/logs.sh"
readonly RUN_BASE="$(mktemp -d)/.logs"
readonly DURATION=4

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Demo of bin/logs.sh capture. Runs three fake services for ${DURATION}s and"
  echo "shows the captured files. Usage: ./demo.logs.capture.sh [--help]"
  exit 0
fi

# Three fake services with distinct output shapes (plain text, JSON, warnings).
svc_web='i=0; while :; do i=$((i+1)); echo "GET /page/$i -> 200 (12ms)"; [ $((i % 4)) -eq 0 ] && echo "ERROR upstream returned 502"; sleep 0.5; done'
svc_api='i=0; while :; do i=$((i+1)); printf "{\"svc\":\"api\",\"req\":%d,\"level\":\"info\",\"ms\":%d}\n" "$i" $((10 + i)); [ $((i % 5)) -eq 0 ] && printf "{\"level\":\"error\",\"msg\":\"db pool exhausted\"}\n"; sleep 0.6; done'
svc_db='echo "connection established"; while :; do echo "WARN slow query (1200ms)"; sleep 1.1; echo "vacuum complete"; sleep 1.1; done'

echo "${cl_cyan}${st_b}=== e-bash logs.sh capture demo ===${st_no_b}${cl_reset}"
echo
echo "Capturing three services for ${cl_yellow}${DURATION}s${cl_reset} into ${cl_yellow}${RUN_BASE}${cl_reset}"
echo "Live joined view below (tag-colored, ERROR/WARN highlighted, JSON formatted):"
echo

# Bounded live capture; timeout sends SIGTERM and the tool's trap kills the services.
timeout "$DURATION" "$LOGS" capture --out "$RUN_BASE" \
  --service "web=bash -c '$svc_web'" \
  --service "api=bash -c '$svc_api'" \
  --service "db=bash -c '$svc_db'" || true

run="$(readlink -f "$RUN_BASE/latest" 2>/dev/null || true)"
echo
echo "${cl_cyan}${st_b}=== files left on disk ===${st_no_b}${cl_reset}"
echo "Run directory: ${cl_yellow}${run}${cl_reset}"
echo
echo "${cl_green}Per-service file (raw, uncolored) - api.log:${cl_reset}"
head -6 "$run/api.log" 2>/dev/null | sed 's/^/  /'
echo
echo "${cl_green}Consolidated, tag-prefixed - all.log (last 8 lines):${cl_reset}"
tail -8 "$run/all.log" 2>/dev/null | sed 's/^/  /'
echo
echo "${cl_cyan}${st_b}=== try the search mode (needs fzf) ===${st_no_b}${cl_reset}"
echo "  ${LOGS} search --base '${RUN_BASE}'"
echo "  ${LOGS} search --base '${RUN_BASE}' --tag api      # only the api service"
echo "  ${LOGS} search --base '${RUN_BASE}' --grep error   # seed the query"
