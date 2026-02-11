# _tui.sh

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
    - [`tui:box:close`](#tuiboxclose)
    - [`tui:box:draw`](#tuiboxdraw)
    - [`tui:box:open`](#tuiboxopen)
    - [`tui:key:capture`](#tuikeycapture)
    - [`tui:key:describe`](#tuikeydescribe)
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
Opens a modal text editor at specified position with configurable dimensions.
Supports arrow key navigation, backspace, word delete, newline, tab, paste.
Press Ctrl+D to save and exit, Esc to cancel.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: TERM, cl_grey, cl_reset
- mutate/publish: __ML_LINES, __ML_ROW, __ML_COL, __ML_SCROLL

#### Side Effects

- Saves/restores terminal state (stty)
- Traps INT/TERM for cleanup
- Reads raw keyboard input
- Renders to terminal via ANSI escape sequences
- Clears editor rectangle on exit
- In stream mode emits extra lines to make room near terminal bottom

#### Returns

- 0 on save (Ctrl+D), 1 on cancel (Esc)
- Echoes captured text to stdout

#### Usage

```bash
text=$(input:multi-line)
text=$(input:multi-line -w 60 -h 10 -x 5 -y 2)
text=$(input:multi-line -m stream -h 5)
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

### tui:box:close

Restore the last modal box layer and redraw affected region

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `layer_id` | integer | required | Layer id returned by tui:box:open |

#### Returns

- 0 on success
- 1 when layer is unknown or not topmost

---

### tui:box:draw

Draw a pseudographics box at specified location and size

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Side Effects

- Mutates internal box canvas and renders updated region to stderr

#### Returns

- 0 on success

---

### tui:box:open

Draw modal box and capture previous canvas state for restoration

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Returns

- Echoes modal layer id

---

### tui:key:capture

Capture one key press from terminal and print sequence formats

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `binding_name` | string | default: "" | Optional env var name for export snippet |

#### Side Effects

- Switches terminal to raw mode briefly

#### Returns

- 0 on success
- Echoes key description lines from tui:key:describe

#### Usage

```bash
tui:key:capture
tui:key:capture TUI_KEY_UP
```

---

### tui:key:describe

Print key sequence description in raw/hex/human formats

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `raw` | string | required | Raw key sequence |
| `binding_name` | string | default: "" | Optional env var name for export snippet |

#### Returns

- Echoes formatted lines:
  RAW=..., HEX=..., EVENT=..., HUMAN=...
  optional: EXPORT=export <binding_name>=...

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

