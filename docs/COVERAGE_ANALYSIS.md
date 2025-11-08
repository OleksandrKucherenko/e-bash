# Code Coverage Analysis: git.semantic-version.sh

## Summary

**Total Functions:** 29
**Functions with Unit Tests:** 16
**Functions without Direct Tests:** 13
**Estimated Coverage:** ~55% (unit tests) + integration tests

---

## ✅ Functions with Unit Tests (16)

### Core Logic Functions
1. **gitsv:parse_commit_type()** - Parses commit message type
   - Tests: 8 test cases covering all conventional types
   - Status: ✅ Well covered

2. **gitsv:has_breaking_change()** - Detects breaking changes
   - Tests: 4 test cases (BREAKING CHANGE:, !, body)
   - Status: ✅ Well covered

3. **gitsv:determine_bump()** - Determines version bump type
   - Tests: 14 test cases (feat, fix, breaking, none, custom keywords)
   - Status: ✅ Excellent coverage

4. **gitsv:bump_version()** - Bumps version number
   - Tests: 6 test cases (major, minor, patch, none, edge cases)
   - Status: ✅ Well covered

5. **gitsv:version_diff()** - Calculates version difference
   - Tests: 5 test cases (major, minor, patch, complex, none)
   - Status: ✅ Well covered

### Utility Functions
6. **gitsv:format_output_line()** - Formats markdown table row
   - Tests: 4 test cases (basic, defaults, long messages, long tags)
   - Status: ✅ Well covered

7. **gitsv:get_first_commit()** - Gets repository's first commit
   - Tests: 1 test case (validates output)
   - Status: ✅ Covered

8. **gitsv:get_commit_tags()** - Gets tags for a commit
   - Tests: 2 test cases (no tags, invalid hash)
   - Status: ⚠️ Could test positive case with tags

9. **gitsv:extract_semver_from_tag()** - Extracts semver from tag string
   - Tests: 12 test cases (v prefix, path prefix, pre-release, build, invalid)
   - Status: ✅ Excellent coverage

10. **gitsv:extract_semvers_from_tags()** - Extracts multiple semvers
    - Tests: 5 test cases (single, multiple, filter, mixed)
    - Status: ✅ Well covered

11. **gitsv:get_last_version_tag()** - Gets latest version tag
    - Tests: 2 test cases (has tags, strips v prefix)
    - Status: ✅ Covered (1 skipped)

12. **gitsv:get_last_version_tag_commit()** - Gets commit for latest tag
    - Tests: 1 test case (returns hash)
    - Status: ✅ Covered

13. **gitsv:get_branch_start_commit()** - Gets branch divergence point
    - Tests: 1 test case (returns valid hash)
    - Status: ✅ Covered

14. **gitsv:get_commit_from_n_versions_back()** - Gets commit N versions back
    - Tests: 2 test cases (exists, overflow fallback)
    - Status: ✅ Well covered

### Configuration Functions
15. **gitsv:add_keyword()** - Adds custom keyword mapping
    - Tests: 4 test cases (add, reject invalid, multiple)
    - Status: ✅ Well covered

16. **gitsv:list_keywords()** - Lists configured keywords
    - Tests: Tested indirectly via integration test (--list-keywords)
    - Status: ✅ Covered

---

## ❌ Functions WITHOUT Direct Unit Tests (13)

### Processing Functions
1. **gitsv:process_commits()** - Main commit processing loop
   - Coverage: ✅ Integration tests only
   - Risk: HIGH - Core logic, 200+ lines
   - Recommendation: Add unit tests for edge cases

2. **gitsv:get_start_commit()** - Determines starting commit based on strategy
   - Coverage: ✅ Integration tests only
   - Risk: MEDIUM - Strategy selection logic
   - Recommendation: Add tests for all strategies

3. **gitsv:count_total_commits()** - Counts commits in repo
   - Coverage: ✅ Called by other functions
   - Risk: LOW - Simple git command wrapper

4. **gitsv:count_branches()** - Counts branches in repo
   - Coverage: ✅ Called by determine_optimal_strategy
   - Risk: LOW - Simple git command wrapper

5. **gitsv:determine_optimal_strategy()** - Auto-selects processing strategy
   - Coverage: ✅ Integration tests only
   - Risk: MEDIUM - Decision logic
   - Recommendation: Add unit tests for thresholds

### Output Functions
6. **gitsv:print_header()** - Prints markdown table header
   - Coverage: ✅ Integration tests only
   - Risk: LOW - Static output

7. **gitsv:print_footer()** - Prints markdown table footer
   - Coverage: ✅ Integration tests only
   - Risk: LOW - Static output

8. **print:help()** - Displays help text
   - Coverage: ✅ Integration test (--help)
   - Risk: LOW - Static text

### CLI Functions
9. **parse:cli:arguments()** - Parses command-line arguments
   - Coverage: ✅ 7 unit tests (--help, --initial-version, --add-keyword, invalid)
   - Risk: LOW - Well tested
   - Note: Listed as "not tested" but actually has good coverage

### Control Functions
10. **on_interrupt()** - Handles Ctrl+C
    - Coverage: ❌ No tests
    - Risk: MEDIUM - Error handling
    - Recommendation: Add test (difficult to test interrupts)

11. **cleanup_tmux_progress()** - Cleans up tmux resources
    - Coverage: ❌ No tests
    - Risk: LOW - Called by on_exit
    - Recommendation: Add unit test for tmux cleanup

12. **on_exit()** - Exit handler
    - Coverage: ❌ No tests
    - Risk: LOW - Cleanup logic
    - Recommendation: Add unit test for different exit codes

13. **main()** - Entry point
    - Coverage: ✅ Integration tests only
    - Risk: MEDIUM - Orchestration logic
    - Recommendation: Add unit tests for edge cases

---

## 🧪 Integration Tests (4)

1. **processes commits from recent history**
   - Runs: `--from-commit HEAD~5 --initial-version 1.0.0`
   - Validates: Output includes "Semantic Version History" and "Summary:"

2. **works with --from-last-tag strategy**
   - Runs: `--from-last-tag --initial-version 1.0.0`
   - Validates: Script succeeds and outputs table

3. **shows tag column in output**
   - Runs: `--from-commit HEAD~10 --initial-version 1.0.0`
   - Validates: Output includes "| Tag |" column

4. **validates not in git repository**
   - Status: SKIPPED (requires non-git directory)

---

## 🔍 Coverage Gaps

### Critical Gaps

1. **Main Processing Loop** (`gitsv:process_commits`)
   - Edge cases not tested:
     - Empty commit list
     - Commits with multiple tags
     - Commits with conflicting bump types
     - Interrupt handling mid-processing
     - Tmux progress display logic

2. **Strategy Selection** (`gitsv:get_start_commit`)
   - Not tested:
     - All strategy branches (from-first-commit, from-last-tag, etc.)
     - Strategy fallback logic
     - Invalid strategy handling

3. **Tmux Integration**
   - Not tested:
     - FIFO creation/cleanup
     - Progress bar rendering
     - Tmux pane management
     - WSL2 retry logic

### Minor Gaps

1. **Error Handling**
   - Missing tests for:
     - Invalid git repository
     - Network errors (if any)
     - Filesystem errors (FIFO creation)

2. **Output Validation**
   - Integration tests check presence, not correctness
   - Should validate actual version calculations

---

## 📊 Coverage by Category

| Category | Tested | Total | Coverage |
|----------|--------|-------|----------|
| **Core Logic** | 5/5 | 5 | 100% ✅ |
| **Utilities** | 9/10 | 10 | 90% ✅ |
| **Processing** | 0/5 | 5 | 0% ❌ |
| **CLI/Control** | 1/5 | 5 | 20% ⚠️ |
| **Output** | 1/3 | 3 | 33% ⚠️ |
| **Integration** | 3/4 | 4 | 75% ✅ |
| **TOTAL** | 16/29 | 29 | **55%** |

---

## 🎯 Recommendations

### High Priority (Add These Tests)

1. **gitsv:process_commits() edge cases**
   ```bash
   It "handles empty commit list"
   It "handles commits with multiple tags"
   It "correctly processes interrupted sessions"
   ```

2. **gitsv:get_start_commit() strategies**
   ```bash
   It "uses from-first-commit strategy"
   It "uses from-last-tag strategy"
   It "uses from-last-n-versions strategy"
   It "uses from-commit strategy"
   ```

3. **Error scenarios**
   ```bash
   It "fails gracefully when not in git repo"
   It "handles FIFO creation failure"
   It "handles invalid initial version"
   ```

### Medium Priority

1. **Tmux integration** (if testable)
   - Test FIFO creation/cleanup
   - Test progress bar generation
   - Test WSL2 retry logic

2. **Output validation**
   - Validate actual version calculations in integration tests
   - Test summary statistics

### Low Priority

1. **print_header/print_footer** - Already validated by integration tests
2. **count_total_commits/count_branches** - Simple wrappers, low value

---

## 🚀 Current State: GOOD

**Strengths:**
- ✅ Core logic (parsing, bumping, diffing) is 100% tested
- ✅ Utility functions are 90% tested
- ✅ Integration tests cover happy paths
- ✅ Regression tests document fixed bugs

**Weaknesses:**
- ❌ Main processing loop lacks unit tests
- ❌ Strategy selection not tested
- ❌ Error handling not tested
- ⚠️ Tmux integration not tested

**Overall:** The most critical logic (version calculation) is well-tested. The gaps are in orchestration, error handling, and integration features.

---

## 📈 CI Coverage Report

To see actual line coverage, run:
```bash
shellspec --kcov spec/git_semantic_version_spec.sh
```

Then open: `coverage/index.html`

Expected kcov coverage (estimate):
- **Lines:** ~65-70% (unit tests + integration tests)
- **Branches:** ~60% (missing error paths)
- **Functions:** ~55% (16/29 directly tested)
