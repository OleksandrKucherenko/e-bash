---
name: shellspec
description: Comprehensive unit testing framework for Bash and POSIX shell scripts using ShellSpec with TDD/BDD best practices. Use when writing tests for shell scripts, debugging test failures, refactoring scripts for testability, setting up test infrastructure, mocking external dependencies, or implementing test-driven development for Bash/shell projects. Covers test structure, isolation, mocking, output capture, coverage, CI integration, and troubleshooting.
---

# ShellSpec Unit Testing Guide

ShellSpec is a full-featured BDD unit testing framework for bash, ksh, zsh, dash and all POSIX shells. It brings professional-grade Test-Driven Development (TDD) practices to shell scripting.

**Think of ShellSpec as**: A translator between natural language test intentions and shell execution verification - like having a bilingual interpreter who understands both "what you want to test" and "how shells actually work."

## Quick Start

### Installation

```bash
# Install ShellSpec
curl -fsSL https://git.io/shellspec | sh -s -- -y

# Initialize project
shellspec --init
```

### Basic Test Example

```bash
# lib/calculator.sh
add() { echo "$(($1 + $2))"; }

# spec/calculator_spec.sh
Describe 'Calculator'
  Include lib/calculator.sh
  
  It 'performs addition'
    When call add 2 3
    The output should eq 5
  End
End
```

**Run tests**: `shellspec`

## Project Structure

```
project/
├── .shellspec              # Project configuration (mandatory)
├── .shellspec-local        # Local overrides (gitignored)
├── lib/                    # Production code
│   ├── module1.sh
│   └── module2.sh
├── spec/                   # Test specifications
│   ├── spec_helper.sh      # Global test setup
│   ├── support/            # Shared test utilities
│   │   ├── mocks.sh
│   │   └── helpers.sh
│   └── lib/
│       ├── module1_spec.sh
│       └── module2_spec.sh
├── coverage/               # Coverage reports (generated)
└── report/                 # Test reports (generated)
```

## Test Structure

### DSL Hierarchy

```bash
Describe 'Feature Name'              # Top-level grouping
  BeforeEach 'setup_function'        # Runs before each test
  AfterEach 'cleanup_function'       # Runs after each test
  
  Context 'when condition X'         # Scenario grouping
    It 'behaves in way Y'            # Individual test
      # GIVEN: Setup (arrange)
      local input="test data"
      
      # WHEN: Execute (act)
      When call function_under_test "$input"
      
      # THEN: Verify (assert)
      The output should equal "expected"
      The status should be success
    End
  End
End
```

**Analogy**: Think of tests like a filing cabinet - `Describe` is the drawer, `Context` is the folder, `It` is the document.

### Execution Modes

| Mode | Use Case | Isolation | Coverage |
|------|----------|-----------|----------|
| `When call func` | Unit test functions | Same shell (fast) | ✅ Yes |
| `When run script` | Integration test | New process | ✅ Yes |
| `When run source` | Hybrid approach | Subshell | ✅ Yes |

**Recommended**: Use `When call` for unit tests (fastest), `When run script` for integration tests.

## Making Scripts Testable

### Pattern 1: Source Guard (Critical)

**Analogy**: Like a bouncer at a club - decides whether to let execution in based on context.

```bash
#!/bin/bash
# my_script.sh

# Testable functions
process_data() {
  validate_input "$1" || return 1
  transform_data "$1"
}

validate_input() {
  [[ -n "$1" ]] || return 1
}

# Source guard - prevents execution when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Only runs when executed, not when sourced for testing
  process_data "$@"
fi
```

**Test file**:
```bash
Describe 'my_script'
  Include my_script.sh  # Loads functions without executing
  
  It 'validates input'
    When call validate_input ""
    The status should be failure
  End
End
```

**Pros**: Functions become unit-testable, zero test pollution in production code
**Cons**: Requires discipline, legacy scripts need refactoring
**Recommended action**: Always add source guards to new scripts

### Pattern 2: Extract Functions from Pipelines

```bash
# ❌ BAD: Untestable inline pipeline
cat /etc/passwd | grep "^${USER}:" | cut -d: -f6

# ✅ GOOD: Testable functions
get_user_home() {
  local user="${1:-$USER}"
  grep "^${user}:" /etc/passwd | cut -d: -f6
}

process_user_homes() {
  local home
  home=$(get_user_home "$1")
  [[ -n "$home" ]] && check_bashrc "$home"
}
```

**Recommended action**: Extract every logical step into a named function

## Dependency Isolation and Mocking

### Three-Tier Mocking Strategy

**1. Function-Based Mocks** (Fastest)
```bash
Describe 'function mocking'
  date() { echo "2024-01-01 00:00:00"; }
  
  It 'uses mocked date'
    When call get_timestamp
    The output should eq "2024-01-01 00:00:00"
  End
End
```

**2. Mock Block** (Cleaner)
```bash
Describe 'command mocking'
  Mock curl
    echo '{"status": "success"}'
    return 0
  End
  
  It 'handles API response'
    When call fetch_data
    The output should include "success"
  End
End
```

**3. Intercept Pattern** (For Built-ins)
```bash
Describe 'intercepting built-ins'
  Intercept command
  
  __command__() {
    if [[ "$2" == "rm" ]]; then
      echo "MOCK: rm intercepted"
      return 0
    fi
    command "$@"
  }
  
  It 'safely mocks dangerous operations'
    When run source ./cleanup_script.sh
    The output should include "MOCK: rm intercepted"
  End
End
```

**Decision Matrix**:

| Dependency | Mock? | Rationale |
|------------|-------|-----------|
| Network (curl, wget) | ✅ Always | Slow, unreliable |
| Date/time | ✅ Always | Reproducibility |
| Random values | ✅ Always | Deterministic tests |
| System commands (grep, sed) | ❌ Rarely | Fast, stable |
| File I/O | ⚠️ Sometimes | Use temp dirs |

**Recommended action**: Mock boundaries (network, time, random), trust stable commands

## Output Capture and Comparison

### Capturing stdout, stderr, and exit status

```bash
It 'captures all output streams'
  When call function_with_output
  The output should eq "stdout message"      # stdout
  The error should eq "error message"        # stderr
  The status should be success               # exit code (0)
End
```

### Comparing Without Color Codes

```bash
# Helper function to strip ANSI codes
strip_colors() {
  sed 's/\x1B\[[0-9;]*[mK]//g'
}

It 'compares without colors'
  When call colored_output
  The result of output filtered by strip_colors should eq "Plain text"
End

# Alternative: Disable colors via environment
It 'disables colors'
  NO_COLOR=1
  When call my_command
  The output should not include pattern '\x1B\['
End
```

**Recommended action**: Set `NO_COLOR=1` in test environment to avoid color-stripping

## Test Environment Management

### Temporary Directories

```bash
Describe 'isolated environment'
  BeforeEach 'setup_test_env'
  AfterEach 'cleanup_test_env'
  
  setup_test_env() {
    export TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
  }
  
  cleanup_test_env() {
    cd - >/dev/null
    rm -rf "$TEST_DIR"
  }
  
  It 'works in isolation'
    When call touch test.txt
    The path test.txt should be file
  End
End
```

**Pros**: Complete isolation, no test interference
**Cons**: Requires discipline in cleanup
**Recommended action**: Always use temp dirs, never write to fixed paths

### Parameterized Tests

```bash
Describe 'data-driven tests'
  Parameters
    "#1" "valid"   "success" 0
    "#2" "invalid" "error"   1
    "#3" "empty"   "missing" 1
  End
  
  It "handles $1 input"
    When call validate "$2"
    The output should include "$3"
    The status should eq $4
  End
End
```

**Recommended action**: Use Parameters to avoid copy-paste test code

## Code Coverage

### Enable Coverage

```bash
# .shellspec configuration
--kcov
--kcov-options "--include-pattern=.sh"
--kcov-options "--exclude-pattern=/spec/,/coverage/"
--kcov-options "--fail-under-percent=80"

# Run with coverage
shellspec --kcov

# View report
open coverage/index.html
```

**Coverage Goals**:
- Critical paths: 100%
- Main functionality: 80-90%
- Utility functions: 70-80%

**Recommended action**: Enable coverage from day 1, set minimum thresholds

## Test Execution

### Running Tests

```bash
# All tests
shellspec

# Specific file
shellspec spec/module_spec.sh

# Specific line
shellspec spec/module_spec.sh:42

# Only previously failed
shellspec --quick

# Stop on first failure
shellspec --fail-fast

# Parallel execution (4 jobs)
shellspec --jobs 4

# With debug trace
shellspec --xtrace

# Focus mode (run only fIt, fDescribe)
shellspec --focus
```

### Focus Mode for TDD

```bash
Describe 'feature under development'
  fIt 'focused test - runs only this'
    When call new_feature
    The status should be success
  End
  
  It 'other test - skipped during focus'
    When call other_feature
  End
End
```

**Recommended action**: Use `--quick` and `--focus` for rapid TDD cycles

## CI/CD Integration

### JUnit Reports

```bash
# .shellspec configuration
--format junit
--output report/junit.xml

# Run in CI
shellspec --kcov --format junit
```

### GitHub Actions Example

```yaml
name: ShellSpec Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Install ShellSpec
      run: curl -fsSL https://git.io/shellspec | sh -s -- -y
    - name: Run tests
      run: shellspec --kcov --format junit
    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

**Recommended action**: Generate JUnit reports for CI integration

## Troubleshooting

### Debug Failed Tests

```bash
# Show execution trace
shellspec --xtrace spec/failing_spec.sh

# Check spec syntax
shellspec --syntax-check spec/failing_spec.sh

# See generated shell code
shellspec --translate spec/failing_spec.sh

# Inspect output during test
It 'debugs with Dump'
  When call my_function
  Dump  # Shows stdout, stderr, status
  The output should not be blank
End
```

### Common Issues

**Problem**: Test passes alone but fails in suite
**Solution**: Check for global state leakage, ensure cleanup in `AfterEach`

**Problem**: Can't mock external command
**Solution**: Use `Mock` block or `Intercept` for built-ins

**Problem**: Tests are slow
**Solution**: Enable parallel execution with `--jobs 4`

**Problem**: Coverage doesn't work
**Solution**: Ensure kcov is installed, check `--kcov-options`

## Best Practices Checklist

- [ ] All scripts have source guards
- [ ] External dependencies are mocked
- [ ] Tests use temporary directories
- [ ] Each test verifies one behavior
- [ ] Tests follow GIVEN/WHEN/THEN structure
- [ ] Coverage is enabled and > 80%
- [ ] Tests run in parallel (`--jobs`)
- [ ] JUnit reports generated for CI
- [ ] No hard-coded paths or commands
- [ ] Side effects are documented and tested

## Common Anti-Patterns to Avoid

❌ **Global state mutation**
```bash
COUNTER=0  # Bad: mutable global
increment() { COUNTER=$((COUNTER + 1)); }
```

✅ **Return values**
```bash
increment() { echo $(($1 + 1)); }  # Good: pure function
counter=$(increment "$counter")
```

❌ **Testing implementation details**
```bash
It 'calls grep with -E flag'  # Bad: too coupled
```

✅ **Testing behavior**
```bash
It 'finds files matching pattern'  # Good: tests outcome
```

❌ **Unmocked network calls**
```bash
It 'fetches real data' curl https://api.com  # Bad: slow, flaky
```

✅ **Mocked dependencies**
```bash
Mock curl; echo "mock"; End  # Good: fast, reliable
```

## Advanced Topics

For deeper coverage of advanced patterns, see:

- **Advanced Patterns**: See [references/advanced-patterns.md](references/advanced-patterns.md) for complex mocking, spies, state management
- **Troubleshooting Guide**: See [references/troubleshooting.md](references/troubleshooting.md) for systematic debugging
- **Real-World Examples**: See [references/real-world-examples.md](references/real-world-examples.md) for production patterns from top OSS projects

## Quick Reference

```bash
# Common commands
shellspec                    # Run all tests
shellspec --quick           # Re-run failures only
shellspec --xtrace          # Debug trace
shellspec --kcov            # With coverage
shellspec --format junit    # JUnit output

# DSL basics
Describe/Context/It/End     # Test structure
When call/run/source        # Execution
The output/status/error     # Assertions
Mock/Intercept              # Mocking
BeforeEach/AfterEach        # Hooks
Parameters                  # Data-driven tests
Dump                        # Debug helper
```

**Recommended action**: Start with simple unit tests, add coverage, then integrate into CI
