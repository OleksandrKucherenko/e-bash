# E-Bash JUnit Tools

Tools for parsing JUnit XML test reports and calculating optimal test chunk distribution for parallel CI execution.

## Overview

This package provides:

1. **`parse-test-timings.ts`** - Parse JUnit XML reports to extract timing data
2. **`calculate-optimal-chunks.ts`** - Distribute tests across CI chunks using bin-packing

## Installation

```bash
	cd .github/scripts/junit
bun install
```

## Usage

### Parse Timing Data from JUnit XML

```bash
# File-level timing (v1.0 format)
bun parse-test-timings.ts .test-timings.json report/*.xml

# Example-level timing (v2.0 format)
bun parse-test-timings.ts .test-timings.json report/*.xml --granularity=example
```

### Calculate Optimal Chunks

```bash
# Get spec files for chunk 0 of 4
bun calculate-optimal-chunks.ts .test-timings.json 4 0

# With example-level granularity
bun calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=example

# Hybrid mode (auto-split large files)
bun calculate-optimal-chunks.ts .test-timings.json 4 0 --granularity=hybrid
```

## Testing

Run all unit tests:

```bash
bun test
```

Run tests in watch mode:

```bash
bun test --watch
```

Run with coverage:

```bash
bun test --coverage
```

Type checking:

```bash
bun run typecheck
```

## Project Structure

```
.github/scripts/junit/
├── package.json              # Package configuration
├── tsconfig.json             # TypeScript configuration
├── parse-test-timings.ts     # Main timing parser script
├── calculate-optimal-chunks.ts  # Main chunk calculator script
├── lib/
│   ├── index.ts              # Library exports
│   ├── parser.ts             # JUnit XML parsing functions
│   └── chunker.ts            # Bin-packing algorithm and utilities
├── __tests__/
│   ├── parser.test.ts        # Parser unit tests
│   ├── chunker.test.ts       # Chunker unit tests
│   └── integration.test.ts   # End-to-end integration tests
└── __fixtures__/
    ├── sample-results.xml    # Sample JUnit XML for testing
    ├── sample-results-2.xml  # Additional sample XML
    └── empty-results.xml     # Edge case: empty results
```

## Library API

The core functions are exported from `lib/` for use in other scripts:

```typescript
import {
  // Parser functions
  normalizeSpecPath,
  parseJUnitXMLContent,
  parseJUnitXMLContentExamples,
  mergeTimingsV1,
  mergeExamplesToV2,
  
  // Chunker functions
  binPackingFFD,
  buildFileItemsFromTimings,
  collapseExampleOutput,
  parseChunkArgs,
} from "./lib";
```

## Timing Data Formats

### V1.0 (File-level)

```json
{
  "version": "1.0",
  "description": "Test execution timings",
  "timings": {
    "spec/arguments_spec.sh": 2.345,
    "spec/commons_spec.sh": 1.567
  },
  "total_time": 3.912,
  "file_count": 2,
  "source_files": ["results.xml"]
}
```

### V2.0 (Example-level)

```json
{
  "version": "2.0",
  "granularity": "example",
  "description": "Per-example timing data",
  "timings": {
    "spec/arguments_spec.sh": {
      "total": 2.345,
      "examples": {
        "@1": { "time": 0.234, "name": "first test" },
        "@2": { "time": 0.156, "name": "second test" }
      }
    }
  },
  "total_time": 2.345,
  "file_count": 1,
  "example_count": 2,
  "source_files": ["results.xml"]
}
```

## Algorithm

The chunk distribution uses the **First Fit Decreasing (FFD)** bin-packing algorithm:

1. Sort test items by weight (execution time) in descending order
2. For each item, assign it to the bin (chunk) with the minimum current weight
3. This minimizes the maximum chunk execution time, improving CI parallelism

## License

Part of the e-bash project.
