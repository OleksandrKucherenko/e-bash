# Lefthook Migration Plan

**Date:** 2026-01-25
**Project:** e-bash
**Current Version:** v1.16.2
**Status:** Ready for Implementation

---

## Executive Summary

This document outlines the migration plan from the current custom git hooks solution (`.githook/`) to [lefthook](https://github.com/evilmartians/lefthook), a modern, cross-platform git hooks manager. The migration will improve maintainability, testing, and cross-platform compatibility while preserving all existing functionality.

**Current Status:** Ready for Phase 1 (Preparation)
**Target Completion:** 2-3 weeks
**Risk Level:** Low (lefthook supports rollback via simple uninstall)

---

## Current Implementation Analysis

### Architecture Overview

**Location:** `.githook/` directory
**Setup:** Configured via `.envrc` with `git config core.hooksPath .githook`

### Hook Files (Current State)

1. **`pre-commit`** (Main Orchestrator)
   - Ensures GNU utilities from `bin/gnubin/` are available
   - Calls sub-hooks sequentially
   - Exits on first failure

2. **`pre-commit-copyright`** (Copyright Management)
   - Verifies copyright notices in `*.sh` files
   - Adds missing copyright headers
   - Validates copyright format (5 lines required)
   - Auto-detects project version via `bin/git.semantic-version.sh`
   - Uses GNU grep/sed/mv for processing
   - Creates numbered backups (`.~1~`, `.~2~`, etc.)
   - Exits with code 2 (wrong line count) or 3 (format mismatch)

3. **`pre-commit-copyright-last-revisit`** (Date Updates)
   - Updates "Last revisit" dates in modified files
   - Uses GNU grep/sed for pattern matching
   - Creates numbered backups
   - Preserves test fixtures

4. **`pre-commit.d/docs-update.sh`** (Documentation Integration)
   - Auto-generates documentation for modified `.scripts/*.sh` files
   - Uses `bin/e-docs.sh` for generation
   - Stages generated documentation files

### Key Features

- **GNU Tools Integration**: Custom `bin/gnubin/` for macOS compatibility (via `_gnu.sh`)
- **Test Mode**: `HOOK_TEST=1` environment variable for manual testing
- **Backup Strategy**: Numbered backups using GNU sed `--in-place`
- **File Filtering**: Processes only staged `.sh` files
- **Exit Codes**: Specific codes for different error types
- **Color Output**: Uses `tput` for colored terminal output

### Dependencies

- bash 5.x
- GNU grep (ggrep) - via `.scripts/_dependencies.sh`
- GNU sed (gsed) - via `.scripts/_dependencies.sh`
- GNU mv (gmv) - via `.scripts/_dependencies.sh`
- git
- tput (for colors)

---

## Migration Strategy

### Approach

**Incremental Migration with Parallel Testing**

Run both systems in parallel during a transition period to validate lefthook behavior before completely removing the old system.

### Phases

1. **Preparation** (Phase 1) - 1-2 days
   - Add lefthook to project dependencies
   - Create initial `lefthook.yml` configuration
   - Port hook scripts to `.lefthook/` directory
   - Document the new setup

2. **Parallel Testing** (Phase 2) - 3-5 days
   - Run both systems simultaneously
   - Compare outputs and behavior
   - Fix any discrepancies

3. **Transition** (Phase 3) - 1 day
   - Update `.envrc` to use lefthook as primary
   - Add deprecation notices to old hooks
   - Update documentation

4. **Cleanup** (Phase 4) - 1 day
   - Remove `.githook/` directory
   - Clean up GNU tools workarounds (if no longer needed)
   - Archive old implementation

---

## Proposed Lefthook Configuration

### `lefthook.yml`

```yaml
# Lefthook configuration for e-bash
# Documentation: https://github.com/evilmartians/lefthook/blob/master/docs/configuration.md

# Minimum lefthook version required
min_version: 2.0.0

# Pre-commit hook
pre-commit:
  # Run jobs sequentially to maintain current behavior
  # (can be enabled to true after validation)
  parallel: false

  # Skip in CI by default
  skip_on_ci: true

  jobs:
    # Job 1: Verify and add copyright notices
    - name: copyright-verification
      script: ".lefthook/copyright-verify.sh"
      runner: bash
      # Only process staged .sh files
      glob: "*.sh"
      # Stage files modified by the hook
      stage_fixed: true
      fail_text: "Copyright verification failed. Please fix copyright issues."
      tags: [copyright, quality]

    # Job 2: Update last revisit date
    - name: last-revisit-update
      script: ".lefthook/last-revisit-update.sh"
      runner: bash
      glob: "*.sh"
      stage_fixed: true
      fail_text: "Failed to update last revisit dates."
      tags: [copyright, maintenance]

    # Job 3: Generate documentation for modified scripts
    - name: docs-update
      script: ".lefthook/docs-update.sh"
      runner: bash
      glob: ".scripts/*.sh"
      # Don't fail if docs generation fails
      run_on_failure: true
      tags: [docs, automation]

# Optional: Commit message validation (for future use)
# commit-msg:
#   jobs:
#     - name: conventional-commits
#       run: bin/git.verify-all-commits.sh {1}

# Optional: Pre-push validation (for future use)
# pre-push:
#   parallel: true
#   jobs:
#     - name: tests
#       run: shellspec --quick
#     - name: lint
#       run: shellcheck .scripts/*.sh bin/*.sh
```

### `.lefthook/copyright-verify.sh`

Port of `pre-commit-copyright` adapted for lefthook:
- Remove test mode (use `lefthook run` instead)
- Use `{staged_files}` from lefthook or `git diff --cached --name-only`
- Keep GNU tools dependency initially
- Maintain numbered backup strategy
- Preserve exit codes (2=line count, 3=format)

### `.lefthook/last-revisit-update.sh`

Port of `pre-commit-copyright-last-revisit`:
- Simplify for lefthook's file handling
- Keep numbered backup strategy
- Preserve test fixture detection

### `.lefthook/docs-update.sh`

Port of `pre-commit.d/docs-update.sh`:
- Check for `bin/e-docs.sh` existence
- Process staged `.scripts/*.sh` files
- Stage generated documentation

---

## Environment Setup Migration

### Current `.envrc`

```bash
# Setup Git hooks from .githook directory
[ -d ".git" ] && git config core.hooksPath .githook
[ -d ".githook" ] && chmod +x .githook/*
```

### Phase 1: Parallel Testing

```bash
# Keep old hooks, install lefthook for testing
[ -d ".git" ] && git config core.hooksPath .githook

# Install lefthook for parallel testing (optional)
if command -v lefthook >/dev/null 2>&1; then
  lefthook install
  echo "✅ Lefthook installed (parallel testing mode)"
fi
```

### Phase 3: Primary System

```bash
# Primary: Lefthook
if command -v lefthook >/dev/null 2>&1; then
  lefthook install
else
  echo "❌ lefthook not found. Install with: brew install lefthook"
  echo "   Falling back to legacy hooks..."
  [ -d ".git" ] && git config core.hooksPath .githook
fi
```

### Phase 4: Final State

```bash
# Install lefthook hooks
dependency lefthook "2.*.*" "brew install lefthook"
lefthook install
```

---

## Dependency Changes

### Will Add

- `lefthook` (single binary, multiple install methods)

### Will Keep (Initially)

- GNU grep (ggrep)
- GNU sed (gsed)
- GNU mv (gmv)
- `bin/gnubin/` directory
- `.scripts/_gnu.sh` module

### Future Consideration (Phase 4+)

- Refactor scripts to POSIX compliance to remove GNU tools dependency
- Remove `bin/gnubin/` if no longer needed by other parts of the project

---

## Implementation Phases

### Phase 1: Preparation (1-2 days)

**Objectives:**
- Set up lefthook infrastructure
- Create initial configuration
- Port hook scripts
- Document migration plan

**Tasks:**

1. **Add lefthook dependency** to `.envrc`:
   ```bash
   dependency lefthook "2.*.*" "brew install lefthook"
   ```

2. **Create directory structure**:
   ```bash
   mkdir -p .lefthook
   ```

3. **Create `lefthook.yml`** (see [Proposed Configuration](#proposed-lefthook-configuration))

4. **Port `.lefthook/copyright-verify.sh`**
   - Extract from `.githook/pre-commit-copyright`
   - Adapt for lefthook environment
   - Test standalone

5. **Port `.lefthook/last-revisit-update.sh`**
   - Extract from `.githook/pre-commit-copyright-last-revisit`
   - Adapt for lefthook environment
   - Test standalone

6. **Port `.lefthook/docs-update.sh`**
   - Extract from `.githook/pre-commit.d/docs-update.sh`
   - Test standalone

7. **Create `.lefthook/README.md`**
   - Document new structure
   - Usage instructions
   - Testing guide

8. **Update `.gitignore`**:
   ```
   # Lefthook local configuration
   lefthook-local.yml
   ```

**Deliverables:**
- [ ] `lefthook.yml` configuration file
- [ ] `.lefthook/` directory with ported scripts
- [ ] `.lefthook/README.md` documentation
- [ ] Updated `.envrc` with lefthook dependency

**Validation:**
- [ ] Scripts run successfully standalone
- [ ] lefthook configuration validates (`lefthook run --validate`)

---

### Phase 2: Parallel Testing (3-5 days)

**Objectives:**
- Run both systems simultaneously
- Validate equivalent behavior
- Build confidence in migration

**Tasks:**

1. **Update `.envrc`** for parallel testing

2. **Create comparison script** `.githook/test-migration.sh`:
   ```bash
   #!/usr/bin/env bash
   # Run old system
   echo "=== Running old hooks ==="
   HOOK_TEST=1 ./.githook/pre-commit-copyright "$@"
   OLD_EXIT=$?

   # Run new system
   echo "=== Running new hooks ==="
   lefthook run pre-commit
   NEW_EXIT=$?

   # Compare results
   if [ $OLD_EXIT -eq $NEW_EXIT ]; then
     echo "✅ Both systems produced same exit code: $OLD_EXIT"
   else
     echo "❌ Exit codes differ: old=$OLD_EXIT, new=$NEW_EXIT"
   fi
   ```

3. **Run comprehensive test suite**:
   - File without copyright → Should add copyright
   - File with valid copyright → Should pass
   - File with invalid copyright format → Should fail with error code 3
   - File with wrong line count → Should fail with error code 2
   - File with old format → Should fail
   - File with tool comments → Should preserve them
   - Multiple files mixed → Should process correctly
   - Last revisit date update → Should update only modified files
   - No staged files → Should skip gracefully
   - Non-.sh files → Should ignore

4. **Performance testing**:
   ```bash
   # Benchmark old system
   time HOOK_TEST=1 ./.githook/pre-commit-copyright test/*.sh

   # Benchmark new system
   time lefthook run pre-commit
   ```

5. **Cross-platform testing**:
   - Test on macOS
   - Test on Linux/WSL
   - Verify GNU tools work correctly

**Deliverables:**
- [ ] Test comparison script
- [ ] Test results documentation
- [ ] Performance benchmarks
- [ ] Cross-platform validation

**Validation:**
- [ ] All test cases pass identically
- [ ] Performance is equal or better
- [ ] Works on macOS and Linux

---

### Phase 3: Transition (1 day)

**Objectives:**
- Switch primary system to lefthook
- Deprecate old hooks
- Update all documentation

**Tasks:**

1. **Update `.envrc`** to use lefthook as primary

2. **Add deprecation notice** to `.githook/pre-commit`:
   ```bash
   cat <<'EOF' >&2
   ⚠️  DEPRECATED: This hook system is deprecated.
   ⚠️  Please install lefthook: brew install lefthook
   ⚠️  Then run: direnv allow
   EOF
   ```

3. **Update documentation**:
   - Update `CLAUDE.md` with lefthook instructions
   - Update `.githook/README.md` with deprecation notice
   - Update project README if applicable
   - Add `.lefthook/README.md` as primary docs

4. **Update CI/CD**:
   - Install lefthook in CI environments
   - Update CI scripts to use `lefthook run`

5. **Create migration announcement**:
   - Document in CHANGELOG or release notes
   - Provide migration instructions for contributors

**Deliverables:**
- [ ] Updated `.envrc`
- [ ] Deprecated old hooks
- [ ] Updated documentation
- [ ] Migration announcement

**Validation:**
- [ ] New contributors can set up successfully
- [ ] Existing contributors can transition smoothly
- [ ] CI/CD works with new system

---

### Phase 4: Cleanup (1 day)

**Objectives:**
- Remove old implementation
- Clean up temporary artifacts
- Finalize documentation

**Tasks:**

1. **Archive old hooks**:
   ```bash
   mkdir -p docs/archive/githooks-legacy
   mv .githook/* docs/archive/githooks-legacy/
   ```

2. **Remove old hooks directory**:
   ```bash
   git rm -r .githook
   ```

3. **Clean up `.envrc`**:
   - Remove GNU tools setup if no longer needed
   - Remove fallback logic
   - Simplify to:
   ```bash
   dependency lefthook "2.*.*" "brew install lefthook"
   lefthook install
   ```

4. **Final documentation review**:
   - Remove outdated references to `.githook/`
   - Update all hook-related documentation
   - Add lefthook tips and tricks

5. **Create migration report**:
   - Document lessons learned
   - Record any issues encountered
   - Provide recommendations for future

**Deliverables:**
- [ ] Old hooks archived
- [ ] Cleaned up `.envrc`
- [ ] Final documentation updates
- [ ] Migration report

**Validation:**
- [ ] No references to old system remain
- [ ] Clean git status
- [ ] All documentation accurate

---

## Testing Strategy

### Unit Testing Scripts

```bash
# Test copyright verification directly
bash .lefthook/copyright-verify.sh test_file.sh

# Test last revisit update directly
bash .lefthook/last-revisit-update.sh test_file.sh

# Test docs update directly
bash .lefthook/docs-update.sh test_file.sh
```

### Lefthook Testing

```bash
# Run all pre-commit jobs
lefthook run pre-commit

# Run specific job
lefthook run pre-commit --commands copyright-verification

# Skip specific job for testing
LEFTHOOK_EXCLUDE=last-revisit-update lefthook run pre-commit

# Run with staged files from a specific commit
lefthook run pre-commit --ref HEAD~1
```

### Validation Checklist

- [ ] All test cases pass with lefthook
- [ ] Output messages match (or are better than) old system
- [ ] Exit codes are consistent (2=line count, 3=format)
- [ ] File modifications are identical
- [ ] Backup files are created correctly
- [ ] Performance is equal or better
- [ ] Works on macOS and Linux
- [ ] Works with direnv setup
- [ ] Documentation is complete

---

## Rollback Plan

### Quick Rollback (Emergency)

```bash
# 1. Uninstall lefthook hooks
lefthook uninstall

# 2. Restore old hooks configuration
git config core.hooksPath .githook

# 3. Ensure old hooks are executable
chmod +x .githook/*

# 4. Test
.githook/pre-commit
```

### Staged Rollback (Controlled)

Keep `.githook/` directory during initial migration phases with fallback in `.envrc`:

```bash
if ! command -v lefthook >/dev/null 2>&1; then
  echo "⚠️  lefthook not found, using legacy hooks"
  [ -d ".git" ] && git config core.hooksPath .githook
fi
```

---

## Success Criteria

### Must Have (Blocking)

- [ ] All existing hook functionality preserved
- [ ] Copyright verification works identically
- [ ] Last revisit update works identically
- [ ] Docs generation works identically
- [ ] All test cases pass
- [ ] Works on macOS and Linux
- [ ] Documentation complete and accurate

### Should Have (Important)

- [ ] Performance equal or better than old system
- [ ] Improved developer experience (easier testing)
- [ ] Simpler setup for new contributors
- [ ] Better error messages
- [ ] Local override capability documented

### Nice to Have (Optional)

- [ ] Parallel execution enabled (if safe)
- [ ] Additional hooks (commit-msg, pre-push)
- [ ] POSIX-compliant scripts (no GNU tools)
- [ ] CI integration examples

---

## Critical Files Reference

### Files to Create

- `lefthook.yml` - Main configuration
- `.lefthook/copyright-verify.sh` - Copyright verification script
- `.lefthook/last-revisit-update.sh` - Date update script
- `.lefthook/docs-update.sh` - Documentation generation script
- `.lefthook/README.md` - Documentation

### Files to Modify

- `.envrc` - Add lefthook dependency and installation
- `CLAUDE.md` - Update with lefthook instructions
- `.gitignore` - Add `lefthook-local.yml`

### Files to Archive (Phase 4)

- `.githook/pre-commit`
- `.githook/pre-commit-copyright`
- `.githook/pre-commit-copyright-last-revisit`
- `.githook/pre-commit.d/docs-update.sh`
- `.githook/README.md`

### Files to Keep

- `bin/git.semantic-version.sh` - Used for version detection
- `bin/e-docs.sh` - Used for documentation generation
- `.scripts/_gnu.sh` - GNU tools compatibility (may be needed elsewhere)
- `.scripts/_dependencies.sh` - Dependency management

---

## Timeline Estimate

**Total Duration:** 6-9 days (can be spread over 2-3 weeks)

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Preparation | 1-2 days | None |
| Phase 2: Parallel Testing | 3-5 days | Phase 1 complete |
| Phase 3: Transition | 1 day | Phase 2 validated |
| Phase 4: Cleanup | 1 day | Phase 3 complete |

**Recommended Approach:**
- Start Phase 1 immediately
- Run Phase 2 for at least one sprint (1-2 weeks) to build confidence
- Execute Phase 3 & 4 together when team is ready

---

## References

### Lefthook Documentation

- Official Repository: https://github.com/evilmartians/lefthook
- Installation Guide: https://github.com/evilmartians/lefthook/blob/master/docs/install.md
- Configuration Reference: https://github.com/evilmartians/lefthook/blob/master/docs/configuration.md
- Migration Examples: https://github.com/evilmartians/lefthook/wiki/Migration-from-other-tools

### E-Bash Resources

- Current Hooks: `.githook/README.md`
- Project Documentation: `CLAUDE.md`
- Environment Setup: `.envrc`
- Dependencies: `.scripts/_dependencies.sh`

---

## Approval

**Plan Status:** Ready for Implementation
**Date:** 2026-01-25
**Next Step:** Begin Phase 1 - Preparation

**Stakeholders:**
- [ ] Project Maintainer
- [ ] Core Contributors

---

*This migration plan is a living document and should be updated as the migration progresses.*
