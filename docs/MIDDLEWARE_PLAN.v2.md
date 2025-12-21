# Hooks Middleware Implementation Plan

## Overview

Implement middleware abstraction for the hooks system that intercepts hook execution, captures output in a timeline array, and enables custom contract interpretation between hooks and main script. This allows hooks to communicate state changes (e.g., switching to DRY_RUN mode) while maintaining backward compatibility.

**Status**: Ready for implementation
**Approach**: Incremental rollout with prerequisites first
**Estimated effort**: 17-25 hours across 6 phases

---

## Key Design Decisions (from user input)

1. ✅ **Unified execution order**: Registered functions and scripts will execute in single alphabetical sequence (function → interleaved registered+scripts)
2. ✅ **Timeline-preserving capture**: Use complex process redirection to maintain stdout/stderr ordering
3. ✅ **No hardcoded contract format**: Middleware is flexible - implementers define their own contract conventions
4. ✅ **Incremental rollout**: Prerequisites first, then core middleware, then tests/demos/docs

---

## Critical Files

- `.scripts/_hooks.sh` (primary implementation, ~500 lines changed)
- `spec/hooks_spec.sh` (48 of 79 tests affected, ~30 new tests)
- `docs/public/hooks.md` (~200 lines added for middleware section)
- `demos/ci-mode/demo.middleware.sh` (new demo, ~150 lines)

---

## Phase 1: Prerequisites (MUST COMPLETE FIRST)

### Task 1.1: Unify Registered Functions and Scripts into Single Sequence

**File**: `.scripts/_hooks.sh`
**Lines affected**: 394-481 (registered functions loop + script execution loop)

**Current behavior**:
- Line 386-392: Execute `hook:name()` function
- Lines 397-428: Execute registered functions (alphabetical)
- Lines 430-481: Execute scripts (alphabetical)

**New behavior**:
- Line 386-392: Execute `hook:name()` function (unchanged)
- Lines 397-481: Execute unified array of (registered functions + scripts) alphabetically

**Implementation approach**:

1. Create unified "executables" array with structure: `{sortkey}:{type}:{target}`
   - `sortkey`: Friendly name (for registered) or script basename (for scripts)
   - `type`: "function" or "script"
   - `target`: Function name or script path

2. Populate array:
   - Add registered functions with their friendly names as sort keys
   - Discover scripts, add with basename as sort key

3. Sort array alphabetically by sort key

4. Execute loop:
   ```bash
   for executable in "${sorted_executables[@]}"; do
     IFS=':' read -r sortkey type target <<< "$executable"
     # Execute based on type with logging
   done
   ```

**Why this matters**: Simplifies middleware integration (single execution point) and matches user expectations (truly alphabetical execution across all implementation types).

**Test impact**: Lines 1081-1083, 311-312 in `spec/hooks_spec.sh` verify execution order and will need updates to reflect interleaved ordering.

---

### Task 1.2: Downgrade "No implementations found" to INFO

**File**: `.scripts/_hooks.sh`
**Line**: 485

**Change**:
```bash
# OLD:
echo:Hooks "  ⚠ No implementations found for hook '$hook_name'"

# NEW:
echo:Hooks "  ℹ No implementations found for hook '$hook_name'"
```

**Rationale**: 99% of hooks have no implementations. This is expected, not a warning.

---

## Phase 2: Core Middleware Implementation

### Task 2.1: Add Middleware Storage

**File**: `.scripts/_hooks.sh`
**Location**: After line 37 (with other global arrays)

Add:
```bash
# declare global associative array for middleware functions (internal)
# stores hook_name -> middleware_function_name
if [[ -z ${__HOOKS_MIDDLEWARE+x} ]]; then declare -g -A __HOOKS_MIDDLEWARE; fi
```

Update `hooks:reset()` at line 690:
```bash
unset __HOOKS_MIDDLEWARE
declare -g -A __HOOKS_MIDDLEWARE
```

---

### Task 2.2: Implement Default Middleware Function

**File**: `.scripts/_hooks.sh`
**Location**: After line 329 (after `hooks:exec:mode`)

**New function**:
```bash
#
# Default middleware for hook implementations
# Preserves current behavior: replays output as-is, returns exit code
#
# Signature:
#   hooks:middleware:default <exit_code> <hook_name> <output_var> -- <hook_args...>
#
# Parameters:
#   $1 - Exit code from implementation
#   $2 - Hook name
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
function hooks:middleware:default() {
  local exit_code="$1"
  local hook_name="$2"
  local output_var="$3"
  shift 3

  # Validate "--" separator
  if [[ "$1" != "--" ]]; then
    echo "Error: hooks:middleware expects '--' separator" >&2
    return 1
  fi
  shift

  # Replay captured output (nameref for efficient array access)
  local -n output_array="$output_var"
  local line
  for line in "${output_array[@]}"; do
    case "${line:0:2}" in
      "1:") echo "${line:3}" ;;        # stdout
      "2:") echo "${line:3}" >&2 ;;    # stderr
    esac
  done

  return "$exit_code"
}
```

**Design notes**:
- Uses nameref (`local -n`) for efficient array access
- Simple replay preserves backward compatibility
- No contract parsing in default middleware (user implements in custom middleware)

---

### Task 2.3: Implement Middleware Registration API

**File**: `.scripts/_hooks.sh`
**Location**: After `hooks:register` function (after line 228)

**New function**:
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
  local middleware_func="$2"

  if [[ -z "$hook_name" ]]; then
    echo "Error: hooks:middleware requires hook name" >&2
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

  __HOOKS_MIDDLEWARE[$hook_name]="$middleware_func"
  echo:Hooks "Registered middleware '${middleware_func}' for hook '${hook_name}'"
  return 0
}
```

---

### Task 2.4: Implement Timeline-Preserving Output Capture Harness

**File**: `.scripts/_hooks.sh`
**Location**: After `hooks:middleware` function

**New function** (timeline-preserving approach per user preference):
```bash
#
# Execute implementation with output capture (internal helper)
#
# Captures stdout/stderr into timeline array with prefixes:
#   "1: <line>" - stdout
#   "2: <line>" - stderr
#
# Parameters:
#   $1 - Type: "function" or "script"
#   $2 - Target: function name or script path
#   $@ - Arguments to pass to implementation
#
# Sets global:
#   __HOOKS_LAST_CAPTURE_VAR - Name of the capture array
#   __HOOKS_LAST_CAPTURE_EXIT - Exit code from implementation
#
# Returns:
#   Exit code from implementation
#
function hooks:capture:run() {
  local impl_type="$1"
  local impl_target="$2"
  shift 2

  # Generate unique array name using to:slug
  local capture_slug=$(to:slug "${impl_target}" "_" 20)
  local capture_var="__hooks_capture_${capture_slug}_$$"
  __HOOKS_LAST_CAPTURE_VAR="$capture_var"

  # Declare capture array in global scope
  declare -g -a "$capture_var"
  local -n capture_array="$capture_var"

  # Create temp file for combined timeline output
  local tmp_combined=$(mktemp) || {
    echo "Error: Failed to create temp file for capture" >&2
    return 1
  }
  trap "rm -f '$tmp_combined'" RETURN

  # Execute with timeline-preserving capture
  # Uses process redirection to interleave stdout (1:) and stderr (2:)
  local exit_code=0
  {
    if [[ "$impl_type" == "function" ]]; then
      {
        "$impl_target" "$@" 2>&1 1>&3 | sed 's/^/2: /' >&2
      } 3>&1 2>&1 | sed 's/^/1: /'
    elif [[ "$impl_type" == "script" ]]; then
      {
        "$impl_target" "$@" 2>&1 1>&3 | sed 's/^/2: /' >&2
      } 3>&1 2>&1 | sed 's/^/1: /'
    fi
  } > "$tmp_combined"
  exit_code=$?

  # Populate array from captured output
  while IFS= read -r line; do
    capture_array+=("$line")
  done < "$tmp_combined"

  __HOOKS_LAST_CAPTURE_EXIT="$exit_code"
  return "$exit_code"
}

#
# Cleanup capture array (internal helper)
#
function hooks:capture:cleanup() {
  local var_name="$1"
  [[ -n "$var_name" ]] && unset "$var_name"
}
```

**Design notes**:
- Timeline order is best-effort (buffering may affect ordering) - documented limitation
- Uses file descriptor redirection (3) to separate stdout/stderr before prefixing
- Temp file cleanup via trap
- Cleanup function prevents memory leaks from capture arrays

---

### Task 2.5: Integrate Middleware into hooks:do

**File**: `.scripts/_hooks.sh`
**Location**: Modify `hooks:do` function (lines 369-491)

**Key integration points**:

1. **After line 382** - Resolve middleware:
   ```bash
   # Resolve middleware function for this hook
   local middleware_func="${__HOOKS_MIDDLEWARE[$hook_name]:-hooks:middleware:default}"
   echo:Hooks "  Using middleware: $middleware_func"
   ```

2. **For hook:name() function** (lines 386-392) - Replace with:
   ```bash
   local func_name="${HOOKS_PREFIX}${hook_name}"
   if declare -F "$func_name" >/dev/null 2>&1; then
     echo:Hooks "  → [function] ${func_name}"

     # Run through capture and middleware
     hooks:capture:run "function" "$func_name" "$@"

     # Call middleware
     "$middleware_func" "$__HOOKS_LAST_CAPTURE_EXIT" "$hook_name" "$__HOOKS_LAST_CAPTURE_VAR" -- "$@"
     last_exit_code=$?

     # Cleanup
     hooks:capture:cleanup "$__HOOKS_LAST_CAPTURE_VAR"

     echo:Hooks "    ↳ exit code: $last_exit_code"
     ((impl_count++))
   fi
   ```

3. **For unified executables loop** (lines 397-481) - Wrap each execution:
   ```bash
   for executable in "${sorted_executables[@]}"; do
     IFS=':' read -r sortkey type target <<< "$executable"

     if [[ "$type" == "function" ]]; then
       echo:Hooks "  → [registered $n/$total] ${sortkey} → ${target}()"

       hooks:capture:run "function" "$target" "$@"
       "$middleware_func" "$__HOOKS_LAST_CAPTURE_EXIT" "$hook_name" "$__HOOKS_LAST_CAPTURE_VAR" -- "$@"
       last_exit_code=$?
       hooks:capture:cleanup "$__HOOKS_LAST_CAPTURE_VAR"

     elif [[ "$type" == "script" ]]; then
       local exec_mode=$(hooks:exec:mode "$(basename "$target")")

       if [[ "$exec_mode" == "source" ]]; then
         # SOURCE MODE: BYPASS MIDDLEWARE
         echo:Hooks "  → [script $n/$total] ${sortkey} (sourced mode)"
         source "$target"
         if declare -F "hook:run" >/dev/null 2>&1; then
           hook:run "$@"
           last_exit_code=$?
         fi
       else
         # EXEC MODE: USE MIDDLEWARE
         echo:Hooks "  → [script $n/$total] ${sortkey} (exec mode)"

         hooks:capture:run "script" "$target" "$@"
         "$middleware_func" "$__HOOKS_LAST_CAPTURE_EXIT" "$hook_name" "$__HOOKS_LAST_CAPTURE_VAR" -- "$@"
         last_exit_code=$?
         hooks:capture:cleanup "$__HOOKS_LAST_CAPTURE_VAR"
       fi
     fi

     echo:Hooks "    ↳ exit code: $last_exit_code"
     ((impl_count++))
   done
   ```

**Critical**: Source mode scripts bypass middleware entirely (run directly in parent shell).

---

## Phase 3: Test Updates

### Task 3.1: Verify Default Middleware Behavior

**File**: `spec/hooks_spec.sh`

**Action**: Run existing test suite after middleware implementation.

**Expected results**:
- Default middleware should make most tests pass unchanged
- Exit code tests (13 tests): Should pass - default middleware returns original exit code
- Output content tests (15+ tests): Should pass - default middleware replays output unchanged
- Logger tests (73 assertions): Should pass - logging is independent of middleware

**Tests requiring updates** (due to unified execution order):
- Line 311-312: "executes function first, then scripts" - Update expected output lines
- Line 1081-1083: "registers multiple functions in alphabetical order" - May interleave with scripts if both present

---

### Task 3.2: Add Middleware-Specific Tests

**File**: `spec/hooks_spec.sh`
**Location**: After line 1519 (new Context)

**New test context**: `Context 'Middleware support /'`

**Required tests** (7 minimum):

1. **Default middleware behavior**:
   - Verifies default middleware replays output unchanged
   - Verifies exit code preserved
   - Checks logger output shows "Using middleware: hooks:middleware:default"

2. **Custom middleware registration**:
   - Registers custom middleware function
   - Verifies custom middleware called instead of default
   - Tests middleware can override exit code

3. **Middleware receives captured output array**:
   - Custom middleware verifies array format ("1: " and "2: " prefixes)
   - Tests middleware can access array via nameref
   - Verifies captured line count

4. **Source mode bypasses middleware**:
   - Creates sourced script
   - Registers custom middleware
   - Verifies middleware NOT called for sourced scripts
   - Confirms parent shell variable modification works

5. **Middleware reset to default**:
   - Registers custom middleware
   - Resets to default
   - Verifies default middleware used

6. **Contract parsing pattern** (example):
   - Implements middleware that parses custom contract lines
   - Hook outputs "CONTRACT: export VAR=value"
   - Middleware executes contract in parent shell
   - Verifies variable set correctly

7. **Error handling**:
   - Tests middleware function doesn't exist
   - Tests invalid parameters

**Implementation**: See detailed test code in Phase 2 Plan agent output (lines for test context starting "Context 'Middleware support /'").

---

## Phase 4: Demo Enhancements

### Task 4.1: Create Middleware Demo

**File**: `demos/ci-mode/demo.middleware.sh` (NEW)

**Purpose**: Showcase middleware pattern with contract-based mode control

**Key demonstrations**:

1. **Default middleware** - Shows backward compatibility
2. **Contract middleware** - Parses custom contract lines:
   - Example: `echo "CONTRACT: export DRY_RUN=true"`
   - Middleware uses regex to detect and execute contracts
3. **Multiple modes** - Shows different contract conventions:
   - `"CONTRACT: ..."` style
   - `"PROTOCOL: ..."` style (alternative)
   - Custom format parsing
4. **Side effects** - Demonstrates parent shell modification via contracts

**Structure** (~150 lines):
```bash
#!/usr/bin/env bash
# Middleware demo showing contract pattern

# Contract-aware middleware function
contract_middleware() {
  local exit_code="$1"
  local hook_name="$2"
  local output_var="$3"
  shift 3; shift  # skip "--"

  local -n output_array="$output_var"

  # Parse contract lines (flexible - no hardcoded format)
  for line in "${output_array[@]}"; do
    if [[ "$line" =~ ^1:\ (CONTRACT|PROTOCOL):\ (.*)$ ]]; then
      local contract="${BASH_REMATCH[2]}"
      echo "→ Executing contract: ${contract}" >&2
      eval "$contract"
    else
      # Replay non-contract output
      case "${line:0:2}" in
        "1:") echo "${line:3}" ;;
        "2:") echo "${line:3}" >&2 ;;
      esac
    fi
  done

  return "$exit_code"
}

# Demo scenarios...
```

---

### Task 4.2: Document CI-Mode Demo Enhancement

**File**: `demos/ci-mode/README.md` (NEW)

**Content** (~100 lines):
- Overview of middleware vs source mode
- When to use each approach
- Contract pattern explanation
- Examples from demo.middleware.sh
- Comparison table

---

## Phase 5: Documentation Updates

### Task 5.1: Add Middleware Section to hooks.md

**File**: `docs/public/hooks.md`
**Location**: After "Execution Modes" section (~line 440)

**New section**: "Hooks Middleware (Contract System)" (~200 lines)

**Content outline**:

1. **Overview** - What middleware does, when to use it
2. **API Reference**:
   - `hooks:middleware <hook> <function>`
   - Middleware function signature
   - Output array format
3. **Contract Pattern** (flexible, not hardcoded):
   - Example contract parsing
   - Shows multiple styles (CONTRACT:, PROTOCOL:, custom)
   - Notes this is convention, not enforced
4. **Source Mode Bypass** - Explicit documentation
5. **Examples**:
   - Default middleware behavior
   - Custom contract middleware
   - Mode switching (DRY_RUN, DEBUG, etc.)
6. **Limitations**:
   - Timeline order is best-effort
   - Subshell isolation (no direct variable modification)
   - Performance overhead vs source mode
   - Large output considerations

---

### Task 5.2: Update Function Reference

**File**: `docs/public/hooks.md`
**Location**: "Key Functions" section

**Add**:
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
  local exit_code="$1"
  local hook_name="$2"
  local output_var="$3"
  shift 3; shift  # skip "--"
  # Process captured output...
  return "$exit_code"
}

hooks:middleware begin my_middleware
```

---

## Phase 6: Edge Cases & Polish

### Edge Case Handling

1. **Subshell side effects** - Document clearly:
   - Hook functions/scripts in exec mode run in subshells
   - Direct variable modifications won't persist
   - Use contract middleware for parent shell modification
   - Source mode available for direct access

2. **Capture array cleanup** - Implemented via `hooks:capture:cleanup` to prevent memory leaks

3. **Error handling**:
   - mktemp failure in capture harness
   - Invalid middleware function names
   - Missing separator in middleware call

4. **Nested hooks** - Document as unsupported pattern (capture variable naming includes PID for isolation)

5. **Large output** - Document limitation, recommend source mode or streaming for >1MB output

---

## Implementation Order & Dependencies

### Recommended sequence:

1. **Phase 1** (Prerequisites) - 2-3 hours
   - Complete Task 1.1 (unified ordering) first
   - Then Task 1.2 (trivial warning fix)
   - **Validation**: Run tests, verify execution order change

2. **Phase 2** (Core Middleware) - 6-8 hours
   - Tasks 2.1 → 2.2 → 2.3 in sequence (foundation)
   - Task 2.4 (capture harness) - most complex
   - Task 2.5 (integration) - ties everything together
   - **Validation**: Run tests after each task

3. **Phase 3** (Tests) - 4-6 hours
   - Task 3.1: Run existing tests, fix failures
   - Task 3.2: Add comprehensive middleware tests
   - **Validation**: All 79 existing + ~7 new tests pass

4. **Phase 4** (Demos) - 2-3 hours
   - Task 4.1: Create middleware demo
   - Task 4.2: Add README
   - **Validation**: Demo runs successfully

5. **Phase 5** (Documentation) - 2-3 hours
   - Task 5.1: Add middleware section
   - Task 5.2: Update function reference
   - **Validation**: Documentation review

6. **Phase 6** (Polish) - 1-2 hours
   - Edge case verification
   - Code review
   - Integration testing

---

## Success Criteria

- [ ] All 79 existing tests pass
- [ ] 7+ new middleware tests pass
- [ ] Default middleware preserves backward compatibility
- [ ] Source mode bypasses middleware correctly
- [ ] Contract parsing demo works with multiple conventions
- [ ] Documentation complete with examples
- [ ] No performance regression in source mode
- [ ] Capture arrays cleaned up (no memory leaks)

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing tests | High | Default middleware preserves behavior; incremental testing |
| Timeline ordering issues | Low | Best-effort documented; contract parsing doesn't require perfect order |
| Performance regression | Medium | Source mode unchanged; exec mode overhead documented |
| Memory leaks | Medium | Cleanup function implemented; documented large output limit |
| Complex capture harness bugs | Medium | Comprehensive testing; fallback to simpler approach if needed |

---

## Notes

- **Contract format is NOT hardcoded** - middleware is flexible, implementers define conventions
- **Timeline preservation is best-effort** - buffering may affect ordering, this is documented
- **Unified execution order changes behavior** - confirmed acceptable by user
- **Incremental rollout** - each phase validated before next phase
- Existing `demos/ci-mode/` structure provides foundation for middleware demo enhancement
