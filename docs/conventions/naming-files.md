# File Naming Conventions

This document details file and directory naming patterns used in the e-bash library.

---

## Overview

Files in e-bash are categorized by **location** and **purpose**:

1. **Library module files** - Core reusable libraries in `.scripts/`
2. **Executable tools** - Standalone scripts in `bin/`
3. **Test files** - ShellSpec tests in `spec/`
4. **Hook scripts** - Lifecycle hooks in project hook directories
5. **Demo scripts** - Examples in `demos/`
6. **Documentation** - Markdown files in `docs/`

---

## 1. Library Module Files

These are the core library files meant to be sourced by other scripts.

### Pattern: `_modulename.sh`

```
.scripts/
├── _arguments.sh       # Argument parsing module
├── _colors.sh          # Terminal color detection
├── _commons.sh         # Common utilities
├── _dependencies.sh    # Dependency management
├── _dryrun.sh          # Dry-run wrapper system
├── _gnu.sh             # GNU tools detection
├── _hooks.sh           # Lifecycle hooks system
├── _logger.sh          # Tag-based logging
├── _self-update.sh     # Self-update functionality
├── _semver.sh          # Semantic versioning
├── _tmux.sh            # Tmux integration
└── _traps.sh           # Signal/trap management
```

### Rules

- **Prefix:** Underscore `_` to distinguish from executables
- **Case:** All lowercase
- **Extension:** `.sh`
- **Location:** Must be in `.scripts/` directory
- **Naming:** Use singular nouns (e.g., `_logger`, not `_loggers`)
- **Purpose:** Files designed to be sourced, not executed

### Usage Pattern

```bash
# In user scripts or other modules
source "$E_BASH/_logger.sh"
source "$E_BASH/_dependencies.sh"
```

### When to Create a New Module

✅ Create new module file when:
- Functionality is reusable across multiple scripts
- Code provides a cohesive set of related functions
- Module can be loaded independently (with its dependencies)

❌ Don't create new module when:
- Functionality is script-specific
- Code is a one-off utility
- Would create circular dependencies

---

## 2. Executable Tools

Standalone scripts that can be run directly from the command line.

### Pattern A: `tool-name.sh` (Simple Tools)

```
bin/
├── un-link.sh            # Unlink script
├── tree.sh               # Tree viewer
├── vhd.sh                # VHD management
├── ipv6.sh               # IPv6 utilities
└── version-up.v2.sh      # Version bumping tool
```

### Pattern B: `namespace.action.sh` (Namespaced Tools)

```
bin/
├── install.e-bash.sh               # Installation script
├── git.files.sh                    # Git file utilities
├── git.graph.sh                    # Git graph visualization
├── git.log.sh                      # Enhanced git log
├── git.semantic-version.sh         # Semantic version from git
├── git.sync-by-patches.sh          # Git sync via patches
├── git.verify-all-commits.sh       # Commit verification
├── git.conventional-commits.sh     # Conventional commits helper
├── npm.versions.sh                 # NPM version utilities
└── ci.validate-envrc.sh            # Validate .envrc in CI
```

### Pattern C: Versioned Scripts (Rewrites/Reimplementations)

When reimplementing a script with different approaches or modules, use version suffix:

```
bin/
├── version-up.sh                   # Original implementation
├── version-up.v2.sh                # Rewrite with improved approach
├── install.e-bash.sh               # Current version
└── install.e-bash.v1.sh            # Legacy version (if kept)
```

**Pattern:** `{script-name}.v{N}.sh` where N is version number (1, 2, 3, etc.)

**When to Use:**
- Major rewrite using different modules or architecture
- Breaking changes that require keeping old version
- Experimental implementations running in parallel
- Migration period where both versions coexist

**Version Numbering:**
- Start at `.v2` (no `.v1` suffix on original)
- Increment for each major rewrite
- Original script has no version suffix

**Example Evolution:**
```bash
# Phase 1: Original
bin/version-up.sh                   # First implementation

# Phase 2: Rewrite
bin/version-up.sh                   # Original (kept for compatibility)
bin/version-up.v2.sh                # New implementation

# Phase 3: v2 becomes default
bin/version-up.sh -> version-up.v2.sh  # Symlink to v2
bin/version-up.v1.sh                   # Original renamed
bin/version-up.v2.sh                   # Current implementation

# Phase 4: Cleanup
bin/version-up.sh                   # v2 renamed to main
# v1 removed after migration
```

### Pattern D: Subdirectories for Related Tools

```
bin/
├── gnubin/                         # GNU tool shims for macOS
│   ├── awk -> gawk
│   ├── sed -> gsed
│   └── grep -> ggrep
├── profiler/                       # Profiling tools
│   ├── profile.sh
│   └── tracing.sh
└── wsl/                            # WSL-specific utilities
    └── diag.wsl2.sh
```

### Rules

- **No underscore prefix** - Executables don't use `_` prefix
- **Case:** lowercase with hyphens or dots
- **Extension:** `.sh` (always)
- **Shebang:** Must include `#!/usr/bin/env bash` or `#!/bin/bash`
- **Executable:** Must have `+x` permission (`chmod +x`)
- **Namespacing:** Use dots (`.`) for namespace separation when grouping related tools
- **Simple names:** Use hyphens (`-`) for multi-word simple tools
- **Version suffix:** Use `.v{N}` for reimplementations/rewrites

### Choosing Pattern A vs Pattern B

| Use Pattern A (`tool-name.sh`) | Use Pattern B (`namespace.action.sh`) |
| ------------------------------ | ------------------------------------- |
| Standalone functionality       | Part of a logical group               |
| No clear namespace             | Clear domain (git, npm, ci)           |
| Clone of the existing OS tool  | `git.semantic-version.sh`             |
| `tree.sh`                      | `npm.versions.sh`                     |
| `ipv6.sh`                      | `ci.validate-envrc.sh`                |

### Examples

```bash
# Good: Clear namespace
git.semantic-version.sh             # ✓ git namespace
npm.versions.sh                     # ✓ npm namespace
install.e-bash.sh                   # ✓ Clear purpose

# Good: Simple standalone
tree.sh                             # ✓ Single-word tool, analog of TREE command

# Bad: Mixing conventions
git-semantic-version.sh             # ✗ Mix of - and words
gitSemanticVersion.sh               # ✗ camelCase
GitSemanticVersion.sh               # ✗ PascalCase
```

---

## 3. Test Files

Test files using ShellSpec testing framework.

### Pattern: `spec/**/{script_under_test}_spec.sh`

```
spec/
├── arguments_spec.sh                # Tests .scripts/_arguments.sh
├── dependencies_spec.sh             # Tests .scripts/_dependencies.sh
├── dryrun_spec.sh                   # Tests .scripts/_dryrun.sh
├── hooks_spec.sh                    # Tests .scripts/_hooks.sh
├── logger_spec.sh                   # Tests .scripts/_logger.sh
├── semver_spec.sh                   # Tests .scripts/_semver.sh
├── traps_spec.sh                    # Tests .scripts/_traps.sh
├── traps_nested_spec.sh             # Additional trap tests
├── version-up_spec.sh               # Tests bin/version-up.v2.sh
└── bin/                             # Mirror bin/ structure
    ├── git.verify-all-commits_spec.sh   # Tests bin/git.verify-all-commits.sh
    └── npm.versions_spec.sh             # Tests bin/npm.versions.sh
```

### Rules

- **Full pattern:** `spec/**/{script_under_test}_spec.sh`
- **No underscore prefix** - Test files don't use `_` prefix (even when testing `_module.sh`)
- **Suffix:** `_spec.sh` (required by ShellSpec)
- **Case:** lowercase with underscores
- **Naming:** Match the module/script being tested
  - `.scripts/_logger.sh` → `spec/logger_spec.sh` (drop underscore prefix)
  - `.scripts/_hooks.sh` → `spec/hooks_spec.sh` (drop underscore prefix)
  - `bin/git.semantic-version.sh` → `spec/bin/git.semantic-version_spec.sh` (keep dots)
- **Location:** Mirror source structure in `spec/`
  - Tests for `.scripts/` modules go in `spec/` root
  - Tests for `bin/` tools go in `spec/bin/`

### Test Subdirectories

```
spec/
├── fixtures/               # Test fixtures
│   ├── versioned-script.sh
│   ├── no-version.sh
│   └── traps_script-a_default.sh
├── helpers/                # Test helpers
│   ├── trap_dispatcher_e2e_minimal.sh
│   └── trap_simple_test.sh
├── support/                # Test support files
│   └── test_helpers.sh
├── spec_helper.sh          # ShellSpec configuration
└── bin/                    # Tests for bin/ scripts
    └── git.verify-all-commits_spec.sh
```

---

## 4. Hook Scripts

Lifecycle hook implementations.

### Pattern A: `{hook-name}-{description}.sh` (Unordered)

```
.hooks/
├── begin-otel-trace.sh           # Start OpenTelemetry trace
├── deploy-slack-notify.sh        # Send Slack notification
├── end-datadog.sh                # Send Datadog metrics
└── end-cleanup.sh                # Cleanup temporary files
```

### Pattern B: `{hook-name}_{NN}_{description}.sh` (Ordered)

```
ci-cd/
├── begin_00_mode-resolve.sh      # Resolve execution mode
├── begin_10_mode-dry.sh          # Dry-run mode setup
├── begin_11_mode-ok.sh           # Normal mode setup
├── begin_12_mode-error.sh        # Error mode setup
├── begin_13_mode-skip.sh         # Skip mode setup
├── begin_14_mode-timeout.sh      # Timeout mode setup
├── begin_15_mode-test.sh         # Test mode setup
├── decide-cache.sh               # Cache decision hook
└── end_99_timeout-cleanup.sh     # Cleanup timeouts on exit
```

### Rules

- **Hook name:** Matches declared hook (begin, end, deploy, etc.)
- **Separator:** Hyphen `-` for unordered, underscore `_` before number for ordered
- **Numbering:** Two-digit numbers (00-99) for execution order
- **Description:** Brief, hyphen-separated words
- **Extension:** `.sh`
- **Executable:** Must have `+x` permission
- **Location:** In project's `HOOKS_DIR` (default: `ci-cd/`)

### Execution Order

```bash
# Unordered hooks execute in:
# - Alphabetical order by filename

# Ordered hooks execute in:
# - Numeric order (00, 10, 11, 12, ...)
# - Then alphabetical within same number

# Example execution order:
begin_00_mode-resolve.sh     # 1st
begin_10_mode-dry.sh         # 2nd
begin_11_mode-ok.sh          # 3rd
begin_12_mode-error.sh       # 4th
```

### Choosing Pattern A vs Pattern B

| Use Unordered (`hook-desc.sh`) | Use Ordered (`hook_NN_desc.sh`)   |
| ------------------------------ | --------------------------------- |
| Order doesn't matter           | Specific execution order required |
| Independent operations         | Dependent operations              |
| `begin-otel-trace.sh`          | `begin_10_setup.sh`               |
| `end-cleanup.sh`               | `end_99_final-cleanup.sh`         |

---

## 5. Demo Scripts

Example scripts showing usage patterns.

### Pattern: `demo.feature.sh`

```
demos/
├── demo.args.sh                    # Arguments demo
├── demo.cache.sh                   # Caching demo
├── demo.colors.sh                  # Colors demo
├── demo.debug.sh                   # Debug logging demo
├── demo.dependencies.sh            # Dependencies demo
├── demo.dryrun.sh                  # Dry-run demo
├── demo.hooks.sh                   # Hooks demo
├── demo.hooks-logging.sh           # Hooks with logging
├── demo.hooks-nested.sh            # Nested hooks
├── demo.logs.sh                    # Logger demo
├── demo.semver.sh                  # Semver demo
├── demo.selfupdate.sh              # Self-update demo
├── demo.tmux.exec.sh               # Tmux execution
├── demo.tmux.progress.sh           # Tmux progress
└── demo.traps.sh                   # Traps demo
```

### Pattern: `benchmark.feature.sh` (Performance Tests)

```
demos/
├── benchmark.colors.sh             # Color detection benchmarks
├── benchmark.ecs.sh                # ECS JSON logging benchmarks
└── benchmark.*.sh                  # Other performance tests
```

### Subdirectories for Complex Demos

```
demos/
├── ci-mode/                        # CI mode demonstrations
│   ├── demo.ci-modes.sh
│   ├── demo.ci-modes-middleware.sh
│   ├── ci-10-compile.sh
│   ├── ci-20-compile.sh
│   └── hooks-mw/                   # Middleware hooks for demo
│       ├── begin_00_mode-resolve.sh
│       └── begin_10_mode-dry.sh
└── (benchmark files at root)
```

### Rules

- **Demo prefix:** `demo.` for demonstration/example scripts
- **Benchmark prefix:** `benchmark.` for performance testing scripts
- **Case:** lowercase with hyphens or dots
- **Extension:** `.sh`
- **Executable:** Optional (can be sourced or executed)
- **Documentation:** Should include comments explaining usage
- **Performance tests:** Use `benchmark.` prefix to distinguish from feature demos

---

## 6. Documentation Files

Markdown documentation.

### Pattern: `DOCUMENT_NAME.md` or `document-name.md`

```
docs/
├── TMUX_PATTERN_ANALYSIS.md        # Technical analysis (CAPS)
├── ROADMAP.IDEAS.MD                # Planning docs (CAPS)
├── public/                         # Public documentation
│   ├── installation.md
│   ├── logger.md
│   ├── arguments.md
│   ├── hooks.md
│   ├── dryrun-wrapper.md
│   └── version-up.md
├── plans/                          # Planning documents
│   ├── 2026-01-24-edocs.md
│   ├── lefthook-migration.md
│   └── bootstrap-poc.sh
└── conventions/                    # Convention docs (NEW)
    ├── NAMING_CONVENTIONS.md
    ├── naming-functions.md
    ├── naming-variables.md
    └── naming-files.md
```

### Rules

- **Major docs:** SCREAMING_SNAKE_CASE for important top-level docs
  - `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`
- **Feature docs:** lowercase-with-hyphens for feature documentation
  - `installation.md`, `logger.md`, `hooks.md`
- **Planning docs:** May use date prefixes: `YYYY-MM-DD-description.md`
- **Extension:** `.md` for Markdown, `.MD` acceptable for major docs

---

## 7. Fixture and Support Files

Test fixtures and support utilities.

### Fixture Files

```
spec/fixtures/
├── versioned-script.sh             # Script with version header
├── no-version.sh                   # Script without version
├── traps_script-a_default.sh       # Trap test script A
├── traps_script-b_default.sh       # Trap test script B
└── e-docs/                         # e-docs test fixtures
    ├── simple_function.sh
    ├── full_function.sh
    └── namespaced.sh
```

### Rules

- **Naming:** Descriptive, indicates test scenario
- **Case:** lowercase with hyphens or underscores
- **Location:** `spec/fixtures/` or `spec/fixtures/{feature}/`

---

## Best Practices

### ✅ DO

```bash
# Library modules: underscore prefix
.scripts/_logger.sh                 # ✓ Clear library module
.scripts/_hooks.sh                  # ✓ Sourceable library

# Executables: no underscore, clear naming
bin/install.e-bash.sh               # ✓ Clear purpose
bin/git.semantic-version.sh         # ✓ Namespaced tool

# Tests: match source with _spec suffix
spec/logger_spec.sh                 # ✓ Tests _logger.sh
spec/hooks_spec.sh                  # ✓ Tests _hooks.sh

# Hooks: descriptive names
ci-cd/begin_10_setup.sh             # ✓ Ordered hook
ci-cd/end-cleanup.sh                # ✓ Unordered hook

# Demos: demo prefix
demos/demo.logger.sh                # ✓ Clear demo
demos/demo.hooks-nested.sh          # ✓ Descriptive
```

### ❌ DON'T

```bash
# Don't mix conventions
.scripts/logger.sh                  # ✗ Missing underscore
.scripts/_logger                    # ✗ Missing .sh extension
bin/_install.sh                     # ✗ Executable shouldn't have _

# Don't use inconsistent naming
bin/git-semantic-version.sh         # ✗ Mix of - and .
bin/gitSemanticVersion.sh           # ✗ camelCase
bin/Git.SemanticVersion.sh          # ✗ PascalCase

# Don't deviate from ShellSpec convention
spec/logger.spec.sh                 # ✗ Wrong suffix (use _spec)
spec/logger-spec.sh                 # ✗ Wrong suffix
spec/test_logger.sh                 # ✗ Wrong prefix

# Don't use vague hook names
ci-cd/script.sh                     # ✗ No hook name
ci-cd/custom.sh                     # ✗ No hook association
ci-cd/begin_init.sh                 # ✗ Missing number for ordered hook
```

---

## Directory Structure Overview

```
e-bash/
├── .scripts/               # Library modules (_*.sh)
│   ├── _logger.sh
│   ├── _hooks.sh
│   └── ...
├── bin/                    # Executable tools
│   ├── git.*.sh
│   ├── install.*.sh
│   ├── gnubin/             # GNU tool shims
│   └── profiler/           # Profiling tools
├── spec/                   # Tests (*_spec.sh)
│   ├── logger_spec.sh
│   ├── fixtures/           # Test fixtures
│   ├── helpers/            # Test helpers
│   └── support/            # Test support
├── demos/                  # Demo scripts (demo.*.sh)
│   └── ci-mode/            # Complex demo subdirectory
├── docs/                   # Documentation
│   ├── public/             # User-facing docs
│   ├── plans/              # Planning documents
│   └── conventions/        # Convention docs
├── .hooks/                 # Project-specific hooks
├── ci-cd/                  # Default hooks directory
└── patches/                # Patch scripts
```

---

## File Permissions

| File Type       | Permission        | Why                      |
| --------------- | ----------------- | ------------------------ |
| Library modules | `644` (rw-r--r--) | Sourced, not executed    |
| Executables     | `755` (rwxr-xr-x) | Must be executable       |
| Hook scripts    | `755` (rwxr-xr-x) | Executed by hooks system |
| Tests           | `755` (rwxr-xr-x) | Executed by ShellSpec    |
| Demos           | `755` (rwxr-xr-x) | Usually executed         |
| Documentation   | `644` (rw-r--r--) | Read-only                |

### Setting Permissions

```bash
# Make file executable
chmod +x bin/git.semantic-version.sh
chmod +x ci-cd/begin_10_setup.sh

# Make library module non-executable (if needed)
chmod 644 .scripts/_logger.sh
```

---

## Quick Checklist

Before creating a new file, ask:

- [ ] Is it a library module? → Use `_modulename.sh` in `.scripts/`
- [ ] Is it an executable tool? → Use `tool-name.sh` or `namespace.action.sh` in `bin/`
- [ ] Is it a test? → Use `modulename_spec.sh` in `spec/`
- [ ] Is it a hook? → Use `hook-desc.sh` or `hook_NN_desc.sh` in hooks directory
- [ ] Is it a demo? → Use `demo.feature.sh` in `demos/`
- [ ] Does it need execute permission? → `chmod +x` for executables, hooks, tests
- [ ] Is naming consistent with similar files? → Check existing patterns

---

## See Also

- [Function Naming](naming-functions.md) - Naming patterns for functions
- [Variable Naming](naming-variables.md) - Naming patterns for variables
- [Main Conventions](NAMING_CONVENTIONS.md) - Overview and quick reference
