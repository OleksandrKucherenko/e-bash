# ShellMetrics Compare Test Suite

## Overview

This test suite provides comprehensive unit testing for `.github/scripts/shellmetrics-compare.sh` using ShellSpec. The tests cover functionality, error handling, edge cases, and CI failure reproduction scenarios.

## Test Structure

The test suite is organized into the following contexts:

### Core Functionality Tests

1. **calculate_totals function** - Tests CSV parsing and metric aggregation
   - Valid CSV files with single/multiple files
   - Empty CSV handling
   - Correct calculation of NLOC, LLOC, and CCN metrics

2. **get_file_metrics function** - Tests file-level metric extraction
   - File name parsing and quote removal
   - Sorted output verification
   - Special characters in paths

3. **format_delta helper** - Tests delta formatting with emojis
   - Positive/negative/zero deltas
   - Reverse emoji mode for complexity metrics

4. **compare_metrics function** - Tests report generation
   - Markdown structure validation
   - File change detection
   - Error handling for missing files
   - Empty metrics handling

5. **main command dispatcher** - Tests command-line interface
   - Help command variations (`help`, `--help`, `-h`)
   - Unknown command handling
   - Collect and compare command routing

### CI Failure Reproduction Tests

Specific tests to reproduce and diagnose the GitHub Actions CI failure:

```bash
./.github/scripts/shellmetrics-compare.sh compare /tmp/base-metrics.csv current-metrics.csv metrics-report.md
```

These tests verify:
- Base metrics file existence
- Current metrics file existence
- Git worktree scenario handling
- CSV validation from collect command

### Edge Cases and Robustness

- Very large CSV files (100+ entries)
- Files with zero metrics
- Files with very high complexity
- Division by zero scenarios
- Malformed CSV handling

## Running the Tests

### Prerequisites

```bash
# Install ShellSpec
curl -fsSL https://git.io/shellspec | sh -s -- -y

# Or using Homebrew
brew install shellspec
```

### Run All Tests

```bash
# From project root
shellspec spec/bin/shellmetrics-compare_spec.sh

# Or run all tests
shellspec
```

### Run Specific Contexts

```bash
# Run only calculate_totals tests
shellspec spec/bin/shellmetrics-compare_spec.sh --focus "calculate_totals"

# Run CI failure reproduction tests
shellspec spec/bin/shellmetrics-compare_spec.sh --focus "CI failure reproduction"
```

### Debug Mode

```bash
# Show execution trace
shellspec --xtrace spec/bin/shellmetrics-compare_spec.sh

# Stop on first failure
shellspec --fail-fast spec/bin/shellmetrics-compare_spec.sh
```

## Test Coverage

The test suite covers:

- **Function-level testing**: All major functions are tested in isolation
- **Integration testing**: Full workflow from collect to compare
- **Error scenarios**: Missing files, malformed data, edge cases
- **CI replication**: Exact reproduction of CI workflow scenarios

### Skipped Tests

Some tests are marked with `Skip if "condition" true` because they require:
- Real shell script files to analyze with shellmetrics
- Actual git repository setup
- External shellmetrics tool availability

These can be enabled in a full integration test environment.

## Diagnosing CI Failures

When the CI fails with:

```
Error: Process completed with exit code 1.
```

Follow these steps:

### 1. Check Base Metrics Collection

The failure might occur if the git worktree step fails to collect base metrics:

```bash
git worktree add --detach /tmp/base-branch origin/master
cp ./.github/scripts/shellmetrics-compare.sh /tmp/base-branch/
cd /tmp/base-branch
./shellmetrics-compare.sh collect /tmp/base-metrics.csv
```

**Potential issues:**
- Script doesn't exist in base branch
- No shell scripts to analyze in base branch
- Shellmetrics not properly installed

### 2. Check File Existence

Verify both CSV files exist before compare:

```bash
ls -la /tmp/base-metrics.csv current-metrics.csv
```

### 3. Run Compare Locally

Test the compare command with debug output:

```bash
set -x
./.github/scripts/shellmetrics-compare.sh compare /tmp/base-metrics.csv current-metrics.csv metrics-report.md
```

### 4. Check CSV Format

Ensure both CSV files have proper format:

```bash
head -n 3 /tmp/base-metrics.csv
head -n 3 current-metrics.csv
```

Expected format:
```csv
file,func,lineno,lloc,ccn,lines,comment,blank
".scripts/example.sh","<begin>",1,0,0,100,10,5
".scripts/example.sh","function_name",10,20,3,30,2,1
```

## Mock Setup

The test suite uses a mock `shellmetrics` command to avoid external dependencies:

```bash
# Mock shellmetrics location
$TEST_DIR/mock-bin/shellmetrics

# Generates CSV output for any input file
# Automatically added to PATH in setup_test_environment
```

For real integration tests, install actual shellmetrics:

```bash
curl -fsSL https://raw.githubusercontent.com/shellspec/shellmetrics/master/shellmetrics > ~/.local/bin/shellmetrics
chmod +x ~/.local/bin/shellmetrics
```

## Test Data

The test suite uses predefined CSV data for consistent results:

- **base-metrics.csv**: 2 files, 128 NLOC, 45 LLOC, 6 CCN
- **current-metrics.csv**: 3 files (one added), 154 NLOC, 58 LLOC, 9 CCN

This allows verification of:
- File addition detection (+1 file)
- NLOC increase (+26)
- LLOC increase (+13)
- Complexity increase (+3)

## Contributing

When adding new tests:

1. Follow the existing `Describe` / `Context` / `It` structure
2. Use `BeforeEach` / `AfterEach` for setup/cleanup
3. Always clean up temporary files
4. Mock external dependencies
5. Add descriptive test names
6. Group related tests in contexts

### Test Naming Convention

```bash
Describe 'feature name /'
  Context 'specific scenario /'
    It 'should do something specific'
      # Test implementation
    End
  End
End
```

## Known Issues

1. **Exit Code 102**: ShellSpec 0.28.1 has a known bug where it may exit with code 102 even when
 tests pass. The CI workflow handles this by checking actual test results.

2. **WSL Path Issues**: When running in WSL, use the correct path format for file access.

3. **Temporary Directory Cleanup**: Some tests may leave files in `/tmp` if interrupted. This is
 handled by `AfterEach` hooks.

## References

- [ShellSpec Documentation](https://shellspec.info/)
- [ShellSpec Skill Guide](../../.claude/skills/shellspec/SKILL.md)
- [ShellMetrics](https://github.com/shellspec/shellmetrics)
- [GitHub Actions Workflow](../../.github/workflows/shellspec.yaml)

## Support

For issues with the tests:
1. Check the [ShellSpec skill guide](../../.claude/skills/shellspec/SKILL.md)
2. Review [existing test examples](../spec/)
3. Run with `--xtrace` for detailed debugging
4. Check CI logs for actual failure messages
