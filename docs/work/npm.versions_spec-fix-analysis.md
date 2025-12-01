# npm.versions_spec.sh Test Failure Analysis and Fix

## Error Message
```
/home/runner/work/e-bash/e-bash/.scripts/_arguments.sh: line 250: printf:Parser: command not found
Unexpected output to stderr occurred at line 14-27 in 'spec/bin/npm.versions_spec.sh'
Bail out! Aborted by unexpected errors.
```

## Root Cause

The failure occurs due to a **timing/execution order problem** in how ShellSpec handles the `Include` directive in combination with the `__SOURCED__` guard pattern used throughout the e-bash codebase.

### Detailed Execution Sequence

When `Include bin/npm.versions.sh` executes:

1. **ShellSpec sets `__SOURCED__`** to prevent scripts from executing their main code

2. **npm.versions.sh sources modules** (lines 41-51):
   ```bash
   source "$E_BASH/_colors.sh"     # Line 41
   source "$E_BASH/_logger.sh"     # Line 43 - Creates logger() function
   source "$E_BASH/_commons.sh"    # Line 45
   source "$E_BASH/_dependencies.sh" # Line 47
   source "$E_BASH/_arguments.sh"  # Line 49 - KEY PROBLEM HERE
   ```

3. **When `_arguments.sh` is sourced** (line 49):
   - Line 488 of `_arguments.sh`: `${__SOURCED__:+return}` **RETURNS EARLY**
   - Lines 490-491 are **NEVER EXECUTED**:
     ```bash
     logger common "$@"  # Line 490 - SKIPPED
     logger:init parser "${cl_blue}[parser]${cl_reset} " # Line 491 - SKIPPED
     ```
   - Result: **`printf:Parser` and `echo:Parser` functions are NEVER created**

4. **Similarly, when `_commons.sh` is sourced** (line 45):
   - Line 490 of `_commons.sh`: `${__SOURCED__:+return}` **RETURNS EARLY**
   - Line 492 is **NEVER EXECUTED**:
     ```bash
     logger common "$@"  # Line 492 - SKIPPED
     ```
   - Result: **`printf:Common` and `echo:Common` functions are NEVER created**

5. **npm.versions.sh continues executing** after sourcing modules:
   - Lines 79-83: **Calls `args:d()` at TOP LEVEL** (not in a function):
     ```bash
     args:d '<package-name>' 'NPM package name to manage' "arguments" 1
     args:d '-h' 'Display this help message and exit' "global" 0
     args:d '-r' 'Specify NPM registry URL...' "options" 2
     args:d '--dry-run' 'Simulate commands...' "options" 2
     args:d '--silent' 'Hide npm command output...' "options" 2
     ```

6. **Inside `args:d()` function** (_arguments.sh line 250):
   ```bash
   printf:Parser "%12s -> %s ${cl_grey}group:%s order:%s${cl_reset}\n" ...
   ```
   **ERROR**: `printf:Parser` doesn't exist because `logger:init parser` was never called!

### Why BeforeRun 'export DEBUG="*"' Didn't Work

The previous fix attempted to solve this by setting `DEBUG="*"` before sourcing:
```bash
BeforeRun 'export DEBUG="*"'
```

This approach failed because:
1. `DEBUG="*"` only enables logger tag filtering (determines if output is shown)
2. It does NOT create logger functions
3. Logger functions are created by calling `logger <tag>` or `logger:init <tag>`
4. Since `_arguments.sh` and `_commons.sh` return early due to `__SOURCED__`, those logger creation calls are never executed

### Why This Doesn't Fail in spec/arguments_spec.sh

The existing `spec/arguments_spec.sh` test file doesn't encounter this error because:
1. It directly includes `_arguments.sh` without going through `bin/npm.versions.sh`
2. The tests only call `parse:arguments`, which doesn't use `printf:Parser` directly
3. **Critically**: `args:d()` is NEVER called during sourcing
4. The logger functions are only used inside test cases, where Mocks are active

## The Fix

Pre-create the required logger functions in `BeforeRun` BEFORE the `Include` directive executes:

```bash
BeforeRun '
  export DEBUG="*"
  export E_BASH="${SHELLSPEC_PROJECT_ROOT}/.scripts"
  source "${E_BASH}/_logger.sh"
  # Manually create logger functions that would normally be created by modules
  # but are skipped due to __SOURCED__ guard
  logger parser
  logger common
'
```

### Why This Fix Works

1. **BeforeRun executes BEFORE Include**: The functions are created before `npm.versions.sh` is sourced
2. **Logger re-sourcing is idempotent**: `_logger.sh` has a guard at line 11:
   ```bash
   if type logger | grep -q "is a function"; then return 0; fi
   ```
   This prevents conflicts when `npm.versions.sh` sources `_logger.sh` again

3. **Functions persist across sourcing**: Logger functions created in BeforeRun remain available when `Include` executes

4. **Covers all required loggers**: Creates both `parser` and `common` loggers, which includes:
   - `echo:Parser` and `printf:Parser` (for args:d() calls)
   - `echo:Common` and `printf:Common` (for general logging)

## Files Modified

- `/home/user/e-bash/spec/bin/npm.versions_spec.sh` (lines 15-30)

## Key Differences from Working Tests

| Aspect | spec/arguments_spec.sh (Working) | spec/bin/npm.versions_spec.sh (Was Failing) |
|--------|----------------------------------|---------------------------------------------|
| Include target | `_arguments.sh` directly | `bin/npm.versions.sh` (which sources modules) |
| args:d() calls | None during sourcing | 5 calls at top-level (lines 79-83) |
| Logger function usage | Only in test cases | During Include execution |
| Mock availability | Active in test cases | Not active during Include |
| __SOURCED__ impact | Prevents test execution | Prevents logger initialization |

## Lessons Learned

1. **Top-level code in scripts** (code outside functions) executes immediately during sourcing
2. **ShellSpec's Include + __SOURCED__** creates a unique execution environment where:
   - Scripts are sourced but initialization code is skipped
   - Functions are defined but may lack dependencies
3. **Mock blocks** are only active during test execution, NOT during Include sourcing
4. **BeforeRun is the correct place** to set up prerequisites for Include
5. **Logger functions must exist** before any code that uses them executes

## Related Files

- `/home/user/e-bash/.scripts/_logger.sh` (line 11: re-source guard, line 230: __SOURCED__ guard)
- `/home/user/e-bash/.scripts/_arguments.sh` (line 250: printf:Parser usage, line 488: __SOURCED__ guard)
- `/home/user/e-bash/.scripts/_commons.sh` (line 490: __SOURCED__ guard)
- `/home/user/e-bash/bin/npm.versions.sh` (lines 79-83: args:d() calls)
