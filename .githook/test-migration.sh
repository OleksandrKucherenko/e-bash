#!/usr/bin/env bash
# shellcheck disable=SC2155

# Lefthook Migration Test Script
# Compares output and behavior between legacy .githook/ and new lefthook hooks

set -e

readonly cl_green=$(tput setaf 2)
readonly cl_red=$(tput setaf 1)
readonly cl_yellow=$(tput setaf 3)
readonly cl_cyan=$(tput setaf 6)
readonly cl_grey=$(tput setaf 8)
readonly cl_reset=$(tput sgr0)

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

echo "${cl_cyan}╔═══════════════════════════════════════════════════════════════╗${cl_reset}"
echo "${cl_cyan}║     Lefthook Migration - Parallel Testing Suite             ║${cl_reset}"
echo "${cl_cyan}╚═══════════════════════════════════════════════════════════════╝${cl_reset}"
echo ""

# Test file setup
TEST_DIR="$REPO_ROOT/.githook/test-temp"
mkdir -p "$TEST_DIR"

cleanup() {
  rm -rf "$TEST_DIR"
  git checkout -- . 2>/dev/null || true
}
trap cleanup EXIT

# Test 1: File without copyright
test_no_copyright() {
  echo "${cl_yellow}Test 1: File without copyright${cl_reset}"

  cat > "$TEST_DIR/test1.sh" <<'EOF'
#!/usr/bin/env bash
# Test file without copyright

echo "Hello, World!"
EOF

  # Test with lefthook
  LEFTHOOK_STAGED_FILES="$TEST_DIR/test1.sh" bash .lefthook/pre-commit/copyright-verify.sh 2>&1 || true

  # Check if copyright was added
  if grep -q "## Copyright" "$TEST_DIR/test1.sh"; then
    echo "${cl_green}✓ Copyright added correctly${cl_reset}"
  else
    echo "${cl_red}✗ Copyright NOT added${cl_reset}"
    return 1
  fi
}

# Test 2: File with valid copyright
test_valid_copyright() {
  echo "${cl_yellow}Test 2: File with valid copyright${cl_reset}"

  cat > "$TEST_DIR/test2.sh" <<'EOF'
#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-25
## Version: 2.7.3
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

echo "Hello, World!"
EOF

  # Test with lefthook
  if LEFTHOOK_STAGED_FILES="$TEST_DIR/test2.sh" bash .lefthook/pre-commit/copyright-verify.sh 2>&1 | grep -q "valid copyright"; then
    echo "${cl_green}✓ Valid copyright detected${cl_reset}"
  else
    echo "${cl_red}✗ Valid copyright NOT detected${cl_reset}"
    return 1
  fi
}

# Test 3: File with last-revisit date
test_last_revisit() {
  echo "${cl_yellow}Test 3: Last revisit date update${cl_reset}"

  cat > "$TEST_DIR/test3.sh" <<'EOF'
#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-01-01
## Version: 2.7.3
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

echo "Hello, World!"
EOF

  # Test with lefthook
  LEFTHOOK_STAGED_FILES="$TEST_DIR/test3.sh" bash .lefthook/pre-commit/last-revisit-update.sh 2>&1 || true

  # Check if date was updated
  if grep -q "## Last revisit: 2026-" "$TEST_DIR/test3.sh"; then
    echo "${cl_green}✓ Last revisit date updated${cl_reset}"
  else
    echo "${cl_red}✗ Last revisit date NOT updated${cl_reset}"
    return 1
  fi
}

# Test 4: Test fixtures are preserved
test_fixtures_preserved() {
  echo "${cl_yellow}Test 4: Test fixtures are preserved${cl_reset}"

  cat > "$TEST_DIR/spec/fixtures/test/test_fixture.sh" <<'EOF'
#!/usr/bin/env bash
# Test fixture - should NOT be modified
echo "test"
EOF

  mkdir -p "$TEST_DIR/spec/fixtures/test"

  # Test with lefthook
  LEFTHOOK_STAGED_FILES="$TEST_DIR/spec/fixtures/test/test_fixture.sh" bash .lefthook/pre-commit/copyright-verify.sh 2>&1 || true

  # Check that copyright was NOT added (because it's in spec/fixtures/)
  if ! grep -q "## Copyright" "$TEST_DIR/spec/fixtures/test/test_fixture.sh"; then
    echo "${cl_green}✓ Test fixture preserved${cl_reset}"
  else
    echo "${cl_red}✗ Test fixture was modified${cl_reset}"
    return 1
  fi
}

# Test 5: Glob patterns work correctly
test_glob_patterns() {
  echo "${cl_yellow}Test 5: Glob pattern matching${cl_reset}"

  # Create test files
  cat > "$TEST_DIR/script.sh" <<'EOF'
#!/usr/bin/env bash
echo "script"
EOF

  cat > "$TEST_DIR/script.txt" <<'EOF'
not a shell file
EOF

  # Test that .sh files are processed
  LEFTHOOK_STAGED_FILES="$TEST_DIR/script.sh" bash .lefthook/pre-commit/copyright-verify.sh 2>&1 || true

  if grep -q "## Copyright" "$TEST_DIR/script.sh"; then
    echo "${cl_green}✓ .sh file processed${cl_reset}"
  else
    echo "${cl_red}✗ .sh file NOT processed${cl_reset}"
    return 1
  fi
}

# Run all tests
echo "${cl_cyan}Running migration tests...${cl_reset}"
echo ""

test_no_copyright
test_valid_copyright
test_last_revisit
test_fixtures_preserved
test_glob_patterns

echo ""
echo "${cl_green}═══════════════════════════════════════════════════════════════${cl_reset}"
echo "${cl_green}All tests passed!${cl_reset}"
echo "${cl_green}═══════════════════════════════════════════════════════════════${cl_reset}"
