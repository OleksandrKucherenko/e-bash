# Per-Example Level Test Chunking

## Overview

This document describes the design for extending `calculate-optimal-chunks.ts` to support **per-example granularity** in test distribution, complementing the existing per-file approach.

## Current State

### Current Granularity: Per-File
- Tests distributed by spec files (`*_spec.sh`)
- Timing data aggregated at file level
- Output format: `spec/file_spec.sh spec/other_spec.sh`

### Limitation
- Large spec files can't be split across chunks
- A single slow file becomes a bottleneck
- Uneven distribution when test files vary greatly in size

## Proposed Enhancement

### Granularity Levels

```
┌──────────────────────────────────────────────────────────────┐
│                    Granularity Options                       │
├──────────────────────────────────────────────────────────────┤
│  Level         │ Unit           │ Output Format              │
├────────────────┼────────────────┼────────────────────────────┤
│  file (default)│ Spec files     │ spec/file_spec.sh          │
│  example       │ Individual It  │ spec/file_spec.sh:@1-2     │
│  hybrid        │ Auto-select    │ Mixed (smart split)        │
└────────────────┴────────────────┴────────────────────────────┘
```

## ShellSpec Features for Per-Example Execution

### 1. Example Listing (`--list examples`)

```bash
$ shellspec --list examples
spec/arguments_spec.sh:@1       # On no ARGS_DEFINITION provided...
spec/arguments_spec.sh:@2       # ARGS_DEFINITION set to "-h,--help"...
spec/arguments_spec.sh:@3       # Extract argument after --id flag...
spec/arguments_spec.sh:@1-1     # Parameters Matrix #00
spec/arguments_spec.sh:@1-2     # Parameters Matrix #01
...
```

### 2. Line Number Format (`--list examples:lineno`)

```bash
$ shellspec --list examples:lineno
spec/arguments_spec.sh:35       # Line 35: It 'On no ARGS_DEFINITION...'
spec/arguments_spec.sh:56       # Line 56: It 'ARGS_DEFINITION set to...'
...
```

### 3. Running Specific Examples

```bash
# By ID (preferred - stable across edits)
shellspec spec/arguments_spec.sh:@1 spec/arguments_spec.sh:@2

# By line number
shellspec spec/arguments_spec.sh:35 spec/arguments_spec.sh:56

# Mixed
shellspec spec/arguments_spec.sh:@1:56:@3
```

## Data Sources for Per-Example Timing

### 1. JUnit XML with Profiling (`--profile -o junit`)

When running with `--profile`, JUnit XML includes per-test timing:

```xml
<testsuite name="spec/arguments_spec.sh" tests="15" time="2.345">
  <testcase 
    classname="spec/arguments_spec.sh" 
    name="On no ARGS_DEFINITION provided, expected fallback to predefined flags"
    time="0.234"
  />
  <testcase 
    classname="spec/arguments_spec.sh" 
    name="ARGS_DEFINITION set to '-h,--help' produce help env variable"
    time="0.156"
  />
  <!-- ... -->
</testsuite>
```

### 2. Static Analysis (Fallback)

For examples without timing data:
- Count assertions (`The ... should`)
- Check for sleep/wait commands
- Detect external command calls
- Estimate based on test complexity

## Enhanced Timing Data Format

### Current Format (`.test-timings.json`)

```json
{
  "version": "1.0",
  "timings": {
    "spec/arguments_spec.sh": 2.345,
    "spec/commons_spec.sh": 5.678
  }
}
```

### Enhanced Format (v2.0)

```json
{
  "version": "2.0",
  "granularity": "example",
  "timings": {
    "spec/arguments_spec.sh": {
      "total": 2.345,
      "examples": {
        "@1": { "time": 0.234, "name": "On no ARGS_DEFINITION..." },
        "@2": { "time": 0.156, "name": "ARGS_DEFINITION set to..." },
        "@1-1": { "time": 0.089, "name": "Parameters Matrix #00" },
        "@1-2": { "time": 0.091, "name": "Parameters Matrix #01" }
      }
    },
    "spec/commons_spec.sh": {
      "total": 5.678,
      "examples": {
        "@1": { "time": 0.456, "name": "..." },
        "@2": { "time": 0.789, "name": "..." }
      }
    }
  },
  "file_count": 13,
  "example_count": 425
}
```

## Implementation Design

### CLI Interface

```bash
# Per-file (current behavior, default)
bun bin/junit/calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=file

# Per-example (new)
bun bin/junit/calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=example

# Hybrid (auto-select best approach)
bun bin/junit/calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=hybrid

# Threshold for hybrid mode (split files larger than threshold)
bun bin/junit/calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=hybrid --split-threshold=30s
```

### Algorithm: Hybrid Chunking

```
1. Load timing data (file + example level)
2. Calculate target time per chunk: total_time / num_chunks
3. Sort items by time descending
4. For each item:
   a. If file_time < target_time * 0.5:
      - Keep file intact (assign whole file to chunk)
   b. If file_time >= target_time * 0.5:
      - Split file into example groups
      - Distribute example groups across chunks
5. Balance using bin-packing FFD
```

### Output Format Changes

```bash
# Per-file output (current)
spec/arguments_spec.sh spec/commons_spec.sh

# Per-example output (new)
spec/arguments_spec.sh:@1:@2:@3 spec/commons_spec.sh:@1:@2

# Hybrid output
spec/arguments_spec.sh spec/installation_spec.sh:@1-5 spec/installation_spec.sh:@6-10
```

## CI Workflow Changes

### Step 1: Run with Profiling

```yaml
- name: Run shellspec tests with profiling
  run: |
    CHUNK_ARGS=$(./bin/chunk-tests.sh 4 ${{ matrix.chunk }} --granularity=example)
    shellspec --profile $CHUNK_ARGS
```

### Step 2: Parse Example-Level Timing

```yaml
- name: Update timing cache
  run: |
    bun bin/junit/parse-test-timings.ts .test-timings.json report/*.xml --granularity=example
```

### Step 3: Enable Profiling in ShellSpec

The `--profile` flag enables per-test timing in JUnit XML output.

```yaml
# Current
shellspec --kcov $CHUNK_FILES

# Enhanced
shellspec --profile --kcov $CHUNK_FILES
```

## File Structure

All optimization scripts are located in `bin/junit/`:

```
bin/
├── chunk-tests.sh              # Main entry point (shell wrapper)
└── junit/
    ├── package.json            # Bun dependencies
    ├── calculate-optimal-chunks.ts  # Bin-packing algorithm
    └── parse-test-timings.ts   # JUnit XML parser
```

### File Descriptions

1. **`bin/junit/calculate-optimal-chunks.ts`** - Bin-packing algorithm for distributing tests
2. **`bin/junit/parse-test-timings.ts`** - JUnit XML parser for timing extraction
3. **`bin/chunk-tests.sh`** - Shell wrapper that calls the TypeScript scripts
4. **`.github/workflows/shellspec.yaml`** - CI workflow using the chunk scripts

## Migration Strategy

### Phase 1: Backward Compatible

1. Implement v2.0 timing format with fallback to v1.0
2. Add `--granularity=example` as opt-in flag
3. Default remains `--granularity=file`

### Phase 2: Collect Data

1. Enable `--profile` in CI
2. Build example-level timing history
3. Monitor overhead of profiling

### Phase 3: Enable Hybrid

1. Switch default to `--granularity=hybrid`
2. Auto-split large files when beneficial
3. Monitor for improved balance

## Performance Considerations

### Profiling Overhead

`--profile` adds ~5-10% overhead to test execution due to timing instrumentation.

**Mitigation**: Use `--boost` flag which profiles without displaying results:
```bash
shellspec --boost --kcov $CHUNK_FILES
```

### Example Discovery Overhead

`shellspec --list examples` requires parsing all spec files.

**Mitigation**: Cache example list in timing data file.

### Large Number of Examples

With 400+ examples, output command line could exceed shell limits.

**Mitigation**: 
- Use file-based passing: `shellspec @chunk-0-examples.txt`
- Collapse consecutive IDs: `spec.sh:@1:@2:@3` → `spec.sh:@1-3`

## Expected Improvement

### Current State (Per-File)
- Largest file: `installation_spec.sh` (98 tests, ~2.5s)
- Can't split across chunks
- Chunk imbalance: up to 1.10x

### After Enhancement (Per-Example)
- Split large files across chunks
- Better load balancing
- Expected imbalance: <1.05x

### Wall-clock Estimate
- Current: 3.6 min (with per-file optimization)
- After: ~3.2 min (with per-example optimization)
- **Improvement: ~11% faster**

## Implementation Checklist

- [x] Update `parse-test-timings.ts` for v2.0 format with `--granularity` flag
- [x] Update `calculate-optimal-chunks.ts` with `--granularity` flag (file/example/hybrid)
- [x] Update `chunk-tests.sh` wrapper to pass through granularity option
- [ ] Add `--profile` to CI workflow for per-example timing collection
- [ ] Update CI to use `--granularity=example` or `--granularity=hybrid`
- [ ] Update documentation with usage examples
- [ ] Test with example-level output
- [ ] Measure improvement

## See Also

- [PARALLEL_TESTING_OPTIMIZATION.md](./PARALLEL_TESTING_OPTIMIZATION.md) - Original per-file optimization
- [ShellSpec Documentation](https://shellspec.info/) - Official docs
