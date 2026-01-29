# Constants Naming Conventions

This document details naming patterns for constants and immutable values in the e-bash library.

---

## Overview

Constants in e-bash include:

1. **Exit codes** - Script return values
2. **Signal names** - POSIX signal identifiers
3. **Version numbers** - Semantic version strings
4. **Readonly configuration** - Immutable settings

---

## 1. Exit Codes

Exit codes follow shell conventions where `0` indicates success and non-zero indicates failure.

### Pattern: `EXIT_DESCRIPTION`

```bash
# Standard pattern
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NO_COMMITS=3
readonly EXIT_INTERRUPTED=130

# Usage
if [[ ! -f "$file" ]]; then
  echo "File not found" >&2
  exit $EXIT_ERROR
fi

return $EXIT_OK
```

### Rules

- **Prefix:** `EXIT_` for all exit codes
- **Case:** SCREAMING_SNAKE_CASE
- **Type:** Integer values
- **Readonly:** Declare with `readonly` keyword
- **Standard codes:**
  - `0` = Success
  - `1` = General error
  - `2` = Misuse of shell builtins (per Bash convention)
  - `126` = Command cannot execute
  - `127` = Command not found
  - `128+N` = Fatal signal (e.g., `130` = SIGINT/Ctrl+C)

### Common Exit Codes

| Constant            | Value | Meaning                  |
| ------------------- | ----- | ------------------------ |
| `EXIT_OK`           | 0     | Success                  |
| `EXIT_ERROR`        | 1     | General error            |
| `EXIT_INVALID_ARGS` | 2     | Invalid arguments        |
| `EXIT_NO_COMMITS`   | 3     | No commits found         |
| `EXIT_NOT_FOUND`    | 3     | Resource not found       |
| `EXIT_INTERRUPTED`  | 130   | SIGINT received (Ctrl+C) |

### Example (Recommended)

```bash
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NO_COMMITS=3
readonly EXIT_INTERRUPTED=130

# Usage
if [[ -z "$commits" ]]; then
  echo:Err "No commits found"
  exit $EXIT_NO_COMMITS
fi
```

### Known Code Deviations (to Fix)

- `bin/git.semantic-version.sh` currently defines `EXIT_NO_COMMITS=2` and `EXIT_INVALID_ARGS=3`, which should be swapped to match this document.

---

## 2. Signal Names

Signal names follow POSIX standards.

### Pattern: `UPPERCASE`

```bash
# Common signals used in e-bash
trap:on cleanup_function EXIT
trap:on handle_interrupt INT TERM
trap:on handle_error ERR

# Signal patterns
EXIT    # Script exit
INT     # Interrupt (Ctrl+C)
TERM    # Termination signal
HUP     # Hangup
QUIT    # Quit signal
KILL    # Kill signal (cannot be trapped)
ERR     # Error trap (Bash-specific)
```

### Rules

- **Case:** UPPERCASE (POSIX standard)
- **No prefix:** Signal names are global standards
- **Common signals:**
  - `EXIT` - Always executed on script exit
  - `INT` - Ctrl+C interrupt
  - `TERM` - Termination request
  - `ERR` - Command failure (with `set -e`)

### Examples

```bash
# Register handlers for multiple signals
trap:on cleanup EXIT INT TERM

# Signal-specific handlers
function on_interrupt() {
  local exit_code=$?
  echo "Interrupted" >&2
  exit $EXIT_INTERRUPTED
}

trap:on on_interrupt INT
```

---

## 3. Version Numbers

Version numbers follow Semantic Versioning 2.0.0.

### Pattern: `MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`

```bash
# Script/module versions
readonly SCRIPT_VERSION="1.0.0"
readonly MODULE_VERSION="2.0.0"

# With pre-release
readonly VERSION="1.0.0-alpha"
readonly VERSION="1.0.0-beta.1"
readonly VERSION="2.0.0-rc.1"

# With build metadata
readonly VERSION="1.0.0+20230615"
readonly VERSION="1.0.0-beta+exp.sha.5114f85"
```

### Rules

- **Format:** `MAJOR.MINOR.PATCH` (three numbers separated by dots)
- **Pre-release:** Optional `-suffix` (e.g., `-alpha`, `-beta.1`, `-rc.1`)
- **Build metadata:** Optional `+metadata` (e.g., `+20230615`)
- **Readonly:** Always declare with `readonly`
- **Variable names:** `VERSION`, `SCRIPT_VERSION`, `MODULE_VERSION`

### Examples from Codebase

```bash
# From bin/e-docs.sh
readonly VERSION="2.7.9"

# From bin/git.semantic-version.sh
readonly SCRIPT_VERSION="1.0.0"

# From module files (.scripts/_*.sh)
## Version: 2.0.0  # In comment header, not variable
```

### Version in Module Headers

```bash
#!/usr/bin/env bash

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: 2026-01-29
## Version: 2.0.0
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash
```

Version in Copyright header is dynamically updated during commits, that allows
to track the moment when change to a specific file was introduced. so User can just compare the version tag to understand how old the script it has in compare to our latest release.

---

## 4. Readonly Configuration

Immutable configuration values.

### Pattern: `SCREAMING_SNAKE_CASE`

```bash
# Paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly E_BASH="$(cd "$PROJECT_ROOT/.scripts" 2>&- && pwd)"

# Script metadata
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"

# Feature flags (immutable)
readonly ENABLE_COLORS=true
readonly MAX_RETRIES=3
readonly TIMEOUT_SECONDS=30

# Constants
readonly DEFAULT_BRANCH="master"
readonly MAIN_BRANCH="master"
readonly TEMP_DIR="/tmp/e-bash"
```

### Rules

- **Case:** SCREAMING_SNAKE_CASE
- **Readonly:** Always use `readonly` keyword
- **Initialization:** Initialize at declaration time
- **Naming:** Descriptive, self-documenting names

### Examples from Codebase

```bash
# From bin/git.semantic-version.sh
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"
readonly ANNOTATION_MAX_LEN=80
readonly TMUX_PROGRESS_HEIGHT=2

# From bin/e-docs.sh
readonly TEMP_DIR=$(mktemp -d -t e-docs.XXXXXX)
readonly E_BASH="$(cd "$PROJECT_ROOT/.scripts" && pwd)"
```

---

## 5. Magic Numbers and Limits

Numeric constants with special meaning.

### Pattern: `DESCRIPTION_LIMIT` or `MAX_DESCRIPTION`

```bash
# Limits
readonly MAX_RETRIES=3
readonly MIN_VERSION=5
readonly CACHE_TTL=86400           # 1 day in seconds
readonly TIMEOUT_MS=2000           # 2 seconds in milliseconds

# Buffer sizes
readonly BUFFER_SIZE=1024
readonly MAX_LINE_LENGTH=2000
readonly ANNOTATION_MAX_LEN=80

# Array indices (when meaningful)
readonly TMUX_MAIN_PANE=0
readonly TMUX_PROGRESS_PANE=1
```

### Rules

- **Case:** SCREAMING_SNAKE_CASE
- **Readonly:** Use `readonly` for true constants
- **Naming:** Include units in name when relevant (`_MS`, `_SECONDS`, `_BYTES`)
- **Comments:** Document meaning and units

### Examples

```bash
# From bin/git.semantic-version.sh
readonly ANNOTATION_MAX_LEN=80
readonly TMUX_MAIN_PANE=0
readonly TMUX_PROGRESS_PANE=1

# From .scripts/_dependencies.sh
declare -g __DEPS_CACHE_TTL=${__DEPS_CACHE_TTL:-86400}  # 1 day
```

---

## 6. Regex Patterns and Strings

Regular expression patterns used across the library.

### Pattern: `PATTERN_NAME` or `FEATURE_REGEX`

```bash
# Semver patterns (exported for external use)
export SEMVER="$(semver:grep)"
export SEMVER_LINE="^${SEMVER}\$"
export SEMVER_LINE_WITH_PREFIX="^v?${SEMVER}\$"

# Internal patterns
local VERSION_REGEX="[0-9]+\.[0-9]+\.[0-9]+"
local TAG_PATTERN="^v?[0-9]"
```

### Rules

- **Case:** SCREAMING_SNAKE_CASE for exported patterns
- **Exported:** Use `export` for patterns used by external scripts
- **Local:** Use `local` for function-scoped patterns
- **Naming:** Suffix with `_REGEX`, `_PATTERN`, or descriptive name

### Examples from Codebase

```bash
# From .scripts/_semver.sh
export SEMVER="$(semver:grep)"
export SEMVER_LINE="^${SEMVER}\$"
export SEMVER_LINE_WITH_PREFIX="^v?${SEMVER}\$"
```

---

## Best Practices

### ✅ DO

```bash
# Use readonly for constants
readonly EXIT_OK=0                  # ✓ Immutable
readonly SCRIPT_VERSION="1.0.0"     # ✓ Won't change

# Use descriptive names
readonly MAX_RETRY_COUNT=3          # ✓ Clear meaning
readonly CACHE_TTL_SECONDS=86400    # ✓ Includes unit

# Initialize with command substitution
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Document magic numbers
readonly TIMEOUT=30  # seconds     # ✓ Documented
```

### ❌ DON'T

```bash
# Don't omit readonly
EXIT_OK=0                           # ✗ Can be modified
SCRIPT_VERSION="1.0.0"              # ✗ Not protected

# Don't use cryptic names
readonly MAX=3                      # ✗ Max what?
readonly TTL=86400                  # ✗ What unit?

# Don't use lowercase for constants
readonly exit_ok=0                  # ✗ Looks like variable
readonly script_version="1.0.0"     # ✗ Should be uppercase
```

---

## Constant Declaration Patterns

### Exit Codes Block

```bash
# Group related exit codes together
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_NOT_FOUND=3
readonly EXIT_INTERRUPTED=130
```

### Metadata Block

```bash
# Script metadata at top of file
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

### Configuration Block

```bash
# Configuration constants
readonly DEFAULT_TIMEOUT=30
readonly MAX_RETRIES=3
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/e-bash"
readonly LOG_LEVEL="${LOG_LEVEL:-INFO}"
```

---

## Quick Reference

| Type          | Pattern             | Example               |
| ------------- | ------------------- | --------------------- |
| Exit code     | `EXIT_DESCRIPTION`  | `EXIT_OK=0`           |
| Signal        | `UPPERCASE`         | `EXIT`, `INT`, `TERM` |
| Version       | `MAJOR.MINOR.PATCH` | `1.0.0`, `2.0.0-beta` |
| Path constant | `DESCRIPTION_PATH`  | `SCRIPT_DIR`          |
| Limit         | `MAX_DESCRIPTION`   | `MAX_RETRIES=3`       |
| Timeout       | `TIMEOUT_UNIT`      | `TIMEOUT_SECONDS=30`  |
| Pattern       | `PATTERN_NAME`      | `SEMVER_LINE`         |

---

## See Also

- [Variable Naming](naming-variables.md) - Variable naming patterns
- [Main Conventions](NAMING_CONVENTIONS.md) - Overview
