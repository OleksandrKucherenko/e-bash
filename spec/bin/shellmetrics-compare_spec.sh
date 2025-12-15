#!/usr/bin/env bash
# shell: bash altsh=shellspec
# shellcheck shell=bash
# shellcheck disable=SC2329,SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2025-12-14
## Version: 1.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash

eval "$(shellspec - -c) exit 1"

Describe '.github/scripts/shellmetrics-compare.sh /'
  # Include the script using relative path from project root
  Include .github/scripts/shellmetrics-compare.sh

  BeforeEach 'setup_test_environment'
  AfterEach 'cleanup_test_environment'

  setup_test_environment() {
    export TEST_DIR=$(mktemp -d)
    export ORIGINAL_DIR=$(pwd)
    # Use an executable copy of the script under TEST_DIR so specs don't
    # depend on checkout filemode support (e.g., core.filemode=false).
    export SHELLMETRICS_SCRIPT="${ORIGINAL_DIR}/.github/scripts/shellmetrics-compare.sh"
    export FIXTURES_DIR="${ORIGINAL_DIR}/spec/fixtures"
    cd "$TEST_DIR"

    # Disable colors for consistent test output
    export NO_COLOR=1
    unset DEBUG

    cp "$SHELLMETRICS_SCRIPT" "$TEST_DIR/shellmetrics-compare.sh"
    chmod +x "$TEST_DIR/shellmetrics-compare.sh" 2>/dev/null || true
    export SHELLMETRICS_SCRIPT="$TEST_DIR/shellmetrics-compare.sh"

    # Mock shellmetrics command to avoid external dependencies
    export PATH="$TEST_DIR/mock-bin:$PATH"
    mkdir -p "$TEST_DIR/mock-bin"

    # Create a mock shellmetrics that generates test data
    cat > "$TEST_DIR/mock-bin/shellmetrics" <<'MOCK_SHELLMETRICS'
#!/bin/bash
# Mock shellmetrics for testing
if [[ "$1" == "--csv" ]]; then
  shift
  for file in "$@"; do
    if [[ -f "$file" ]]; then
      # Generate mock CSV output for each file
      echo "file,func,lineno,lloc,ccn,lines,comment,blank"
      echo "\"$file\",\"<begin>\",1,0,0,100,10,5"
      echo "\"$file\",\"test_function\",10,20,3,30,2,1"
      echo "\"$file\",\"<end>\",100,0,0,100,10,5"
    fi
  done
fi
MOCK_SHELLMETRICS
    chmod +x "$TEST_DIR/mock-bin/shellmetrics"
  }

  cleanup_test_environment() {
    cd "$ORIGINAL_DIR" >/dev/null
    rm -rf "$TEST_DIR" 2>/dev/null || true
    unset TEST_DIR ORIGINAL_DIR SHELLMETRICS_SCRIPT FIXTURES_DIR
  }

  # Helper to create empty CSV
  create_empty_metrics() {
    local file="$1"
    echo "file,func,lineno,lloc,ccn,lines,comment,blank" > "$file"
  }

  # Helper to create malformed CSV
  create_malformed_csv() {
    local file="$1"
    cat > "$file" <<'CSV'
file,func,lineno,lloc,ccn
invalid,data,without,enough,columns
CSV
  }

  Context 'calculate_totals function /'
    It 'calculates totals from valid CSV'
      When call calculate_totals "$FIXTURES_DIR/shellmetrics-base.csv"
      The output should match pattern "2,*,*,*"
      The status should be success
    End

    It 'handles CSV with single file'
      When call calculate_totals "$FIXTURES_DIR/shellmetrics-single.csv"
      The output should match pattern "1,*,*,*"
      The status should be success
    End

    It 'handles empty CSV (header only)'
      When call calculate_totals "$FIXTURES_DIR/shellmetrics-empty.csv"
      The output should match pattern "0,0,0,0"
      The status should be success
    End

    It 'calculates correct NLOC (lines - comment - blank)'
      # Base metrics: test1.sh has 100-10-5=85 NLOC, test2.sh has 50-5-2=43 NLOC
      # Total NLOC should be 128
      When call calculate_totals "$FIXTURES_DIR/shellmetrics-base.csv"
      The output should match pattern "2,128,*,*"
    End

    It 'calculates correct LLOC'
      # Base metrics: test1.sh has 20+15=35 LLOC, test2.sh has 10 LLOC
      # Total LLOC should be 45
      When call calculate_totals "$FIXTURES_DIR/shellmetrics-base.csv"
      The output should match pattern "2,128,45,*"
    End

    It 'calculates correct CCN'
      # Base metrics: test1.sh has 3+2=5 CCN, test2.sh has 1 CCN
      # Total CCN should be 6
      When call calculate_totals "$FIXTURES_DIR/shellmetrics-base.csv"
      The output should eq "2,128,45,6"
    End
  End

  Context 'get_file_metrics function /'
    It 'extracts file-level metrics'
      When call get_file_metrics "$FIXTURES_DIR/shellmetrics-base.csv"
      The output should include ".scripts/test1.sh"
      The output should include "bin/test2.sh"
      The status should be success
    End

    It 'removes quotes from file names'
      When call get_file_metrics "$FIXTURES_DIR/shellmetrics-base.csv"
      The output should not include '"'
    End

    It 'outputs sorted file list'
      When call get_file_metrics "$FIXTURES_DIR/shellmetrics-base.csv"
      # Files are sorted alphabetically: .scripts < bin
      The line 2 of output should include ".scripts/test1.sh"
      The line 1 of output should include "bin/test2.sh"
    End

    It 'handles files with special characters in paths'
      When call get_file_metrics "$FIXTURES_DIR/shellmetrics-special-chars.csv"
      The output should include "path/with spaces/file.sh"
    End
  End

  # Note: format_delta is an internal function defined inside compare_metrics
  # It cannot be tested directly. Its behavior is tested through compare_metrics output.

  Context 'compare_metrics function - basic operation /'
    It 'generates markdown report successfully'
      When call compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/report.md" should be file
    End

    It 'creates report with proper markdown structure'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      The output should include "## 📊 ShellMetrics Code Complexity Report"
      The output should include "### Summary"
      The output should include "| Metric | Base | Current | Change |"
    End

    It 'includes all key metrics in summary'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      The output should include "**Files Analyzed**"
      The output should include "**NLOC**"
      The output should include "**LLOC**"
      The output should include "**CCN**"
      The output should include "**Avg Complexity/File**"
    End

    It 'includes metrics explanation'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      The output should include "### 📈 Metrics Explained"
      The output should include "Non-comment lines of code"
      The output should include "Cyclomatic Complexity"
    End

    It 'includes file-level changes section'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      The output should include "### 📁 Changes by File"
    End

    It 'includes footer with ShellMetrics link'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      The output should include "ShellMetrics"
      The output should include "https://github.com/shellspec/shellmetrics"
    End
  End

  Context 'compare_metrics - error handling /'
    It 'handles missing base file gracefully'
      When run compare_metrics "/nonexistent/base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" 2>&1
      The status should be success
      The output should include "Warning: Base metrics file not found"
      The output should include "Creating empty baseline"
    End

    It 'handles missing current file gracefully'
      When run compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "/nonexistent/current.csv" "$TEST_DIR/report.md" 2>&1
      The status should be success
      The output should include "Warning: Current metrics file not found"
      The output should include "Creating empty metrics file"
    End

    It 'handles missing output file path gracefully'
      When call compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/metrics-comparison.md" should be file
    End

    It 'handles empty base metrics'
      When call compare_metrics "$FIXTURES_DIR/shellmetrics-empty.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/report.md" should be file
    End

    It 'handles empty current metrics'
      When call compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-empty.csv" "$TEST_DIR/report.md"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/report.md" should be file
    End

    It 'handles both files being empty'
      When call compare_metrics "$FIXTURES_DIR/shellmetrics-empty.csv" "$FIXTURES_DIR/shellmetrics-empty.csv" "$TEST_DIR/report.md"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/report.md" should be file
    End
  End

  Context 'compare_metrics - change detection /'
    It 'detects file additions'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      # base has 2 files, current has 3 files
      The output should include "| **Files Analyzed** | 2 | 3 |"
    End

    It 'detects NLOC increases'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      # Should show increase in NLOC (base: 128, current: 171 based on fixtures)
      The output should match pattern "*NLOC*128*171*"
    End

    It 'reports changes with delta indicators'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      # Should contain delta with + sign
      The output should include "+1"
    End

    It 'shows file-specific changes'
      compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/report.md" >/dev/null 2>&1
      When call cat "$TEST_DIR/report.md"
      The output should include ".scripts/test1.sh"
      The output should include "bin/test3.sh"
    End

	    It 'detects no changes when files are identical'
	      When call compare_metrics "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-base.csv" "$TEST_DIR/report.md"
	      The output should include "Comparison report saved to:"
	      The status should be success
	      The contents of file "$TEST_DIR/report.md" should include "No changes detected"
	    End

	    It 'handles negative per-file deltas without exiting'
	      When run script "$SHELLMETRICS_SCRIPT" compare "$FIXTURES_DIR/shellmetrics-negative-base.csv" "$FIXTURES_DIR/shellmetrics-negative-current.csv" negative-report.md
	      The status should be success
	      The output should include "Comparison report saved to:"
	      The path negative-report.md should be file
	      The contents of file negative-report.md should include "(-5)"
	    End
	  End

  Context 'main function - command dispatcher /'
    It 'handles help command'
      When call main help
      The output should include "Usage:"
      The output should include "Commands:"
      The output should include "collect"
      The output should include "compare"
      The status should be success
    End

    It 'handles --help flag'
      When call main --help
      The output should include "Usage:"
      The status should be success
    End

    It 'handles -h flag'
      When call main -h
      The output should include "Usage:"
      The status should be success
    End

    It 'shows help when no command provided'
      When call main
      The output should include "Usage:"
      The status should be success
    End

    It 'handles unknown command'
      When run main invalid_command
      The output should include "Unknown command"
      The output should include "invalid_command"
      The status should be failure
    End
  End

  Context 'collect command /'
    It 'creates output file with header'
      # Create a test shell script
      mkdir -p .scripts
      cat > .scripts/test-script.sh <<'SCRIPT'
#!/bin/bash
test_function() {
  echo "test"
}
SCRIPT
      chmod +x .scripts/test-script.sh

      When call main collect "$TEST_DIR/output.csv"
      The output should include "Metrics collected:"
      The status should be success
      The path "$TEST_DIR/output.csv" should be file
    End

    It 'uses default filename when not provided'
      mkdir -p .scripts
      echo '#!/bin/bash' > .scripts/test.sh
      
      When call main collect
      The output should include "Saved to: metrics.csv"
      The path metrics.csv should be file
      The status should be success
    End

    It 'creates CSV with proper header'
      mkdir -p .scripts bin
      echo '#!/bin/bash' > .scripts/test.sh
      echo 'function test() { echo "v1"; }' >> .scripts/test.sh
      
      main collect "$TEST_DIR/test-collect.csv" >/dev/null 2>&1
      
      When call head -n 1 "$TEST_DIR/test-collect.csv"
      The output should include "file,func,lineno,lloc,ccn,lines,comment,blank"
      The status should be success
    End
  End

  Context 'compare command /'
    It 'executes compare with minimal arguments'
      When call main compare "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv"
      The output should include "Comparison report saved to:"
      The status should be success
    End

    It 'executes compare with all arguments'
      When call main compare "$FIXTURES_DIR/shellmetrics-base.csv" "$FIXTURES_DIR/shellmetrics-current.csv" "$TEST_DIR/custom-report.md"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/custom-report.md" should be file
    End

    It 'uses default filenames when arguments missing'
      # Create test files with default names in current directory
      cp "$FIXTURES_DIR/shellmetrics-base.csv" base-metrics.csv
      cp "$FIXTURES_DIR/shellmetrics-current.csv" current-metrics.csv
      
      When call main compare
      The output should include "Comparison report saved to:"
      The status should be success
    End
  End

  Context 'edge cases and robustness /'
    It 'handles very large CSV files'
      # Create a large CSV with many entries
      {
        echo "file,func,lineno,lloc,ccn,lines,comment,blank"
        for i in {1..100}; do
          echo "\"file${i}.sh\",\"<begin>\",1,0,0,100,10,5"
          echo "\"file${i}.sh\",\"func${i}\",10,20,3,30,2,1"
          echo "\"file${i}.sh\",\"<end>\",100,0,0,100,10,5"
        done
      } > "$TEST_DIR/large.csv"

      When call calculate_totals "$TEST_DIR/large.csv"
      The status should be success
      The output should match pattern "100,*,*,*"
    End

    It 'handles files with zero metrics'
      cat > "$TEST_DIR/zeros.csv" <<'CSV'
file,func,lineno,lloc,ccn,lines,comment,blank
"empty.sh","<begin>",1,0,0,0,0,0
"empty.sh","<end>",1,0,0,0,0,0
CSV
      When call calculate_totals "$TEST_DIR/zeros.csv"
      The output should eq "0,0,0,0"
      The status should be success
    End

    It 'handles files with very high complexity'
      When call calculate_totals "$FIXTURES_DIR/shellmetrics-complex.csv"
      The status should be success
      The output should match pattern "1,*,*,150"
    End

    It 'handles division by zero when no files exist'
      When call compare_metrics "$FIXTURES_DIR/shellmetrics-empty.csv" "$FIXTURES_DIR/shellmetrics-empty.csv" "$TEST_DIR/div-zero.md"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/div-zero.md" should be file
    End
  End

  Context 'ensure_shellmetrics function /'
    It 'checks for shellmetrics availability'
      # Our mock shellmetrics is already in PATH
      When call ensure_shellmetrics
      The status should be success
    End
  End

  Context 'integration tests /'
    It 'full workflow: collect and compare'
      # Create test shell scripts
      mkdir -p .scripts
      cat > .scripts/workflow-test.sh <<'SHELL'
#!/bin/bash
process() {
  echo "processing $1"
}
SHELL

      # Collect base
      main collect base-workflow.csv >/dev/null 2>&1
      
      # Modify script
      echo 'new_function() { echo "new"; }' >> .scripts/workflow-test.sh

      # Collect current
      main collect current-workflow.csv >/dev/null 2>&1

      # Compare
      When call main compare base-workflow.csv current-workflow.csv workflow-comparison.md
      The output should include "Comparison report saved to:"
      The status should be success
      The path workflow-comparison.md should be file
    End
  End

  Context 'script execution modes /'
    It 'can be sourced without execution'
      # With source guard, script should not execute when sourced
      When run source "$SHELLMETRICS_SCRIPT"
      The status should be success
      The output should be blank
    End

    It 'executes when run directly with help'
      When run script "$SHELLMETRICS_SCRIPT" help
      The output should include "Usage:"
      The status should be success
    End
  End

  Context 'CI failure reproduction /'
    # Reproduce the exact CI failure scenario
    It 'handles CI workflow scenario with valid files'
      # Simulate the CI workflow steps
      # 1. Collect current metrics
      mkdir -p .scripts bin
      echo '#!/bin/bash' > .scripts/test.sh
      echo 'function test() { echo "test"; }' >> .scripts/test.sh
      echo '#!/bin/bash' > bin/test.sh
      echo 'function main() { echo "main"; }' >> bin/test.sh
      chmod +x bin/test.sh

      # Collect current metrics (like CI does)
      main collect current-metrics.csv >/dev/null 2>&1

      # Create base metrics (simulating previous branch state)
      cp current-metrics.csv "$TEST_DIR/base-metrics.csv"

      # 2. Run compare command exactly as CI does
      When run script "$SHELLMETRICS_SCRIPT" compare "$TEST_DIR/base-metrics.csv" current-metrics.csv metrics-report.md
      The output should include "Comparison report saved to:"
      The status should be success
      The path metrics-report.md should be file
    End

    It 'handles missing base metrics gracefully'
      # This is the likely CI failure - base metrics not collected properly
      touch current-metrics.csv
      echo "file,func,lineno,lloc,ccn,lines,comment,blank" > current-metrics.csv

      # Use a non-existent path within TEST_DIR (guaranteed not to exist)
      # Redirect stderr to stdout to capture warnings
      When run script "$SHELLMETRICS_SCRIPT" compare "$TEST_DIR/nonexistent-base.csv" current-metrics.csv metrics-report.md 2>&1
      The status should be success
      The output should include "Warning: Base metrics file not found"
    End

    It 'handles missing current metrics gracefully'
      # Create base file in TEST_DIR
      touch "$TEST_DIR/test-base.csv"
      echo "file,func,lineno,lloc,ccn,lines,comment,blank" > "$TEST_DIR/test-base.csv"

      # Use non-existent current file within TEST_DIR
      # Redirect stderr to stdout to capture warnings
      When run script "$SHELLMETRICS_SCRIPT" compare "$TEST_DIR/test-base.csv" "$TEST_DIR/nonexistent-current.csv" metrics-report.md 2>&1
      The status should be success
      The output should include "Warning: Current metrics file not found"
    End

    It 'handles worktree scenario from CI'
      # Simulate git worktree scenario using fixtures directly
      When run script "$SHELLMETRICS_SCRIPT" compare "$FIXTURES_DIR/shellmetrics-worktree-base.csv" "$FIXTURES_DIR/shellmetrics-worktree-current.csv" "$TEST_DIR/worktree-report.md"
      The output should include "Comparison report saved to:"
      The status should be success
      The path "$TEST_DIR/worktree-report.md" should be file
    End
  End

  Context 'portability /'
    It 'works with BSD-style mktemp (template required)'
      # Simulate BSD/macOS mktemp which fails when no template is provided.
      mkdir -p "$TEST_DIR/bsd-mktemp-bin"
      cat > "$TEST_DIR/bsd-mktemp-bin/mktemp" <<'MOCK_MKTEMP'
#!/bin/bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "mktemp: missing template" >&2
  exit 1
fi

if [[ "${1:-}" == --* ]]; then
  echo "mktemp: illegal option -- ${1#--}" >&2
  exit 1
fi

template="$1"
if [[ "$template" != *XXXXXX* ]]; then
  echo "mktemp: template must contain XXXXXX" >&2
  exit 1
fi

replacement=$(printf '%06d' "$RANDOM")
path="${template/XXXXXX/$replacement}"
mkdir -p "$(dirname "$path")" 2>/dev/null || true
: > "$path"
echo "$path"
MOCK_MKTEMP
      chmod +x "$TEST_DIR/bsd-mktemp-bin/mktemp"
      export PATH="$TEST_DIR/bsd-mktemp-bin:$PATH"

      cp "$FIXTURES_DIR/shellmetrics-base.csv" base.csv
      cp "$FIXTURES_DIR/shellmetrics-current.csv" current.csv

      When run script "$SHELLMETRICS_SCRIPT" compare base.csv current.csv report.md
      The status should be success
      The output should include "Comparison report saved to:"
      The path report.md should be file
    End
  End

  Context 'github actions debug logging /'
    It 'does not emit ::debug:: logs by default'
      When run script "$SHELLMETRICS_SCRIPT" help
      The output should include "Usage:"
      The output should not include "::debug::"
      The status should be success
    End

    It 'emits ::debug:: logs when ACTIONS_STEP_DEBUG is enabled'
      export ACTIONS_STEP_DEBUG=true
      When run script "$SHELLMETRICS_SCRIPT" help
      The output should include "Usage:"
      The output should include "::debug::"
      The status should be success
      unset ACTIONS_STEP_DEBUG
    End
  End

  Context 'debugging CI failure /'
    It 'validates CSV format from collect command'
      # Create actual shell scripts
      mkdir -p .scripts
      cat > .scripts/sample.sh <<'SHELL'
#!/bin/bash
process() {
  local input="$1"
  if [[ -z "$input" ]]; then
    return 1
  fi
  echo "processed: $input"
}
SHELL

      # Collect metrics first
      main collect debug-metrics.csv >/dev/null 2>&1
      
      # Then verify CSV structure by reading first line
      When call head -n 1 debug-metrics.csv
      The output should include "file,func,lineno,lloc,ccn,lines,comment,blank"
      The status should be success
    End

    It 'verifies compare works with collect output'
      mkdir -p .scripts bin
      echo '#!/bin/bash' > .scripts/test.sh
      echo 'test() { echo "v1"; }' >> .scripts/test.sh

      # Collect base
      main collect base.csv >/dev/null 2>&1
      
      # Modify script
      echo '#!/bin/bash' > .scripts/test.sh
      echo 'test() { echo "v2"; }' >> .scripts/test.sh
      echo 'new_func() { echo "new"; }' >> .scripts/test.sh

      # Collect current
      main collect current.csv >/dev/null 2>&1

      # Compare
      When call main compare base.csv current.csv comparison.md
      The output should include "Comparison report saved to:"
      The status should be success
      The path comparison.md should be file
    End
  End

End
