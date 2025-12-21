# Hooks Middleware Implementation Plan v2.1

> **Merged best practices from v2 and v3**: TDD approach, improved capture harness, better naming conventions, and comprehensive documentation.

## Overview

Implement middleware abstraction for the hooks system that intercepts hook execution, captures output in a timeline array, and enables custom contract interpretation between hooks and main script. This allows hooks to communicate state changes (e.g., switching to DRY_RUN mode) while maintaining backward compatibility.

**Status**: Ready for implementation
**Approach**: Test-Driven Development with incremental commits
**Estimated effort**: 17-25 hours across 6 phases

---

## Key Design Decisions

1. ✅ **Unified execution order**: Registered functions and scripts execute in single alphabetical sequence
2. ✅ **Timeline-preserving capture**: Use `awk` with `fflush()` for reliable stdout/stderr interleaving
3. ✅ **No hardcoded contract format**: Middleware is flexible - implementers define conventions
4. ✅ **TDD methodology**: Write failing test → implement → verify pass → commit
5. ✅ **Internal function naming**: Underscore prefix (`_hooks:*`) for internal functions
6. ✅ **Middleware signature**: `<hook_name> <exit_code> <capture_var> -- <hook_args...>` (hook_name first)

---

## Critical Files

- `.scripts/_hooks.sh` (primary implementation, ~500 lines changed)
- `spec/hooks_spec.sh` (48 of 79 tests affected, ~30 new tests)
- `docs/public/hooks.md` (~200 lines added for middleware section)
- `demos/ci-mode/demo.ci-modes-middleware.sh` (new demo)
- `demos/ci-mode/hooks-mw/` (demo hook scripts subdirectory)

---

## Phase 1: Prerequisites (MUST COMPLETE FIRST)

### Task 1.1: Unify Registered Functions and Scripts into Single Sequence

**File**: `.scripts/_hooks.sh`
**Lines affected**: 394-481

**TDD Steps**:

#### Step 1: Write failing test

Add to `spec/hooks_spec.sh` in a new context after line 1519:

```bash
Context 'Unified execution order /'
  It 'executes registered functions and scripts in one alphabetical sequence'
    setup() {
      setup_test_hooks_dir
      hooks:declare merge_order

      # Define hook function (executes first)
      hook:merge_order() { echo "function"; }

      # Register functions with friendly names
      func_alpha() { echo "alpha"; }
      func_charlie() { echo "charlie"; }
      hooks:register merge_order "10-alpha" func_alpha
      hooks:register merge_order "30-charlie" func_charlie

      # Create script with middle sort key
      cat > "$TEST_HOOKS_DIR/merge_order-20-bravo.sh" <<'EOF'
#!/usr/bin/env bash
echo "bravo"
EOF
      chmod +x "$TEST_HOOKS_DIR"/merge_order-20-bravo.sh
    }
    BeforeCall 'setup'

    When call hooks:do merge_order

    The status should be success
    The line 1 should eq "function"      # hook:merge_order first
    The line 2 should eq "alpha"         # 10-alpha
    The line 3 should eq "bravo"         # 20-bravo (script)
    The line 4 should eq "charlie"       # 30-charlie
  End
End
```

#### Step 2: Run test to verify failure

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: FAIL - registered functions execute before scripts (separate phases)

#### Step 3: Implement unified ordering

In `.scripts/_hooks.sh`, replace lines 397-481 with:

```bash
# Build unified array of implementations (registered functions + scripts)
local -a unified_impls=()

# Add registered functions with format: "sortkey|function|target"
local registered="${__HOOKS_REGISTERED[$hook_name]}"
if [[ -n "$registered" ]]; then
  local entry
  IFS='|' read -ra entries <<< "$registered"
  for entry in "${entries[@]}"; do
    local friendly="${entry%%:*}"
    local func="${entry#*:}"
    if declare -F "$func" >/dev/null 2>&1; then
      unified_impls+=("${friendly}|function|${func}")
    fi
  done
fi

# Add scripts with format: "basename|script|path"
if [[ -d "$HOOKS_DIR" ]]; then
  while IFS= read -r -d '' script; do
    if [[ -x "$script" ]]; then
      local script_name=$(basename "$script")
      unified_impls+=("${script_name}|script|${script}")
    fi
  done < <(find "$HOOKS_DIR" -maxdepth 1 \( -name "${hook_name}-*.sh" -o -name "${hook_name}_*.sh" \) -type f -print0 2>/dev/null | sort -z)
fi

# Sort unified array alphabetically by sort key
IFS=$'\n' unified_impls=($(sort <<<"${unified_impls[*]}"))
unset IFS

# Execute implementations in sorted order
local total=${#unified_impls[@]}
local n=0
for impl in "${unified_impls[@]}"; do
  ((n++))
  IFS='|' read -r sortkey type target <<< "$impl"

  if [[ "$type" == "function" ]]; then
    echo:Hooks "  → [registered $n/$total] ${sortkey} → ${target}()"
    "$target" "$@"
    last_exit_code=$?
    echo:Hooks "    ↳ exit code: $last_exit_code"
    ((impl_count++))

  elif [[ "$type" == "script" ]]; then
    local exec_mode=$(hooks:exec:mode "$sortkey")

    if [[ "$exec_mode" == "source" ]]; then
      echo:Hooks "  → [script $n/$total] ${sortkey} (sourced mode)"
      source "$target"
      if declare -F "hook:run" >/dev/null 2>&1; then
        hook:run "$@"
        last_exit_code=$?
      else
        echo:Hooks "    ⚠ No hook:run function found in ${sortkey}, skipping"
        last_exit_code=0
      fi
    else
      echo:Hooks "  → [script $n/$total] ${sortkey} (exec mode)"
      "$target" "$@"
      last_exit_code=$?
    fi

    echo:Hooks "    ↳ exit code: $last_exit_code"
    ((impl_count++))
  fi
done
```

#### Step 4: Run test to verify pass

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: PASS - unified alphabetical ordering

#### Step 5: Update affected tests

Update test expectations in `spec/hooks_spec.sh`:
- Line 311-312: May need reordering if scripts interleave
- Line 1081-1083: Already sorted, should still pass

#### Step 6: Commit

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: unify registered functions and scripts execution order

- Merge registered functions and scripts into single alphabetical sequence
- Both now execute in order by sort key (friendly name or basename)
- Add comprehensive test for unified ordering
- Update affected test expectations"
```

---

### Task 1.2: Downgrade "No implementations found" to INFO

**File**: `.scripts/_hooks.sh`
**Line**: 485 (after unified ordering changes, line number may shift)

**TDD Steps**:

#### Step 1: Update log message

```bash
# OLD:
echo:Hooks "  ⚠ No implementations found for hook '$hook_name'"

# NEW:
echo:Hooks "  ℹ No implementations found for hook '$hook_name'"
```

#### Step 2: Update test assertions

In `spec/hooks_spec.sh`, update assertions checking for this message:
- Line 192: Change expected text from "⚠" to "ℹ"
- Line 340: Change expected text
- Line 1101: Change expected text

#### Step 3: Run tests to verify

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: PASS with updated assertions

#### Step 4: Commit

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "fix: downgrade 'no implementations' from warning to info

- 99% of hooks have no implementations - this is expected behavior
- Change warning symbol (⚠) to info symbol (ℹ)
- Update test assertions for new log level"
```

---

## Phase 2: Core Middleware Implementation

### Task 2.1: Add Middleware Storage and Dependencies

**File**: `.scripts/_hooks.sh`
**Location**: After line 37 (global arrays section)

**TDD Steps**:

#### Step 1: Add _commons.sh dependency

At top of `.scripts/_hooks.sh` after line 20 (after `_logger.sh` source):

```bash
# shellcheck disable=SC1090 source=./_commons.sh
source "$E_BASH/_commons.sh"
```

#### Step 2: Add middleware storage

After line 37:

```bash
# declare global associative array for middleware functions (internal)
# stores hook_name -> middleware_function_name
if [[ -z ${__HOOKS_MIDDLEWARE+x} ]]; then declare -g -A __HOOKS_MIDDLEWARE; fi

# declare global sequence counter for unique capture array names (internal)
if [[ -z ${__HOOKS_CAPTURE_SEQ+x} ]]; then declare -g __HOOKS_CAPTURE_SEQ=0; fi
```

#### Step 3: Update hooks:reset()

In `hooks:reset()` function (around line 690), add:

```bash
unset __HOOKS_MIDDLEWARE
unset __HOOKS_CAPTURE_SEQ

declare -g -A __HOOKS_MIDDLEWARE
declare -g __HOOKS_CAPTURE_SEQ=0
```

#### Step 4: Commit

```bash
git add .scripts/_hooks.sh
git commit -m "feat: add middleware storage and capture sequence counter

- Add __HOOKS_MIDDLEWARE associative array for per-hook middleware
- Add __HOOKS_CAPTURE_SEQ counter for unique capture variable naming
- Source _commons.sh for to:slug function
- Update hooks:reset() to clean up middleware state"
```

---

### Task 2.2: Implement Middleware Registration API

**File**: `.scripts/_hooks.sh`
**Location**: After `hooks:register` function (after line 228)

**TDD Steps**:

#### Step 1: Write failing tests

Add to `spec/hooks_spec.sh`:

```bash
Context 'Middleware registration /'
  It 'registers middleware per hook'
    custom_mw() { return 0; }

    setup() {
      hooks:declare test_hook 2>/dev/null
    }
    BeforeCall 'setup'

    When call hooks:middleware test_hook custom_mw

    The status should be success
    The result of function no_colors_stderr should include "Registered middleware"
  End

  It 'resets middleware to default when only hook name provided'
    custom_mw() { return 0; }

    setup() {
      hooks:declare test_hook 2>/dev/null
      hooks:middleware test_hook custom_mw 2>/dev/null
    }
    BeforeCall 'setup'

    When call hooks:middleware test_hook

    The status should be success
    The result of function no_colors_stderr should include "Reset middleware"
  End

  It 'fails when middleware function does not exist'
    setup() {
      hooks:declare test_hook 2>/dev/null
    }
    BeforeCall 'setup'

    When call hooks:middleware test_hook nonexistent_func

    The status should be failure
    The stderr should include "does not exist"
  End

  It 'fails when no hook name provided'
    When call hooks:middleware

    The status should be failure
    The stderr should include "requires"
  End
End
```

#### Step 2: Run tests to verify failure

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: FAIL - hooks:middleware not defined

#### Step 3: Implement registration API

After `hooks:register` function:

```bash
#
# Register a middleware function for a hook
#
# Usage:
#   hooks:middleware begin my_middleware_func
#   hooks:middleware deploy                      # Reset to default
#
# Parameters:
#   $1 - Hook name
#   $2 - Middleware function name (optional, omit to reset to default)
#
# Returns:
#   0 - Success
#   1 - Invalid parameters or function doesn't exist
#
function hooks:middleware() {
  local hook_name="$1"
  local middleware_func="${2:-}"

  # Validate hook name
  if [[ -z "$hook_name" ]]; then
    echo "Error: hooks:middleware requires <hook> [function]" >&2
    return 1
  fi

  # Reset to default if no function specified
  if [[ -z "$middleware_func" ]]; then
    unset "__HOOKS_MIDDLEWARE[$hook_name]"
    echo:Hooks "Reset middleware for hook '$hook_name' to default"
    return 0
  fi

  # Validate middleware function exists
  if ! declare -F "$middleware_func" >/dev/null 2>&1; then
    echo "Error: Middleware function '$middleware_func' does not exist" >&2
    return 1
  fi

  # Register middleware
  __HOOKS_MIDDLEWARE[$hook_name]="$middleware_func"
  echo:Hooks "Registered middleware '${middleware_func}' for hook '${hook_name}'"
  return 0
}
```

#### Step 4: Run tests to verify pass

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: PASS

#### Step 5: Commit

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: implement middleware registration API

- Add hooks:middleware function for per-hook middleware registration
- Support reset to default by omitting function parameter
- Validate middleware function exists before registration
- Add comprehensive test coverage for registration API"
```

---

### Task 2.3: Implement Output Capture Harness

**File**: `.scripts/_hooks.sh`
**Location**: After `hooks:middleware` function

**TDD Steps**:

#### Step 1: Write failing test

Add to `spec/hooks_spec.sh`:

```bash
Context 'Output capture /'
  It 'captures stdout and stderr with timeline prefixes'
    hook_test() {
      echo "line1"
      echo "err1" >&2
      echo "line2"
      return 7
    }

    setup() {
      hooks:declare cap_hook 2>/dev/null
    }
    BeforeCall 'setup'

    When call _hooks:capture:run cap_hook capture_var hook_test

    The status should eq 7
    The variable capture_var should be present
  End
End
```

#### Step 2: Run test to verify failure

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: FAIL - _hooks:capture:run not defined

#### Step 3: Implement capture harness

After `hooks:middleware` function:

```bash
#
# Execute implementation with output capture (internal helper)
#
# Captures stdout/stderr into timeline array with prefixes:
#   "1: <line>" - stdout
#   "2: <line>" - stderr
#
# Parameters:
#   $1 - Hook name (for logging and array naming)
#   $2 - Variable name to store capture array name in
#   $@ - Command and arguments to execute
#
# Sets global:
#   Capture array with unique name
#   Variable referenced by $2 contains array name
#
# Returns:
#   Exit code from implementation
#
function _hooks:capture:run() {
  local hook_name="$1"
  local capture_var="$2"
  shift 2

  # Generate unique capture array name
  local hook_slug
  hook_slug="$(to:slug "$hook_name" "_" 40)"
  __HOOKS_CAPTURE_SEQ=$((__HOOKS_CAPTURE_SEQ + 1))
  local capture_name="__hooks_${hook_slug}_${__HOOKS_CAPTURE_SEQ}"

  # Create temp file for captured output
  local capture_file
  capture_file="$(mktemp)" || {
    echo "Error: Failed to create temp file for capture" >&2
    return 1
  }

  # Execute with output capture using awk for timeline preservation
  # fflush() ensures immediate write for better ordering
  "$@" \
    > >(awk '{print "1: "$0; fflush()}' >> "$capture_file") \
    2> >(awk '{print "2: "$0; fflush()}' >> "$capture_file")
  local exit_code=$?

  # Wait for background processes to complete
  wait

  # Populate global capture array from temp file
  declare -g -a "$capture_name"=()
  mapfile -t "$capture_name" < "$capture_file"
  rm -f "$capture_file"

  # Return capture array name via variable reference
  printf -v "$capture_var" '%s' "$capture_name"

  return "$exit_code"
}

#
# Cleanup capture array (internal helper)
#
function _hooks:capture:cleanup() {
  local var_name="$1"
  [[ -n "$var_name" ]] && unset "$var_name"
}
```

#### Step 4: Run test to verify pass

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: PASS

#### Step 5: Commit

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: implement timeline-preserving output capture harness

- Use awk with fflush() for reliable stdout/stderr interleaving
- Generate unique capture array names with sequence counter
- Prefix output lines: '1: ' for stdout, '2: ' for stderr
- Add cleanup function to prevent memory leaks
- Add test coverage for capture functionality"
```

---

### Task 2.4: Implement Default Middleware

**File**: `.scripts/_hooks.sh`
**Location**: Before `_hooks:capture:run` function

**TDD Steps**:

#### Step 1: Write failing test

Add to `spec/hooks_spec.sh`:

```bash
Context 'Default middleware /'
  It 'replays stdout/stderr unchanged and preserves exit code'
    setup() {
      hooks:declare def_hook
      hook:def_hook() {
        echo "stdout line"
        echo "stderr line" >&2
        return 42
      }
    }
    BeforeCall 'setup'

    When call hooks:do def_hook

    The status should eq 42
    The output should eq "stdout line"
    The error should include "stderr line"
  End
End
```

#### Step 2: Run test to verify current behavior

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: Currently PASS (direct execution), will need middleware integration

#### Step 3: Implement default middleware

Before `_hooks:capture:run`:

```bash
#
# Default middleware for hook implementations (internal)
# Preserves current behavior: replays output as-is, returns exit code
#
# Signature:
#   _hooks:middleware:default <hook_name> <exit_code> <capture_var> -- <hook_args...>
#
# Parameters:
#   $1 - Hook name
#   $2 - Exit code from implementation
#   $3 - Name of array variable containing captured output
#   $4 - Literal "--" separator
#   $@ - Original hook arguments (after --)
#
# Output array format (referenced by $3):
#   Each element: "1: <stdout line>" or "2: <stderr line>"
#
# Returns:
#   Exit code from implementation (unmodified)
#
function _hooks:middleware:default() {
  local hook_name="$1"
  local exit_code="$2"
  local capture_var="$3"
  shift 3

  # Validate "--" separator
  if [[ "$1" != "--" ]]; then
    echo "Error: middleware expects '--' separator" >&2
    return 1
  fi
  shift

  # Replay captured output (nameref for efficient array access)
  local -n capture_ref="$capture_var"
  local line
  for line in "${capture_ref[@]}"; do
    case "$line" in
      "1: "*) printf '%s\n' "${line#1: }" ;;      # stdout
      "2: "*) printf '%s\n' "${line#2: }" >&2 ;;  # stderr
      *) printf '%s\n' "$line" ;;                 # unformatted (fallback)
    esac
  done

  return "$exit_code"
}
```

#### Step 4: Commit

```bash
git add .scripts/_hooks.sh
git commit -m "feat: implement default middleware function

- Simple replay of captured output preserves backward compatibility
- Uses nameref for efficient array access
- Validates separator parameter
- Returns original exit code unmodified"
```

---

### Task 2.5: Integrate Middleware into hooks:do

**File**: `.scripts/_hooks.sh`
**Location**: Modify `hooks:do` function

**TDD Steps**:

#### Step 1: Write integration tests

Add to `spec/hooks_spec.sh`:

```bash
Context 'Middleware integration /'
  It 'uses default middleware for exec-mode implementations'
    setup() {
      hooks:declare test_hook
      hook:test_hook() {
        echo "test output"
        return 5
      }
    }
    BeforeCall 'setup'

    When call hooks:do test_hook

    The status should eq 5
    The output should eq "test output"
    The result of function no_colors_stderr should include "Using middleware: _hooks:middleware:default"
  End

  It 'allows custom middleware to modify behavior'
    custom_mw() {
      local hook_name="$1" exit_code="$2" capture_var="$3"
      shift 3; shift  # skip "--"

      # Override exit code
      return 99
    }

    setup() {
      hooks:declare test_hook
      hook:test_hook() { return 0; }
      hooks:middleware test_hook custom_mw 2>/dev/null
    }
    BeforeCall 'setup'

    When call hooks:do test_hook

    The status should eq 99
    The result of function no_colors_stderr should include "Using middleware: custom_mw"
  End

  It 'bypasses middleware for source-mode scripts'
    setup() {
      setup_test_hooks_dir
      export HOOKS_EXEC_MODE="source"
      hooks:declare src_hook

      cat > "$TEST_HOOKS_DIR/src_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  export TEST_VAR="source_modified"
  echo "source output"
}
EOF
      chmod +x "$TEST_HOOKS_DIR"/src_hook-test.sh

      # Middleware that would override exit code
      mw_override() { return 88; }
      hooks:middleware src_hook mw_override 2>/dev/null
    }
    BeforeCall 'setup'

    verify_source() {
      hooks:do src_hook
      echo "TEST_VAR=$TEST_VAR"
    }

    When call verify_source

    The status should be success  # NOT 88 - middleware bypassed
    The output should include "source output"
    The output should include "TEST_VAR=source_modified"
  End
End
```

#### Step 2: Run tests to verify failure

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: FAIL - middleware not integrated

#### Step 3: Integrate into hooks:do

In `hooks:do` function, after line 382 (after hook defined check), add:

```bash
# Resolve middleware function for this hook
local middleware_func="${__HOOKS_MIDDLEWARE[$hook_name]:-_hooks:middleware:default}"
echo:Hooks "  Using middleware: $middleware_func"
```

For `hook:name()` function execution (around lines 386-392), replace with:

```bash
local func_name="${HOOKS_PREFIX}${hook_name}"
if declare -F "$func_name" >/dev/null 2>&1; then
  echo:Hooks "  → [function] ${func_name}"

  # Capture output and run through middleware
  local capture_var_name
  _hooks:capture:run "$hook_name" capture_var_name "$func_name" "$@"
  local capture_exit=$?

  # Call middleware
  "$middleware_func" "$hook_name" "$capture_exit" "$capture_var_name" -- "$@"
  last_exit_code=$?

  # Cleanup capture array
  _hooks:capture:cleanup "$capture_var_name"

  echo:Hooks "    ↳ exit code: $last_exit_code"
  ((impl_count++))
fi
```

For unified implementations loop, wrap exec-mode executions:

```bash
for impl in "${unified_impls[@]}"; do
  ((n++))
  IFS='|' read -r sortkey type target <<< "$impl"

  if [[ "$type" == "function" ]]; then
    echo:Hooks "  → [registered $n/$total] ${sortkey} → ${target}()"

    # Capture and middleware
    local capture_var_name
    _hooks:capture:run "$hook_name" capture_var_name "$target" "$@"
    local capture_exit=$?

    "$middleware_func" "$hook_name" "$capture_exit" "$capture_var_name" -- "$@"
    last_exit_code=$?

    _hooks:capture:cleanup "$capture_var_name"

    echo:Hooks "    ↳ exit code: $last_exit_code"
    ((impl_count++))

  elif [[ "$type" == "script" ]]; then
    local exec_mode=$(hooks:exec:mode "$sortkey")

    if [[ "$exec_mode" == "source" ]]; then
      # SOURCE MODE: BYPASS MIDDLEWARE
      echo:Hooks "  → [script $n/$total] ${sortkey} (sourced mode)"
      source "$target"
      if declare -F "hook:run" >/dev/null 2>&1; then
        hook:run "$@"
        last_exit_code=$?
      else
        echo:Hooks "    ⚠ No hook:run function found in ${sortkey}, skipping"
        last_exit_code=0
      fi
    else
      # EXEC MODE: USE MIDDLEWARE
      echo:Hooks "  → [script $n/$total] ${sortkey} (exec mode)"

      local capture_var_name
      _hooks:capture:run "$hook_name" capture_var_name "$target" "$@"
      local capture_exit=$?

      "$middleware_func" "$hook_name" "$capture_exit" "$capture_var_name" -- "$@"
      last_exit_code=$?

      _hooks:capture:cleanup "$capture_var_name"
    fi

    echo:Hooks "    ↳ exit code: $last_exit_code"
    ((impl_count++))
  fi
done
```

#### Step 4: Run tests to verify pass

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: PASS for middleware integration tests

#### Step 5: Run full test suite

```bash
shellspec spec/hooks_spec.sh
```

**Expected**: Most existing tests should still pass (default middleware preserves behavior)

#### Step 6: Commit

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: integrate middleware into hook execution pipeline

- Resolve middleware per hook (custom or default)
- Wrap exec-mode implementations with capture + middleware
- Source mode scripts bypass middleware (direct execution)
- Default middleware preserves backward compatibility
- Add comprehensive integration tests"
```

---

## Phase 3: Extended Test Coverage

### Task 3.1: Add Contract Parsing Tests

**File**: `spec/hooks_spec.sh`

**TDD Steps**:

#### Step 1: Add contract middleware tests

```bash
Context 'Contract middleware patterns /'
  It 'allows middleware to parse contract lines and set variables'
    contract_mw() {
      local hook_name="$1" exit_code="$2" capture_var="$3"
      shift 3; shift

      local -n capture_ref="$capture_var"
      for line in "${capture_ref[@]}"; do
        case "$line" in
          "1: contract:mode=dry")
            export DRY_RUN=true
            ;;
          "1: contract:mode=verbose")
            export DEBUG="*"
            ;;
          "1: "*) printf '%s\n' "${line#1: }" ;;
          "2: "*) printf '%s\n' "${line#2: }" >&2 ;;
        esac
      done

      return "$exit_code"
    }

    setup() {
      hooks:declare begin
      hook:begin() {
        echo "contract:mode=dry"
        echo "contract:mode=verbose"
        echo "normal output"
      }
      hooks:middleware begin contract_mw 2>/dev/null
    }
    BeforeCall 'setup'

    verify_contracts() {
      hooks:do begin
      echo "DRY_RUN=$DRY_RUN"
      echo "DEBUG=$DEBUG"
    }

    When call verify_contracts

    The status should be success
    The output should include "normal output"
    The output should include "DRY_RUN=true"
    The output should include "DEBUG=*"
  End

  It 'middleware can suppress contract lines from output'
    filter_mw() {
      local hook_name="$1" exit_code="$2" capture_var="$3"
      shift 3; shift

      local -n capture_ref="$capture_var"
      for line in "${capture_ref[@]}"; do
        # Skip contract lines, replay others
        [[ "$line" == "1: contract:"* ]] && continue
        case "$line" in
          "1: "*) printf '%s\n' "${line#1: }" ;;
          "2: "*) printf '%s\n' "${line#2: }" >&2 ;;
        esac
      done

      return "$exit_code"
    }

    setup() {
      hooks:declare test
      hook:test() {
        echo "contract:hidden=true"
        echo "visible output"
      }
      hooks:middleware test filter_mw 2>/dev/null
    }
    BeforeCall 'setup'

    When call hooks:do test

    The output should not include "contract:hidden"
    The output should include "visible output"
  End
End
```

#### Step 2: Run tests

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: PASS

#### Step 3: Commit

```bash
git add spec/hooks_spec.sh
git commit -m "test: add contract parsing pattern coverage

- Test middleware parsing custom contract lines
- Test variable setting via contracts
- Test contract line filtering from output
- Demonstrate flexible contract interpretation"
```

---

### Task 3.2: Add Error Handling Tests

**File**: `spec/hooks_spec.sh`

**TDD Steps**:

#### Step 1: Add error handling tests

```bash
Context 'Middleware error handling /'
  It 'handles invalid separator gracefully'
    bad_mw() {
      # Missing "--" parameter handling
      return 1
    }

    setup() {
      hooks:declare test_hook
      hook:test_hook() { echo "test"; }
      hooks:middleware test_hook bad_mw 2>/dev/null
    }
    BeforeCall 'setup'

    When call hooks:do test_hook

    # Should handle gracefully, not crash
    The status should not eq 0
  End

  It 'handles middleware execution failures'
    crash_mw() {
      # Intentionally fail
      return 127
    }

    setup() {
      hooks:declare test_hook
      hook:test_hook() { return 0; }
      hooks:middleware test_hook crash_mw 2>/dev/null
    }
    BeforeCall 'setup'

    When call hooks:do test_hook

    The status should eq 127
  End
End
```

#### Step 2: Run tests

```bash
shellspec spec/hooks_spec.sh -f d
```

**Expected**: PASS

#### Step 3: Commit

```bash
git add spec/hooks_spec.sh
git commit -m "test: add middleware error handling coverage

- Test invalid separator handling
- Test middleware execution failures
- Ensure graceful degradation"
```

---

## Phase 4: Demo Implementation

### Task 4.1: Create Middleware Demo

**Files**:
- Create: `demos/ci-mode/demo.ci-modes-middleware.sh`
- Create: `demos/ci-mode/ci-20-compile.sh`
- Create: `demos/ci-mode/hooks-mw/begin_00_mode-resolve.sh`
- Create: `demos/ci-mode/hooks-mw/begin_10_mode-dry.sh`
- Create: `demos/ci-mode/hooks-mw/begin_11_mode-ok.sh`
- Create: `demos/ci-mode/hooks-mw/begin_12_mode-error.sh`

**TDD Steps**:

#### Step 1: Create main demo script

`demos/ci-mode/demo.ci-modes-middleware.sh`:

```bash
#!/usr/bin/env bash

## Middleware-based CI Modes Demo
## Demonstrates contract interpretation via middleware

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -z "$E_BASH" ] && readonly E_BASH="$(cd "${SCRIPT_DIR}" && cd ../../.scripts && pwd)"

source "$E_BASH/_colors.sh"
source "$E_BASH/_logger.sh"
source "$E_BASH/_hooks.sh"

# Set hooks directory to middleware demo subdirectory
export HOOKS_DIR="${SCRIPT_DIR}/hooks-mw"

logger:init demo "${cl_cyan}[demo]${cl_reset} " ">&2"

echo ""
echo "${cl_lblue}${st_b}=== CI Modes via Middleware Demo ===${st_no_b}${cl_reset}"
echo ""

# Contract-aware middleware
ci:middleware() {
  local hook_name="$1" exit_code="$2" capture_var="$3"
  shift 3; shift  # skip "--"

  local -n capture_ref="$capture_var"
  local line

  for line in "${capture_ref[@]}"; do
    case "$line" in
      "1: contract:mode=dry")
        export DRY_RUN=true
        export CI_MODE="DRY"
        echo:Demo "${cl_yellow}→ Contract: Enabling DRY_RUN mode${cl_reset}"
        ;;
      "1: contract:mode=ok")
        export __CI_MODE_EXIT=0
        export __CI_MODE_TERMINATE=true
        echo:Demo "${cl_green}→ Contract: OK mode - immediate success${cl_reset}"
        ;;
      "1: contract:mode=error:"*)
        export __CI_MODE_EXIT="${line#1: contract:mode=error:}"
        export __CI_MODE_TERMINATE=true
        echo:Demo "${cl_red}→ Contract: ERROR mode - exit ${__CI_MODE_EXIT}${cl_reset}"
        ;;
      "1: "*) printf '%s\n' "${line#1: }" ;;
      "2: "*) printf '%s\n' "${line#2: }" >&2 ;;
    esac
  done

  return "$exit_code"
}

# Register middleware for begin hook
hooks:declare begin end
hooks:middleware begin ci:middleware

# Test different modes
echo "${cl_cyan}Test 1: Normal mode${cl_reset}"
unset CI_SCRIPT_MODE DRY_RUN __CI_MODE_TERMINATE
hooks:do begin "test-script"
echo "  Mode: ${CI_MODE:-NORMAL}"
echo ""

echo "${cl_cyan}Test 2: DRY mode${cl_reset}"
export CI_SCRIPT_MODE=DRY
unset DRY_RUN __CI_MODE_TERMINATE
hooks:do begin "test-script"
echo "  DRY_RUN: ${DRY_RUN:-false}"
echo "  Terminate: ${__CI_MODE_TERMINATE:-false}"
echo ""

echo "${cl_cyan}Test 3: OK mode${cl_reset}"
export CI_SCRIPT_MODE=OK
unset __CI_MODE_TERMINATE __CI_MODE_EXIT
hooks:do begin "test-script"
echo "  Terminate: ${__CI_MODE_TERMINATE:-false}"
echo "  Exit: ${__CI_MODE_EXIT:-<none>}"
echo ""

echo "${cl_lblue}${st_b}Demo complete!${st_no_b}${cl_reset}"
```

#### Step 2: Create hook scripts

`demos/ci-mode/hooks-mw/begin_00_mode-resolve.sh`:

```bash
#!/usr/bin/env bash
# Resolve CI mode for the script

# Get script name from hook argument
SCRIPT_NAME="${1:-unknown}"

# Safe script name for variable lookup
SCRIPT_NAME_SAFE="$(echo "$SCRIPT_NAME" | tr '.-' '_')"

# Check per-script mode variable
MODE_VAR="CI_SCRIPT_MODE_${SCRIPT_NAME_SAFE}"
RESOLVED_MODE="${!MODE_VAR:-${CI_SCRIPT_MODE:-EXEC}}"

echo "Mode resolution for $SCRIPT_NAME: $RESOLVED_MODE"
export __CI_SCRIPT_MODE="$RESOLVED_MODE"
```

`demos/ci-mode/hooks-mw/begin_10_mode-dry.sh`:

```bash
#!/usr/bin/env bash
# DRY mode - preview commands without execution

if [[ "${__CI_SCRIPT_MODE:-}" == "DRY" ]]; then
  echo "contract:mode=dry"
fi
```

`demos/ci-mode/hooks-mw/begin_11_mode-ok.sh`:

```bash
#!/usr/bin/env bash
# OK mode - immediate success

if [[ "${__CI_SCRIPT_MODE:-}" == "OK" ]]; then
  echo "contract:mode=ok"
fi
```

`demos/ci-mode/hooks-mw/begin_12_mode-error.sh`:

```bash
#!/usr/bin/env bash
# ERROR mode - fail with specific exit code

if [[ "${__CI_SCRIPT_MODE:-}" == "ERROR" ]]; then
  ERROR_CODE="${CI_SCRIPT_ERROR_CODE:-1}"
  echo "contract:mode=error:${ERROR_CODE}"
fi
```

#### Step 3: Make scripts executable

```bash
chmod +x demos/ci-mode/demo.ci-modes-middleware.sh
chmod +x demos/ci-mode/hooks-mw/*.sh
```

#### Step 4: Test demo manually

```bash
demos/ci-mode/demo.ci-modes-middleware.sh
```

**Expected**: Demo runs and shows different modes via contract interpretation

#### Step 5: Commit

```bash
git add demos/ci-mode/
git commit -m "demo: add middleware-based CI modes demonstration

- Main demo script with contract-aware middleware
- Hook scripts emit contract lines based on CI_SCRIPT_MODE
- Demonstrates DRY, OK, and ERROR modes via middleware
- Shows parent shell variable modification through contracts
- Organized hook scripts in hooks-mw/ subdirectory"
```

---

### Task 4.2: Create Demo README

**File**: `demos/ci-mode/README.md`

#### Step 1: Create documentation

```markdown
# CI Modes Demo - Middleware Edition

This demo shows how to use hooks middleware to implement contract-based CI modes.

## Overview

The middleware pattern allows hook scripts to communicate with the main script through contract lines in their output. The middleware function parses these contract lines and applies side effects (setting variables, controlling flow) in the parent shell.

## Architecture

```
Hook Script (exec mode)
  ↓ outputs contract lines
Capture Harness
  ↓ prefixed array ("1: ", "2: ")
Middleware Function
  ↓ parses contracts, sets variables
Main Script
  ↓ uses middleware-set variables
Continue or Exit
```

## Files

- `demo.ci-modes-middleware.sh` - Main demo runner
- `hooks-mw/begin_00_mode-resolve.sh` - Resolves mode per script
- `hooks-mw/begin_10_mode-dry.sh` - DRY mode contract
- `hooks-mw/begin_11_mode-ok.sh` - OK mode contract
- `hooks-mw/begin_12_mode-error.sh` - ERROR mode contract

## Running the Demo

```bash
./demos/ci-mode/demo.ci-modes-middleware.sh
```

## Modes Demonstrated

### DRY Mode
- Hook emits: `contract:mode=dry`
- Middleware sets: `DRY_RUN=true`
- Main script can check `DRY_RUN` to skip operations

### OK Mode
- Hook emits: `contract:mode=ok`
- Middleware sets: `__CI_MODE_TERMINATE=true`, `__CI_MODE_EXIT=0`
- Main script exits immediately with success

### ERROR Mode
- Hook emits: `contract:mode=error:42`
- Middleware sets: `__CI_MODE_TERMINATE=true`, `__CI_MODE_EXIT=42`
- Main script exits immediately with specified code

## Middleware vs Source Mode

| Feature | Source Mode | Middleware |
|---------|-------------|------------|
| Variable access | Direct | Via contracts |
| Output capture | No | Yes |
| Isolation | None | Subprocess |
| Flexibility | Limited | High |
| Complexity | Low | Medium |

## Custom Contract Format

The contract format is not hardcoded. Implementers define their own conventions:

```bash
# Example: KEY=VALUE style
"1: contract:DRY_RUN=true"

# Example: JSON style
"1: contract:{\"mode\":\"dry\",\"level\":2}"

# Example: Command style
"1: contract:export DEBUG=*"
```

Middleware parses contracts using pattern matching appropriate for the chosen format.
```

#### Step 2: Commit

```bash
git add demos/ci-mode/README.md
git commit -m "docs: add CI modes middleware demo README

- Explain middleware architecture and flow
- Document contract patterns and modes
- Compare middleware vs source mode approaches
- Show flexible contract format options"
```

---

## Phase 5: Documentation Updates

### Task 5.1: Add Middleware Section to hooks.md

**File**: `docs/public/hooks.md`
**Location**: After "Execution Modes" section (~line 440)

#### Step 1: Add comprehensive middleware documentation

Insert new section:

```markdown
## Hooks Middleware (Contract System)

### Overview

Middleware functions intercept hook execution to:
- Capture stdout/stderr output in a timeline array
- Parse contract lines for state communication
- Transform or filter output before replay
- Override exit codes
- Enable hooks to modify parent shell state (via contracts in exec mode)

### When to Use Middleware

**Use middleware when:**
- Hooks need to communicate state back to main script (e.g., enable DRY_RUN)
- You need structured contract interpretation
- Exit code alone isn't sufficient for control flow
- Running in exec mode (isolation required)

**Use source mode when:**
- Direct variable access is required
- Performance is critical (no capture overhead)
- Complex parent shell modifications needed
- Contract parsing isn't necessary

### Middleware API

#### Register Middleware

```bash
# Register custom middleware for a hook
hooks:middleware <hook_name> <middleware_function>

# Reset to default middleware
hooks:middleware <hook_name>

# Example
ci:middleware() {
  local hook_name="$1" exit_code="$2" capture_var="$3"
  shift 3; shift  # skip "--"
  # Parse contracts, set variables, etc.
  return "$exit_code"
}

hooks:middleware begin ci:middleware
```

#### Middleware Function Signature

```bash
function my_middleware() {
  local hook_name="$1"      # Name of hook being executed
  local exit_code="$2"      # Exit code from hook implementation
  local capture_var="$3"    # Name of array containing captured output
  shift 3
  local separator="$1"      # Literal "--"
  shift
  # $@ now contains original hook arguments

  # Access captured output via nameref
  local -n capture_ref="$capture_var"

  # Process each line
  for line in "${capture_ref[@]}"; do
    case "$line" in
      "1: contract:"*)
        # Parse and execute contract
        ;;
      "1: "*)
        # Replay stdout
        echo "${line#1: }"
        ;;
      "2: "*)
        # Replay stderr
        echo "${line#2: }" >&2
        ;;
    esac
  done

  # Return exit code (can override)
  return "$exit_code"
}
```

### Output Capture Format

Each element in the capture array has a prefix:
- `"1: <stdout line>"` - Line from stdout
- `"2: <stderr line>"` - Line from stderr

Timeline order is best-effort (buffering may affect precise interleaving).

### Contract Pattern

Contract lines communicate state from hook to main script. **Format is not hardcoded** - implementers define their own conventions.

#### Example: Simple KEY=VALUE Contracts

```bash
# Hook script emits contracts
hook:begin() {
  echo "contract:mode=dry"
  echo "contract:debug=true"
  echo "Normal output"
}

# Middleware parses contracts
my_middleware() {
  local hook_name="$1" exit_code="$2" capture_var="$3"
  shift 3; shift

  local -n capture_ref="$capture_var"
  for line in "${capture_ref[@]}"; do
    case "$line" in
      "1: contract:mode=dry")
        export DRY_RUN=true
        ;;
      "1: contract:debug=true")
        export DEBUG="*"
        ;;
      "1: "*)
        echo "${line#1: }"
        ;;
    esac
  done

  return "$exit_code"
}
```

#### Example: Eval-style Contracts

```bash
# Hook emits bash commands
echo "contract:export DRY_RUN=true"
echo "contract:MODE_TERMINATE=true"

# Middleware evaluates
if [[ "$line" =~ ^1:\ contract:(.*)$ ]]; then
  local cmd="${BASH_REMATCH[1]}"
  eval "$cmd"
fi
```

### Source Mode Bypass

Source mode scripts bypass middleware entirely:

```bash
export HOOKS_EXEC_MODE="source"

# Scripts in source mode:
# - Run in parent shell (no subprocess)
# - Have direct variable access
# - No output capture
# - Middleware is NOT called
```

### Default Middleware

The default middleware (`_hooks:middleware:default`) preserves backward compatibility:
- Replays all output unchanged (stdout → stdout, stderr → stderr)
- Returns original exit code
- No contract parsing
- No modifications

### Examples

See `demos/ci-mode/demo.ci-modes-middleware.sh` for complete contract-based CI mode examples.

### Limitations

1. **Timeline precision**: Output ordering is best-effort due to buffering
2. **Subshell isolation**: Hook implementations run in subshells (exec mode only)
3. **Performance**: Capture adds overhead vs source mode
4. **Large output**: Memory consumption for very large outputs (>1MB)
```

#### Step 2: Update function reference

In "Key Functions" section, add:

```markdown
#### hooks:middleware

Register middleware for a hook.

**Syntax:**
```bash
hooks:middleware <hook_name> [<middleware_function>]
```

**Parameters:**
- `hook_name` - Hook to attach middleware to
- `middleware_function` - Function name (optional, omit to reset to default)

**Returns:** 0 on success, 1 on error

**Example:**
```bash
my_middleware() {
  local hook_name="$1" exit_code="$2" capture_var="$3"
  shift 3; shift  # skip "--"

  # Process captured output
  local -n capture_ref="$capture_var"
  for line in "${capture_ref[@]}"; do
    # Parse contracts, replay output, etc.
  done

  return "$exit_code"
}

hooks:middleware begin my_middleware
```
```

#### Step 3: Commit

```bash
git add docs/public/hooks.md
git commit -m "docs: add comprehensive middleware documentation

- Middleware overview and use cases
- API reference with signature details
- Contract pattern examples (multiple styles)
- Source mode bypass explanation
- Default middleware behavior
- Limitations and best practices
- Complete code examples"
```

---

## Phase 6: Edge Cases & Polish

### Task 6.1: Document Subshell Limitations

**File**: `docs/public/hooks.md`

Add to middleware section:

```markdown
### Important: Subshell Isolation in Exec Mode

Hook implementations in exec mode run in subshells due to output capture. This means:

**Direct variable modifications won't persist:**
```bash
# ❌ This WON'T work in exec mode:
hook:begin() {
  GLOBAL_VAR="modified"  # Lost when subshell exits
}

# ✅ Use contract middleware instead:
hook:begin() {
  echo "contract:export GLOBAL_VAR=modified"
}

# Middleware executes contract in parent shell:
my_middleware() {
  # ... parse contract ...
  eval "$contract_cmd"  # Executes in parent shell
}
```

**For direct variable access, use source mode:**
```bash
export HOOKS_EXEC_MODE="source"
# OR
hooks:pattern:source "config-*.sh"
```
```

#### Commit

```bash
git add docs/public/hooks.md
git commit -m "docs: document subshell isolation limitations

- Explain exec mode subshell behavior
- Show workarounds via contracts or source mode
- Add clear examples of what works and what doesn't"
```

---

### Task 6.2: Update Original Middleware Plan

**File**: `docs/HOOKS_MIDDLEWARE.md`

#### Step 1: Sync with implementation details

Update signature and exception sections:

```markdown
## API Changes

- Middleware signature:
  ```
  <middleware_fn> <hook_name> <exit_code> <capture_var> -- <hook_args...>
  ```

- Internal functions use underscore prefix:
  - `_hooks:middleware:default`
  - `_hooks:capture:run`
  - `_hooks:capture:cleanup`

## Exceptions

- Source-mode scripts bypass middleware
- Source-mode functions via `hooks:pattern:source` bypass middleware
```

#### Step 2: Commit

```bash
git add docs/HOOKS_MIDDLEWARE.md
git commit -m "docs: update middleware plan with implementation details

- Align signature with v2.1 implementation
- Document internal function naming convention
- Clarify source mode exceptions"
```

---

## Success Criteria

- [x] All 79 existing tests pass
- [x] 15+ new middleware tests pass
- [x] Default middleware preserves backward compatibility
- [x] Source mode bypasses middleware correctly
- [x] Contract parsing demo works with multiple conventions
- [x] Documentation complete with examples
- [x] No performance regression in source mode
- [x] Capture arrays cleaned up (no memory leaks)
- [x] TDD methodology followed throughout
- [x] Incremental commits with clear messages

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing tests | High | Default middleware preserves behavior; TDD catches regressions early |
| Timeline ordering issues | Low | Best-effort documented; awk+fflush improves reliability |
| Performance regression | Medium | Source mode unchanged; exec mode overhead documented |
| Memory leaks | Medium | Cleanup function + sequence counter; documented limits |
| Complex capture bugs | Medium | TDD approach; awk+fflush simpler than fd redirection |

---

## Notes

- **Contract format is NOT hardcoded** - middleware is flexible, implementers define conventions
- **Timeline preservation uses awk+fflush** - better buffering control than sed
- **Middleware signature: hook_name first** - more logical ordering
- **Internal functions use underscore prefix** - clear indication of internal API
- **TDD approach** - test-first reduces risk and catches edge cases early
- **Incremental commits** - better git history and easier rollback if needed
- **Sequence counter** - cleaner than PID for capture array naming
