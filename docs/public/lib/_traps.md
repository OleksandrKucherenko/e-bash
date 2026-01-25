# _traps.sh

**Enhanced Signal Handling with Multiple Handlers per Signal**

This module provides a trap management system that supports multiple handlers
per signal, LIFO execution order, legacy trap preservation, and stack-based scoping.

## References

- demo: demo.traps.sh
- bin: (used internally by _hooks.sh which many bin scripts depend on)
- documentation: docs/public/traps.md
- tests: spec/traps_spec.sh

## Module Globals

- E_BASH - Path to .scripts directory
- __TRAP_PREFIX - Prefix for handler arrays ("__TRAP_HANDLERS_SIG_")
- __TRAP_LEGACY_PREFIX - Prefix for legacy trap storage ("__TRAP_LEGACY_SIG_")
- __TRAP_INIT_PREFIX - Prefix for initialization flags ("__TRAP_INITIALIZED_SIG_")
- __TRAP_STACK_PREFIX - Prefix for stack snapshots ("__TRAP_STACK_")
- __TRAP_STACK_LEVEL - Current stack depth counter, default: 0
- __TRAPS_MODULE_INITIALIZED - Module initialization flag
- __TRAP_HANDLERS_SIG_{signal} - Array of handler function names for each signal
- __TRAP_INITIALIZED_SIG_{signal} - Flag indicating signal has been initialized
- __TRAP_LEGACY_SIG_{signal} - Original trap command before module loaded
- __TRAP_STACK_{N} - Stack snapshot at level N (associative array)

## Index

* [`Trap::dispatch`](#trap--dispatch)
* [`_Trap::capture_legacy`](#_trap--capture_legacy)
* [`_Trap::contains`](#_trap--contains)
* [`_Trap::initialize_signal`](#_trap--initialize_signal)
* [`_Trap::list_all_signals`](#_trap--list_all_signals)
* [`_Trap::normalize_signal`](#_trap--normalize_signal)
* [`_Trap::remove_handler`](#_trap--remove_handler)
* [`trap:clear`](#trap-clear)
* [`trap:list`](#trap-list)
* [`trap:off`](#trap-off)
* [`trap:on`](#trap-on)
* [`trap:pop`](#trap-pop)
* [`trap:push`](#trap-push)
* [`trap:restore`](#trap-restore)
* [`trap:scope:begin`](#trap-scope-begin)
* [`trap:scope:end`](#trap-scope-end)

---

## Functions

---

### Trap::dispatch

Main dispatcher called by the OS trap mechanism

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `signal` | string | automatic | Signal name being dispatched |

#### Globals

- reads/listen: __TRAP_PREFIX, __TRAP_LEGACY_PREFIX, $?
- mutate/publish: none (calls registered handlers)

#### Side Effects

- Executes all registered handlers in LIFO order
- Executes legacy trap before handlers

#### Usage

```bash
Not called directly - set as trap by trap:on
```

---

### trap:clear

Clear all handlers for signal(s) (keeps legacy trap intact)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `signals` | string array | variadic | Signal names to clear |

#### Globals

- reads/listen: __TRAP_PREFIX
- mutate/publish: __TRAP_HANDLERS_SIG_{signal} array (empties)

#### Usage

```bash
trap:clear EXIT
trap:clear INT TERM ERR
```

---

### trap:list

List all registered handlers for signal(s)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `signals` | string array | optional | Signal names (empty to list all) |

#### Globals

- reads/listen: __TRAP_PREFIX, __TRAP_LEGACY_PREFIX
- mutate/publish: none

#### Usage

```bash
trap:list EXIT INT
trap:list    # all signals
```

#### Returns

- 0, prints handlers to stdout

---

### trap:off

Unregister handler function from signal(s)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `handler_function` | string | required | Function to remove |
| `signals` | string array | variadic | Signal names |

#### Globals

- reads/listen: __TRAP_PREFIX
- mutate/publish: __TRAP_HANDLERS_SIG_{signal} array

#### Usage

```bash
trap:off cleanup_temp EXIT
trap:off handle_interrupt INT TERM
```

---

### trap:on

Register handler function for one or more signals

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `--allow-duplicates` | flag | optional | Allow duplicate handler registration |
| `handler_function` | string | required | Function to call when signal triggers |
| `signals` | string array | variadic | Signal names (EXIT, INT, TERM, ERR, etc.) |

#### Globals

- reads/listen: __TRAP_PREFIX, __TRAP_INIT_PREFIX
- mutate/publish: __TRAP_HANDLERS_SIG_{signal} array, __TRAP_INITIALIZED_SIG_{signal}

#### Side Effects

- Creates trap on signal using Trap::dispatch
- Initializes signal state on first registration

#### Usage

```bash
trap:on cleanup_temp EXIT
trap:on handle_interrupt INT TERM
trap:on --allow-duplicates log_event ERR
```

---

### trap:pop

Pop and restore previous handler state from stack

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `signals` | string array | optional | Signal names to restore (empty for last push's signals) |

#### Globals

- reads/listen: __TRAP_STACK_LEVEL, __TRAP_STACK_PREFIX, __TRAP_PREFIX
- mutate/publish: __TRAP_STACK_LEVEL, __TRAP_HANDLERS_SIG_{signal}, removes __TRAP_STACK_{N}

#### Usage

```bash
trap:pop EXIT INT
trap:pop    # all signals in last push
```

#### Returns

- 0 on success, 1 if stack is empty

---

### trap:push

Push current handler state to stack (create snapshot)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `signals` | string array | optional | Signal names to snapshot (empty for all) |

#### Globals

- reads/listen: __TRAP_PREFIX, __TRAP_STACK_PREFIX
- mutate/publish: __TRAP_STACK_LEVEL, creates __TRAP_STACK_{N} associative array

#### Usage

```bash
trap:push EXIT INT
trap:push    # all active signals
```

---

### trap:restore

Restore original trap configuration from before module loaded

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `signals` | string array | variadic | Signal names to restore |

#### Globals

- reads/listen: __TRAP_LEGACY_PREFIX
- mutate/publish: __TRAP_HANDLERS_SIG_{signal} array (removes trap)

#### Usage

```bash
trap:restore EXIT
```

#### Side Effects

- Removes trap module's trap, restores original if existed

---

### trap:scope:begin

Begin scoped trap section (alias for trap:push)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | string array | variadic | Signal names to snapshot |

#### Globals

- reads/listen: (same as trap:push)
- mutate/publish: (same as trap:push)

#### Usage

```bash
trap:scope:begin EXIT INT
trap:scope:begin    # all active signals
See Also:
trap:push
```

---

### trap:scope:end

End scoped trap section (alias for trap:pop)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | string array | variadic | Signal names to restore |

#### Globals

- reads/listen: (same as trap:pop)
- mutate/publish: (same as trap:pop)

#### Usage

```bash
trap:scope:end EXIT INT
trap:scope:end    # all signals in last push
```

#### Returns

- 0 on success, 1 if stack is empty
See Also:
- trap:pop

