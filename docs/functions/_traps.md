# _traps

**Version:** 2.0.0

Enhanced signal trap management system with support for multiple handlers per signal.
Register a handler function for one or more signals. Validates that the handler
Unregister a previously registered handler function from one or more signals.
Display all registered handlers for specified signals. If no signals are
Remove all registered handlers from specified signals while preserving the
Restore the original trap configuration that existed before the traps module
Save the current handler state by creating a snapshot on the state stack.
Restore handler state from the most recent trap:push snapshot. Removes the
Semantic alias for trap:push. Marks the beginning of a scoped trap section
Semantic alias for trap:pop. Marks the end of a scoped trap section for
Central dispatcher function invoked by the OS trap mechanism when a signal fires.
Internal helper that normalizes signal names to a standard uppercase format
Internal helper that performs one-time initialization for a signal. Called
Internal helper that captures the existing trap command for a signal before
Internal helper that checks if a specific handler function name exists in a
Internal helper that removes a specific handler from a handler array. Creates
Internal helper that discovers all signals currently managed by the traps module.

## Functions


### `trap:on`

⚠️ _Documentation pending_


### `trap:off`

⚠️ _Documentation pending_


### `trap:list`

⚠️ _Documentation pending_


### `trap:clear`

⚠️ _Documentation pending_


### `trap:restore`

⚠️ _Documentation pending_


### `trap:push`

⚠️ _Documentation pending_


### `trap:pop`

⚠️ _Documentation pending_


### `trap:scope:begin`

⚠️ _Documentation pending_


### `trap:scope:end`

⚠️ _Documentation pending_


### `Trap::dispatch`

⚠️ _Documentation pending_


### `_Trap::normalize_signal`

⚠️ _Documentation pending_


### `_Trap::initialize_signal`

⚠️ _Documentation pending_


### `_Trap::capture_legacy`

⚠️ _Documentation pending_


### `_Trap::contains`

⚠️ _Documentation pending_


### `_Trap::remove_handler`

⚠️ _Documentation pending_


### `_Trap::list_all_signals`

⚠️ _Documentation pending_

