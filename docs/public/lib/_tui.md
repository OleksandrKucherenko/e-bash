# _tui.sh

**Terminal User Interface (TUI) Functions**

This module provides terminal user interface components including
cursor positioning, password input, input validation, key input handling,
multi-line text editing, and menu selection.

## References

- demo: demo.readpswd.sh, demo.selector.sh, demo.multi-line.sh, demo.capture-key.sh
- bin: vhd.sh, git.sync-by-patches.sh
- documentation: docs/public/tui.md
- tests: spec/commons_spec.sh, spec/multi_line_input_spec.sh, spec/read_key_spec.sh

## Module Globals

- E_BASH - Path to .scripts directory
- use_macos_extensions - Enable macOS-specific features, boolean, default: based on OSTYPE

## Additional Information

### Cursor Position Functions

- cursor:position() - Get "row;col" position
- cursor:position:row() - Get row number
- cursor:position:col() - Get column number

### Input Functions

- input:readpwd() - Read password with masking and line editing
- input:selector() - Interactive menu selector from array
- input:multi-line() - Interactive multi-line text editor

### Input Validation Functions

- validate:input() - Generic input validation
- validate:input:masked() - Masked input validation
- validate:input:yn() - Yes/no input validation
- confirm:by:input() - Cascading default confirmation
Key Input Functions (Internal):
- _input:read-key() - Read semantic key token
- _input:_raw() - Set raw bytes helper
- _input:capture-key() - Interactive key capture diagnostic
Multi-line Editor Functions (Internal):
- _input:ml:init() - Initialize editor state
- _input:ml:insert-char() - Insert character
- _input:ml:delete-char() - Delete character (backspace)
- _input:ml:delete-char-forward() - Delete character (forward delete)
- _input:ml:delete-word() - Delete word backward
- _input:ml:insert-newline() - Insert newline
- _input:ml:move-up/down/left/right/home/end() - Cursor movement
- _input:ml:scroll() - Adjust scroll offset
- _input:ml:get-content() - Get buffer content
- _input:ml:render() - Render editor to terminal
- _input:ml:edit-line() - Readline-based line editing
- _input:ml:paste() - Paste text
- _input:ml:insert-tab() - Insert tab as spaces
- _input:ml:delete-line() - Delete line content
- _input:ml:sel-start() - Start/extend selection
- _input:ml:sel-clear() - Clear selection
- _input:ml:sel-bounds() - Get normalized selection bounds
- _input:ml:sel-get-text() - Get selected text
- _input:ml:sel-delete() - Delete selected text
- _input:ml:sel-all() - Select all text
- _input:ml:stream:*() - Stream mode helpers

### Global State

- __INPUT_MODIFIER_NAMES - Modifier name lookup table
- __INPUT_CSI_KEYS - CSI key name lookup table
- __INPUT_CSI_TILDE_KEYS - CSI tilde key lookup table
- __INPUT_RAW_BYTES - Raw hex bytes from last key read
- __INPUT_RAW_CHARS - Raw characters from last key read
- __ML_LINES - Multi-line editor line buffer
- __ML_ROW, __ML_COL - Cursor position
- __ML_SCROLL - Scroll offset
- __ML_WIDTH, __ML_HEIGHT - Editor dimensions
- __ML_MODIFIED - Modified flag
- __ML_MESSAGE - Status message
- __ML_STATUS_BAR - Status bar visibility
- __ML_SEL_ACTIVE - Selection active flag
- __ML_SEL_ANCHOR_ROW, __ML_SEL_ANCHOR_COL - Selection anchor position


---

## Functions

<!-- TOC -->

- [_tui.sh](#_tuish)
    - [`confirm:by:input`](#confirmbyinput)
    - [`cursor:position`](#cursorposition)
    - [`cursor:position:col`](#cursorpositioncol)
    - [`cursor:position:row`](#cursorpositionrow)
    - [`input:multi-line`](#inputmulti-line)
    - [`input:readpwd`](#inputreadpwd)
    - [`input:selector`](#inputselector)
    - [`print:confirmation`](#printconfirmation)
    - [`validate:input`](#validateinput)
    - [`validate:input:masked`](#validateinputmasked)
    - [`validate:input:yn`](#validateinputyn)

<!-- /TOC -->

---

### confirm:by:input

Cascading confirmation with fallback to input prompts

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hint` | string | required | Prompt message |
| `variable` | string | required | Variable name to store result |
| `fallback` | string | required | Default value |
| `top` | string | default: "" (triggers prompt) | First value to use |
| `second` | string | default: "" (uses fallback) | Second value to use |
| `third` | string | default: "" (uses input prompt) | Third value to use |
| `masked` | string | default: "" | Display value instead of prompting |

#### Globals

- reads/listen: cl_purple, cl_reset, cl_blue
- mutate/publish: creates global variable named by second parameter

#### Returns

- 0 on success
- Sets variable to: top if set, second if set, third if set, or prompts for input

#### Usage

```bash
confirm:by:input "Continue?" result "y" "" "" ""
```

---

### cursor:position

Get cursor position in "row;col" format

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes "row;col" position

#### Usage

```bash
pos=$(cursor:position)
```

---

### cursor:position:col

Get cursor column position

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes column number

#### Usage

```bash
col=$(cursor:position:col)
```

---

### cursor:position:row

Get cursor row position

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes row number

#### Usage

```bash
row=$(cursor:position:row)
```

---

### input:multi-line

Interactive multi-line text editor in terminal
Opens a modal text editor with two rendering modes:
**Box mode** (default): Position and size the editor explicitly with
-x, -y, -w, -h. Useful for modal dialog overlays. Supports --alt-buffer
to preserve terminal scroll history.
**Stream mode** (-m stream): Uses current cursor position, full terminal
width, and a configurable height (default 5 lines). If the cursor is near
the bottom of the terminal, emits newlines to scroll up and make room.
On exit, repositions cursor to the editor area so output reuses those lines.
Features inspired by the bed (bash editor) project:
- Alternative terminal buffer (--alt-buffer, box mode only)
- WINCH signal handling for terminal resize
- Configurable keybindings via ML_KEY_* environment variables
- Bracketed paste detection (paste from clipboard)
- Text selection via Shift+arrow keys (highlighted with cl_selected)
- Clipboard integration: Ctrl+C copy, Ctrl+X cut, Ctrl+V paste
- Select all with Ctrl+A
- Modified indicator in status bar
- Readline-based line editing (Ctrl+E)
- Status bar with position info and help hints

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `--alt-buffer` | string | required | Use alternative terminal buffer (box mode only) |
| `--no-status` | string | required | Hide status bar |

#### Globals

- reads/listen: TERM, ML_KEY_SAVE, ML_KEY_EDIT, ML_KEY_DEL_WORD, ML_KEY_DEL_LINE,
                cl_selected
- mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL, __ML_MODIFIED,
                  __ML_SEL_ACTIVE, __ML_SEL_ANCHOR_ROW, __ML_SEL_ANCHOR_COL

#### Side Effects

- Saves/restores terminal state (stty)
- Traps INT/TERM/WINCH for cleanup and resize
- Reads raw keyboard input
- Renders to terminal via ANSI escape sequences
- Enables/disables bracketed paste mode

#### Returns

- 0 on save (Ctrl+D), 1 on cancel (Esc)
- Echoes captured text to stdout

#### Usage

```bash
text=$(input:multi-line)                            # box mode, full screen
text=$(input:multi-line -w 60 -h 10 -x 5 -y 2)     # box mode, positioned
text=$(input:multi-line --alt-buffer)                # box mode, alt buffer
text=$(input:multi-line -m stream)                   # stream mode, 5 lines
text=$(input:multi-line -m stream -h 10)             # stream mode, 10 lines
ML_KEY_SAVE="ctrl-s" text=$(input:multi-line)        # custom save key
```

---

### input:readpwd

Read user password input with masking and line editing

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: none

#### Side Effects

- Reads from terminal with arrow key navigation
- Masks input as asterisks

#### Returns

- Echoes entered password

#### Usage

```bash
password=$(input:readpwd)
```

---

### input:selector

Interactive menu selector from associative array

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `sourceVariableName` | string | required | Name of associative array to read from |
| `keyOrValue` | string | default: "key" | Return "key" or "value" from array |

#### Globals

- reads/listen: cursor:position:row, cursor:position:col
- mutate/publish: none

#### Side Effects

- Hides/shows cursor during selection

#### Returns

- 0 on success, 1 on escape/abort
- Echoes selected key or value from array

#### Usage

```bash
declare -A MENU=([1]="Option 1" [2]="Option 2")
selected=$(input:selector "MENU" "value")
```

---

### print:confirmation

Print confirmation prompt with value

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `value` | string | required | Value to display in prompt |

#### Globals

- reads/listen: hint, cl_purple, cl_reset, cl_blue
- mutate/publish: none

#### Side Effects

- Outputs formatted prompt to stdout

#### Returns

- None

#### Usage

```bash
print:confirmation "value"
```

---

### validate:input

Generic input validation with prompt and retry

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable` | string | required | Variable name to store result |
| `default` | string | default: "" | Default value to suggest |
| `hint` | string | default: "" | Prompt text to display |

#### Globals

- reads/listen: use_macos_extensions, cl_purple, cl_reset, cl_blue
- mutate/publish: creates global variable named by first parameter

#### Side Effects

- Sets trap for SIGINT during read operation

#### Returns

- 0 on success
- Sets variable to user input or default value

#### Usage

```bash
validate:input result "default" "Enter value"
```

---

### validate:input:masked

Masked input validation (password-style prompt with asterisks)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable` | string | required | Variable name to store result |
| `default` | string | default: "" | Default value to suggest |
| `hint` | string | default: "" | Prompt text to display |

#### Globals

- reads/listen: use_macos_extensions, cl_purple, cl_reset, cl_blue
- mutate/publish: creates global variable named by first parameter

#### Side Effects

- Displays input as asterisks, supports arrow key navigation

#### Returns

- 0 on success
- Sets variable to user input (masked during entry)

#### Usage

```bash
validate:input:masked password "" "Enter password"
```

---

### validate:input:yn

Prompt user for yes/no input and store as boolean value

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable` | string | required | Variable name to store result (passed by reference) |
| `default` | string | default: "" | Default value to suggest |
| `hint` | string | default: "" | Prompt text to display |

#### Globals

- reads/listen: use_macos_extensions
- mutate/publish: creates global variable named by first parameter

#### Returns

- 0 on success
- Sets variable to 'true' for yes, 'false' for no/other

#### Usage

```bash
validate:input:yn result "y" "Continue?"
```

