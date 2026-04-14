# Migration Guide: v2.0.0 → v2.1.0

This guide covers breaking changes, behavioral changes, and how to adopt new features when upgrading from e-bash v2.0.0 to v2.1.0.

## Breaking Changes

### 1. Defaults are now pre-filled for value flags

**What changed:** `parse:arguments` now exports default values for all value flags (`args_qt > 0`) BEFORE processing CLI arguments. Previously, defaults were only applied when the flag was present on the command line.

**Before (v2.0.0):**
```bash
ARGS_DEFINITION="--port=port:8080:1"
parse:arguments  # no --port flag
echo "$port"     # empty/unset
```

**After (v2.1.0):**
```bash
ARGS_DEFINITION="--port=port:8080:1"
parse:arguments  # no --port flag
echo "$port"     # "8080" — pre-filled from default
```

**Who is affected:** Scripts that check `[[ -z "${port:-}" ]]` to detect "flag not provided" will now see the default value instead of empty.

**How to migrate:**

Option A — If you need to detect "not provided", compare against the default:
```bash
# v2.0.0 pattern (no longer works for detecting absence)
[[ -z "${port:-}" ]] && echo "port not provided"

# v2.1.0 pattern
[[ "$port" == "8080" ]] && echo "port is default (may not have been provided)"
```

Option B — Use a sentinel default that indicates "not set":
```bash
ARGS_DEFINITION="--port=port:__UNSET__:1"
parse:arguments "$@"
[[ "$port" == "__UNSET__" ]] && echo "port not provided"
```

Option C — Check `ARGS_UNPARSED` or examine `$@` directly before parsing.

**Note:** Boolean flags (`args_qt == 0`) are NOT affected — they are still unset when not provided.

### 2. `parse:arguments` returns 1 instead of exit 1

**What changed:** When too few arguments are provided for a flag expecting values (e.g., `--range` expects 2 args but only 1 given), the parser now returns 1 instead of calling `exit 1`.

**Before (v2.0.0):**
```bash
parse:arguments --range 10  # --range expects 2 values
# Script exits immediately — no chance to handle the error
```

**After (v2.1.0):**
```bash
parse:arguments --range 10  # --range expects 2 values
# Returns 1 — script can handle the error
echo "Error was: $?"
```

**Who is affected:** Scripts relying on the parser to exit the process on argument errors. This is unlikely to cause issues since the previous behavior was undesirable.

**How to migrate:** If you want the old exit behavior, add an explicit check:
```bash
parse:arguments "$@" || exit 1
```

### 3. Error message format changed

**What changed:** The error message for missing arguments changed from `"Error. Too little arguments provided"` to `"Error: too few arguments provided (expected N more for 'FLAG')"`.

**Who is affected:** Scripts that parse or match the exact error string.

### 4. Debug log format changed

**What changed:** Parser debug output (visible with `DEBUG=parser`) uses new descriptive labels instead of cryptic markers.

| v2.0.0 | v2.1.0 |
|--------|--------|
| `[L1] export X='val'` | `assign(aggregated): X='val'` |
| `[L2] export X='val'` | `assign(default): X='val'` |
| `[L3] export X='val'` | `assign(inline): X='val'` |
| `[L4] export X='val'` | `assign(positional): X='val'` |
| `ignored: --flag (val)` | `skip: unknown flag '--flag'` |
| `ignored: arg [$1] vs ...` | `skip: unmatched positional 'arg'` |
| `definition to output index:` | `--- parsed results ---` |

**Who is affected:** Scripts or tests that match specific debug output strings.

## Behavioral Changes (non-breaking)

### `--` end-of-options sentinel

The `--` token now stops flag processing. Everything after `--` is treated as positional, even if it starts with `-`.

```bash
./script.sh --verbose -- --not-a-flag file.txt
# --verbose → flag, --not-a-flag → positional, file.txt → positional
```

**No migration needed.** This is additive — existing scripts without `--` are unaffected.

### `--completion` and `--install-completion` auto-appended

Two new flags are automatically appended to every `ARGS_DEFINITION`:
- `--completion=completion::1` — print shell completion script
- `--install-completion=install_completion::1` — install completion to OS directory

These are processed by `args:dispatch` (called automatically when `SKIP_ARGS_PARSING` is not set).

**No migration needed** unless your script already uses variables named `completion` or `install_completion` for other purposes. In that case, rename your variables.

### `ARGS_UNPARSED` global array

A new global array `ARGS_UNPARSED` is populated after each `parse:arguments` call, containing arguments not consumed by the parser (unknown flags + unmatched positionals).

**No migration needed.** The array exists but is harmless if not read.

## New Features to Adopt

### Shell Completion

Every script using `_arguments.sh` now supports `--completion` and `--install-completion` for free:

```bash
# Generate bash completion
./myscript.sh --completion bash > /etc/bash_completion.d/myscript

# Auto-install
./myscript.sh --install-completion zsh
```

### Scoped Parsing for Subcommands

Replace flat "all flags in one definition" with multi-phase parsing:

```bash
# v2.0.0: flat definition (hard to maintain)
ARGS_DEFINITION="--verbose --port=port::1 --replicas=replicas::1 \$1=command::1"
parse:arguments "$@"
# Must manually figure out which flags belong to which command

# v2.1.0: scoped parsing (clean separation)
ARGS_DEFINITION="--verbose \$1=command::1"
parse:arguments "$@"

DEPLOY_SCOPE="--replicas=replicas:1:1 --region=region:us-east-1:1"
SERVE_SCOPE="--port=port:8080:1 --host=host:0.0.0.0:1"

case "$command" in
  deploy) args:scope DEPLOY_SCOPE "${ARGS_UNPARSED[@]}" ;;
  serve)  args:scope SERVE_SCOPE  "${ARGS_UNPARSED[@]}" ;;
esac
```

### Type Validation

Add constraints to flag values:

```bash
args:t "--port" "int:1:65535"
args:t "--format" "enum:json,csv,text"
args:t "--email" "pattern:^[^@]+@[^@]+$"

parse:arguments "$@"
args:validate || exit 1
```

### Short Option Unbundling

Support `-abc` style bundled flags:

```bash
readarray -t expanded < <(args:unbundle "$@")
parse:arguments "${expanded[@]}"
```

### Flag/No-Flag Toggle Pattern

```bash
ARGS_DEFINITION="--dry-run=dry:true --no-dry-run=dry:false"
parse:arguments "$@"
# --dry-run → dry=true, --no-dry-run → dry=false, last wins
```

## Quick Migration Checklist

- [ ] Check if any script relies on value flags being unset when not provided → update to handle defaults
- [ ] Check if any script relies on `parse:arguments` calling `exit 1` → add `|| exit 1`
- [ ] Check if any script matches exact error messages or debug output → update patterns
- [ ] Check if variables named `completion` or `install_completion` conflict → rename
- [ ] Consider adopting `args:validate` for input validation
- [ ] Consider adopting scoped parsing for multi-command scripts
- [ ] Run existing tests to verify compatibility
