# Hooks Middleware v3.1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add per-hook middleware for exec-mode hooks that can interpret a contract from hook output, enable side effects in the parent shell, and preserve the current default behavior (exit code + output passthrough).

**Architecture:** Keep `hooks:do` as the single entry point. Each exec-mode implementation (hook function, registered function, exec script) is executed through a capture harness that writes a prefixed stdout/stderr timeline into a unique global array. A per-hook middleware function receives the hook name, exit code, and capture array name, applies contract logic (optional), replays output, and returns the effective exit code. Sourced hooks bypass middleware. Contract formats are not hardcoded.

**Tech Stack:** Bash, e-bash hooks module (`.scripts/_hooks.sh`), ShellSpec tests (`spec/hooks_spec.sh`), docs (`docs/public/hooks.md`), demos (`demos/ci-mode`).

### Task 1: Lock ordering + log-level baseline (prereq)

**Files:**
- Modify: `.scripts/_hooks.sh`
- Modify: `spec/hooks_spec.sh`

**Step 1: Write the failing test (ordering merged)**

```bash
It 'executes registered functions and scripts in one alphabetical sequence'
  setup() {
    setup_test_hooks_dir
    hooks:declare merge_order
    hook:merge_order() { echo "function"; }
    hooks:register merge_order "10-alpha" func_alpha
    hooks:register merge_order "30-charlie" func_charlie
    func_alpha() { echo "alpha"; }
    func_charlie() { echo "charlie"; }
    cat > "$TEST_HOOKS_DIR/merge_order-20-bravo.sh" <<'EOF'
#!/usr/bin/env bash
echo "bravo"
EOF
    chmod +x "$TEST_HOOKS_DIR"/merge_order-20-bravo.sh
  }
  BeforeCall 'setup'

  When call hooks:do merge_order

  The status should be success
  The line 1 should eq "function"
  The line 2 should eq "alpha"
  The line 3 should eq "bravo"
  The line 4 should eq "charlie"
End
```

**Step 2: Run test to verify it fails**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: FAIL with order mismatch (registered functions run before scripts).

**Step 3: Implement minimal ordering merge**

```bash
# Keep hook:{name} first, then merge registered + scripts by sort key
local -a merged_impls=()
# registered entries: "key|registered|func"
# script entries: "key|script|path"
# sort by key, then execute in order
```

**Step 4: Run test to verify it passes**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: PASS for the new ordering test.

**Step 5: Update "No implementations found" log level and tests**

```bash
echo:Hooks "  ℹ No implementations found for hook '$hook_name'"
```

Update matching assertions in `spec/hooks_spec.sh` to look for the new text.

**Step 6: Run test to verify it passes**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: PASS for updated log expectations.

**Step 7: Commit**

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "test: merge hook implementation ordering"
```

### Task 2: Add middleware registry + reset coverage + logging

**Files:**
- Modify: `.scripts/_hooks.sh`
- Modify: `spec/hooks_spec.sh`

**Step 1: Write failing tests (register/reset + log)**

```bash
It 'registers middleware per hook and logs it'
  setup() {
    hooks:declare mid_hook
    middleware:noop() { return 0; }
  }
  BeforeCall 'setup'

  When call hooks:middleware mid_hook middleware:noop

  The status should be success
  The result of function no_colors_stderr should include "Registered middleware"
End

It 'resets middleware to default when only hook name provided'
  setup() {
    hooks:declare mid_hook
    middleware:noop() { return 0; }
    hooks:middleware mid_hook middleware:noop
  }
  BeforeCall 'setup'

  When call hooks:middleware mid_hook

  The status should be success
  The result of function no_colors_stderr should include "Reset middleware"
End
```

**Step 2: Run tests to verify they fail**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: FAIL (hooks:middleware not defined).

**Step 3: Implement registry + reset + logging**

```bash
declare -g -A __HOOKS_MIDDLEWARE
declare -g __HOOKS_CAPTURE_SEQ=0

function hooks:middleware() {
  local hook_name="$1"
  local middleware_fn="${2:-}"
  if [[ -z "$hook_name" ]]; then
    echo "Error: hooks:middleware requires <hook> [function]" >&2
    return 1
  fi
  if [[ -z "$middleware_fn" ]]; then
    unset "__HOOKS_MIDDLEWARE[$hook_name]"
    echo:Hooks "Reset middleware for hook '$hook_name' to default"
    return 0
  fi
  if ! declare -F "$middleware_fn" >/dev/null 2>&1; then
    echo "Error: Middleware function '$middleware_fn' does not exist" >&2
    return 1
  fi
  __HOOKS_MIDDLEWARE["$hook_name"]="$middleware_fn"
  echo:Hooks "Registered middleware '${middleware_fn}' for hook '${hook_name}'"
  return 0
}
```

Update `hooks:reset` to unset and re-declare `__HOOKS_MIDDLEWARE` and reset `__HOOKS_CAPTURE_SEQ`.

**Step 4: Run tests to verify they pass**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: PASS for middleware registration/reset tests.

**Step 5: Commit**

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: add per-hook middleware registry"
```

### Task 3: Add timeline capture harness (exec-mode)

**Files:**
- Modify: `.scripts/_hooks.sh`
- Modify: `spec/hooks_spec.sh`

**Step 1: Write failing test (capture + default replay)**

```bash
It 'replays stdout/stderr unchanged via default middleware'
  setup() {
    hooks:declare cap_hook
    hook:cap_hook() {
      echo "out"
      echo "err" >&2
      return 7
    }
  }
  BeforeCall 'setup'

  When call hooks:do cap_hook

  The status should eq 7
  The output should eq "out"
  The error should include "err"
End
```

**Step 2: Run test to verify it fails**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: FAIL (no capture/middleware yet).

**Step 3: Implement capture helper (timeline-preserving)**

```bash
function _hooks:capture:run() {
  local hook_name="$1"
  local capture_var="$2"
  shift 2

  local hook_slug
  hook_slug="$(to:slug "$hook_name" "_" 40)"
  __HOOKS_CAPTURE_SEQ=$((__HOOKS_CAPTURE_SEQ + 1))
  local capture_name="__${hook_slug}_${__HOOKS_CAPTURE_SEQ}"

  local capture_file
  capture_file="$(mktemp)" || {
    echo "Error: Failed to create temp file for hook capture" >&2
    return 1
  }

  {
    "$@" \
      > >(sed 's/^/1: /' >> "$capture_file") \
      2> >(sed 's/^/2: /' >> "$capture_file")
  }
  local exit_code=$?

  declare -g -a "$capture_name"=()
  mapfile -t "$capture_name" < "$capture_file"
  rm -f "$capture_file"

  printf -v "$capture_var" '%s' "$capture_name"
  return "$exit_code"
}
```

Add `source "$E_BASH/_commons.sh"` in `.scripts/_hooks.sh` so `to:slug` is available.

**Step 4: Run test to verify it passes**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: PASS for capture + replay test once middleware is wired in Task 4.

**Step 5: Commit**

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: add hook capture harness"
```

### Task 4: Add default middleware with separator validation

**Files:**
- Modify: `.scripts/_hooks.sh`
- Modify: `spec/hooks_spec.sh`

**Step 1: Write failing test (separator enforcement)**

```bash
It 'fails when middleware call lacks separator'
  setup() {
    hooks:declare sep_hook
    hook:sep_hook() { echo "ok"; }
  }
  BeforeCall 'setup'

  When call hooks:middleware:default sep_hook 0 missing_separator

  The status should be failure
End
```

**Step 2: Run test to verify it fails**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: FAIL (default middleware missing).

**Step 3: Implement default middleware**

```bash
function _hooks:middleware:default() {
  local hook_name="$1" exit_code="$2" capture_var="$3"
  shift 3

  if [[ "${1:-}" != "--" ]]; then
    echo "Error: hooks middleware expects '--' separator" >&2
    return 1
  fi
  shift

  local -n capture_ref="$capture_var"
  local line
  for line in "${capture_ref[@]}"; do
    case "$line" in
      "1: "*) printf '%s\n' "${line#1: }" ;;
      "2: "*) printf '%s\n' "${line#2: }" >&2 ;;
      *) printf '%s\n' "$line" ;;
    esac
  done
  return "$exit_code"
}
```

**Step 4: Run test to verify it passes**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: PASS for separator validation and default replay.

**Step 5: Commit**

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: add default hook middleware"
```

### Task 5: Wire middleware into hooks:do (exec-mode only)

**Files:**
- Modify: `.scripts/_hooks.sh`
- Modify: `spec/hooks_spec.sh`

**Step 1: Write failing tests (custom middleware + source bypass)**

```bash
It 'allows middleware to set parent-shell variables'
  setup() {
    hooks:declare mid_hook
    hook:mid_hook() { echo "contract:mode=dry"; }
    middleware:mode() {
      local hook_name="$1" exit_code="$2" capture_var="$3"
      local -n capture_ref="$capture_var"
      for line in "${capture_ref[@]}"; do
        [[ "$line" == "1: contract:mode=dry" ]] && export DRY_RUN=true
      done
      return "$exit_code"
    }
    hooks:middleware mid_hook middleware:mode
  }
  BeforeCall 'setup'

  When call hooks:do mid_hook

  The status should be success
  The result of variable DRY_RUN should eq "true"
End

It 'bypasses middleware for source-mode scripts'
  setup() {
    setup_test_hooks_dir
    export HOOKS_EXEC_MODE="source"
    hooks:declare source_hook
    cat > "$TEST_HOOKS_DIR/source_hook-test.sh" <<'EOF'
#!/usr/bin/env bash
function hook:run() {
  echo "source-out"
}
EOF
    chmod +x "$TEST_HOOKS_DIR"/source_hook-test.sh
    middleware:noop() { return 9; }
    hooks:middleware source_hook middleware:noop
  }
  BeforeCall 'setup'

  When call hooks:do source_hook

  The status should be success
  The output should include "source-out"
End
```

**Step 2: Run tests to verify they fail**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: FAIL (middleware not wired).

**Step 3: Implement middleware integration + logging**

```bash
local middleware_fn="${__HOOKS_MIDDLEWARE[$hook_name]:-_hooks:middleware:default}"
echo:Hooks "  Using middleware: $middleware_fn"

# For function/registered/exec script:
_hooks:capture:run "$hook_name" capture_var "$impl_cmd" "$@"
"$middleware_fn" "$hook_name" "$exit_code" "$capture_var" -- "$@"
last_exit_code=$?
```

Source-mode scripts continue to run without middleware.

**Step 4: Run tests to verify they pass**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: PASS for middleware behavior and source bypass.

**Step 5: Commit**

```bash
git add .scripts/_hooks.sh spec/hooks_spec.sh
git commit -m "feat: wire middleware into hook execution"
```

### Task 6: Expand middleware tests (exit overrides + capture format)

**Files:**
- Modify: `spec/hooks_spec.sh`

**Step 1: Add tests for exit code override**

```bash
It 'allows middleware to override exit code'
  setup() {
    hooks:declare code_hook
    hook:code_hook() { return 2; }
    middleware:override() { return 11; }
    hooks:middleware code_hook middleware:override
  }
  BeforeCall 'setup'

  When call hooks:do code_hook

  The status should eq 11
End
```

**Step 2: Add tests for capture format prefixes**

```bash
It 'provides prefixed capture lines to middleware'
  setup() {
    hooks:declare cap_format
    hook:cap_format() { echo "a"; echo "b" >&2; }
    middleware:inspect() {
      local hook_name="$1" exit_code="$2" capture_var="$3"
      local -n capture_ref="$capture_var"
      printf '%s\n' "${capture_ref[0]}"
      printf '%s\n' "${capture_ref[1]}"
      return 0
    }
    hooks:middleware cap_format middleware:inspect
  }
  BeforeCall 'setup'

  When call hooks:do cap_format

  The output should include "1: a"
  The output should include "2: b"
End
```

**Step 3: Run tests to verify they fail**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: FAIL if middleware return values or capture array not working.

**Step 4: Ensure middleware return code is used**

```bash
last_exit_code=$?
```

**Step 5: Run tests to verify they pass**

Run: `shellspec spec/hooks_spec.sh -f d`  
Expected: PASS.

**Step 6: Commit**

```bash
git add spec/hooks_spec.sh
git commit -m "test: cover middleware exit code and capture format"
```

### Task 7: Update public docs with middleware contract

**Files:**
- Modify: `docs/public/hooks.md`

**Step 1: Add documentation section**

```markdown
## Hooks Middleware (Contract)

Use `hooks:middleware <hook> <function>` to register a per-hook middleware.
Default behavior replays stdout/stderr and returns the original exit code.
Middleware signature:
  <middleware_fn> <hook_name> <exit_code> <capture_var> -- <hook_args...>
Capture format:
  "1: " prefix for stdout lines
  "2: " prefix for stderr lines
Contract formats are not hardcoded; middleware interprets them.
Source-mode scripts bypass middleware.
```

**Step 2: Commit**

```bash
git add docs/public/hooks.md
git commit -m "docs: document hook middleware contract"
```

### Task 8: Add middleware demo in demos/ci-mode + README

**Files:**
- Create: `demos/ci-mode/demo.ci-modes-middleware.sh`
- Create: `demos/ci-mode/ci-20-compile.sh`
- Create: `demos/ci-mode/hooks-mw/begin_00_mode-resolve.sh`
- Create: `demos/ci-mode/hooks-mw/begin_10_mode-dry.sh`
- Create: `demos/ci-mode/hooks-mw/begin_11_mode-ok.sh`
- Create: `demos/ci-mode/hooks-mw/begin_12_mode-error.sh`
- Create: `demos/ci-mode/hooks-mw/begin_13_mode-skip.sh`
- Create: `demos/ci-mode/hooks-mw/begin_14_mode-timeout.sh`
- Create: `demos/ci-mode/hooks-mw/begin_15_mode-test.sh`
- Create: `demos/ci-mode/README.md`

**Step 1: Implement middleware in the main script**

```bash
ci:middleware() {
  local hook_name="$1" exit_code="$2" capture_var="$3"
  local -n capture_ref="$capture_var"
  local line

  for line in "${capture_ref[@]}"; do
    case "$line" in
      "1: contract:mode=dry") export DRY_RUN=true ;;
      "1: contract:mode=ok") export __CI_MODE_EXIT=0 __CI_MODE_TERMINATE=true ;;
      "1: contract:mode=skip") export __CI_MODE_EXIT=0 __CI_MODE_TERMINATE=true ;;
      "1: contract:mode=error:"*) export __CI_MODE_EXIT="${line#1: contract:mode=error:}" __CI_MODE_TERMINATE=true ;;
      "1: contract:mode=timeout:"*) export CI_SCRIPT_TIMEOUT="${line#1: contract:mode=timeout:}" ;;
      "1: contract:mode=test:"*) export __CI_MODE_TEST_SCRIPT="${line#1: contract:mode=test:}" __CI_MODE_TERMINATE=true ;;
      "1: "*) printf '%s\n' "${line#1: }" ;;
      "2: "*) printf '%s\n' "${line#2: }" >&2 ;;
    esac
  done

  return "$exit_code"
}
```

**Step 2: Hook scripts emit contract lines**

```bash
# begin_10_mode-dry.sh (exec mode)
echo "contract:mode=dry"

# begin_12_mode-error.sh (exec mode)
echo "contract:mode=error:${CI_SCRIPT_ERROR_CODE:-1}"
```

**Step 3: Main script behavior**

```bash
hooks:middleware begin ci:middleware
hooks:do begin "$SCRIPT_NAME"

if [[ "${__CI_MODE_TERMINATE:-}" == "true" ]]; then
  if [[ -n "${__CI_MODE_TEST_SCRIPT:-}" ]]; then
    source "${__CI_MODE_TEST_SCRIPT}"
    exit "${__CI_MODE_EXIT:-0}"
  fi
  exit "${__CI_MODE_EXIT:-0}"
fi
```

**Step 4: Add README section**

```markdown
# CI Mode Middleware Demo

- Explains default vs middleware contract flow
- Shows contract line formats used
- Notes source-mode bypass and subshell side effects
```

**Step 5: Manual demo run**

Run: `demos/ci-mode/demo.ci-modes-middleware.sh`  
Expected: Each mode is triggered through middleware contract lines.

**Step 6: Commit**

```bash
git add demos/ci-mode
git commit -m "demo: add ci-mode middleware contract example"
```

### Task 9: Update middleware plan doc (optional sync)

**Files:**
- Modify: `docs/HOOKS_MIDDLEWARE.md`

**Step 1: Align signature and exception wording**

```markdown
Middleware signature:
  <middleware_fn> <hook_name> <exit_code> <capture_var> -- <hook_args...>
Exception:
  Source-mode scripts bypass middleware.
```

**Step 2: Commit**

```bash
git add docs/HOOKS_MIDDLEWARE.md
git commit -m "docs: align middleware plan with v3.1 details"
```
