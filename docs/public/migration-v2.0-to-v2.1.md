# Upgrade Guide: v2.0.0 → v2.1.0

No breaking changes. All existing scripts continue to work without modification.

This guide covers what's new, what was refactored, and what you can optionally adopt.

---

## Module Refactoring

### TUI functions extracted to `_tui.sh`

Terminal UI functions (cursor positioning, input handling, validation, multi-line editor) were extracted from `_commons.sh` into a dedicated `_tui.sh` module (62 functions).

**No action required.** `_commons.sh` automatically sources `_tui.sh` for full backward compatibility. All existing `source "$E_BASH/_commons.sh"` calls continue to work.

**Optional:** If your script only needs TUI functions, you can source `_tui.sh` directly for a lighter dependency:

```bash
# Before: pulls in everything
source "$E_BASH/_commons.sh"

# After: only TUI functions (cursor, input, validation, multi-line editor)
source "$E_BASH/_tui.sh"
```

Functions moved to `_tui.sh`:
- `cursor:position`, `cursor:position:row`, `cursor:position:col`
- `input:readpwd`, `input:selector`, `input:multi-line`
- `validate:input`, `validate:input:masked`, `validate:input:yn`
- `confirm:by:input`, `print:confirmation`
- `_input:read-key`, `_input:capture-key`

### Parser logging improved

Debug output for `_arguments.sh` (visible with `DEBUG=parser`) now uses descriptive labels:

| v2.0.0 | v2.1.0 |
|--------|--------|
| `[L1] export X='val'` | `assign(aggregated): X='val'` |
| `[L2] export X='val'` | `assign(default): X='val'` |
| `[L3] export X='val'` | `assign(inline): X='val'` |
| `[L4] export X='val'` | `assign(positional): X='val'` |
| `ignored: --flag` | `skip: unknown flag '--flag'` |

All parser logs now use `echo:Parser` exclusively (previously some used `echo:Common`). This makes it easier to filter parser-specific output via `DEBUG=parser`.

---

## Behavioral Improvements

### Defaults pre-fill for value flags

Value flags (`args_qt > 0`) with defaults are now pre-filled before CLI processing. CLI values override defaults. Boolean flags are not affected.

```bash
ARGS_DEFINITION="--port=port:8080:1 --verbose"

parse:arguments  # no flags provided
echo "$port"     # "8080" — pre-filled (new in v2.1.0, was empty in v2.0.0)
echo "$verbose"  # unset — booleans unchanged
```

This is the standard CLI pattern (Python argparse, Go flag, etc.). If you need to distinguish "user provided" vs "default", use a sentinel:

```bash
ARGS_DEFINITION="--port=port:__DEFAULT__:1"
parse:arguments "$@"
[[ "$port" == "__DEFAULT__" ]] && port=8080  # apply real default, know it wasn't user-provided
```

### Safer error handling

`parse:arguments` now returns 1 (instead of calling `exit 1`) when too few arguments are provided. Error messages go to stderr with the flag name included:

```
Error: too few arguments provided (expected 1 more for '--port')
```

Add `|| exit 1` if you want the old exit-on-error behavior:

```bash
parse:arguments "$@" || exit 1
```

### Safer value assignment

`eval "export X='$val'"` replaced with `export "${X}=${val}"` throughout the parser. Values containing single quotes, double quotes, backticks, or `$()` are now handled safely.

---

## New Features

### Shell Completion

Every script using `_arguments.sh` now supports `--completion` and `--install-completion` automatically:

```bash
./myscript.sh --completion bash    # print Bash completion script
./myscript.sh --completion zsh     # print Zsh completion script
./myscript.sh --install-completion bash   # install to OS directory
```

See [docs/public/completion.md](completion.md) for details.

### End-of-Options `--`

The `--` token stops flag processing. Everything after is positional:

```bash
./script.sh --verbose -- --not-a-flag file.txt
# --verbose → flag, --not-a-flag → positional argument
```

### Short Option Unbundling

New `args:unbundle` helper decomposes `-abc` into `-a -b -c`:

```bash
readarray -t expanded < <(args:unbundle "$@")
parse:arguments "${expanded[@]}"
```

### Scoped Parsing

New `ARGS_UNPARSED`, `args:reset`, and `args:scope` enable subcommand-style CLIs:

```bash
ARGS_DEFINITION="--verbose \$1=command::1"
parse:arguments "$@"

DEPLOY_SCOPE="--replicas=replicas:1:1 --region=region:us-east-1:1"
args:scope DEPLOY_SCOPE "${ARGS_UNPARSED[@]}"
```

See [docs/public/arguments.md](arguments.md#scoped-parsing) and [docs/public/cli-strategy.md](cli-strategy.md) for the full pattern.

### Type Validation

New `args:t` and `args:validate` for declaring and checking value constraints:

```bash
args:t "--port" "int:1:65535"
args:t "--format" "enum:json,csv,text"
args:t "--email" "pattern:^[^@]+@[^@]+$"

parse:arguments "$@"
args:validate || exit 1
```

See [docs/public/arguments.md](arguments.md#type-validation) for all supported types.

---

## Summary

| Area | Impact | Action |
|------|--------|--------|
| `_tui.sh` extraction | None | Backward compatible via `_commons.sh` |
| Debug log labels | None | Only visible with `DEBUG=parser` |
| Defaults pre-fill | Low | Value flags now have defaults even without CLI input |
| Error returns | Low | `return 1` instead of `exit 1` (safer) |
| `eval` → `export` | None | Security improvement, transparent |
| `--completion` flags | None | Auto-appended, no conflict unless you use `completion` variable |
| `ARGS_UNPARSED` | None | New global, harmless if not read |

**Bottom line:** Update your e-bash, run your tests. Everything should pass. Then optionally adopt scoped parsing, validation, and completion.
