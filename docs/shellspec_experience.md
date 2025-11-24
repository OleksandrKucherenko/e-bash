# ShellSpec Testing Experience Guide

## Overview

This document captures detailed experience and best practices for developing ShellSpec unit tests for e-bash modules, based on real-world implementation of `_dryrun.sh` tests. It serves as a comprehensive guide for future test development.

## Key Learning from _dryrun.sh Implementation

### 1. Module Analysis Phase

#### Required Pre-Analysis Checklist
- [ ] **Dependency Mapping**: Identify all sourced modules (_colors.sh, _logger.sh, etc.)
- [ ] **Global Variables**: Document all exported variables and their default values
- [ ] **Function Generation**: Detect `eval` usage and dynamic function creation
- [ ] **Environment Hierarchy**: Map variable precedence (command-specific > global > default)
- [ ] **Logger Integration**: Identify logger tags and output destinations
- [ ] **Shell Options**: Note any shell option manipulation (-e, +e, etc.)

#### Critical Information to Extract
```bash
# Example for each module:
# 1. Dependencies and load order
# 2. Global variables with defaults
# 3. Function signatures and return codes
# 4. Environment variable patterns
# 5. Logger tags and output formatting
# 6. Error handling strategies
```

### 2. Mock Strategy Development

#### Logger System Mocking Pattern
```bash
# Complete logger mocking template
Mock printf:Exec
    # Capture for output verification
    printf "%s\n" "$@" > "$SHELLSPEC_TMPBASE/exec_output"
End

Mock echo:Exec
    printf "%s\n" "$@" > "$SHELLSPEC_TMPBASE/exec_echo"
End

Mock log:Output
    printf "%s\n" "$@" >> "$SHELLSPEC_TMPBASE/log_output"
End

# Mock all logger tag functions used by module
Mock printf:Dry
Mock echo:Dry
Mock printf:Rollback
Mock echo:Rollback
Mock echo:Loader
```

#### Color Variable Handling
```bash
BeforeAll "unset cl_red cl_green cl_blue cl_purple cl_yellow cl_reset"
BeforeAll "export cl_red='' cl_green='' cl_blue='' cl_purple='' cl_yellow='' cl_reset=''"
```

#### Mock Prioritization
1. **High Priority**: Functions called directly by test code
2. **Medium Priority**: Dependency functions (logger, colors)
3. **Low Priority**: System commands (use actual commands when possible)

### 3. Test Structure Patterns

#### Standard Test File Template
```bash
#!/usr/bin/env bash
# shell: sh altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2317,SC2016

## Copyright info...
eval "$(shellspec - -c) exit 1"

# Module-specific setup
% TEST_DIR: "$SHELLSPEC_TMPBASE/test_data"
export SCRIPT_DIR=".scripts"

# Comprehensive mocks section
Mock ...
End

# Include target module
Include ".scripts/_target_module.sh"

Describe "_target_module.sh"
    # Global setup
    BeforeAll "setup_module_environment"
    BeforeEach "reset_test_environment"
    AfterEach "cleanup_test_artifacts"

    # Test sections organized by functionality
    Describe "Global Variables"
        # Tests for default values and environment behavior
    End

    Describe "Core Functions"
        # Tests for main module functions
    End

    Describe "Generated Functions"
        # Tests for dynamically created functions
    End
End
```

### 4. Dynamic Function Testing

#### Testing eval-Generated Functions
```bash
Describe "Function Generation"
    It "creates wrapper functions with correct behavior"
        # Generate functions
        When call dry-run "echo" "CUSTOM"

        # Verify function existence
        The function "run:echo" should be defined
        The function "dry:echo" should be defined
        The function "rollback:echo" should be defined
    End

    It "respects per-command environment variables"
        BeforeCall "export DRY_RUN_ECHO=true"
        When call run:echo "test"

        # Should not execute, just log
        The function should be called
        The output should include "echo test"
    End
End
```

#### Testing Variable Scoping
```bash
It "handles variable precedence correctly"
    # Set multiple override levels
    BeforeCall "export DRY_RUN=false"
    BeforeCall "export DRY_RUN_ECHO=true"

    When call run:echo "test"

    # Command-specific should override global
    The output should include "echo test"
    The function "echo" should not be called
End
```

### 5. Environment Variable Testing

#### Hierarchical Variable Testing Framework
```bash
test_variable_hierarchy() {
    local cmd="$1"
    local var_prefix="$2"

    # Test 1: Default values
    unset "${var_prefix}_${cmd}" "${var_prefix}"

    # Test 2: Global override
    export "${var_prefix}=true"

    # Test 3: Command-specific override
    export "${var_prefix}_${cmd}=false"

    # Test 4: Cleanup
    unset "${var_prefix}" "${var_prefix}_${cmd}"
}
```

#### Environment Reset Pattern
```bash
BeforeEach "cleanup_environment"
cleanup_environment() {
    # Reset all module variables
    unset DRY_RUN UNDO_RUN SILENT
    unset DRY_RUN_ECHO UNDO_RUN_ECHO SILENT_ECHO
    # ... reset all command-specific variables

    # Reset to defaults
    export DRY_RUN=false UNDO_RUN=false SILENT=false
}
```

### 6. Shell Option Testing

#### Testing errexit Preservation
```bash
It "preserves shell options during execution"
    BeforeCall "set -e"  # Enable errexit

    When call dryrun:exec Exec false echo "test"

    The status should be failure
    # Verify errexit is still enabled after call
    run test "$-" == "*e*"
    The status should be success
End
```

### 7. Error Handling and Edge Cases

#### Command Failure Testing Matrix
```bash
Describe "Command Failure Handling"
    It "handles non-existent commands"
        When call dryrun:exec Exec "nonexistent_command"

        The status should be failure
        The error should include "nonexistent_command"
    End

    It "handles permission denied"
        When call dryrun:exec Exec "/root/protected_file"

        The status should be failure
        The error should include "code:"
    End

    It "preserves output even on failure"
        When call dryrun:exec Exec sh -c "echo 'error output'; exit 1"

        The status should be failure
        The output should include "error output"
    End
End
```

#### Silent Mode Testing
```bash
It "suppresses command output in silent mode"
    BeforeCall "export SILENT=true"

    When call dryrun:exec Exec true echo "loud output"

    The status should be success
    # Command should be logged but output suppressed
    The output should not include "loud output"
End
```

### 8. Cross-Platform Compatibility

#### Platform-Aware Test Design
```bash
# Use commands that work consistently across platforms
test_commands=("echo" "pwd" "date" "true" "false")
# Avoid: GNU-specific tools, macOS-only commands

# Handle output differences
normalize_output() {
    # Remove platform-specific formatting
    sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//'
}
```

### 9. Integration Testing Patterns

#### Module Integration Validation
```bash
It "integrates properly with logger system"
    BeforeCall "export DEBUG=*"

    When call run:echo "test message"

    # Verify logger initialization and usage
    The error should include "execute:"
    The error should include "code:"
End
```

### 10. Performance and Maintenance

#### Test Organization Best Practices
- Group related tests in logical `Describe` blocks
- Use consistent naming conventions
- Implement comprehensive setup/teardown
- Document complex test scenarios with comments

#### Reusable Test Utilities
```bash
# Create helper functions for common patterns
create_mock_command() {
    local cmd_name="$1"
    local exit_code="${2:-0}"
    local output="${3:-test_output}"

    eval "Mock $cmd_name
        echo '$output'
        exit $exit_code
    End"
}

verify_command_execution() {
    local expected_cmd="$1"
    local expected_args="$2"
    local expected_status="${3:-0}"

    The function "printf:Exec" should be called
    The output should include "$expected_cmd $expected_args"
    The status should be "$expected_status"
}
```

## Common Pitfalls and Solutions

### 1. Logger Mocking Issues
**Problem:** Logger functions not properly mocked, causing test failures
**Solution:** Mock all logger tag functions used by the module, including output redirection

### 2. Environment Variable Leakage
**Problem:** Tests interfere with each other through shared environment
**Solution:** Implement comprehensive environment reset in BeforeEach

### 3. Shell Option Conflicts
**Problem:** Test framework options conflict with module behavior
**Solution:** Test both with and without shell options, verify preservation

### 4. Mock Scope Issues
**Problem:** Mocks not available in all test contexts
**Solution:** Define mocks at appropriate scope (BeforeAll vs Describe level)

### 5. Platform-Specific Behavior
**Problem:** Tests pass on one platform, fail on another
**Solution:** Use cross-platform compatible commands and normalize output

## Advanced Testing Techniques

### 1. Test Data Management
```bash
# Create isolated test data
BeforeAll "mkdir -p '$TEST_DIR'"
AfterAll "rm -rf '$TEST_DIR'"

# Use temp files for output capture
local capture_file="$TEST_DIR/capture_$$"
```

### 2. Dynamic Test Generation
```bash
# Generate tests for multiple commands
for cmd in echo pwd date; do
    It "handles $cmd command correctly"
        When call dryrun:exec Exec "$cmd" "test"
        The status should be success
    End
done
```

### 3. Complex Scenario Testing
```bash
It "handles complex multi-variable scenarios"
    BeforeCall "export DRY_RUN=false"
    BeforeCall "export DRY_RUN_ECHO=true"
    BeforeCall "export UNDO_RUN=false"
    BeforeCall "export SILENT_ECHO=true"

    When call run:echo "complex test"

    # Verify expected behavior based on all variables
    The output should include "echo complex test"
    The function "echo" should not be called
End
```

## Quality Assurance Checklist

### Before Committing Tests
- [ ] All tests pass on multiple platforms
- [ ] Mocks are comprehensive and accurate
- [ ] Environment variables properly reset
- [ ] Test coverage is complete (>90% lines)
- [ ] Documentation is clear and helpful
- [ ] No test pollution or leakage
- [ ] Performance is acceptable (tests run quickly)

### Test Coverage Requirements
- [ ] All public functions tested
- [ ] All error conditions covered
- [ ] All environment variable combinations tested
- [ ] All generated function variations tested
- [ ] Integration points validated

## Maintenance Guidelines

### Keeping Tests Current
1. Review tests when modifying source code
2. Update mocks when module dependencies change
3. Add new tests for new functionality
4. Refactor tests for maintainability
5. Regular cross-platform validation

### Test Evolution Strategy
1. Start with basic functionality tests
2. Add edge case and error handling tests
3. Implement integration tests
4. Optimize performance and maintainability
5. Document complex scenarios

This guide serves as a living document, updated with each major testing project to incorporate new learnings and best practices.