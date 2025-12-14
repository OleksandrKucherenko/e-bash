#!/usr/bin/env bash
#
# Generate committed baseline timing artifacts for CI chunking.
#
# Output:
#   - ci/test-timings/<os>/report/*.xml
#   - ci/test-timings/<os>/test-timings.json
#
# This is intended for local/dev use; CI updates baselines via PR using
# .github/workflows/baseline.yaml.

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

detect_os_slug() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    *) echo "linux" ;;
  esac
}

OS_SLUG="$(detect_os_slug)"
OUT_DIR="$PROJECT_ROOT/ci/test-timings/${OS_SLUG}"

cd "$PROJECT_ROOT"

echo "Generating baseline for: ${OS_SLUG}"
rm -rf report coverage || true
rm -rf "$OUT_DIR" || true
mkdir -p "$OUT_DIR/report"

SHELLSPEC_CMD=(shellspec)
if [ "$OS_SLUG" = "linux" ] && command -v kcov >/dev/null 2>&1; then
  SHELLSPEC_CMD=(shellspec --kcov)
fi

echo "Running: ${SHELLSPEC_CMD[*]}"
set -o pipefail
"${SHELLSPEC_CMD[@]}" 2>&1 | tee /tmp/test_output.txt || {
  exit_code=${PIPESTATUS[0]}
  echo "Shellspec exited with code $exit_code, checking if tests actually passed..."

  passed_tests=$(grep -c "^ok " /tmp/test_output.txt || true)
  failed_tests=$(grep -c "^not ok " /tmp/test_output.txt || true)
  has_summary=$(grep -q "examples, .* failures" /tmp/test_output.txt && echo "yes" || echo "no")

  if [ "$passed_tests" -gt 0 ] && [ "$failed_tests" -eq 0 ] && [ "$has_summary" = "yes" ]; then
    echo "✅ All $passed_tests tests passed (0 failures) - ignoring shellspec exit code bug"
  else
    echo "❌ Tests actually failed or incomplete"
    echo "   Passed: $passed_tests, Failed: $failed_tests, Has summary: $has_summary"
    exit 1
  fi
}

mapfile -t XML_FILES < <(find report -type f -name '*.xml' -print | sort)
if [ "${#XML_FILES[@]}" -eq 0 ]; then
  echo "No JUnit XML files found in report/; cannot generate baseline."
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "bun is required to generate timing JSON. Install bun and re-run."
  exit 1
fi

bun "$SCRIPT_DIR/junit/sanitize-junit-xml.ts" "$OUT_DIR/report/baseline.xml" "${XML_FILES[@]}"

bun "$SCRIPT_DIR/junit/parse-test-timings.ts" "$OUT_DIR/test-timings.json" "$OUT_DIR/report/baseline.xml" --granularity=example

echo ""
echo "Baseline updated:"
echo "  - $OUT_DIR/report/"
echo "  - $OUT_DIR/test-timings.json"
echo ""
echo "Next:"
echo "  git status"
echo "  git add ci/test-timings/${OS_SLUG}"
echo "  git commit -m \"new unit tests optimization baseline\""
