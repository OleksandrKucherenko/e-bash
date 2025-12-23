#!/bin/bash
# init_bats_project.sh - Initialize BATS test infrastructure in a project
#
# Usage: ./init_bats_project.sh [target_directory]
#
# Creates:
#   - test/ directory structure
#   - Git submodules for BATS libraries
#   - Common setup helper
#   - Example test file
#   - Makefile targets

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-23
## Version: 1.12.6
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash


set -euo pipefail

TARGET_DIR="${1:-.}"
TEST_DIR="$TARGET_DIR/test"

echo "Initializing BATS test infrastructure in: $TARGET_DIR"

# Check if git repo
if ! git -C "$TARGET_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: $TARGET_DIR is not a git repository"
    echo "Initialize with: git init $TARGET_DIR"
    exit 1
fi

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$TEST_DIR/test_helper"
mkdir -p "$TEST_DIR/unit"
mkdir -p "$TEST_DIR/integration"
mkdir -p "$TEST_DIR/fixtures"

# Add BATS submodules
echo "Adding BATS submodules..."
cd "$TARGET_DIR"

if [ ! -d "test/bats" ]; then
    git submodule add https://github.com/bats-core/bats-core.git test/bats
fi

if [ ! -d "test/test_helper/bats-support" ]; then
    git submodule add https://github.com/bats-core/bats-support.git test/test_helper/bats-support
fi

if [ ! -d "test/test_helper/bats-assert" ]; then
    git submodule add https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert
fi

if [ ! -d "test/test_helper/bats-file" ]; then
    git submodule add https://github.com/bats-core/bats-file.git test/test_helper/bats-file
fi

# Create common setup helper
echo "Creating common setup helper..."
cat > "$TEST_DIR/test_helper/common-setup.bash" << 'EOF'
#!/usr/bin/env bash
# Common setup for all test files

_common_setup() {
    # Load assertion libraries
    load "$BATS_TEST_DIRNAME/test_helper/bats-support/load"
    load "$BATS_TEST_DIRNAME/test_helper/bats-assert/load"
    load "$BATS_TEST_DIRNAME/test_helper/bats-file/load"
    
    # Add source directory to PATH
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export PATH="$PROJECT_ROOT/src:$PATH"
    export PROJECT_ROOT
}

# Helper: Strip ANSI color codes from string
strip_colors() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Helper: Wait for condition with timeout
wait_for() {
    local cmd="$1"
    local timeout="${2:-30}"
    local interval="${3:-1}"
    
    local elapsed=0
    while ! eval "$cmd" 2>/dev/null; do
        sleep "$interval"
        elapsed=$((elapsed + interval))
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
    done
    return 0
}
EOF

# Create example unit test
echo "Creating example unit test..."
cat > "$TEST_DIR/unit/example.bats" << 'EOF'
#!/usr/bin/env bats

# Example unit test file demonstrating BATS patterns

setup() {
    load '../test_helper/common-setup'
    _common_setup
    
    # Test-specific setup
    TEST_TEMP="$BATS_TEST_TMPDIR"
}

teardown() {
    # Cleanup (optional - BATS_TEST_TMPDIR auto-cleaned)
    :
}

# Basic test
@test "example: addition works" {
    result=$((2 + 2))
    [ "$result" -eq 4 ]
}

# Using run and assertions
@test "example: echo command works" {
    run echo "hello world"
    
    assert_success
    assert_output "hello world"
}

# Testing exit codes
@test "example: false returns non-zero" {
    run false
    
    assert_failure
}

# Testing file operations
@test "example: can create files" {
    echo "test content" > "$TEST_TEMP/test.txt"
    
    assert_file_exists "$TEST_TEMP/test.txt"
    assert_file_contains "$TEST_TEMP/test.txt" "test content"
}

# Skip example
@test "example: skipped test" {
    skip "Demonstrate skip functionality"
    
    false  # This won't run
}

# Tagged test example
# bats test_tags=slow,integration
@test "example: tagged test" {
    skip "Remove skip to run this test"
    
    run sleep 1
    assert_success
}
EOF

# Create example integration test
echo "Creating example integration test..."
cat > "$TEST_DIR/integration/example.bats" << 'EOF'
#!/usr/bin/env bats

# Example integration test file

setup_file() {
    # Run once before all tests in this file
    # Good for expensive setup (Docker, databases, etc.)
    export SHARED_FIXTURE="initialized"
}

teardown_file() {
    # Run once after all tests in this file
    unset SHARED_FIXTURE
}

setup() {
    load '../test_helper/common-setup'
    _common_setup
}

# bats test_tags=integration
@test "integration: shared fixture is available" {
    [ "$SHARED_FIXTURE" = "initialized" ]
}

# bats test_tags=integration
@test "integration: can mock external commands" {
    # Create mock
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/curl" << 'MOCK'
#!/bin/bash
echo '{"status":"mocked"}'
MOCK
    chmod +x "$BATS_TEST_TMPDIR/bin/curl"
    
    # Override PATH
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    
    # Test uses mock
    run curl http://example.com
    
    assert_success
    assert_output --partial "mocked"
}
EOF

# Create .gitignore for test artifacts
echo "Creating .gitignore..."
cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# BATS test artifacts
test/reports/
coverage/
EOF

# Create Makefile targets (append if exists)
echo "Adding Makefile targets..."
if [ -f "$TARGET_DIR/Makefile" ]; then
    cat >> "$TARGET_DIR/Makefile" << 'EOF'

# BATS Testing
.PHONY: test test-unit test-integration test-coverage

BATS := ./test/bats/bin/bats

test: test-unit test-integration

test-unit:
	@echo "Running unit tests..."
	$(BATS) --timing test/unit/

test-integration:
	@echo "Running integration tests..."
	$(BATS) --timing test/integration/

test-parallel:
	$(BATS) --timing --jobs $$(nproc) test/

test-ci:
	@mkdir -p test/reports
	$(BATS) --formatter junit --output test/reports test/

test-coverage:
	@mkdir -p coverage
	kcov --include-path=src/ coverage/ $(BATS) test/
	@echo "Report: coverage/index.html"
EOF
else
    cat > "$TARGET_DIR/Makefile" << 'EOF'
# BATS Testing
.PHONY: test test-unit test-integration test-coverage

BATS := ./test/bats/bin/bats

test: test-unit test-integration

test-unit:
	@echo "Running unit tests..."
	$(BATS) --timing test/unit/

test-integration:
	@echo "Running integration tests..."
	$(BATS) --timing test/integration/

test-parallel:
	$(BATS) --timing --jobs $$(nproc) test/

test-ci:
	@mkdir -p test/reports
	$(BATS) --formatter junit --output test/reports test/

test-coverage:
	@mkdir -p coverage
	kcov --include-path=src/ coverage/ $(BATS) test/
	@echo "Report: coverage/index.html"
EOF
fi

echo ""
echo "✅ BATS test infrastructure initialized!"
echo ""
echo "Next steps:"
echo "  1. Initialize submodules: git submodule update --init --recursive"
echo "  2. Run example tests:     ./test/bats/bin/bats test/"
echo "  3. Add your own tests in: test/unit/ and test/integration/"
echo ""
echo "Quick commands:"
echo "  make test           - Run all tests"
echo "  make test-unit      - Run unit tests only"
echo "  make test-parallel  - Run tests in parallel"
echo "  make test-ci        - Generate JUnit reports"
EOF
chmod +x /home/claude/bats-skill/scripts/init_bats_project.sh
