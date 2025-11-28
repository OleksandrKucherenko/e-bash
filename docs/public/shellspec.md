# ShellSpec Testing Guide

## Overview

This document covers common issues, solutions, and best practices for ShellSpec testing in the e-bash project.

## Major Issue: junit_tests_0 Unbound Variable Error

### Problem Description

When running tests with `shellspec spec/git_semantic_version_spec.sh`, the following error occurred:

```
Bail out! Aborted by unexpected errors.
/home/linuxbrew/.linuxbrew/lib/shellspec/lib/libexec/reporter/junit_formatter.sh: line 117: junit_tests_0: unbound variable
Aborted with status code [executor: 1] [reporter: 1] [error handler: 102]
Fatal error occurred, terminated with exit status 102.
```

### Root Cause Analysis

The issue was caused by **EXIT trap interference** when scripts were sourced by ShellSpec:

1. **Primary Issue**: The script `bin/git.semantic-version.sh` was setting up EXIT and INT/TERM traps unconditionally when sourced
2. **Secondary Issue**: The BeforeAll command in the test was failing due to incorrect path calculation
3. **Impact**: The trap setup was disrupting ShellSpec's execution flow, causing the junit formatter to fail with unbound variables

### Solution Implemented

#### 1. ShellSpec Pattern for Script Execution Control

**Before (Problematic)**:
```bash
# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  trap on_exit EXIT
  trap on_interrupt INT TERM
  main "$@"
  exit $?
fi
```

**After (Fixed)**:
```bash
# This is the writing style presented by ShellSpec, which is short but unfamiliar.
# Note that it returns the current exit status (could be non-zero).
${__SOURCED__:+return}

# Setup exit and interrupt traps
trap on_exit EXIT
trap on_interrupt INT TERM

# Run main function
main "$@"
exit $?
```

#### 2. BeforeAll Command Fix

**Before (Problematic)**:
```bash
BeforeAll 'E_BASH="$(cd "$(dirname "$SHELLSPEC_SPECFILE")" && cd ../.scripts && pwd)"'
```

**After (Fixed)**:
```bash
# BeforeAll 'E_BASH="$(cd "$(dirname "$SHELLSPEC_SPECFILE")" && cd ../.scripts && pwd)"'
# Note: Commented out because the path calculation fails in test environment.
# The script's fallback mechanism works correctly.
```

### Results

- **95 examples, 0 failures, 2 skips** - All tests pass
- **Exit code 0** - No errors
- **Junit output working** - TAP format output generated correctly
- **Code coverage working** - 10.11% coverage, 475 executed lines

## Best Practices

### 1. Script Execution Control

Use the ShellSpec pattern to prevent script execution when sourced:

```bash
# This prevents execution when sourced by ShellSpec
${__SOURCED__:+return}

# Your script execution code here
```

This pattern is:
- **Shorter** than conditional checks
- **More reliable** than `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`
- **ShellSpec-recommended** approach

### 2. Avoid Problematic BeforeAll Commands

- Don't rely on complex path calculations in BeforeAll
- Let scripts use their built-in fallback mechanisms for variable initialization
- Test BeforeAll commands in isolation before using them

### 3. Trap Management

- Never set up traps unconditionally in sourced scripts
- Use the ShellSpec pattern to control when traps are set
- Traps should only be active when scripts run directly, not when sourced

## ANSI Color Filtering Utilities

```bash
# Define helper functions to strip ANSI escape sequences
# $1 = stdout, $2 = stderr, $3 = exit status of the command
no_colors_stderr() { echo -n "$2" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }
no_colors_stdout() { echo -n "$1" | sed -E $'s/\x1B\\[[0-9;]*[A-Za-z]//g; s/\x1B\\([A-Z]//g; s/\x0F//g' | tr -s ' '; }

# Usage example
The result of function no_colors_stdout should include "v1.0.0 [CURRENT] [LATEST]"
```

## Configuration

### .shellspec Configuration

```bash
--require spec_helper
--shell bash
--format t
--skip-message quiet
--pending-message quiet
--output junit

## Default kcov (coverage) options
--kcov
--kcov-options "--include-path=. --path-strip-level=1"
--kcov-options "--exclude-pattern=/.shellspec,/spec/,/coverage/,/report/,/demos/"
--kcov-options "--include-pattern=.scripts/,bin/"
```

## Debugging Tips

1. **Test in isolation**: Create minimal test files to isolate issues
2. **Check syntax**: Use `bash -n script.sh` to verify syntax
3. **Disable coverage**: Use `--no-kcov` for faster debugging
4. **Use format d**: Use `--format d` for detailed output during debugging
5. **Check exit codes**: Monitor exit codes to identify failure points

## Common Patterns

### Mock Functions
```bash
Mock logger:init
  echo "$@" >/dev/null
End

Mock echo:SemVer
  echo "$@" >/dev/null
End
```

### Include Scripts
```bash
Include "bin/script-name.sh"
```

### Test Structure
```bash
Describe "Feature name"
  It "should do something"
    When call function_name "arg1" "arg2"
    The output should eq "expected output"
    The status should be success
  End
End
```