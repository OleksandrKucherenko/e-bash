# Naming Conventions

**Version:** 1.0.0
**Last Updated:** 2026-01-29

This document establishes comprehensive naming conventions for the **e-bash** library to ensure consistency, readability, and maintainability across the codebase.

---

## Table of Contents

1. [Philosophy](#philosophy)
2. [Quick Reference](#quick-reference)
3. [Detailed Conventions](#detailed-conventions)
4. [Anti-Patterns](#anti-patterns)
5. [Decision Tree](#decision-tree)
6. [Enforcement](#enforcement)

---

## Philosophy

The e-bash naming conventions are guided by these principles:

1. **Brevity is Critical**: Keep names short and expressive
   - One-line expressions are limited to **120 characters**
   - Short names = more readable code in constrained width
   - ✅ `logger:init` vs ❌ `logger:initialize_with_configuration`

2. **Common Language**: Use familiar, frequently-used words
   - Prefer common verbs: `get`, `set`, `do`, `run`, `list`, `on`, `off`
   - Avoid rare or obscure terms: `procure`, `ameliorate`, `obviate`
   - ✅ `hooks:do` vs ❌ `hooks:execute_lifecycle_operations`

3. **Purpose Over Length**: Express intent clearly but concisely
   - Names should reveal "what" without verbose "how"
   - Balance: short enough to scan, long enough to understand
   - ✅ `trap:on` vs ❌ `trap:register_signal_handler`

4. **Consistency**: Patterns should be predictable and uniform
   - Same verb = same meaning across all modules
   - Same structural patterns everywhere
   - Example: `:init` always means "initialize", never varies

5. **Clarity**: Names should be self-documenting and reveal intent
   - Self-documenting without being verbose
   - Readable at a glance

6. **Namespace Safety**: Avoid collisions with user code
   - Use module prefixes (`logger:`, `hooks:`)
   - Prefix internals (`__`, `_module:`)

7. **Discoverability**: Easy to find via tab-completion
   - Module prefix enables `logger:<TAB>` completion
   - Logical grouping by domain

---

## ⚠️ Critical Rule: Module Functions Must Be Lowercase

**All functions in library modules (`.scripts/_*.sh`) MUST be lowercase.**

- ✅ `logger:init`, `hooks:do`, `semver:compare`
- ❌ `logger:Init`, `Logger:init`, `loggerInit`

**Exceptions:**
- Generated functions (via `eval`): `echo:Common`, `log:MyApp` - CamelCase allowed
- Script functions (`bin/*.sh`, user scripts): Mixed case allowed

See [Function Naming](naming-functions.md) for complete details.

---

## Quick Reference

| Type                           | Pattern                     | Example                                                          | Scope                     | Case                  |
| ------------------------------ | --------------------------- | ---------------------------------------------------------------- | ------------------------- | --------------------- |
| **Module Function**            | `{domain}:{verb}`           | `logger:init`, `hooks:do`                                        | `.scripts/_*.sh`          | **lowercase only**    |
| **Module Function (nested)**   | `{domain}:{verb}:{entity}`  | `semver:increase:major`                                          | `.scripts/_*.sh`          | **lowercase only**    |
| **Internal Function**          | `_{domain}:*`               | `_hooks:capture:run`                                             | `.scripts/_*.sh`          | **lowercase only**    |
| **Internal Function (legacy, avoid)** | `_module::method`     | `_trap::dispatch`                                                | `.scripts/_*.sh` (legacy) | **lowercase only**    |
| **Generated Function**         | `action:Tag`                | `echo:Common`, `log:MyApp`                                       | Dynamic (eval)            | **CamelCase allowed** |
| **Script Function**            | `{domain}:{verb}` or `name` | `gitsv:add_keyword`, `processCommit`                             | `bin/*.sh`, user scripts  | **mixed case OK**     |
| **Module Global Variable**     | `__MODULE_VARIABLE`         | `__LOGGER_TAGS`, `__HOOKS_DEFINED`                               | Module state              |
| **Library Config Variable**    | `E_BASH_FEATURE`            | `E_BASH`, `E_BASH_SKIP_CACHE`                                    | Library configuration     |
| **Module Config Variable**     | `MODULE_CONFIG`             | `HOOKS_DIR`, `DEBUG`                                             | Module configuration      |
| **Local Variable**             | `snake_case`                | `version`, `tag_name`                                            | Function-local            |
| **Library Module File**        | `_modulename.sh`            | `_logger.sh`, `_hooks.sh`                                        | `.scripts/`               |
| **Executable Tool**            | `tool-name.sh`              | `install.e-bash.sh`                                              | `bin/`                    |
| **Namespaced Tool**            | `namespace.action.sh`       | `git.semantic-version.sh`                                        | `bin/`                    |
| **Versioned Script**           | `script-name.v{N}.sh`       | `version-up.v2.sh`, `install.e-bash.v1.sh`                       | `bin/` (rewrites)         |
| **Test File**                  | `spec/**/{script}_spec.sh`  | `spec/logger_spec.sh`, `spec/bin/git.verify-all-commits_spec.sh` | `spec/`                   |
| **Hook Script**                | `{hook}-{desc}.sh`          | `begin-init.sh`                                                  | `.hooks/`, `ci-cd/`       |
| **Ordered Hook Script**        | `{hook}_{NN}_{desc}.sh`     | `begin_10_setup.sh`                                              | `.hooks/`, `ci-cd/`       |
| **Demo Script**                | `demo.{feature}.sh`         | `demo.logger.sh`                                                 | `demos/`                  |
| **Benchmark Script**           | `benchmark.{feature}.sh`    | `benchmark.colors.sh`                                            | `demos/`                  |
| **Logger Tag**                 | `lowercase`                 | `common`, `debug`, `hooks`                                       | Logger system             |
| **Constant**                   | `SCREAMING_SNAKE_CASE`      | `EXIT_OK`, `TERM`                                                | Immutable values          |

---

## Detailed Conventions

For comprehensive details on each category, see the dedicated sub-documents:

- **[Function Naming](naming-functions.md)** - Public APIs, internal helpers, generated functions
- **[Variable Naming](naming-variables.md)** - Globals, configuration, locals, parameters
- **[File Naming](naming-files.md)** - Modules, tools, tests, hooks
- **[Logger/Tag Naming](naming-loggers.md)** - Logger tags and debug output
- **[Constants Naming](naming-constants.md)** - Exit codes, signals, versions
- **[Array Naming](naming-arrays.md)** - Associative and indexed arrays

---

## Anti-Patterns

❌ **DON'T** do these:

### Functions
```bash
# DON'T: Mixed case in public APIs
function Logger:Redirect() { ... }      # Wrong
function logger:redirect() { ... }      # Correct

# DON'T: Underscores in public APIs
function logger_redirect() { ... }      # Wrong (looks internal)
function logger:redirect() { ... }      # Correct

# DON'T: Single underscore for module globals functions
function _logger_init() { ... }         # Unclear scope
function _logger:init() { ... }        # Correct (clearly internal)

# DON'T: Legacy OOP-style internal functions
function _Trap::normalize_signal() { ... }  # Wrong (legacy mixed case)
function _trap:signal:normalize() { ... }   # Correct (internal helper)
```

### Variables
```bash
# DON'T: Unprefixed module globals
HOOKS_DEFINED=()                        # Wrong (pollutes global namespace)
__HOOKS_DEFINED=()                      # Correct

# DON'T: SCREAMING_CASE for locals
local VERSION="1.0.0"                   # Wrong
local version="1.0.0"                   # Correct

# DON'T: Use E_BASH_ prefix for non-library config
E_BASH_MY_VAR="value"                   # Wrong (reserved for library)
MY_MODULE_VAR="value"                   # Correct
```

### Files
```bash
# DON'T: Mixed naming styles
logger.sh                               # Wrong (no underscore prefix)
_logger.sh                              # Correct

# DON'T: Inconsistent tool naming
git-semantic-version.sh                 # Wrong (mix of - and words)
git.semantic-version.sh                 # Correct (consistent dots)
```

---

## Decision Tree

Use this flowchart to choose the right naming pattern:

### For Functions

```
Is this function part of the public API?
├─ YES → Use `module:action` or `module:action:target`
│        Example: logger:init, semver:increase:major
│
└─ NO → Is it module-internal?
    ├─ YES → Use `_module:function`
    │        Example: _logger:init
    │
    └─ NO → Is it dynamically generated?
        └─ YES → Use `action:Tag`
                 Example: echo:Common
```

### For Variables

```
Is this a variable?
├─ Library configuration (affects whole library)?
│  └─ Use `E_BASH_FEATURE`
│      Example: E_BASH, E_BASH_SKIP_CACHE
│
├─ Module configuration (user-facing)?
│  └─ Use `MODULE_CONFIG`
│      Example: HOOKS_DIR, DEBUG, HOOKS_EXEC_MODE
│
├─ Module internal state?
│  └─ Use `__MODULE_VARIABLE`
│      Example: __HOOKS_DEFINED, __LOGGER_TAGS
│
└─ Function-local or parameter?
   └─ Use `snake_case`
      Example: local version, local tag_name
```

### For Files

```
What type of file is this?
├─ Library module (sourced by other scripts)?
│  └─ Use `_modulename.sh`
│      Example: _logger.sh, _semver.sh
│
├─ Standalone executable?
│  ├─ Simple tool?
│  │  └─ Use `tool-name.sh`
│  │      Example: install.e-bash.sh
│  │
│  └─ Namespaced tool?
│     └─ Use `namespace.action.sh`
│         Example: git.semantic-version.sh
│
├─ Test file?
│  └─ Use `modulename_spec.sh`
│      Example: logger_spec.sh
│
└─ Hook script?
   ├─ Need ordered execution?
   │  └─ Use `{hook}_{NN}_{description}.sh`
   │      Example: begin_10_init.sh
   │
   └─ No specific order?
      └─ Use `{hook}-{description}.sh`
          Example: begin-otel-trace.sh
```

---

## Enforcement

### Manual Review
- All pull requests should reference this document
- Reviewers should check naming compliance
- Use examples from existing code as reference

### Automated Validation Tools

#### 1. Using ctags for Function Extraction

Extract and validate all function names using Universal Ctags:

```bash
# Extract all functions from module files
ctags --languages=sh --kinds-sh=f -x .scripts/*.sh | awk '{print $1}' > /tmp/module_functions.txt

# Check for mixed case violations in module functions
if grep -E '^[a-z_]+:[A-Z]' /tmp/module_functions.txt; then
  echo "ERROR: Module functions must be all lowercase"
  echo "Found mixed-case functions (see above)"
  exit 1
fi

# Check for functions without colon separator
if grep -E '^[a-z_]+[A-Z]' /tmp/module_functions.txt | grep -v '^_'; then
  echo "ERROR: Module functions must use colon separator (:)"
  echo "Found functions without colons (see above)"
  exit 1
fi
```

#### 2. Using ctags for Variable Extraction

Extract and validate global variables:

```bash
# Extract all global variables from module files
ctags --languages=sh --kinds-sh=v -x .scripts/*.sh | awk '{print $1}' > /tmp/module_vars.txt

# Check for unprefixed module globals
if grep -E '^[A-Z_]+$' /tmp/module_vars.txt | grep -vE '^(E_BASH|DEBUG|SKIP_|DRY_RUN|UNDO)'; then
  echo "WARNING: Module-internal globals should use __ prefix"
  echo "Found unprefixed globals (see above)"
fi

# Check for E_BASH_ prefix misuse (should only be library-level)
if grep -E '^E_BASH_[A-Z_]+$' /tmp/module_vars.txt; then
  echo "WARNING: Review E_BASH_ prefixed variables (reserved for library config)"
fi
```

#### 3. Git Hooks (via lefthook)

Add automated checks to `.lefthook/pre-commit/naming-validation.sh`:

```bash
#!/usr/bin/env bash
# Naming conventions validation hook

set -e

echo "🔍 Validating naming conventions..."

# Get staged .sh files in .scripts/
STAGED_MODULE_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '^\.scripts/.*\.sh$' || true)

if [[ -z "$STAGED_MODULE_FILES" ]]; then
  echo "✅ No module files changed"
  exit 0
fi

# Check 1: Module functions must be lowercase
echo "  Checking module function case..."
for file in $STAGED_MODULE_FILES; do
  # Extract functions using ctags
  ctags --languages=sh --kinds-sh=f -x "$file" 2>/dev/null | awk '{print $1}' | while read -r func; do
    # Skip internal functions (starting with _)
    if [[ "$func" =~ ^_ ]]; then
      continue
    fi

    # Check for mixed case in public functions (domain:Verb)
    if [[ "$func" =~ :[A-Z] ]]; then
      echo "❌ ERROR: Function '$func' in $file uses mixed case"
      echo "   Module functions must be lowercase: ${func,,}"
      exit 1
    fi
  done
done

# Check 2: Local variables should be snake_case
echo "  Checking local variable case..."
for file in $STAGED_MODULE_FILES; do
  if git diff --cached "$file" | grep -E '^\+\s+local [A-Z_]+=' | grep -v '^\+\s+local [A-Z_]+_[a-z]'; then
    echo "❌ ERROR: Local variables in $file use SCREAMING_CASE"
    echo "   Local variables should be snake_case"
    exit 1
  fi
done

# Check 3: Module globals should use __ prefix
echo "  Checking module global prefixes..."
for file in $STAGED_MODULE_FILES; do
  # Extract global variables (declare -g, declare -A -g, etc.)
  git diff --cached "$file" | grep -E '^\+\s*declare.*-g' | grep -oE '[A-Z_][A-Z0-9_]+=' | sed 's/=$//' | while read -r var; do
    # Skip well-known globals
    if [[ "$var" =~ ^(E_BASH|DEBUG|SKIP_|DRY_RUN|UNDO|HOOKS_|TAGS|SEMVER) ]]; then
      continue
    fi

    # Check for __ prefix
    if [[ ! "$var" =~ ^__ ]]; then
      echo "⚠️  WARNING: Global variable '$var' in $file should use __ prefix"
      echo "   Consider: __${var}"
    fi
  done
done

# Check 4: Module files must start with underscore
echo "  Checking module filename prefixes..."
for file in $STAGED_MODULE_FILES; do
  basename_file=$(basename "$file")
  if [[ ! "$basename_file" =~ ^_ ]]; then
    echo "❌ ERROR: Module file '$basename_file' must start with underscore"
    echo "   Rename to: _${basename_file}"
    exit 1
  fi
done

echo "✅ Naming conventions validated"
```

#### 4. ShellCheck Integration

ShellCheck already catches many issues. Run regularly:

```bash
# Check all shell files
shellcheck .scripts/*.sh bin/*.sh

# Check only staged files (in git hook)
git diff --cached --name-only | grep '\.sh$' | xargs shellcheck
```

#### 5. Continuous Integration

Add to CI pipeline (`.github/workflows/naming-validation.yml`):

```yaml
name: Naming Conventions

on: [push, pull_request]

jobs:
  validate-naming:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install ctags
        run: sudo apt-get install -y universal-ctags

      - name: Validate function naming
        run: |
          # Extract functions from modules
          ctags --languages=sh --kinds-sh=f -x .scripts/*.sh | awk '{print $1}' > /tmp/funcs.txt

          # Check for mixed case in public functions
          if grep -E '^[a-z_]+:[A-Z]' /tmp/funcs.txt | grep -v '^_'; then
            echo "ERROR: Module functions must be lowercase"
            exit 1
          fi

      - name: Run ShellCheck
        run: shellcheck .scripts/*.sh bin/*.sh
```

### Enforcement Summary

| Tool | What it Checks | When |
|------|----------------|------|
| **ctags** | Function/variable extraction & validation | Pre-commit, CI |
| **grep/awk** | Pattern matching for violations | Pre-commit, CI |
| **ShellCheck** | General shell script quality | Pre-commit, CI |
| **lefthook** | Orchestrate all checks | Pre-commit |
| **Manual review** | Complex cases, intent | PR review |

---

## Migration Guide

If you're updating existing code to follow these conventions:

1. **Start with new code** - Apply conventions to all new functions/files
2. **Rename strategically** - Focus on public APIs first
3. **Maintain compatibility** - Consider aliases for breaking changes:
   ```bash
   # Provide backward compatibility
   function old_function_name() {
      module:new:name "$@"
   }
   ```
4. **Document changes** - Update `CHANGELOG.md` with deprecation notices
5. **Version bumping** - Breaking renames require major version bump

---

## Examples Matrix

Real-world examples from the codebase:

| Pattern         | Good Example      | Bad Example       | Why?                                      |
| --------------- | ----------------- | ----------------- | ----------------------------------------- |
| Public API      | `logger:redirect` | `loggerRedirect`  | Colon separator is e-bash convention      |
| Internal helper | `__logger_init`   | `_logger_init`    | Double underscore = module-private        |
| Generated fn    | `echo:Common`     | `echo_common`     | Matches logger tag style                  |
| Module global   | `__HOOKS_DEFINED` | `HOOKS_DEFINED`   | Prefix prevents namespace pollution       |
| Library config  | `E_BASH`          | `EBASH`           | Underscore improves readability           |
| Module config   | `HOOKS_DIR`       | `HOOKS_DIRECTORY` | Shorter, clear, follows shell conventions |
| Local var       | `exit_code`       | `exitCode`        | Shell convention is snake_case            |
| Module file     | `_logger.sh`      | `logger.sh`       | Underscore distinguishes from tools       |
| Tool file       | `git.log.sh`      | `git-log.sh`      | Dots match git subcommand pattern         |
| Versioned tool  | `version-up.v2.sh` | `version-up-v2.sh`, `version-up_v2.sh` | Dot separator for version suffix |
| Test file       | `logger_spec.sh`  | `logger-spec.sh`  | Underscore matches ShellSpec convention   |

---

## Further Reading

- [ShellCheck Wiki](https://www.shellcheck.net/wiki/) - Shell script static analysis
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) - Industry best practices
- [Bash Hackers Wiki](https://wiki.bash-hackers.org/) - Bash scripting reference
- [Semantic Versioning](https://semver.org/) - Version number conventions

---

## Contributing

Found an inconsistency? See a better pattern? Please:

1. Open an issue with examples
2. Discuss in PR comments
3. Update this document as needed
4. Keep CHANGELOG.md updated

**Remember:** Consistency is more important than perfection. When in doubt, follow existing patterns in the codebase.
