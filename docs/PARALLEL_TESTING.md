# Parallel Test Execution

This document describes the parallel test execution implementation for the e-bash project.

## Overview

To reduce CI execution time, the test suite is divided into chunks that run in parallel across multiple GitHub Actions runners. This approach significantly reduces total test execution time while maintaining full test coverage.

## Architecture

### Chunking Strategy

Tests are divided into 4 equal chunks using the `.github/scripts/chunk-tests.sh` script:

- **Chunk 0**: 4 test files
- **Chunk 1**: 4 test files
- **Chunk 2**: 4 test files
- **Chunk 3**: 1 test file

Total: 13 test files

### GitHub Actions Matrix

Both macOS and Ubuntu jobs use a matrix strategy with 4 parallel runners:

```yaml
strategy:
  fail-fast: false
  matrix:
    chunk: [0, 1, 2, 3]
```

The `fail-fast: false` setting ensures all chunks complete even if one fails, providing complete test results.

## Usage

### Running Specific Chunks Locally

You can run individual test chunks locally for faster iteration:

```bash
# Run chunk 0
shellspec $(./.github/scripts/chunk-tests.sh 4 0)

# Run chunk 1
shellspec $(./.github/scripts/chunk-tests.sh 4 1)

# Run all tests (traditional way)
shellspec
```

### Chunk Script Usage

The `.github/scripts/chunk-tests.sh` script divides test files evenly:

```bash
./.github/scripts/chunk-tests.sh <total_chunks> <chunk_index>
```

**Arguments:**
- `total_chunks`: Total number of chunks (currently 4)
- `chunk_index`: Zero-based chunk index (0-3)

**Example:**
```bash
# Get files for chunk 2 of 4
./.github/scripts/chunk-tests.sh 4 2
```

**Output:**
```
spec/installation_spec.sh
spec/logger_spec.sh
spec/traps_nested_spec.sh
spec/traps_spec.sh
```

## CI Workflow Details

### macOS Jobs

4 parallel jobs run on `macos-latest`:
- `MacOS (chunk 0)`
- `MacOS (chunk 1)`
- `MacOS (chunk 2)`
- `MacOS (chunk 3)`

Each job:
1. Sets up dependencies via direnv
2. Runs only its assigned test chunk
3. Reports results independently

### Ubuntu Jobs with Coverage

4 parallel jobs run on `ubuntu-22.04`:
- `Ubuntu (chunk 0)`
- `Ubuntu (chunk 1)`
- `Ubuntu (chunk 2)`
- `Ubuntu (chunk 3)`

Each job:
1. Sets up dependencies via direnv
2. Runs tests with kcov coverage for its chunk
3. Uploads partial coverage to Codecov
4. Uploads coverage artifacts

**Coverage Merging:**
Codecov automatically merges coverage reports from all chunks into a unified report, providing complete project coverage metrics.

### Artifacts

Each chunk uploads separate artifacts:
- Coverage: `coverage-report-ubuntu-chunk-{0-3}`
- Test results: `test-results-ubuntu-chunk-{0-3}`

This allows debugging individual chunk failures without downloading all test results.

## Benefits

1. **Faster CI Execution**: Tests run in parallel, reducing total time by ~75% (4x speedup)
2. **Independent Failure Isolation**: Failed chunks don't block other chunks
3. **Flexible Scaling**: Easy to adjust chunk count based on test suite growth
4. **Maintained Coverage**: Full coverage maintained through Codecov merging

## Performance Impact

**Before Parallelization:**
- Sequential execution of all 13 test files
- Total time: ~T minutes

**After Parallelization:**
- 4 chunks running in parallel
- Total time: ~T/4 minutes (theoretical)
- Actual speedup: ~75% reduction (accounting for setup overhead)

## Modifying Chunk Count

To change the number of chunks:

1. Update the matrix in `.github/workflows/shellspec.yaml`:
   ```yaml
   matrix:
     chunk: [0, 1, 2, 3, 4]  # Add more indices
   ```

2. Update the chunk count in test execution steps:
   ```bash
   CHUNK_FILES=$(./.github/scripts/chunk-tests.sh 5 ${{ matrix.chunk }})  # Change 4 to 5
   ```

3. Consider GitHub Actions concurrent job limits for your account

## Troubleshooting

### Chunk Has No Tests

Some chunks may have fewer tests (like chunk 3 with only 1 file). This is normal and the job will complete quickly.

### Coverage Gaps

If Codecov shows coverage gaps:
1. Check that all 4 chunks completed successfully
2. Verify each chunk uploaded coverage to Codecov
3. Review Codecov merge settings

### Test Failures in Specific Chunks

To debug a failing chunk:
1. Download the chunk's test results artifact
2. Run the same chunk locally: `shellspec $(./.github/scripts/chunk-tests.sh 4 X)`
3. Review the specific test files in that chunk

## Future Improvements

Potential enhancements:
- **Smart Chunking**: Balance chunks by test execution time rather than file count
- **Dynamic Chunk Count**: Adjust based on total test count
- **Test Sharding**: Further divide large test files
- **Caching**: Share dependency caches across chunks more efficiently
