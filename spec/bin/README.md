# Tests for bin/ Scripts

This directory contains ShellSpec unit tests for all executable scripts in the `bin/` directory.

## Test Files

- `npm.versions_spec.sh` - Comprehensive tests for `bin/npm.versions.sh` script

## Running Tests

### Prerequisites

Ensure ShellSpec is installed:

```bash
# Using Homebrew
brew install shellspec

# Or using the installer
curl -fsSL https://git.io/shellspec | sh -s -- -y
```

### Run All Tests

```bash
# From project root
shellspec

# With coverage
shellspec --kcov

# Only bin/ tests
shellspec spec/bin/
```

### Run Specific Test File

```bash
# Run npm.versions tests
shellspec spec/bin/npm.versions_spec.sh

# Run without coverage (faster)
shellspec spec/bin/npm.versions_spec.sh --no-kcov

# Run specific test by line number
shellspec spec/bin/npm.versions_spec.sh:42
```

### Test Development Workflow

```bash
# Quick mode - only run previously failed tests
shellspec --quick

# Focus mode - only run focused tests (fIt, fDescribe)
shellspec --focus

# TDD mode - run tests on file change
watchman-make -p 'spec/**/*_spec.sh' 'bin/**/*.sh' --run "shellspec --quick"
```

## Test Structure for npm.versions.sh

The test suite covers all major functions:

### Core Functionality
- `parse_range()` - Parsing version selection syntax (single, ranges, mixed)
- `exec:npm()` - NPM command execution with dry-run support
- `fetch_versions()` - Fetching package versions from registry
- `display_versions()` - Formatting version output
- `parse_arguments()` - Command-line argument parsing

### User Interaction
- `confirm_unpublish()` - User confirmation prompts
- `print_usage()` - Help text display

### NPM Operations
- `unpublish_version()` - Unpublishing specific versions
- `verify_unpublish()` - Verifying unpublish operations

### Test Coverage

The tests cover:

✅ **Happy paths** - Normal usage scenarios
✅ **Edge cases** - Empty inputs, boundary conditions
✅ **Error handling** - Invalid inputs, network failures
✅ **Mocking** - All external dependencies (npm commands)
✅ **Dry-run mode** - Testing without actual execution

## Testability Improvements Made

1. **Source Guard Added**: The script now has a source guard to prevent execution when sourced:
   ```bash
   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
     main "$@"
     exit $?
   fi
   ```

2. **Function Isolation**: All core logic is in testable functions
3. **Dependency Injection**: External commands are wrapped in `exec:npm()` for easy mocking

## Writing New Tests

Follow the established patterns:

```bash
Describe 'function_name()'
  Context 'when condition'
    BeforeEach 'setup_function'

    It 'describes expected behavior'
      # GIVEN: Setup
      versions=("1.0.0" "2.0.0")

      # WHEN: Execute
      When call function_under_test "${versions[@]}"

      # THEN: Assert
      The output should include "expected"
      The status should be success
    End
  End
End
```

### Best Practices

1. **Mock External Dependencies**: Always mock `npm` commands
2. **Use Temporary Directories**: For file operations
3. **Test Isolation**: Each test should be independent
4. **Clear Test Names**: Describe what is being tested
5. **Coverage**: Aim for 80%+ code coverage

## Debugging Failed Tests

```bash
# Show execution trace
shellspec --xtrace spec/bin/npm.versions_spec.sh

# Check syntax
shellspec --syntax-check spec/bin/npm.versions_spec.sh

# See generated shell code
shellspec --translate spec/bin/npm.versions_spec.sh

# Use Dump in tests for debugging
It 'debugs output'
  When call my_function
  Dump  # Shows stdout, stderr, status
  The output should not be blank
End
```

## CI Integration

Tests run automatically in GitHub Actions:

```yaml
- name: Run ShellSpec Tests
  run: shellspec --kcov --format junit

- name: Upload Coverage
  uses: codecov/codecov-action@v3
```

## References

- [ShellSpec Documentation](https://shellspec.info/)
- [ShellSpec GitHub](https://github.com/shellspec/shellspec)
- [e-bash Testing Guide](../../CLAUDE.md#testing--quality-assurance)
