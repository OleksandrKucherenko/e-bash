# _dryrun.sh

**Dry-Run and Rollback Command Wrappers**

This module provides a three-mode execution system: Normal, Dry-run, and Undo/Rollback.

## References

- demo: demo.dryrun.sh, demo.dryrun-modes.sh, demo.dryrun-v2.sh
- bin: git.sync-by-patches.sh, npm.versions.sh
- documentation: docs/public/dryrun-wrapper.md
- tests: spec/dryrun_spec.sh

## Index

* [`_dryrun:exec`](#_dryrun-exec)
* [`dry-run`](#dry-run)
* [`dryrun`](#dryrun)
* [`rollback:func`](#rollback-func)
* [`undo:func`](#undo-func)

---

## Functions

---

### dry-run

Backward compatibility alias for dryrun

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | string | required | Same as dryrun |

#### Globals

- reads/listen: none
- mutate/publish: none (forwards to dryrun)

---

### dryrun

Generate run:{cmd}, dry:{cmd}, rollback:{cmd}, undo:{cmd} wrapper functions

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `commands` | string array | variadic | Command names to wrap |

#### Globals

- reads/listen: DRY_RUN, UNDO_RUN, SILENT
- mutate/publish: Creates run:{cmd}, dry:{cmd}, rollback:{cmd}, undo:{cmd} functions

#### Side Effects

- Defines wrapper functions for each command
- Wrapper functions respect DRY_RUN_{SUFFIX}, UNDO_RUN_{SUFFIX}, SILENT_{SUFFIX}

#### Usage

```bash
dryrun git docker               # create run:git, dry:git, etc.
dryrun npm BOWER                # use custom suffix BOWER instead of NPM
DRY_RUN=true dry:git status     # show what would run
UNDO_RUN=true undo:rm -rf /tmp # rollback mode
```

---

### rollback:func

Backward compatibility alias for undo:func

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `@` | string | required | Same as undo:func |

#### Globals

- reads/listen: none
- mutate/publish: none (forwards to undo:func)

---

### undo:func

Complex undo handler for function calls (shows function body in dry-run mode)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `func_name` | string | required | Function name to execute |
| `@` | variadic | required | Arguments for the function |

#### Globals

- reads/listen: UNDO_RUN, DRY_RUN, SILENT
- mutate/publish: none

#### Side Effects

- In dry-run mode: displays function body
- In undo mode: executes function

#### Usage

```bash
undo:func my_function arg1 arg2
```

