# _tmux.sh

**Tmux Integration for Progress Display**

This module provides tmux integration for displaying progress bars and
session management for long-running scripts.

## References

- demo: demo.tmux.progress.sh, demo.tmux.runner.sh, demo.tmux.streams.sh,
       demo.tmux.exec.sh
- bin: git.sync-by-patches.sh (uses tmux progress display)

## Module Globals

- E_BASH - Path to .scripts directory
- TMUX_PROGRESS_HEIGHT - Progress pane height, default: 2
- TMUX_MAIN_PANE - Main pane index, default: 0
- TMUX_PROGRESS_PANE - Progress pane index, default: 1
- TMUX_STARTED_BY_SCRIPT - Flag if script started tmux session
- TMUX_SESSION_NAME - Session name for tracking
- TMUX_PROGRESS_ACTIVE - Whether progress display is active
- TMUX_FIFO_PATH - FIFO path for progress updates

---

## Functions

<!-- TOC -->

- [_tmux.sh](#_tmuxsh)
    - [`tmux:check_mouse_support`](#tmuxcheck_mouse_support)
    - [`tmux:cleanup_all`](#tmuxcleanup_all)
    - [`tmux:cleanup_progress`](#tmuxcleanup_progress)
    - [`tmux:ensure_session`](#tmuxensure_session)
    - [`tmux:init_progress`](#tmuxinit_progress)
    - [`tmux:setup_trap`](#tmuxsetup_trap)
    - [`tmux:show_progress_bar`](#tmuxshow_progress_bar)
    - [`tmux:update_progress`](#tmuxupdate_progress)

<!-- /TOC -->

---

### tmux:check_mouse_support

Check and enable mouse support in tmux

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Side Effects

- Enables mouse mode for tmux session

#### Returns

- None

#### Usage

```bash
tmux:check_mouse_support
```

---

### tmux:cleanup_all

Clean up and optionally exit tmux session

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: TMUX_STARTED_BY_SCRIPT, TMUX_SESSION_NAME, TMUX_PROGRESS_ACTIVE
- mutate/publish: none

#### Side Effects

- May kill tmux session

#### Returns

- None

#### Usage

```bash
tmux:cleanup_all
tmux:cleanup_all false  # Keep session alive
```

---

### tmux:cleanup_progress

Clean up tmux progress display resources

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: TMUX_PROGRESS_ACTIVE, TMUX_FIFO_PATH, TMUX_MAIN_PANE, TMUX_PROGRESS_PANE
- mutate/publish: TMUX_PROGRESS_ACTIVE

#### Side Effects

- Removes FIFO file
- Kills tmux progress pane

#### Returns

- 0 on success, tmux error code otherwise

#### Usage

```bash
tmux:cleanup_progress
```

---

### tmux:ensure_session

Start tmux session if not already in one

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | variadic | required | Script start parameters (passed to tmux) |

#### Globals

- reads/listen: TMUX, TMUX_SESSION_NAME
- mutate/publish: TMUX_STARTED_BY_SCRIPT, TMUX_SESSION_NAME
Side Effects:
- Executes tmux with current script (replaces process via exec)

#### Returns

- 0 on success (process is replaced)
- 0 if already in tmux (no action taken)

#### Usage

```bash
tmux:ensure_session "$@"
```

---

### tmux:init_progress

Initialize progress display in a tmux pane

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `fifo_path` | string | default: mktemp --dry-run -t 'tmux_progress' | Path for the named pipe |

#### Globals

- reads/listen: TMUX_PROGRESS_HEIGHT, TMUX_MAIN_PANE, TMUX_PROGRESS_PANE
- mutate/publish: TMUX_FIFO_PATH, TMUX_PROGRESS_ACTIVE
Side Effects:
- Creates named pipe (FIFO)
- Splits tmux pane to create progress display area

#### Returns

- 0 on success, 1 on failure

#### Usage

```bash
tmux:init_progress "/tmp/my_progress"
```

---

### tmux:setup_trap

Set up trap to catch interrupt and clean up resources

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- None

#### Usage

```bash
tmux:setup_trap
```

---

### tmux:show_progress_bar

Show percentage-based progress bar

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `current` | number | required | Current progress value |
| `total` | number | required | Total progress value |
| `prefix` | string | default: "Progress" | Prefix for the progress bar |
| `width` | number | default: 50 | Width of the progress bar |

#### Globals

- reads/listen: TMUX_PROGRESS_ACTIVE, TMUX_FIFO_PATH, cl_red, cl_reset
- mutate/publish: none

#### Returns

- 0 on success, 1 on failure

#### Usage

```bash
tmux:show_progress_bar 50 100 "Loading" 40
```

---

### tmux:update_progress

Update progress display message

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `message` | string | required | Progress message to display |

#### Globals

- reads/listen: TMUX_PROGRESS_ACTIVE, TMUX_FIFO_PATH
- mutate/publish: none

#### Returns

- 0 on success, 1 if progress display not active

#### Usage

```bash
tmux:update_progress "Processing item 3 of 10"
```

