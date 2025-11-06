# Tmux Progress Pattern Analysis

## Executive Summary

After deep analysis of `demos/demo.tmux.progress.sh` (working) vs `.scripts/_tmux.sh` (abstraction attempt), I've identified **7 critical issues** that prevent the extracted pattern from working reliably.

## Critical Issues

### Issue 1: Source-Time Initialization Conflicts ⚠️ **ROOT CAUSE**

**Problem:** When `_tmux.sh` is sourced, it runs initialization code at the bottom:

```bash
${__SOURCED__:+return}

logger:init tmux "[${cl_lgreen}tmux${cl_reset}] " ">&2"
dependency tmux "3.5a" "brew install tmux" "-VV" >&2
tmux:check_mouse_support  # ← THIS FAILS!
```

The `tmux:check_mouse_support` function calls:
```bash
tmux show -g | grep -q "mouse on"
```

**This command REQUIRES being inside a tmux session and FAILS when run outside tmux!**

**Impact:** If we source `_tmux.sh` at script startup (before auto-starting tmux), this function fails and may corrupt script state or produce error output.

**Demo approach:** Never sources `_tmux.sh`. Implements pattern inline. No source-time initialization.

---

### Issue 2: Trap Handler Conflicts ⚠️

**Problem:** Multiple trap handlers overwrite each other:

```bash
# In git.semantic-version.sh:
trap on_interrupt INT
trap on_exit EXIT

# Then if we call tmux:setup_trap():
trap "tmux:cleanup_all $exit_session" INT TERM EXIT  # ← OVERWRITES!
```

When `tmux:setup_trap` is called, it **completely replaces** our existing trap handlers!

**Impact:** Our `on_exit` function never runs. Script cleanup logic is broken.

**Demo approach:** Single cleanup function, single trap. No abstraction conflicts.

---

### Issue 3: Variable Scope Across exec ⚠️

**Problem:** When we do `exec tmux new-session "$0" "$@"`, the process is completely replaced. Variables must be explicitly exported to survive:

```bash
# Demo does this correctly:
export TMUX_STARTED_BY_SCRIPT=1
export TMUX_SESSION_NAME="$SESSION_NAME"
exec tmux new-session -s "$SESSION_NAME" "$0"
# Script restarts from line 1, but exported vars are preserved
```

**In _tmux.sh:** Variables are initialized with `: ${VAR:=value}` which preserves exports, but this is fragile and non-obvious.

**Impact:** If exports are forgotten, session cleanup fails and tmux sessions leak.

**Demo approach:** Clear, explicit exports right before exec. Easy to understand and maintain.

---

### Issue 4: FIFO Path in Separate Shell Process ⚠️

**Critical insight:** The `tail -f` command runs in a **completely separate shell process**:

```bash
tmux split-window -v -l 2 "tail -f $FIFO_PATH"
#                           ^^^^^^^^^^^^^^^^^^^^
#                           This runs in a NEW shell!
```

**What happens:**
1. Parent shell expands `$FIFO_PATH` → `/tmp/progress_fifo`
2. Sends command to tmux: `tmux split-window ... "tail -f /tmp/progress_fifo"`
3. Tmux spawns new pane with fresh shell
4. That shell runs `tail -f /tmp/progress_fifo` (literal string, no variables)

**Key requirement:** FIFO path must be absolute, not relative, because the new shell might have a different CWD.

**Demo uses:** `/tmp/progress_fifo` (absolute, hardcoded, simple)
**_tmux.sh uses:** `mktemp --dry-run` (generates absolute path, but complex)

**Impact:** If path generation fails or isn't absolute, tail can't find the FIFO.

**Demo approach:** Simple absolute path. Works reliably.

---

### Issue 5: Progress Fallback Logic ⚠️

**Problem:** The fallback logic in `tmux:update_progress` has TWO conditions:

```bash
if [ "$TMUX_PROGRESS_ACTIVE" = true ] && [ -p "$TMUX_FIFO_PATH" ]; then
  echo -e "$message" > "$TMUX_FIFO_PATH"
else
  echo -e "$message" >&2  # Fallback to stderr
fi
```

If EITHER condition fails, progress goes to stderr (main pane) instead of FIFO (progress pane).

**Common failure modes:**
- `TMUX_PROGRESS_ACTIVE` not set to string "true" (could be "1", "yes", etc.)
- FIFO path wrong or FIFO deleted
- FIFO exists but has no reader (tail died)

**Impact:** User sees: "progress is still printed in the wrong tmux panel"

**Demo approach:** No fallback. Direct write to FIFO. Fails fast if broken.

---

### Issue 6: The Double-Sourcing Problem ⚠️

**Timeline of what happens:**

```
1. Script starts (outside tmux)
2. Source _tmux.sh → runs tmux:check_mouse_support → FAILS
3. Check: not in tmux
4. exec tmux new-session "$0" "$@"
5. ─────────────────────────────────
6. Script RESTARTS (inside tmux)
7. Source _tmux.sh → runs tmux:check_mouse_support → WORKS
8. Check: in tmux → continue
9. Later: call tmux:init_progress
```

The script sources `_tmux.sh` TWICE. The first time fails. The second time works but might have leftover state.

**Impact:** Fragile initialization order. Hard to debug.

**Demo approach:** No sourcing. Linear execution. Predictable.

---

### Issue 7: Readonly Variable Re-declaration

**Potential issue:** If _tmux.sh declares readonly variables:

```bash
readonly TMUX_PROGRESS_HEIGHT=2
```

And the script is sourced twice (before and after exec), the second source tries to set readonly again → ERROR.

**Note:** exec replaces the process, so this shouldn't happen. But it's a risk if the pattern is modified.

**Demo approach:** No readonly. Just regular variables.

---

## Comparison Table

| Aspect | Demo (Works) | _tmux.sh (Broken) |
|--------|--------------|-------------------|
| **Sourcing** | None. Inline code | Sources _tmux.sh with side effects |
| **Initialization** | Runs when needed | Runs at source time (fails outside tmux) |
| **Trap handling** | Single cleanup trap | Multiple traps conflict |
| **FIFO path** | Hardcoded `/tmp/progress_fifo` | Generated with mktemp |
| **Variable exports** | Explicit before exec | Implicit with `: ${VAR:=}` |
| **Cleanup** | Single function | Split across multiple functions |
| **Lines of code** | ~118 lines (all in one file) | ~250+ lines (split across files) |
| **Debuggability** | Easy. Linear flow | Hard. Abstraction layers |

---

## Recommended Solution

**Option A: Inline Implementation (RECOMMENDED)**

Implement the tmux pattern directly in `git.semantic-version.sh`, following the demo exactly:

```bash
# Early in script, before main():
FIFO_PATH="/tmp/git_semver_progress_$$"
SESSION_NAME="git-semver-$$"

# Check if in tmux
if [ -z "$TMUX" ]; then
  # Export tracking variables
  export TMUX_STARTED_BY_SCRIPT=1
  export TMUX_SESSION_NAME="$SESSION_NAME"
  # Auto-start tmux and re-exec
  exec tmux new-session -s "$SESSION_NAME" "$0" "$@"
fi

# From here, we're in tmux. Set up cleanup:
cleanup_tmux_progress() {
  tmux select-pane -t 0 2>/dev/null
  tmux kill-pane -t 1 2>/dev/null
  [ -p "$FIFO_PATH" ] && rm -f "$FIFO_PATH"
}

# Modify existing on_exit to call cleanup_tmux_progress
# Do NOT use tmux:setup_trap (conflicts with our traps)

# When ready to enable progress:
if [[ "$USE_TMUX" == "true" ]]; then
  [ -p "$FIFO_PATH" ] && rm -f "$FIFO_PATH"
  mkfifo "$FIFO_PATH"
  tmux split-window -v -l 2 "tail -f $FIFO_PATH"
  tmux select-pane -t 1 -d  # Disable input
  tmux select-pane -t 1 -P 'bg=colour25'  # Blue background
  tmux select-pane -t 0  # Focus on main
fi

# In the processing loop:
if [[ "$USE_TMUX" == "true" ]] && [ -p "$FIFO_PATH" ]; then
  # Build progress bar string
  printf "Progress: [################    ] 80%% (40/50)\n" > "$FIFO_PATH"
else
  # Fallback to stderr
  echo "Progress: 40/50"
fi
```

**Advantages:**
- ✅ No source-time initialization issues
- ✅ No trap conflicts
- ✅ Simple, linear flow
- ✅ Easy to debug
- ✅ Proven pattern from demo

**Disadvantages:**
- ⚠️ Code duplication (but it's only ~50 lines)
- ⚠️ Not reusable (but _tmux.sh doesn't work reliably anyway)

---

## Implementation Plan for git.semantic-version.sh

1. **Remove:** `source "$E_BASH/_tmux.sh"` from top of script
2. **Remove:** Call to `tmux:setup_trap` (conflicts with our traps)
3. **Add:** Inline tmux pattern after argument parsing
4. **Add:** FIFO creation before `gitsv:process_commits`
5. **Modify:** Progress output to write to FIFO
6. **Modify:** `on_exit` to clean up FIFO and tmux pane
7. **Keep:** Our existing trap handlers (don't let tmux overwrite them)

**Result:** A working tmux progress display using the proven demo pattern.
