# _logger.sh

**Advanced Tag-Based Logging System**

This module provides a flexible logging system with tag-based filtering,
pipe/redirect support, and dynamic function creation.

## References

- demo: demo.logs.sh, demo.ecs-json-logging.sh, benchmark.ecs.sh
- bin: git.log.sh, git.sync-by-patches.sh, git.verify-all-commits.sh
  ci.validate-envrc.sh, ipv6.sh, tree.sh, vhd.sh, npm.versions.sh
- documentation: docs/public/logger.md
- tests: spec/logger_spec.sh

## Module Globals

- __SESSION - Unique session ID (uuidgen or "session-$$-$RANDOM")
- __TTY - TTY device path or "notty"
- DEBUG - Comma-separated tags to enable (supports wildcards: *, negation: -tag)
- TAGS - Associative array of tag enable state (0=disabled, 1=enabled)
- TAGS_PREFIX - Associative array of tag to prefix string
- TAGS_PIPE - Associative array of tag to named pipe path
- TAGS_REDIRECT - Associative array of tag to redirection string
- TAGS_STACK - Stack level counter for push/pop operations

---

## Functions

<!-- TOC -->

- [_logger.sh](#_loggersh)
    - [`logger`](#logger)
    - [`logger:cleanup`](#loggercleanup)
    - [`logger:compose`](#loggercompose)
    - [`logger:compose:eval`](#loggercomposeeval)
    - [`logger:compose:helpers`](#loggercomposehelpers)
    - [`logger:compose:helpers:eval`](#loggercomposehelperseval)
    - [`logger:init`](#loggerinit)
    - [`logger:listen`](#loggerlisten)
    - [`logger:pop`](#loggerpop)
    - [`logger:prefix`](#loggerprefix)
    - [`logger:push`](#loggerpush)
    - [`logger:redirect`](#loggerredirect)
    - [`pipe:killer:compose`](#pipekillercompose)

<!-- /TOC -->

---

### logger

Register a tag-based logger that creates dynamic logging functions

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required, e.g. "debug" | Logger tag name (lowercase) |
| `@` | string | default: none | Optional flags for initial tag enablement (e.g., "--debug") |

#### Globals

- reads/listen: DEBUG (environment variable, controls tag visibility)
- mutate/publish: TAGS (associative array), TAGS_PREFIX, TAGS_PIPE, TAGS_REDIRECT

#### Side Effects

- Creates named pipe in /tmp for pipe logging (path: /tmp/_logger.{Tag}.{__SESSION})
- Creates background process to clean up named pipe on parent exit
- Defines the following dynamic functions:
  - echo:{Tag}() - Print output if tag enabled (with TAGS_PREFIX if set, respecting TAGS_REDIRECT)
  - printf:{Tag}() - Formatted print if tag enabled
  - log:{Tag}() - Pipe-friendly logger (reads stdin, supports prefix argument)
  - config:logger:{Tag}() - Re-configure tag based on DEBUG variable changes

#### Usage

```bash
logger debug "$@"                    # basic logger
logger myapp --debug                 # enabled by --debug flag
echo:Debug "Only shows when DEBUG=debug"  # use generated function
find . | log:Debug                   # pipe mode logging
DEBUG=myapp ./script.sh              # enable specific tag
DEBUG=* ./script.sh                  # enable all tags
DEBUG=*,-dbg ./script.sh              # enable all except debug tag
```

---

### logger:cleanup

Remove all named pipes created by the logger system

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: TAGS_PIPE
- mutate/publish: TAGS_PIPE (empties array)

#### Side Effects

- Deletes all FIFO files in TAGS_PIPE

#### Usage

```bash
logger:cleanup    # typically in EXIT trap
```

---

### logger:compose

Generate Bash code to create dynamic echo:Tag and printf:Tag logging functions

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required, e.g. "debug" | The logger tag name (lowercase) |
| `suffix` | string | required, e.g. "Debug" | Capitalized tag name for function suffix |
| `flags` | string | default: "" | Additional flags (unused) |

#### Globals

- reads/listen: TAGS, TAGS_PREFIX, TAGS_REDIRECT
- mutate/publish: none (outputs generated function code)

#### Usage

```bash
eval "$(logger:compose "mytag" "Mytag")" # creates echo:Mytag and printf:Mytag
```

---

### logger:compose:eval

Generate and eval Bash code to create dynamic echo:Tag and printf:Tag functions

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required, e.g. "debug" | The logger tag name (lowercase) |
| `suffix` | string | required, e.g. "Debug" | Capitalized tag name for function suffix |
| `flags` | string | default: "" | Additional flags (unused) |

#### Globals

- reads/listen: TAGS, TAGS_PREFIX, TAGS_REDIRECT
- mutate/publish: none (defines functions via eval)

#### Usage

```bash
logger:compose:eval "mytag" "Mytag"
```

---

### logger:compose:helpers

Generate Bash code to create helper functions (log:Tag, config:logger:Tag)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required, e.g. "debug" | The logger tag name (lowercase) |
| `suffix` | string | required, e.g. "Debug" | Capitalized tag name for function suffix |
| `flags` | string | default: "" | Additional flags (unused) |

#### Globals

- reads/listen: DEBUG, TAGS
- mutate/publish: TAGS (may modify tag state)

#### Usage

```bash
eval "$(logger:compose:helpers "mytag" "Mytag")"
```

---

### logger:compose:helpers:eval

Generate and eval helper functions (log:Tag, config:logger:Tag)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required, e.g. "debug" | The logger tag name (lowercase) |
| `suffix` | string | required, e.g. "Debug" | Capitalized tag name for function suffix |
| `flags` | string | default: "" | Additional flags (unused) |

#### Globals

- reads/listen: DEBUG, TAGS
- mutate/publish: TAGS (may modify tag state)

#### Usage

```bash
logger:compose:helpers:eval "mytag" "Mytag"
```

---

### logger:init

Initialize logger with prefix and redirect in one call

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required | Logger tag name |
| `prefix` | string | default: "[${tag}] " | Prefix string |
| `redirect` | string | default: ">&2" | Redirection target |

#### Globals

- reads/listen: none
- mutate/publish: none (calls logger, logger:prefix, logger:redirect)

#### Side Effects

- Creates logger and configures prefix/redirect

#### Usage

```bash
logger:init myapp                    # defaults: [myapp] to stderr
logger:init myapp "[MyApp] " ">&2"   # explicit
logger:init myapp "" ""              # no prefix, no redirect
```

---

### logger:listen

Run background process to read from named pipe and output to TTY

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required | Logger tag name |

#### Globals

- reads/listen: TAGS_PIPE
- mutate/publish: none (creates background process)

#### Side Effects

- Creates background cat process

#### Usage

```bash
logger:listen myapp    # forward pipe to terminal
```

---

### logger:pop

Restore previous TAGS state from stack

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: TAGS_STACK
- mutate/publish: TAGS (replaces with stacked state), removes __TAGS_STACK_N

#### Side Effects

- Decrements TAGS_STACK counter
- Removes stacked snapshot after restoration

#### Usage

```bash
logger:push
TAGS([temp])=1
logger:pop
```

---

### logger:prefix

Set or change the prefix string for a logger tag

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required | Logger tag name |
| `prefix` | string | default: "" | Prefix string (empty to reset) |

#### Globals

- reads/listen: TAGS
- mutate/publish: TAGS_PREFIX

#### Side Effects

- Unsets TAGS_PREFIX[$tag] if prefix is empty

#### Usage

```bash
logger:prefix myapp "[ MyApp ] "
logger:prefix myapp ""    # reset to default
```

---

### logger:push

Save current TAGS state to stack for temporary modification

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: TAGS
- mutate/publish: TAGS_STACK, creates __TAGS_STACK_N associative arrays

#### Side Effects

- Increments TAGS_STACK counter
- Creates snapshot of current TAGS state

#### Usage

```bash
logger:push    # save state
DEBUG=temp ./script.sh
logger:pop     # restore state
```

---

### logger:redirect

Set or change output redirection for a logger tag

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tag` | string | required | Logger tag name |
| `redirect` | string | default: "" | Redirection target |

#### Globals

- reads/listen: TAGS
- mutate/publish: TAGS_REDIRECT, recreates echo:Tag and printf:Tag

#### Side Effects

- Recreates logger functions with new redirection

#### Usage

```bash
logger:redirect myapp ">&2"              # to stderr
logger:redirect myapp ">/tmp/myapp.log"  # to file
logger:redirect myapp ""                 # reset
```

---

### pipe:killer:compose

Generate a background process that monitors parent and cleans up named pipe on exit

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `pipe` | string | required | Path to the named pipe to clean up |
| `myPid` | integer | default: "$BASHPID" | Parent process ID to monitor |

#### Globals

- reads/listen: none
- mutate/publish: none (outputs generated process code)

#### Side Effects

- Creates background process with trap to delete pipe on parent exit

#### Usage

```bash
bash <(pipe:killer:compose "/tmp/my.pipe" "$$") &
```

