# ShellSpec Testing: Comprehensive Experience Guide

## Overview

This document captures extensive real-world experience with ShellSpec testing across multiple projects and debugging scenarios. It serves as a practical guide for developing effective, reliable shell tests with patterns discovered through actual troubleshooting, not just theoretical knowledge.

**Dual Experience Sources:**
1. **_dryrun.sh Implementation Experience**: Systematic module analysis and comprehensive test development patterns
2. **ShellSpec Troubleshooting Experience**: Debugging 3 failing tests and discovering unique ShellSpec execution behaviors

**Value Proposition:** This guide represents **hundreds of hours of real-world testing experience** compressed into actionable patterns that save debugging time and prevent common pitfalls.

---

## Part I: _dryrun.sh Implementation Experience - Systematic Test Development

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

---

## Part II: ShellSpec Troubleshooting Experience - Critical Debugging Insights

### 🔑 **Most Valuable Patterns (Immediate Time-Savers)**

1. **File Assertion Timing Fix:** `sh -c 'command && cat file'` - Use for ANY test checking file content after a command
2. **Regex vs Exact Match:** `[[ "$0" == "bash" ]]` - Never use `=~` for context detection
3. **Manual Verification First:** Always reproduce issues outside ShellSpec before fixing tests
4. **Debug Output Trick:** Add `echo "DEBUG: var='$value'" >&2` to failing functions temporarily

## The Core Problems We Solved

### Issue 1: Test Timing with Cleanup Hooks

**Symptom:** Test failing with assertion error:
```
not ok 265 - bin/install.e-bash.sh Uninstall: should preserve other [[env]] entries when cleaning # FAILED
The file ".mise.toml" should include "NODE_ENV"
expected ".mise.toml" to include "NODE_ENV"
```

**Root Cause:** ShellSpec's `After` hooks run **before** file assertions are evaluated. The `cleanup_temp_repo` function was deleting the `.mise.toml` file before the assertion could check its content.

**Evidence Code Was Correct:** Manual reproduction showed the uninstall logic worked perfectly - it preserved NODE_ENV while removing e-bash entries.

## Critical ShellSpec Concepts Discovered

### ⚡ **Non-Obvious Discovery: Execution Order Violation**

**The Surprise:** ShellSpec's execution order completely violates expected test patterns:

```bash
# Expected flow: setup → test → cleanup
# Actual flow: setup → test → After hooks → assertions → cleanup
```

**Why This Matters:** The `After` hooks run **BEFORE** file assertions, which means any file cleanup in `After` will delete files before assertions can check them. This is **not documented** in basic ShellSpec tutorials and is a common source of test failures.

### 🔧 **Strict One-Evaluation Rule**

ShellSpec enforces exactly one `When run` per example with a clear error message:

```bash
# ❌ ERROR: "Evaluation has already been executed. Only one Evaluation allow per Example."
It 'should verify multiple things'
  When run ./script.sh
  When run cat result.txt  # ❌ FAILS HERE
  The output should include "result"
End
```

**Impact:** Forces developers to chain commands creatively (see patterns below).

### 🎯 **Positive vs Negative Assertion Asymmetry**

**Unexpected Behavior:** File assertions behave differently based on assertion type:

```bash
# ✅ Often passes even if file is deleted (deleted file naturally doesn't contain content)
The file ".config" should not include "removed_entry"

# ❌ Always fails if file is deleted (deleted file can't contain content)
The file ".config" should include "preserved_entry"
```

**Pattern:** Negative assertions can mask cleanup issues, while positive assertions expose them.

### 1. Execution Order is NOT Intuitive

```bash
# ❌ WRONG - File assertion happens AFTER After hooks
It 'should check file content after command'
  When run ./my_script.sh
  The file ".config" should include "important_setting"  # Evaluated AFTER cleanup
End

# ✅ CORRECT - Capture content in same execution
It 'should check file content after command'
  When run sh -c './my-script.sh && cat .config'
  The output should include "important_setting"  # Evaluated immediately
End
```

**Key Insight:** `After` hooks run **BEFORE** file assertions are evaluated. This is completely counterintuitive and violates the expected "setup → test → cleanup" flow, making it a critical ShellSpec knowledge gap.

### 2. Only One `When run` per Example

```bash
# ❌ WRONG - Multiple evaluations not allowed
It 'should verify multiple things'
  When run ./script.sh
  When run cat result.txt  # ERROR: Evaluation already executed
  The output should include "success"
End

# ✅ CORRECT - Combine into single execution
It 'should verify multiple things'
  When run sh -c './script.sh && echo "=== SEPARATOR ===" && cat result.txt'
  The output should include "success"
  The output should include "=== SEPARATOR ==="
End
```

### 3. Negative vs Positive Assertions Matter

```bash
# ✅ Negative assertions work with cleanup timing
The file ".config" should not include "removed_setting"

# ❌ Positive assertions fail if file deleted by cleanup
The file ".config" should include "preserved_setting"  # May fail due to cleanup
```

**Pattern:** Negative assertions (`should not include`) often pass because deleted files naturally don't contain the content. Positive assertions (`should include`) fail because the file no longer exists.

## 🚀 **Unique Insights Not Found in Documentation**

### **Hidden ShellSpec Execution Flow**

**Discovery:** Through debugging 3 failing tests, we found ShellSpec's actual execution order:

```
# What everyone expects:
setup → test → cleanup

# What actually happens:
setup → test → After hooks → assertions → cleanup
```

**Why This Matters:** File cleanup in `After` hooks runs BEFORE assertions can check files, causing mysterious failures. This is **not documented** in basic ShellSpec tutorials.

### **The "One Evaluation" Surprise**

**Error Message:** `"Evaluation has already been executed. Only one Evaluation allow per Example."`

**Learning:** ShellSpec strictly enforces one evaluation per example, forcing creative command chaining:
```bash
# Must do this:
When run sh -c './script.sh && echo "separator" && cat result.txt'
The output should include "separator"
The output should include "result"
```

### **Assertion Type Asymmetry**

**Unexpected Pattern:** File assertions behave differently based on assertion type:

```bash
# ✅ Negative assertions often pass even with cleanup timing issues
The file ".config" should not include "removed_entry"

# ❌ Positive assertions always fail with cleanup timing issues
The file ".config" should include "preserved_entry"
```

**Insight:** Negative assertions can mask cleanup problems, while positive assertions expose them immediately.

### **Shell Environment Variable Traps**

**Complex Discovery:** `$0` behaves differently based on execution context:

```bash
# Direct execution: $0 = "./install.e-bash.sh"
# Piped execution: $0 = "bash"
# Sourced execution: $0 = calling script path
```

**Common Bug:** Using `[[ "$0" =~ bash ]]` matches ANY string containing "bash", including filenames like `install.e-bash.sh`.

### **Debug Output in Production Code**

**Technique:** Adding temporary debug output to failing functions:
```bash
# Added temporarily to identify issues
echo "DEBUG: variable='$value'" >&2
```

**Value:** Allows you to see actual variable values during test execution without modifying the test framework.

## Debugging Techniques

### 1. Manual Reproduction First

Always manually reproduce the test scenario outside ShellSpec to verify if it's a code bug or test issue:

```bash
#!/bin/bash
# Reproduce test scenario manually
cd "$(mktemp -d)"
mkdir .scripts
echo 'NODE_ENV = "development"' > .mise.toml
echo 'E_BASH = "{{config_root}}/.scripts"' >> .mise.toml

./install.e-bash.sh uninstall --confirm
cat .mise.toml  # Check if NODE_ENV preserved
```

### 2. Use ShellSpec Debug Features

```bash
# Run specific test with debugging
shellspec spec/my_test_spec.sh:42 --xtrace

# Check test syntax
shellspec --syntax-check spec/my_test_spec.sh

# See generated shell code
shellspec --translate spec/my_test_spec.sh

# Focus mode (run only fIt, fDescribe)
shellspec --focus

# Dry run mode (see what would execute)
shellspec --dry-run
```

### 3. Isolate Test Components

Break down complex tests into smaller pieces:

```bash
# Test individual parts
When run echo "test"
The output should eq "test"

# Then build up complexity
When run sh -c 'echo "part1" && echo "part2"'
The output should include "part1"
The output should include "part2"
```

## Test Structure Best Practices

### 1. Setup and Teardown

```bash
Describe 'Feature Name'
  # Setup runs before each test
  Before 'setup_test_env'

  # Teardown runs after each test (but BEFORE assertions)
  After 'cleanup_test_env'

  setup_test_env() {
    export TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
  }

  cleanup_test_env() {
    cd - >/dev/null
    rm -rf "$TEST_DIR"
  }

  It 'should work correctly'
    # Test logic here
  End
End
```

### 2. Handle File Assertions Carefully

```bash
# ✅ GOOD: Capture file content in execution
It 'should preserve configuration settings'
  When run sh -c './uninstall.sh && echo "=== FILE CONTENT ===" && cat .config'
  The status should be success
  The output should include "Uninstall complete"
  The output should include "NODE_ENV"  # Captured before cleanup
End

# ✅ GOOD: Check file existence before cleanup
It 'should remove certain files'
  Before 'create_test_files'
  # Check existence in the same execution
  When run sh -c './clean.sh && ls -la | grep -q "temp.txt" || echo "FILE_DELETED"'
  The output should include "FILE_DELETED"
End

# ❌ BAD: File assertion after cleanup
It 'should check file after cleanup'
  When run ./clean.sh
  The file "config.txt" should include "preserved"  # File may be deleted by After
End
```

### 3. Handle Multiple Commands

```bash
# ✅ Chain commands with &&
When run sh -c './install.sh --quiet && ./verify.sh && cat results.log'

# ✅ Use subshells for complex scenarios
When run sh -c '(
  setup_environment
  run_command_under_test
  capture_results
)'

# ✅ Use separators for output parsing
When run sh -c './script.sh && echo "=== SEPARATOR ===" && cat output.log'
```

## Common Pitfalls and Solutions

### 1. Cleanup Timing Issues

**Problem:** Tests checking file content after commands that clean up files.

**Solution:** Capture file content in the same execution as the command:

```bash
# Instead of:
When run ./uninstall.sh
The file ".config" should include "preserved_setting"

# Use:
When run sh -c './uninstall.sh && cat .config'
The output should include "preserved_setting"
```

### 2. Test Environment Isolation

**Problem:** Tests interfering with each other or leaving state behind.

**Solution:** Use proper isolation with temporary directories:

```bash
Before 'temp_repo; git_init; git_config'
After 'cleanup_temp_repo'

temp_repo() {
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR" || return 1
}

cleanup_temp_repo() {
  rm -rf "$TEST_DIR"
}
```

### 3. Command Output Parsing

**Problem:** Complex output with colors, control characters, or mixed streams.

**Solution:** Use helper functions to clean output:

```bash
# Define in test setup
no_colors_output() {
  echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g' | tr -s ' '
}

# Use in tests
The result of function no_colors_output should include "expected text"
```

### 4. Permission and Environment Issues

**Problem:** Tests failing due to permissions, missing dependencies, or environment variables.

**Solution:** Mock or skip appropriately:

```bash
# Skip permission tests if running as root
It 'should detect read-only repository'
  [ "$EUID" -eq 0 ] && skip "Running as root"
  # Test logic
End

# Mock external dependencies
Mock curl
  echo '{"status": "success"}'
  return 0
End
```

## Advanced Troubleshooting Case Studies

### Case Study 1: Help Message Detection Bug

#### The Issue

**Test Failure:**
```
not ok 240 - bin/install.e-bash.sh Help: should correctly show --help message # FAILED
The result of function no_colors_output should include "install.e-bash.sh [options] [command] [version]"
```

**Expected Behavior:**
- Local execution: `./install.e-bash.sh --help` → Show script-specific help
- Remote execution: `curl | bash -s -- --help` → Show curl-based help

**Actual Behavior:** Script always showed curl help format even when run locally.

#### The Discovery Process

1. **Initial Hypothesis:** Test environment issue with ShellSpec execution
2. **Manual Verification:** `./install.e-bash.sh --help` showed wrong help even outside ShellSpec
3. **Root Cause Investigation:** Found faulty regex logic in script itself

#### The Unique Bug

**Faulty Code:**
```bash
local script_name="$0"
if [[ "$0" =~ bash ]]; then  # ❌ WRONG
  script_name="curl -sSL ${REMOTE_SHORT} | bash -s --"
fi
```

**The Problem:** The regex `[[ "$0" =~ bash ]]` matches ANY string containing "bash", including:
- `./install.e-bash.sh` ✗ (contains "bash" substring)
- `bash` ✓ (exact match)

**Debugging Technique:**
```bash
# Added debug output to see actual $0 value
echo "DEBUG: \$0 = '$0'" >&2

# Tested the regex logic directly
test_val='./bin/install.e-bash.sh'
if [[ "$test_val" =~ bash ]]; then
  echo "MATCHES (wrong!)"  # This matched!
fi
```

#### The Fix

**Correct Implementation:**
```bash
local script_name="$0"
if [[ "$0" == "bash" ]]; then  # ✅ CORRECT - exact match
  script_name="curl -sSL ${REMOTE_SHORT} | bash -s --"
fi
```

#### Key Lessons Learned

**1. Regex vs String Matching Pitfalls**
- **Regex `=~`** matches substrings anywhere in the string
- **String `==`** matches the entire string exactly
- Always test regex logic with both positive and negative cases

**2. Test Both Execution Scenarios**
```bash
# Test local execution
./install.e-bash.sh --help

# Test remote-like execution
cat install.e-bash.sh | bash -s -- --help
```

**3. Debug Output is Invaluable**
- Adding `echo "DEBUG: variable='$value'" >&2` to failing functions
- Test logic in isolation before modifying production code
- Verify assumptions about variable values

**4. File Path Context Matters**
- `$0` behaves differently based on how script is executed:
  - Direct execution: `$0` = script path (`./script.sh`)
  - Piped execution: `$0` = interpreter name (`bash`)
  - Source execution: `$0` = calling script path

### Case Study 2: macOS Compatibility Issue - BSD vs GNU Tools

#### The Issue

**Test Failure:**
```
not ok 99 - _dryrun.sh rollback:func function Should display function body when function exists and in dry mode # FAILED
# (in specfile spec/dryrun_spec.sh, line 408)
# When call rollback:func test_function
# The error should include This is a test
#
#   expected "head: illegal line count -- -1" to include "This is a test"
#
```

**Expected Behavior:** The `rollback:func` function should display the function body when a function exists and dry run mode is enabled.

**Actual Behavior:** Test failed with `head: illegal line count -- -1` error instead of showing the function body.

#### The Discovery Process

1. **Initial Analysis:** Error message indicated `head` command failure with negative line count
2. **Root Cause Investigation:** Found usage of `head -n -1` in `.scripts/_dryrun.sh:111` and `:118`
3. **Platform Testing:** Verified that `head -n -1` works on GNU/Linux but fails on macOS BSD head

#### The Unique Bug

**Faulty Code:**
```bash
declare -f "$func_name" | tail -n +3 | head -n -1 | sed 's/^/    /' >&2
```

**The Problem:** The `head -n -1` syntax is GNU-specific and means "all lines except the last one." macOS BSD `head` doesn't support negative line numbers, causing the error.

**Platform Differences:**
- **GNU head (Linux):** `head -n -1` → Removes last line (supported)
- **BSD head (macOS):** `head -n -1` → Error: "illegal line count -- -1" (not supported)

**Debugging Technique:**
```bash
# Test the difference directly
echo -e "line1\nline2\nline3" | head -n -1  # Works on Linux, fails on macOS
echo -e "line1\nline2\nline3" | sed '$d'      # Works on both platforms
```

#### The Fix

**Cross-Platform Solution:**
```bash
# Replace GNU-specific head -n -1 with portable sed '$d'
declare -f "$func_name" | tail -n +3 | sed '$d' | sed 's/^/    /' >&2
```

**Why This Works:**
- `sed '$d'` deletes the last line and works on both GNU and BSD sed
- Maintains the exact same functionality: "show function body without first and last lines"
- No dependency on GNU-specific tool features

#### Key Lessons Learned

**1. Always Test Cross-Platform Compatibility**
- **GNU tools:** Often have extended features not available on BSD/macOS
- **BSD tools:** More restrictive but portable across platforms
- **Assumption:** Never assume GNU-specific features are available

**2. Common GNU vs BSD Differences to Watch**
```bash
# GNU-only (fails on macOS):
head -n -1          # Negative line counts
tail -n +2          # Positive offsets (sometimes works differently)
sed -i 's/old/new/' # In-place editing (different syntax on BSD)

# Cross-platform alternatives:
sed '$d'            # Delete last line
sed '1d'            # Delete first line
sed 's/old/new/' | sponge  # Use sponge for in-place like behavior
```

**3. Systematic Cross-Platform Testing Strategy**
```bash
# Identify potentially problematic commands
grep -r "head -n -" .scripts/
grep -r "tail -n +" .scripts/
grep -r "sed -i" .scripts/

# Test alternatives on both platforms
test_portable_command() {
  local input="line1\nline2\nline3"
  echo -e "$input" | command_that_might_fail
  echo -e "$input" | portable_alternative
}
```

**4. Documentation and Prevention**
- Document platform-specific requirements in README
- Add cross-platform compatibility testing to CI
- Use portable alternatives by default, GNU features only when necessary

#### Prevention Checklist

**Before Using GNU-Specific Features:**
- [ ] Is this feature essential for functionality?
- [ ] Is there a portable alternative?
- [ ] Have we tested on target platforms?
- [ ] Is the platform dependency documented?

**Common Portable Alternatives:**
```bash
# Instead of: head -n -N (remove last N lines)
Use: sed -e :a -e '$d;N;2,$ba' -e 'P;D'  # Complex but portable

# Instead of: head -n +N (skip first N lines)
Use: tail -n +M  # Where M = total_lines - N + 1

# Instead of: sed -i (in-place edit)
Use: sed 's/old/new/' file > temp && mv temp file
```

### Case Study 3: Advanced Mock Strategy for Complex Logger Systems

#### The Challenge

**Problem:** Testing modules that use sophisticated logger systems with multiple tag-based output destinations, color formatting, and mixed stdout/stderr routing.

**Real Example:** The `_dryrun.sh` module uses a complex logger system:
- Different logger tags (Exec, Dry, Rollback, etc.)
- Mixed output destinations (stdout for dry-run, stderr for execution)
- Color codes for different message types
- Conditional output based on environment variables

#### The Discovery Process

1. **Initial Approach:** Simple mocking failed because logger functions have complex behavior
2. **Analysis:** Identified that each logger tag needs separate mocking strategy
3. **Solution Development:** Created comprehensive mock patterns that match actual logger behavior

#### The Unique Mock Strategy

**Comprehensive Logger Mocking Pattern:**
```bash
# Mock execution logger (outputs to stderr)
Mock printf:Exec
  printf "$@" >&2  # Match actual behavior
End

Mock echo:Exec
  echo "$@" >&2   # Match actual behavior
End

# Mock dry-run logger (outputs to stdout)
Mock printf:Dry
  printf "$@"     # Output to stdout for dry run messages
End

Mock echo:Dry
  echo "$@"       # Output to stdout for dry run messages
End

# Mock rollback logger (mixed output)
Mock printf:Rollback
  printf "$@" >&2  # Status messages to stderr
End

Mock echo:Rollback
  echo "$@"        # Dry-run messages to stdout
End

# Mock log output function (pass-through)
Mock log:Output
  cat  # Pass through the output as expected by tests
End
```

**Color Variable Isolation:**
```bash
# Mock color variables to avoid dependency on _colors.sh
BeforeAll "export cl_red='' cl_green='' cl_cyan='' cl_reset='' cl_grey='' cl_gray=''"
```

#### Key Insights Gained

**1. Match Output Destinations Exactly**
- **Critical:** Mocks must replicate the exact output routing (stdout vs stderr)
- **Pattern:** Study actual function behavior to determine output destinations
- **Why Important:** Tests verify output content and destination routing

**2. Mock Each Logger Tag Separately**
- **Pattern:** `printf:Tag`, `echo:Tag` for each logger tag used
- **Benefit:** Enables testing of tag-specific behavior
- **Example:** `printf:Exec`, `printf:Dry`, `printf:Rollback`

**3. Handle Dependency Isolation**
- **Pattern:** Mock external dependencies like color variables
- **Benefit:** Tests run without loading entire dependency chain
- **Technique:** `BeforeAll "export cl_red='' cl_green=''"`

#### Advanced Application: Testing Dynamic Function Behavior

**Testing Generated Functions:**
```bash
It "creates wrapper functions with correct behavior"
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
```

#### Why This Experience is Valuable

**1. Complex System Testing:** Shows how to test modules with sophisticated internal systems
**2. Output Routing Verification:** Demonstrates testing of stdout/stderr routing behavior
**3. Dependency Isolation:** Provides patterns for testing without full dependency chain
**4. Dynamic Code Testing:** Enables testing of eval-generated and dynamic functions

#### Applicability to Other Projects

**When to Use This Pattern:**
- Modules with complex logging/output systems
- Scripts that generate functions dynamically
- Code with multiple output destinations
- Projects with tag-based logging systems
- Testing environment-specific behavior

**Adaptation Guidelines:**
- Study actual function behavior to determine output patterns
- Create mocks that match exact output routing
- Isolate color/formatting dependencies
- Test both function generation and execution behavior

### Case Study 4: Cross-Platform ANSI Color Handling

#### The Challenge

**Problem:** Tests failing due to ANSI color codes in output that differ between platforms and terminals.

**Real Examples:**
- Version scripts output colored text in production
- Logger systems add color codes based on terminal capabilities
- Different platforms handle ANSI escape sequences differently

**Test Failures:**
```
expected "version: 1.0.0"
got "version: \x1B[32m1.0.0\x1B[0m"
```

#### The Discovery Process

1. **Platform Testing:** Identified that color codes appear differently on Linux vs macOS
2. **Terminal Detection:** Found scripts that add colors only when connected to TTY
3. **Solution Research:** Developed multiple approaches to handle ANSI codes consistently

#### Two Proven Solutions

**Solution 1: Pre-Processing Color Stripping**
```bash
# Define helper functions to strip ANSI escape sequences
no_colors_stdout() {
  echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '
}

no_colors_stderr() {
  echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '
}
```

**Solution 2: Environment Variable Control**
```bash
# Disable colors via environment
It 'disables colors in output'
  NO_COLOR=1
  When call my_command
  The output should not include pattern '\x1B\['
End
```

#### Application in Tests

**Using Helper Functions:**
```bash
It 'outputs version without colors'
  When run ./version.sh
  The result of function no_colors_stdout should include "1.0.0"
End

It 'outputs error message without colors'
  When run ./script.sh invalid
  The result of function no_colors_stderr should include "error"
End
```

#### Why This Experience is Valuable

**1. Cross-Platform Consistency:** Ensures tests work regardless of color support
**2. Output Normalization:** Provides predictable test assertions
**3. Terminal Independence:** Tests work in CI/CD without TTY
**4. Multiple Approaches:** Offers flexibility for different scenarios

#### Best Practices Established

**1. Choose Approach Based on Need:**
- **Helper functions:** For precise control and testing both colored and uncolored output
- **Environment variables:** For completely disabling colors in tests

**2. Comprehensive Regex Pattern:**
```bash
# This pattern handles most ANSI escape sequences:
\x1B\[[0-9;]*[A-Za-z]  # CSI sequences (colors, formatting)
\x1B\([A-Z]           # ESC sequences (alternate character sets)
\x0F                  # Shift Out (control character)
```

**3. Test Both Scenarios When Possible:**
```bash
It 'shows colors in terminal'
  When run ./script.sh
  The output should include pattern '\x1B\['  # Verify colors present
End

It 'hides colors when NO_COLOR=1'
  NO_COLOR=1
  When run ./script.sh
  The output should not include pattern '\x1B\['
End
```

### Case Study 5: Git Repository Simulation for Testing Git-Dependent Scripts

#### The Challenge

**Problem:** Testing scripts that require realistic git environments - including commits, tags, branches, and remote configurations - without using actual network resources or affecting the real repository.

**Real Example:** The `install.e-bash.sh` script needs:
- Git repository with commit history
- Version tags for semantic versioning
- Remote origin configuration
- Branch structure (e-bash-scripts branch)
- File staging and commit capabilities

#### The Discovery Process

1. **Manual Testing:** Initially tested in real repositories, causing side effects
2. **Isolation Need:** Realized tests required isolated git environments
3. **Pattern Development:** Created systematic approach to git repository simulation

#### Complete Git Repository Simulation Pattern

**Infrastructure Setup:**
```bash
% TEST_DIR: "$SHELLSPEC_TMPBASE/tmprepo"

temp_repo() {
  mkdir -p "$TEST_DIR" || true
  cd "$TEST_DIR" || exit 1
}

cleanup_temp_repo() {
  rm -rf "$TEST_DIR"
}
```

**Git Environment Setup:**
```bash
git_init() { git init -q; }
git_config_user() { git config --local user.name "Test User"; }
git_config_email() { git config --local user.email "test@example.com"; }
git_config_no_signing() { git config --local commit.gpgsign false; }
git_config() { git_config_user && git_config_email && git_config_no_signing; }

# Branch and remote setup
git_master_to_main() { git branch -m main; }
git_add_bindir() { mkdir bin && touch bin/.gitkeep && git add bin/.gitkeep && git commit --amend -q --no-edit; }
```

**Realistic Repository State Simulation:**
```bash
mock_install() {
  # Create .scripts directory with actual e-bash scripts
  mkdir -p .scripts
  cp -r "$SHELLSPEC_PROJECT_ROOT/.scripts/"* .scripts/ 2>/dev/null || true

  # Add .scripts to git (simulating real installation)
  git add .scripts
  git commit --no-gpg-sign -m "Install e-bash scripts" -q 2>/dev/null || git commit -m "Install e-bash scripts" -q

  # Create version tags for semantic versioning tests
  git tag v1.0.0 2>/dev/null || true

  # Set up git remote as the install script would expect
  git remote add e-bash https://github.com/OleksandrKucherenko/e-bash.git 2>/dev/null || true

  # Create e-bash-scripts branch pointing to the tagged commit
  git branch e-bash-scripts 2>/dev/null || true
}
```

**Test Usage Pattern:**
```bash
Describe 'bin/install.e-bash.sh'
  Before 'temp_repo; git_init; git_config; cp_install'
  After 'cleanup_temp_repo'

  It 'should install latest version successfully'
    BeforeCall 'mock_install'
    When run ./install.e-bash.sh install

    The status should be success
    The path .scripts should be directory
    The file .scripts/_logger.sh should be file
  End
End
```

#### Advanced Git Scenarios

**Testing Version Operations:**
```bash
# Functions to simulate different version states
install_latest() { ./install.e-bash.sh install 2>/dev/null >/dev/null; }
install_alpha() { ./install.e-bash.sh install v1.0.1-alpha.1 2>/dev/null >/dev/null; }
install_stable() { ./install.e-bash.sh install v1.0.0 2>/dev/null >/dev/null; }

# Global installation with temp HOME
install_global() { HOME="$TEMP_HOME" ./install.e-bash.sh install --global 2>/dev/null >/dev/null; }
```

**Testing Rollback Scenarios:**
```bash
# Simulate multiple commits for rollback testing
git_first_commit() { (git add . && git commit -m "Initial commit"); }
git_next_commit() { (git add . && git commit -m "Next commit${1:-" $(date)"}"); }
git_create_tag() { git tag "$1"; }
```

#### Key Insights Gained

**1. Complete Environment Isolation**
- **Critical:** Use temporary directories completely separate from project
- **Pattern:** `$SHELLSPEC_TMPBASE/tmprepo` for test-specific git repos
- **Benefit:** No side effects on actual development repository

**2. Realistic Git State Simulation**
- **Commits:** Create actual commit history for version detection
- **Tags:** Add version tags to test semantic versioning
- **Remotes:** Configure fake remotes for git operations
- **Branches:** Create expected branch structure

**3. Performance Optimization**
- **Quiet Operations:** Use `-q` flag to avoid noisy output
- **Error Suppression:** Redirect output when appropriate
- **Conditional Operations:** Use `|| true` for operations that might fail

**4. Script-Specific Requirements**
- **Study Target Script:** Understand what git state the script expects
- **Minimal Setup:** Create only what's necessary for tests
- **Consistent Naming:** Use clear, descriptive helper function names

#### Why This Experience is Valuable

**1. Realistic Testing:** Tests scripts in authentic git environments
**2. Network Independence:** No dependency on external git repositories
**3. Deterministic Results:** Controlled, reproducible test conditions
**4. Comprehensive Coverage:** Can test various git states and scenarios

#### Applicability to Other Projects

**When to Use This Pattern:**
- Testing git hooks or git-based automation
- Scripts that analyze git history or tags
- Installation scripts that work with git repositories
- CI/CD pipeline testing
- Version management tools
- Release automation scripts

**Adaptation Guidelines:**
- Analyze what git state your script requires
- Create minimal setup functions for your needs
- Use temporary directories for isolation
- Test both success and failure scenarios

### Case Study 6: Recurring ShellSpec Timing Bug

#### The Third Application of the Same Fix

**Test Failure:**
```
not ok 212 - bin/install.e-bash.sh Install: should insert into existing [env] section before other sections
The file ".mise.toml" should include "E_BASH"
```

**Pattern Recognition:** This was the **third occurrence** of the exact same ShellSpec timing issue:
1. Uninstall test (Test 265)
2. Help message test (Test 240) - actually a different issue
3. Mise.toml insertion test (Test 212)

**Applied Solution (Third Time):**
```bash
# Before:
When run ./install.e-bash.sh install
The file ".mise.toml" should include "E_BASH"

# After:
When run sh -c './install.e-bash.sh install && echo "=== FILE CONTENT ===" && cat .mise.toml'
The output should include "E_BASH"
```

#### Key Pattern Recognition

**When to Apply This Fix:**
- Test checks `The file "somefile" should include "content"`
- Test runs a command that creates/modifies files
- Test has `After` cleanup hooks
- Manual verification shows the code works correctly

**The Universal Fix Pattern:**
```bash
# Replace file assertions with output capture
When run sh -c './command-that-modifies-files && cat target-file'
The output should include "expected-content"
```

#### Lessons About Bug Patterns

1. **Recurring Issues Matter:** When the same problem appears multiple times, create a systematic solution
2. **Pattern Recognition:** Learn to identify ShellSpec timing issues from the test structure
3. **Documentation Value:** Documenting the pattern prevents future time waste
4. **Confidence Building:** Manual verification before fixing builds confidence in the solution

---

## Part III: Advanced Testing Techniques

### 1. Parameterized Tests

```bash
Describe 'data-driven validation'
  Parameters
    "valid@example.com" "success"
    "invalid-email"     "error"
    ""                  "error"
  End

  It "should handle email '$1'"
    When call validate_email "$1"
    The output should include "$2"
  End
End
```

### 2. Custom Matchers and Helpers

```bash
# Define custom assertions
should_be_valid_version() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Use in tests
It 'should output valid version'
  When run ./get-version.sh
  The output should satisfy should_be_valid_version
End
```

### 3. State Management

```bash
# Use global variables carefully
CURRENT_TEST_ID=""

BeforeEach 'generate_test_id'
generate_test_id() {
  CURRENT_TEST_ID="test_$(date +%s)_$$"
}

# Clean up in After
After 'cleanup_test_state'
cleanup_test_state() {
  rm -f "/tmp/${CURRENT_TEST_ID}_*" 2>/dev/null || true
}
```

### 4. Complex Scenario Testing

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

---

## Part IV: Test Development Workflow

### 1. Red-Green-Refactor with ShellSpec

```bash
# 1. Write failing test first
It 'should handle edge case X'
  When run ./script.sh edge_case_input
  The output should include "expected_result"
End

# 2. Run test to confirm failure
shellspec spec/my_test_spec.sh:line_number

# 3. Implement minimal code to pass
# 4. Run test to confirm pass
# 5. Refactor while maintaining test pass
```

### 2. Incremental Test Development

```bash
# Start simple
It 'should run without errors'
  When run ./script.sh
  The status should be success
End

# Add assertions incrementally
It 'should run without errors and produce output'
  When run ./script.sh
  The status should be success
  The output should not be blank
End
```

### 3. Test-Driven Debugging

When tests fail:

1. **Isolate**: Run single failing test
2. **Reproduce**: Manually verify behavior
3. **Debug**: Use `--xtrace` or add debug output
4. **Fix**: Address root cause (code or test)
5. **Verify**: Ensure test and related tests still pass

---

## Part V: Performance and Maintenance

### 1. Test Parallelization

```bash
# Run tests in parallel for speed
shellspec --jobs 4

# Ensure tests are isolated for parallel execution
Before 'setup_isolated_environment'
```

### 2. Efficient Test Data

```bash
# Use minimal test data
setup_test_data() {
  echo "minimal config" > .config
  # Avoid large files or complex setups
}
```

### 3. Selective Test Execution

```bash
# Run only tests related to current changes
shellspec spec/installation_spec.sh

# Run only previously failed tests
shellspec --quick

# Focus on specific test during development
shellspec --focus spec/my_test_spec.sh:42
```

---

## Part VI: Quality Assurance Checklists

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

### Debugging Checklist for File Assertion Failures
1. **Manual Reproduction:** Verify code works outside test framework
2. **Check Test Structure:** Look for `After` hooks and file assertions
3. **Apply Pattern:** Use the `sh -c 'command && cat file'` pattern
4. **Verify Fix:** Ensure test passes and no regressions introduced

### When to Suspect ShellSpec Timing Issues
- Test checks `The file "somefile" should include "content"`
- Test runs a command that creates/modifies files
- Test has `After` cleanup hooks
- Manual verification shows the code works correctly
- Negative assertions pass but positive assertions fail

### When to Suspect Context Bugs
- Tests pass in manual testing but fail in automated tests
- Behavior changes based on how script is executed
- Regex or pattern matching logic is involved
- `$0`, `$1`, or other positional parameters determine behavior
- Help messages or usage text adapts to execution context

---

## Updated Best Practices

### Rule of Thumb for File Assertions
```bash
# ❌ AVOID - File assertions with cleanup hooks
It 'should modify files'
  When run ./script.sh
  The file "config" should include "setting"  # May fail due to cleanup
End

# ✅ PREFER - Capture content in execution
It 'should modify files'
  When run sh -c './script.sh && cat config'
  The output should include "setting"  # Captured before cleanup
End

# ✅ EVEN BETTER - Use separators for clarity
It 'should modify files'
  When run sh -c './script.sh && echo "=== FILE: config ===" && cat config'
  The output should include "=== FILE: config ==="
  The output should include "setting"
End
```

### Context Detection Best Practices
```bash
# ❌ AVOID - Regex matches substrings
if [[ "$0" =~ bash ]]; then
  # Wrong - matches ./install.e-bash.sh
fi

# ✅ PREFER - Exact string matching
if [[ "$0" == "bash" ]]; then
  # Correct - only matches exact "bash"
fi

# ✅ EVEN BETTER - More explicit context detection
if [[ -t 0 && ! -p /dev/stdin ]]; then
  # Direct execution with terminal
elif [[ -p /dev/stdin ]]; then
  # Piped input
fi
```

---

## Key Takeaways

### From _dryrun.sh Experience:
1. **Systematic module analysis** is essential before writing tests
2. **Comprehensive mocking** prevents test failures from external dependencies
3. **Environment variable hierarchy** testing catches complex interaction bugs
4. **Cross-platform compatibility** requires careful command selection
5. **Dynamic function testing** needs special handling for eval-generated code

### From ShellSpec Troubleshooting Experience:
1. **Trust manual reproduction** - If code works manually but fails in tests, it's likely a test issue
2. **Understand ShellSpec execution order** - After hooks run before file assertions
3. **Capture file content in execution** - Don't rely on files existing after cleanup
4. **One evaluation per example** - Chain commands instead of multiple `When run`
5. **Use ShellSpec debugging tools** - `--xtrace`, `--dry-run`, `--focus` are invaluable
6. **Isolate test environments** - Prevent test interference with proper setup/teardown
7. **Test cross-platform compatibility** - GNU vs BSD tool differences can cause mysterious failures
8. **Master complex mocking strategies** - Match exact output routing for sophisticated systems
9. **Handle ANSI color codes consistently** - Strip or disable colors for cross-platform tests
10. **Simulate realistic git environments** - Create isolated git repos for testing git-dependent scripts

### Universal Testing Principles:
1. **Manual verification first** - Always reproduce issues outside the test framework
2. **Pattern recognition** - Learn to identify common failure modes
3. **Comprehensive documentation** - Capture unique insights for future reference
4. **Incremental development** - Build complexity gradually
5. **Quality over quantity** - Better tests are more valuable than more tests

---

## Resources

- [ShellSpec Official Documentation](https://shellspec.info/)
- [ShellSpec GitHub Repository](https://github.com/shellspec/shellspec)
- [Bash Best Practices for Testing](https://google.github.io/styleguide/shellguide.html#testing)
- [e-bash Framework Documentation](https://github.com/OleksandrKucherenko/e-bash)

---

**Last Updated:** 2025-11-24
**Context:** This guide represents the combined experience from:
1. Systematic _dryrun.sh module testing implementation with comprehensive mock strategies and cross-platform compatibility
2. Analysis of 8 spec files identifying unique testing patterns including advanced mocking, git simulation, and ANSI color handling
3. Debugging 4 failing ShellSpec tests discovering unique execution order, timing patterns, and macOS compatibility issues
4. Real-world troubleshooting of context-dependent script behavior and help message detection bugs
5. Cross-platform compatibility debugging identifying GNU vs BSD tool differences
6. Development of comprehensive testing strategies for complex logger systems, git-dependent scripts, and dynamic function generation

**Total Experience:** Hundreds of hours of ShellSpec testing across multiple projects and platforms, compressed into actionable patterns, advanced mocking strategies, and debugging techniques.