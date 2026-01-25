# _commons.sh

**Common Utilities and Helper Functions**

This module provides a collection of frequently used utility functions
for time handling, cursor position, input validation, git operations,
config file discovery, and user interaction.

## Index

* [`_env:resolve:string`](#_env-resolve-string)
* [`args:isHelp`](#args-ishelp)
* [`config:hierarchy`](#config-hierarchy)
* [`config:hierarchy:xdg`](#config-hierarchy-xdg)
* [`confirm:by:input`](#confirm-by-input)
* [`cursor:position`](#cursor-position)
* [`cursor:position:col`](#cursor-position-col)
* [`cursor:position:row`](#cursor-position-row)
* [`env:resolve`](#env-resolve)
* [`env:variable:or:secret:file`](#env-variable-or-secret-file)
* [`env:variable:or:secret:file:optional`](#env-variable-or-secret-file-optional)
* [`git:root`](#git-root)
* [`input:readpwd`](#input-readpwd)
* [`input:selector`](#input-selector)
* [`print:confirmation`](#print-confirmation)
* [`time:diff`](#time-diff)
* [`time:now`](#time-now)
* [`to:slug`](#to-slug)
* [`to:slug:hash`](#to-slug-hash)
* [`val:l0`](#val-l0)
* [`val:l1`](#val-l1)
* [`validate:input`](#validate-input)
* [`validate:input:masked`](#validate-input-masked)
* [`validate:input:yn`](#validate-input-yn)
* [`var:l0`](#var-l0)
* [`var:l1`](#var-l1)

---

## Functions

---

### args:isHelp

Check if --help flag is present in arguments

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Arguments to check |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- "true" if --help present, "false" otherwise

#### Usage

```bash
if args:isHelp "$@"; then ...; fi
```

---

### config:hierarchy

Find configuration file hierarchy by searching upward from current folder

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `config_name` | string | default: ".config" | Config file name(s), comma-separated |
| `start_path` | string | default: "." | Starting directory |
| `stop_at` | string | default: "git" | Where to stop searching |
| `extensions` | string | default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc" | Comma-separated extensions |

#### Globals

- reads/listen: HOME, git:root()
- mutate/publish: none

#### Returns

- 0 if at least one config file found, 1 otherwise
- Echoes config paths, one per line, ordered root to current (bottom-up)

#### Usage

```bash
config:hierarchy ".eslintrc"
config:hierarchy "package.json" "." "home"
config:hierarchy ".config" "." "git" ".json,.yaml"
```

---

### config:hierarchy:xdg

Find config files following XDG Base Directory Specification

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `app_name` | string | required | Application name for XDG dirs |
| `config_name` | string | default: "config" | Config file name(s), comma-separated |
| `start_path` | string | default: "." | Starting directory |
| `stop_at` | string | default: "home" | Where to stop hierarchical search |
| `extensions` | string | default: ",.json,.yaml,.yml,.toml,.ini,.conf,.rc" | Comma-separated extensions |

#### Globals

- reads/listen: HOME, XDG_CONFIG_HOME, XDG_CONFIG_DIRS
- mutate/publish: none

#### Returns

- 0 if at least one config file found, 1 otherwise
- Echoes config paths, one per line, ordered by priority (highest to lowest)
Search order:
- 1. Hierarchical from current_dir to stop_path
- 2. $XDG_CONFIG_HOME/<app_name>/
- 3. ~/.config/<app_name>/
- 4. /etc/xdg/<app_name>/
- 5. /etc/<app_name>/

#### Usage

```bash
config:hierarchy:xdg "myapp" "config"
config:hierarchy:xdg "nvim" "init.vim,.nvimrc"
```

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

### env:resolve

Resolve {{env.VAR_NAME}} patterns to environment variable values

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `input_string` | string | default: stdin | String with {{env.*}} patterns (optional if pipeline mode) |
| `array_name` | string | default: none (env vars only) | Associative array name for custom vars |

#### Globals

- reads/listen: environment variables
- mutate/publish: none

#### Returns

- String with {{env.VAR_NAME}} patterns replaced
- Resolution priority: associative array > environment variables

#### Usage

```bash
result=$(env:resolve "Path: {{env.HOME}}")
echo "{{env.HOME}}" | env:resolve
declare -A VARS=([x]="y"); result=$(env:resolve "{{env.x}}" "VARS")
```

---

### env:variable:or:secret:file

Get environment variable value or read from secret file (required)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | required | Variable name to store result |
| `variable` | string | required | Environment variable name to check |
| `filepath` | string | required | Path to secret file as fallback |
| `fallback` | string | default: "No hints, check the documentation" | User-friendly hint message |

#### Globals

- reads/listen: none
- mutate/publish: creates global variable named by first parameter

#### Returns

- 0 on success, 1 if neither env var nor file exists

#### Usage

```bash
env:variable:or:secret:file value "API_KEY" ".secrets/api_key" "Set your API key"
```

---

### env:variable:or:secret:file:optional

Get environment variable value or read from secret file (optional)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | required | Variable name to store result |
| `variable` | string | required | Environment variable name to check |
| `filepath` | string | required | Path to secret file as fallback |

#### Globals

- reads/listen: none
- mutate/publish: creates global variable named by first parameter

#### Returns

- 0 on success, 1 if neither env var nor file exists

#### Usage

```bash
env:variable:or:secret:file:optional value "API_KEY" ".secrets/api_key"
```

---

### git:root

Find git repository root directory (handles regular repos, worktrees, submodules)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `start_path` | string | default: "." | Starting directory path |
| `output_type` | string | default: "path" | Output format |

#### Globals

- reads/listen: use_macos_extensions
- mutate/publish: none

#### Returns

- 0 if git root found, 1 otherwise
- Echoes based on output_type

#### Usage

```bash
root=$(git:root)
type=$(git:root "." "type")  # "regular" or "worktree" or "submodule"
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

### time:diff

Calculate time difference from given start timestamp

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `start` | string | required | Start timestamp from time:now |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes time difference in seconds

#### Usage

```bash
start=$(time:now); sleep 1; time:diff "$start"
```

---

### time:now

Get current epoch timestamp with microsecond precision

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: EPOCHREALTIME
- mutate/publish: none

#### Returns

- Echoes timestamp string

#### Usage

```bash
start=$(time:now)
time:diff "$start"
```

---

### to:slug

Convert string to filesystem-safe slug

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `string` | string | required | String to convert |
| `separator` | string | default: "_" | Separator character |
| `trim` | string | default: 20 | Maximum length or "always" for hash, string/number |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes filesystem-safe slug trimmed to length with optional hash
- Returns "__" + hash (7 chars) if input only special characters

#### Usage

```bash
result=$(to:slug "Hello World!" "_" 20)
result=$(to:slug "Hello World!" "_" "always")
```

---

### to:slug:hash

Generate cross-platform hash for slug generation (internal helper)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `input` | string | required | String to hash |
| `length` | number | required | Hash length to return |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes hash of specified length

#### Usage

```bash
hash=$(to:slug:hash "input" 7)
```

---

### val:l0

Get value or fallback to default (value coalescing level 0)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `value` | string | required | Value to check |
| `default` | string | required | Default value if value is empty |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes value if non-empty, otherwise default

#### Usage

```bash
result=$(val:l0 "hello" "default")
```

---

### val:l1

Get value from value1, value2, or default (value coalescing level 1)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `value1` | string | required | First value to check |
| `value` | string | required | Second value to check |
| `default` | string | required | Default value if both values empty |

#### Globals

- reads/listen: none
- mutate/publish: none

#### Returns

- Echoes value1 if non-empty, value if non-empty, otherwise default

#### Usage

```bash
result=$(val:l1 "first" "second" "default")
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

---

### var:l0

Get variable value or fallback to default (variable coalescing level 0)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `variable_name` | string | required | Name of variable to check |
| `default` | string | required | Default value if variable is empty/unset |

#### Globals

- reads/listen: variables by name
- mutate/publish: none

#### Returns

- Echoes variable value if set and non-empty, otherwise default

#### Usage

```bash
MY_VAR="hello"; result=$(var:l0 "MY_VAR" "default")
```

---

### var:l1

Get variable value from var1, var2, or default (variable coalescing level 1)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `var1` | string | required | Name of first variable to check |
| `var2` | string | required | Name of second variable to check |
| `default` | string | required | Default value if both variables empty/unset |

#### Globals

- reads/listen: variables by name
- mutate/publish: none

#### Returns

- Echoes var1 if set, var2 if set, otherwise default

#### Usage

```bash
result=$(var:l1 "VAR1" "VAR2" "default")
```

