# Lefthook Migration Plan

## Executive Summary

This document outlines the migration plan from the current custom git hooks solution (`.githook/`) to [lefthook](https://github.com/evilmartians/lefthook), a modern, cross-platform git hooks manager. The migration will improve maintainability, testing, and cross-platform compatibility while preserving all existing functionality.

**Current Status:** Planning Phase
**Target Completion:** TBD
**Risk Level:** Low (lefthook supports rollback via simple uninstall)

---

## Table of Contents

- [Motivation](#motivation)
- [Current Implementation Analysis](#current-implementation-analysis)
- [Lefthook Benefits](#lefthook-benefits)
- [Migration Strategy](#migration-strategy)
- [Configuration Mapping](#configuration-mapping)
- [Testing Strategy](#testing-strategy)
- [Rollback Plan](#rollback-plan)
- [Implementation Phases](#implementation-phases)
- [Compatibility Considerations](#compatibility-considerations)
- [Success Criteria](#success-criteria)
- [References](#references)

---

## Motivation

### Why Migrate?

1. **Standardization**: Lefthook is an industry-standard tool used by thousands of projects
2. **Better Testing**: Native support for running hooks without commits (`lefthook run`)
3. **Improved Maintainability**: YAML configuration is easier to maintain than shell scripts
4. **Enhanced Features**: Parallel execution, better file filtering, skip conditions, local overrides
5. **Cross-Platform**: Single dependency-free binary works consistently across macOS/Linux/Windows
6. **Community Support**: Active development, comprehensive documentation, large user base
7. **CI/CD Integration**: Better integration with CI workflows and testing pipelines

### Current Pain Points

- Custom shell scripts require bash expertise to maintain
- Testing requires setting `HOOK_TEST=1` environment variable manually
- GNU tools dependency management is complex (ggrep, gsed, gmv)
- No native parallel execution support
- Limited skip/disable functionality for specific developers
- No built-in configuration override mechanism

---

## Current Implementation Analysis

### Architecture Overview

**Location:** `.githook/` directory
**Setup:** Configured via `.envrc` with `git config core.hooksPath .githook`

### Hook Files

1. **pre-commit** (887 bytes)
   - Main orchestrator
   - Calls sub-hooks sequentially
   - Ensures GNU utilities are available
   - Exits on first failure

2. **pre-commit-copyright** (6,041 bytes)
   - Verifies copyright notices in `*.sh` files
   - Adds copyright to files missing it
   - Validates copyright format and line count
   - Uses GNU grep/sed/mv for processing
   - Supports test mode via `HOOK_TEST=1`
   - Creates numbered backups when modifying files

3. **pre-commit-copyright-last-revisit** (2,686 bytes)
   - Updates "Last revisit" date in modified files
   - Uses GNU grep/sed for pattern matching
   - Supports test mode via `HOOK_TEST=1`
   - Creates numbered backups

### Key Features

- **GNU Tools Integration**: Custom `bin/gnubin/` for macOS compatibility
- **Test Mode**: `HOOK_TEST=1` environment variable enables manual testing
- **Backup Strategy**: Numbered backups (`.~1~`, `.~2~`, etc.)
- **File Filtering**: Processes only staged `.sh` files
- **Exit Codes**: Specific codes for different error types (2=lines, 3=format)
- **Color Output**: Uses `tput` for colored terminal output

### Dependencies

- bash 5.x
- GNU grep (ggrep)
- GNU sed (gsed)
- GNU mv (gmv)
- git
- tput (for colors)

---

## Lefthook Benefits

### Core Advantages

1. **Single Binary**: No external dependencies beyond git
2. **Native Testing**: `lefthook run pre-commit` for testing
3. **YAML Configuration**: Declarative, easy to read and modify
4. **Parallel Execution**: Run independent jobs simultaneously
5. **File Patterns**: Advanced glob patterns with `{staged_files}`, `{all_files}`
6. **Local Overrides**: `lefthook-local.yml` for developer-specific settings
7. **Skip Conditions**: Conditional execution based on branches, files, etc.
8. **Multiple Package Managers**: Install via npm, brew, pip, gem, go, apt, etc.
9. **Cross-Platform**: Works identically on macOS, Linux, Windows
10. **CI Integration**: Tag-based execution, skip in CI, custom runners

### Feature Comparison

| Feature | Current Solution | Lefthook |
|---------|------------------|----------|
| Configuration Format | Shell scripts | YAML |
| Testing | `HOOK_TEST=1 ./hook file.sh` | `lefthook run pre-commit` |
| Parallel Execution | No | Yes (`parallel: true`) |
| File Filtering | Manual `git diff` | `{staged_files}`, globs |
| Skip/Disable | Manual script edits | `skip: true`, conditions |
| Local Overrides | Not supported | `lefthook-local.yml` |
| Cross-Platform | Requires GNU tools | Native support |
| Installation | Part of repo | Package managers |
| Documentation | README in `.githook/` | Official docs + examples |

---

## Migration Strategy

### Approach

**Incremental Migration with Parallel Testing**

We will run both systems in parallel during a transition period to validate lefthook behavior before completely removing the old system.

### Phases

1. **Preparation** (Phase 1)
   - Add lefthook to project dependencies
   - Create initial `lefthook.yml` configuration
   - Document the new setup

2. **Parallel Testing** (Phase 2)
   - Run both systems simultaneously
   - Compare outputs and behavior
   - Fix any discrepancies

3. **Transition** (Phase 3)
   - Update `.envrc` to use lefthook
   - Add deprecation notices to old hooks
   - Update documentation

4. **Cleanup** (Phase 4)
   - Remove `.githook/` directory
   - Remove GNU tools workarounds (if no longer needed)
   - Archive old implementation

---

## Configuration Mapping

### Proposed lefthook.yml

```yaml
# Lefthook configuration for e-bash
# Documentation: https://github.com/evilmartians/lefthook/blob/master/docs/configuration.md

# Minimum lefthook version required
min_version: 2.0.0

# Pre-commit hook
pre-commit:
  # Run jobs in parallel for better performance
  parallel: false  # Keep sequential to maintain current behavior initially

  jobs:
    # Job 1: Verify and add copyright notices
    - name: copyright-verification
      # Use custom script for complex logic
      script: ".lefthook/copyright-verify.sh"
      runner: bash
      # Only process staged .sh files
      glob: "*.sh"
      # Stage files modified by the hook
      stage_fixed: true
      # Fail on non-zero exit
      fail_text: "Copyright verification failed. Please fix copyright issues."

    # Job 2: Update last revisit date
    - name: last-revisit-update
      script: ".lefthook/last-revisit-update.sh"
      runner: bash
      glob: "*.sh"
      stage_fixed: true
      fail_text: "Failed to update last revisit dates."

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

### Script Migration

We'll extract the core logic from the current hooks into standalone scripts in `.lefthook/`:

1. **`.lefthook/copyright-verify.sh`**
   - Port logic from `pre-commit-copyright`
   - Remove test mode (use `lefthook run` instead)
   - Use `{staged_files}` or `git diff --cached --name-only`
   - Keep GNU tools dependency (or refactor to POSIX)

2. **`.lefthook/last-revisit-update.sh`**
   - Port logic from `pre-commit-copyright-last-revisit`
   - Simplify for lefthook's file handling
   - Keep numbered backup strategy

3. **`.lefthook/README.md`**
   - Document the new structure
   - Migration guide from old system
   - Testing instructions

### Environment Setup Migration

**Current (`.envrc`):**
```bash
[ -d ".git" ] && git config core.hooksPath .githook
[ -d ".githook" ] && chmod +x .githook/*
```

**New (`.envrc`):**
```bash
# Install/update lefthook hooks
if command -v lefthook >/dev/null 2>&1; then
  lefthook install
fi
```

---

## Testing Strategy

### Phase 1: Unit Testing Scripts

Test individual scripts before integrating with lefthook:

```bash
# Test copyright verification directly
bash .lefthook/copyright-verify.sh test_file.sh

# Test last revisit update directly
bash .lefthook/last-revisit-update.sh test_file.sh
```

### Phase 2: Lefthook Testing

Test hooks without actual commits:

```bash
# Run all pre-commit jobs
lefthook run pre-commit

# Run specific job
lefthook run pre-commit --commands copyright-verification

# Skip specific job for testing
LEFTHOOK_EXCLUDE=last-revisit-update lefthook run pre-commit
```

### Phase 3: Parallel System Testing

Create temporary comparison script to run both systems:

```bash
#!/usr/bin/env bash
# File: .githook/test-migration.sh

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

### Test Cases

Create comprehensive test suite in `docs/plans/lefthook-migration-tests.md`:

1. **File without copyright** → Should add copyright
2. **File with valid copyright** → Should pass
3. **File with invalid copyright format** → Should fail with error
4. **File with wrong line count** → Should fail with error
5. **File with old format** → Should fail with error
6. **File with tool comments** → Should preserve them
7. **Multiple files mixed** → Should process correctly
8. **Last revisit date update** → Should update only modified files
9. **No staged files** → Should skip gracefully
10. **Non-.sh files** → Should ignore

### Validation Checklist

- [ ] All test cases pass with lefthook
- [ ] Output messages match (or are better than) old system
- [ ] Exit codes are consistent
- [ ] File modifications are identical
- [ ] Performance is equal or better
- [ ] Works on macOS and Linux
- [ ] Works with direnv setup
- [ ] Documentation is complete

---

## Rollback Plan

### Quick Rollback (Emergency)

If critical issues are discovered:

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

1. Keep `.githook/` directory during initial migration phases
2. Add `git config` fallback in `.envrc`:
   ```bash
   if ! command -v lefthook >/dev/null 2>&1; then
     echo "⚠️  lefthook not found, using legacy hooks"
     [ -d ".git" ] && git config core.hooksPath .githook
   fi
   ```
3. Document rollback procedure in migration notes
4. Keep old hooks in `.githook-legacy/` for reference

### Rollback Testing

Test rollback procedure before full migration:

```bash
# Install lefthook
lefthook install

# Test new system
git commit -m "test"

# Rollback
lefthook uninstall
git config core.hooksPath .githook

# Test old system
git commit -m "test"
```

---

## Implementation Phases

### Phase 1: Preparation (1-2 days)

**Objectives:**
- Set up lefthook infrastructure
- Create initial configuration
- Document migration plan

**Tasks:**

1. **Add lefthook dependency**
   ```bash
   # Add to .envrc
   dependency lefthook "2.*.*" "brew install lefthook"
   ```

2. **Create directory structure**
   ```bash
   mkdir -p .lefthook
   ```

3. **Create lefthook.yml** (see [Configuration Mapping](#configuration-mapping))

4. **Port copyright-verify.sh**
   - Extract from `pre-commit-copyright`
   - Adapt for lefthook environment
   - Test standalone

5. **Port last-revisit-update.sh**
   - Extract from `pre-commit-copyright-last-revisit`
   - Adapt for lefthook environment
   - Test standalone

6. **Create .lefthook/README.md**
   - Document new structure
   - Usage instructions
   - Testing guide

7. **Update .gitignore**
   ```
   # Lefthook local configuration
   lefthook-local.yml
   ```

**Deliverables:**
- [ ] `lefthook.yml` configuration file
- [ ] `.lefthook/` directory with ported scripts
- [ ] `.lefthook/README.md` documentation
- [ ] Updated `.envrc` with lefthook dependency
- [ ] This migration plan document

**Validation:**
- [ ] Scripts run successfully standalone
- [ ] lefthook configuration validates (`lefthook run --validate`)
- [ ] Documentation is complete and accurate

---

### Phase 2: Parallel Testing (3-5 days)

**Objectives:**
- Run both systems simultaneously
- Validate equivalent behavior
- Build confidence in migration

**Tasks:**

1. **Update .envrc for parallel testing**
   ```bash
   # Install lefthook but keep old hooks as backup
   if command -v lefthook >/dev/null 2>&1; then
     lefthook install
     echo "✅ Lefthook installed (parallel testing mode)"
   fi

   # Keep old hooks as secondary validation
   [ -d ".githook" ] && echo "⚠️  Old hooks still present in .githook/"
   ```

2. **Create comparison script**
   - Build `.githook/test-migration.sh`
   - Run both systems on test files
   - Compare outputs and exit codes

3. **Run comprehensive test suite**
   - Execute all test cases from [Testing Strategy](#testing-strategy)
   - Document any discrepancies
   - Fix issues in lefthook scripts

4. **Performance testing**
   ```bash
   # Benchmark old system
   time HOOK_TEST=1 ./.githook/pre-commit-copyright test/*.sh

   # Benchmark new system
   time lefthook run pre-commit
   ```

5. **Developer validation**
   - Have team members test in their environments
   - Collect feedback on usability
   - Update documentation based on feedback

**Deliverables:**
- [ ] Test comparison script
- [ ] Test results documentation
- [ ] Performance benchmarks
- [ ] Team feedback incorporated

**Validation:**
- [ ] All test cases pass identically
- [ ] Performance is equal or better
- [ ] Team approves migration
- [ ] No critical issues discovered

---

### Phase 3: Transition (1 day)

**Objectives:**
- Switch primary system to lefthook
- Deprecate old hooks
- Update all documentation

**Tasks:**

1. **Update .envrc**
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

2. **Add deprecation notice to old hooks**
   ```bash
   # At top of .githook/pre-commit
   cat <<'EOF' >&2
   ⚠️  DEPRECATED: This hook system is deprecated.
   ⚠️  Please install lefthook: brew install lefthook
   ⚠️  Then run: direnv allow
   EOF
   ```

3. **Update documentation**
   - Update `CLAUDE.md` with lefthook instructions
   - Update `.githook/README.md` with deprecation notice
   - Update project README if applicable
   - Add `.lefthook/README.md` as primary docs

4. **Update CI/CD if applicable**
   - Install lefthook in CI environments
   - Update CI scripts to use `lefthook run`

5. **Create migration announcement**
   - Document in CHANGELOG or release notes
   - Provide migration instructions for contributors
   - Link to this migration plan

**Deliverables:**
- [ ] Updated `.envrc`
- [ ] Deprecated old hooks
- [ ] Updated documentation
- [ ] Migration announcement

**Validation:**
- [ ] New contributors can set up successfully
- [ ] Existing contributors can transition smoothly
- [ ] CI/CD works with new system
- [ ] Documentation is accurate

---

### Phase 4: Cleanup (1 day)

**Objectives:**
- Remove old implementation
- Clean up temporary artifacts
- Finalize documentation

**Tasks:**

1. **Archive old hooks**
   ```bash
   # Move to documentation/historical reference
   mkdir -p docs/archive/githooks-legacy
   mv .githook/* docs/archive/githooks-legacy/
   ```

2. **Remove old hooks directory**
   ```bash
   git rm -r .githook
   ```

3. **Clean up .envrc**
   - Remove GNU tools setup if no longer needed
   - Remove fallback logic
   - Simplify to:
   ```bash
   # Install lefthook hooks
   dependency lefthook "2.*.*" "brew install lefthook"
   lefthook install
   ```

4. **Final documentation review**
   - Remove outdated references to `.githook/`
   - Update all hook-related documentation
   - Add lefthook tips and tricks

5. **Create final migration report**
   - Document lessons learned
   - Record any issues encountered
   - Provide recommendations for future

**Deliverables:**
- [ ] Old hooks archived or removed
- [ ] Cleaned up `.envrc`
- [ ] Final documentation updates
- [ ] Migration report

**Validation:**
- [ ] No references to old system remain
- [ ] Clean git status
- [ ] All documentation accurate
- [ ] Team confirmed transition complete

---

## Compatibility Considerations

### Platform Compatibility

| Platform | Current System | Lefthook | Notes |
|----------|----------------|----------|-------|
| macOS | ✅ (with GNU tools) | ✅ Native | Simpler setup |
| Linux | ✅ Native | ✅ Native | No change |
| Windows/WSL | ✅ (with setup) | ✅ Native | Better support |

### Dependency Changes

**Will Remove:**
- Potentially GNU grep (if scripts refactored to POSIX)
- Potentially GNU sed (if scripts refactored to POSIX)
- Potentially GNU mv (if scripts refactored to POSIX)
- Custom gnubin setup (potentially)

**Will Add:**
- lefthook (single binary, multiple install methods)

**Will Keep:**
- bash 5.x
- git
- All existing e-bash dependencies

### Script Compatibility

**Option 1: Keep GNU Tools** (Easier Migration)
- Keep current script logic using ggrep/gsed/gmv
- Maintain `bin/gnubin/` for macOS
- Quick migration, no logic changes

**Option 2: Refactor to POSIX** (Better Compatibility)
- Rewrite scripts to use POSIX-compliant commands
- Remove GNU tools dependency
- More portable, but requires testing

**Recommendation:** Start with Option 1, consider Option 2 as future enhancement.

### Integration Points

**Existing Integrations:**
- `.envrc` (direnv) → Update to call `lefthook install`
- ShellSpec tests → No impact
- CI/CD pipelines → May need lefthook installation
- Developer workflows → Improved (`lefthook run` for testing)

---

## Success Criteria

### Must Have (Blocking)

- [ ] All existing hook functionality preserved
- [ ] Copyright verification works identically
- [ ] Last revisit update works identically
- [ ] All test cases pass
- [ ] Works on macOS and Linux
- [ ] Documentation complete and accurate
- [ ] Team can use new system successfully
- [ ] No regressions in commit workflow

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
- [ ] Advanced lefthook features documented

---

## Risk Assessment

### Identified Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Behavioral differences | Medium | High | Parallel testing phase, comprehensive test suite |
| Team adoption issues | Low | Medium | Good documentation, training |
| Performance regression | Low | Low | Benchmark testing |
| Rollback required | Low | Medium | Keep old system during transition |
| GNU tools issues | Low | Low | Keep current dependency or refactor |
| CI/CD breaks | Low | Medium | Test in CI before full rollback |

### Mitigation Strategies

1. **Behavioral Differences**
   - Extensive parallel testing
   - Side-by-side comparison scripts
   - Gradual rollout

2. **Team Adoption**
   - Clear documentation
   - Migration guides
   - Available support

3. **Technical Issues**
   - Rollback plan ready
   - Old system preserved initially
   - Staged migration phases

---

## Timeline Estimate

**Total Duration:** 6-9 days (can be spread over 2-3 weeks)

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| Phase 1: Preparation | 1-2 days | None |
| Phase 2: Parallel Testing | 3-5 days | Phase 1 complete |
| Phase 3: Transition | 1 day | Phase 2 validated |
| Phase 4: Cleanup | 1 day | Phase 3 complete |

**Buffer:** Add 2-3 days for unexpected issues

**Recommended Approach:**
- Start Phase 1 immediately
- Run Phase 2 for at least one sprint (1-2 weeks) to build confidence
- Execute Phase 3 & 4 together when team is ready

---

## Post-Migration

### Monitoring

For the first month after migration:

1. **Track Issues**
   - Any hook failures
   - Performance concerns
   - Developer feedback

2. **Collect Metrics**
   - Hook execution times
   - Failure rates
   - Developer satisfaction

3. **Document Learnings**
   - What went well
   - What could be improved
   - Recommendations for future

### Future Enhancements

After successful migration, consider:

1. **Additional Hooks**
   - `commit-msg`: Validate commit message format
   - `pre-push`: Run tests before push
   - `post-merge`: Update dependencies

2. **Advanced Features**
   - Parallel execution (if jobs are independent)
   - Conditional skipping based on branches
   - Docker runner for isolated execution
   - Tag-based job grouping

3. **Script Improvements**
   - Refactor to POSIX compliance
   - Remove GNU tools dependency
   - Performance optimizations
   - Better error messages

4. **CI/CD Integration**
   - Run hooks in CI for validation
   - Skip hooks in CI if desired
   - Generate hook execution reports

---

## References

### Lefthook Documentation

- Official Documentation: https://github.com/evilmartians/lefthook
- Configuration Guide: https://github.com/evilmartians/lefthook/blob/master/docs/configuration.md
- Installation Guide: https://github.com/evilmartians/lefthook/blob/master/docs/install.md
- Migration Examples: https://github.com/evilmartians/lefthook/wiki/Migration-from-other-tools

### E-Bash Resources

- Current Hooks: `.githook/README.md`
- Project Documentation: `CLAUDE.md`
- Environment Setup: `.envrc`
- Dependencies: `.scripts/_dependencies.sh`

### Tools & Dependencies

- Lefthook GitHub: https://github.com/evilmartians/lefthook
- ShellSpec: https://github.com/shellspec/shellspec
- GNU Tools: https://www.gnu.org/software/coreutils/
- Direnv: https://direnv.net/

---

## Appendix

### A. Example Test Cases

See `docs/plans/lefthook-migration-tests.md` (to be created) for comprehensive test suite.

### B. Lefthook Configuration Reference

See `lefthook.yml` (to be created) for full configuration with comments.

### C. Script Migration Details

See `.lefthook/README.md` (to be created) for detailed script documentation.

### D. Team Training Materials

See `docs/guides/lefthook-usage.md` (to be created) for developer guide.

---

## Changelog

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-11-28 | 1.0.0 | Claude Code | Initial migration plan created |

---

## Approval

**Plan Status:** Draft
**Approved By:** TBD
**Approval Date:** TBD

**Stakeholders:**
- [ ] Project Maintainer
- [ ] Core Contributors
- [ ] DevOps/CI Team (if applicable)

---

**Next Steps:**
1. Review this plan with stakeholders
2. Get approval to proceed
3. Begin Phase 1: Preparation
4. Schedule regular check-ins during migration

---

*This migration plan is a living document and should be updated as the migration progresses.*
