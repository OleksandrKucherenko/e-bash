# _hooks.sh

**Extensibility and Lifecycle Hooks System**

This module provides a declarative hooks system for script extension points.

## References

- demo: demo.hooks.sh, demo.hooks-logging.sh, demo.hooks-nested.sh,
       demo.hooks-registration.sh, ci-mode/demo.ci-modes.sh,
       ci-mode/ci-10-compile.sh, ci-mode/ci-20-compile.sh
- bin: npm.versions.sh (uses hooks for extensibility)
- documentation: docs/public/hooks.md
- tests: spec/hooks_spec.sh
External Dependencies:
- _traps.sh - trap:on for EXIT trap installation
- _commons.sh - to:slug() for creating filesystem-safe slugs

## Index

* [`_hooks:capture:run`](#_hooks-capture-run)
* [`_hooks:env:apply`](#_hooks-env-apply)
* [`_hooks:logger:refresh`](#_hooks-logger-refresh)
* [`_hooks:middleware:default`](#_hooks-middleware-default)
* [`_hooks:middleware:modes`](#_hooks-middleware-modes)
* [`_hooks:on_exit`](#_hooks-on_exit)
* [`_hooks:trap:end`](#_hooks-trap-end)
* [`hooks:bootstrap`](#hooks-bootstrap)
* [`hooks:declare`](#hooks-declare)
* [`hooks:do`](#hooks-do)
* [`hooks:do:script`](#hooks-do-script)
* [`hooks:do:source`](#hooks-do-source)
* [`hooks:exec:mode`](#hooks-exec-mode)
* [`hooks:flow:apply`](#hooks-flow-apply)
* [`hooks:known`](#hooks-known)
* [`hooks:list`](#hooks-list)
* [`hooks:middleware`](#hooks-middleware)
* [`hooks:pattern:script`](#hooks-pattern-script)
* [`hooks:pattern:source`](#hooks-pattern-source)
* [`hooks:register`](#hooks-register)
* [`hooks:reset`](#hooks-reset)
* [`hooks:runnable`](#hooks-runnable)
* [`hooks:unregister`](#hooks-unregister)

---

## Functions

---

### hooks:bootstrap

Bootstrap default hooks and install EXIT trap for end hook

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: HOOKS_AUTO_TRAP
- mutate/publish: __HOOKS_DEFINED, __HOOKS_END_TRAP_INSTALLED

#### Side Effects

- Declares begin/end hooks
- Installs EXIT trap if HOOKS_AUTO_TRAP=true

#### Usage

```bash
hooks:bootstrap
```

---

### hooks:declare

Declare available hook names for the script

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | string array | variadic | Hook names to declare |

#### Globals

- reads/listen: BASH_SOURCE, __HOOKS_DEFINED, __HOOKS_CONTEXTS
- mutate/publish: __HOOKS_DEFINED, __HOOKS_CONTEXTS

#### Side Effects

- Registers hook names as available
- Tracks calling context for nested/composed scripts

#### Usage

```bash
hooks:declare begin end validate process
hooks:declare custom_hook another_hook
```

#### Returns

- 0 on success, 1 on invalid hook name

---

### hooks:do

Execute a hook and all its implementations

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name to execute |
| `@` | variadic | required | Additional parameters to pass to implementations |

#### Globals

- reads/listen: __HOOKS_DEFINED, __HOOKS_REGISTERED, HOOKS_DIR,
                HOOKS_PREFIX, HOOKS_EXEC_MODE, __HOOKS_SOURCE_PATTERNS,
                __HOOKS_SCRIPT_PATTERNS, __HOOKS_MIDDLEWARE
- mutate/publish: none (calls hook implementations)

#### Side Effects

- Executes hook:hook_name function if exists
- Executes all registered functions in alphabetical order
- Executes all matching scripts in HOOKS_DIR
- Calls middleware for output processing
Execution order:
1. Check if hook is defined via hooks:declare
2. Execute function hook:{name} if it exists
3. Execute registered functions (hooks:register) in alphabetical order
4. Find and execute matching scripts in HOOKS_DIR/{hook_name}-*.sh or {hook_name}_*.sh
5. Scripts execute in alphabetical order
Script naming patterns:
- {hook_name}-{purpose}.sh
- {hook_name}_{NN}_{purpose}.sh (recommended for ordered execution)
Execution modes (controlled by HOOKS_EXEC_MODE):
- "exec" (default): Scripts execute in subprocess
- "source": Scripts sourced, hook:run function called
Logging:
- Enable with DEBUG=hooks or DEBUG=* to see execution flow

#### Usage

```bash
hooks:do begin
hooks:do decide param1 param2
result=$(hooks:do decide "question")
```

#### Returns

- Last hook's exit code or 0 if not implemented

---

### hooks:do:script

Execute a hook with forced exec mode (overrides HOOKS_EXEC_MODE)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name to execute |
| `@` | variadic | required | Additional parameters |

#### Globals

- reads/listen: HOOKS_EXEC_MODE
- mutate/publish: HOOKS_EXEC_MODE (temporarily sets to "exec")

#### Usage

```bash
hooks:do:script end
hooks:do:script notify url status
```

#### Returns

- Last hook's exit code or 0 if not implemented

---

### hooks:do:source

Execute a hook with forced sourced mode (overrides HOOKS_EXEC_MODE)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name to execute |
| `@` | variadic | required | Additional parameters |

#### Globals

- reads/listen: HOOKS_EXEC_MODE
- mutate/publish: HOOKS_EXEC_MODE (temporarily sets to "source")

#### Usage

```bash
hooks:do:source begin
hooks:do:source deploy param1 param2
```

#### Returns

- Last hook's exit code or 0 if not implemented

---

### hooks:exec:mode

Determine execution mode for a specific script

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `script_name` | string | required | Script basename to check |

#### Globals

- reads/listen: HOOKS_EXEC_MODE, __HOOKS_SOURCE_PATTERNS, __HOOKS_SCRIPT_PATTERNS
- mutate/publish: none

#### Returns

- Echoes "source" or "exec"

#### Usage

```bash
mode=$(hooks:exec:mode "begin-init.sh")
```

---

### hooks:flow:apply

Apply flow directives from middleware (route, exit)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: __HOOKS_FLOW_TERMINATE, __HOOKS_FLOW_ROUTE, __HOOKS_FLOW_EXIT_CODE
- mutate/publish: none (may exit or source route script)

#### Side Effects

- May exit with code if __HOOKS_FLOW_TERMINATE=true
- May source route script if __HOOKS_FLOW_ROUTE set

#### Usage

```bash
hooks:flow:apply    # call after hook execution
```

---

### hooks:known

Check if a hook is defined

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name to check |

#### Globals

- reads/listen: __HOOKS_DEFINED
- mutate/publish: none

#### Usage

```bash
if hooks:known begin; then echo "begin hook defined"; fi
```

#### Returns

- 0 if hook is defined, 1 otherwise

---

### hooks:list

List all defined hooks and their implementations

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: __HOOKS_DEFINED, __HOOKS_REGISTERED,
                HOOKS_PREFIX, HOOKS_DIR
- mutate/publish: none

#### Usage

```bash
hooks:list
```

#### Returns

- 0, prints hooks and implementations to stdout

---

### hooks:middleware

Register middleware function for a hook

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name for middleware |
| `middleware_fn` | string | optional | Middleware function name (empty to reset) |

#### Globals

- reads/listen: __HOOKS_MIDDLEWARE
- mutate/publish: __HOOKS_MIDDLEWARE

#### Usage

```bash
hooks:middleware begin my_middleware
hooks:middleware begin          # reset to default
```

#### Returns

- 0 on success, 1 on invalid parameters or missing function

---

### hooks:pattern:script

Register file patterns to always execute as scripts (not sourced)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | string array | variadic | File patterns (wildcards supported) |

#### Globals

- reads/listen: none
- mutate/publish: __HOOKS_SCRIPT_PATTERNS

#### Usage

```bash
hooks:pattern:script "end-datadog.sh"
hooks:pattern:script "notify-*.sh"
```

---

### hooks:pattern:source

Register file patterns to always execute in sourced mode

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | string array | variadic | File patterns (wildcards supported) |

#### Globals

- reads/listen: none
- mutate/publish: __HOOKS_SOURCE_PATTERNS

#### Usage

```bash
hooks:pattern:source "begin-*-init.sh"
hooks:pattern:source "env-*.sh" "config-*.sh"
```

---

### hooks:register

Register a function to be executed as part of a hook

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name to register for |
| `friendly_name` | string | required | Sort key for ordering (e.g. "10-backup") |
| `function_name` | string | required | Function to execute |

#### Globals

- reads/listen: __HOOKS_DEFINED, __HOOKS_REGISTERED
- mutate/publish: __HOOKS_REGISTERED

#### Usage

```bash
hooks:register deploy "10-backup" backup_database
hooks:register deploy "20-update" update_code
```

#### Returns

- 0 on success, 1 on invalid parameters or missing function

---

### hooks:reset

Reset all hooks module state (for testing)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: none
- mutate/publish: __HOOKS_DEFINED, __HOOKS_CONTEXTS, __HOOKS_REGISTERED,
                 __HOOKS_MIDDLEWARE, __HOOKS_SOURCE_PATTERNS,
                 __HOOKS_SCRIPT_PATTERNS, __HOOKS_CAPTURE_SEQ,
                 __HOOKS_END_TRAP_INSTALLED, HOOKS_DIR, HOOKS_PREFIX,
                 HOOKS_EXEC_MODE, HOOKS_AUTO_TRAP

#### Side Effects

- Unsets and redeclares all global arrays/variables
- Resets to default values

#### Usage

```bash
hooks:reset    # typically in test teardown
```

---

### hooks:runnable

Check if a hook has any implementation (function or script)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name to check |

#### Globals

- reads/listen: HOOKS_PREFIX, HOOKS_DIR, __HOOKS_REGISTERED
- mutate/publish: none

#### Usage

```bash
if hooks:runnable begin; then echo "has implementation"; fi
```

#### Returns

- 0 if hook has implementation, 1 otherwise

---

### hooks:unregister

Unregister a function from a hook

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `hook_name` | string | required | Hook name |
| `friendly_name` | string | required | Friendly name of registration to remove |

#### Globals

- reads/listen: __HOOKS_REGISTERED
- mutate/publish: __HOOKS_REGISTERED

#### Usage

```bash
hooks:unregister deploy "10-backup"
hooks:unregister build "metrics"
```

#### Returns

- 0 on success, 1 on invalid parameters or not found

