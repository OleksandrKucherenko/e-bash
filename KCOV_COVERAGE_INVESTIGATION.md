# Kcov Coverage Investigation

## Problem Statement

User expected to see coverage for `bin/install.e-bash.sh` and other scripts on Codecov, but only seeing ~5 files instead of the expected ~25 files.

## Root Cause Identified ✅

The issue is **NOT with kcov configuration**. The kcov patterns are correct:
```bash
--kcov-options "--include-pattern=.scripts/,bin/"
```

**The actual problem:** Kcov only captures coverage for scripts that are **sourced** (via `Include` directive), NOT for scripts that are **executed** as external commands (via `When run`).

## Files in Repository

### Total Scripts
- **10 files in `.scripts/`**
- **15 files in `bin/`**
- **25 total script files**
- **~10,226 lines of code**

### Coverage Breakdown

#### ✅ Files WITH Coverage (5 files)
Scripts tested using `Include` directive (sourced into shellspec):

1. `.scripts/_arguments.sh` - spec/arguments_spec.sh (uses `Include`)
2. `.scripts/_commons.sh` - spec/commons_spec.sh (uses `Include`)
3. `.scripts/_dependencies.sh` - spec/dependencies_spec.sh (uses `Include`)
4. `.scripts/_logger.sh` - spec/logger_spec.sh (uses `Include`)
5. `bin/git.semantic-version.sh` - spec/git_semantic_version_spec.sh (uses `Include`)

#### ⚠️ Files WITH Tests but NO Coverage (2 files)
Scripts tested using `When run` command (executed as subprocess):

1. `bin/install.e-bash.sh`
   - Tested by: spec/installation_spec.sh (1048 lines)
   - Test count: 60 `When run` invocations
   - **Why no coverage:** Executed as external process, not instrumented by kcov

2. `bin/version-up.v2.sh`
   - Tested by: spec/version-up_spec.sh (1252 lines)
   - Test count: 43 `When run` invocations
   - **Why no coverage:** Executed as external process, not instrumented by kcov

#### ❌ Files WITHOUT Tests or Coverage (18 files)

**.scripts/ without coverage:**
- `_colors.sh`
- `_self-update.sh`
- `_semver.sh`
- `_setup_gnu_aliases.sh`
- `_setup_gnu_symbolic_links.sh`
- `_tmux.sh`

**bin/ without coverage:**
- `git.conventional.commits.sh`
- `git.files.sh`
- `git.graph.sh`
- `git.log.sh`
- `git.sync.by-patches.sh`
- `git.verify.all.commits.sh`
- `ipv6.sh`
- `qa_validate_envrc.sh`
- `tree.sh`
- `un-link.sh`
- `version-up.sh`
- `vhd.sh`

## Technical Explanation

### How Kcov Works with Shellspec

When `shellspec --kcov` runs:

1. Kcov instruments the shellspec process
2. Any script **sourced** via `Include` is executed within the instrumented process → **coverage captured** ✅
3. Any script **executed** via `When run` spawns a separate process → **coverage NOT captured** ❌

### Example from Specs

**✅ WORKS (has coverage):**
```bash
# spec/arguments_spec.sh:21
Include ".scripts/_arguments.sh"
```

**❌ DOESN'T WORK (no coverage):**
```bash
# spec/installation_spec.sh:112
When run ./install.e-bash.sh
```

## Solutions

### Option 1: Kcov Wrapper for External Commands (RECOMMENDED)

Wrap external script executions with kcov in the spec files:

```bash
# Before (no coverage):
When run ./install.e-bash.sh install

# After (with coverage):
When run kcov --include-pattern=bin/ coverage_install ./install.e-bash.sh install
```

**Pros:**
- Captures coverage for externally executed scripts
- Minimal changes needed
- Works for integration tests

**Cons:**
- Requires kcov available during test run
- More complex test setup
- Coverage data in separate directories needs merging

### Option 2: Refactor Scripts to be Testable via Include

Extract functions from main scripts into separate files that can be sourced:

```bash
# bin/install.e-bash.sh → split into:
# bin/install.e-bash.sh (entry point, thin wrapper)
# .scripts/_install_functions.sh (all functions, can be sourced)

# Then in spec:
Include ".scripts/_install_functions.sh"
```

**Pros:**
- Works with existing kcov setup
- Improves code organization
- Functions become reusable

**Cons:**
- Significant refactoring required
- Changes production code for test purposes
- Time-consuming

### Option 3: Accept Current Coverage and Document

Document that only ~20% of scripts (5/25) have unit test coverage, and focus on:
- Integration tests for scripts like install.e-bash.sh
- Manual testing for utility scripts
- Coverage only for core library scripts

**Pros:**
- No changes needed
- Reflects actual unit test coverage
- Clear documentation of what's covered

**Cons:**
- Codecov shows low coverage percentage
- Missing coverage for well-tested scripts

### Option 4: Use Different Coverage Tool

Try `bashcov` or other tools that might handle subprocess execution:

**Pros:**
- Might capture subprocess coverage
- Different approach

**Cons:**
- Requires tool evaluation
- May have same limitations
- Additional setup complexity

## Recommended Action

**Short term (immediate):**
- Document the limitation in README
- Update COVERAGE_ANALYSIS.md to reflect 5 files with coverage
- Add note in codecov.yml about coverage scope

**Medium term:**
- For critical scripts like `install.e-bash.sh`, consider Option 1 (kcov wrapper) if coverage metrics are needed
- Add unit tests for untested .scripts/ files (6 missing)
- Use `Include` pattern for new spec files when possible

**Long term:**
- Evaluate if refactoring (Option 2) makes sense for commonly tested scripts
- Consider integration test coverage separately from unit test coverage

## Conclusion

The current setup correctly captures coverage for **unit-tested** scripts (those sourced via `Include`). The missing coverage for `install.e-bash.sh` and `version-up.v2.sh` is due to **integration testing approach** (external execution) which kcov doesn't instrument by default.

This is a **testing pattern limitation**, not a configuration issue. The kcov patterns are working correctly for the intended use case (unit tests of sourced scripts).

**Current Coverage:** 5/25 files (20%) - Accurately reflects unit test coverage
**Actual Test Coverage:** 7/25 files (28%) - Including integration-tested scripts
