# Variable Naming Conventions

This document details variable naming patterns used in the e-bash library.

---

## Philosophy

**Key Principles:**
1. **Brevity**: Short names for one-line expressions (120 char limit)
2. **Common words**: Use familiar terms, avoid rare words
3. **Purpose-driven**: Name reveals what, not how

---

## Overview

Variables in e-bash are categorized by **scope** and **purpose**:

1. **Library configuration variables** - Control library-wide behavior (`E_BASH*`)
2. **Module configuration variables** - User-facing module settings
3. **Module internal variables** - Module-private state (`__{UPPER_CASE_NAME}`)
4. **Local variables** - Function-scoped variables
5. **Function parameters** - Arguments captured from `$@`
6. **Loop counters** - Iteration variables

**Naming Guidelines:**
- ✅ Short: `DEBUG`, `HOOKS_DIR`, `version`, `tag`
- ❌ Verbose: `DEBUGGING_ENABLED`, `HOOKS_DIRECTORY_PATH`, `version_string`, `tag_name_identifier`

---

## 1. Library Configuration Variables

These variables configure the **entire e-bash library** and affect multiple modules.

### Pattern: `E_BASH_FEATURE`

```bash
# Core library path
E_BASH="/path/to/.scripts"

# Feature flags
E_BASH_SKIP_CACHE=1                    # Skip dependency cache
CI_E_BASH_INSTALL_DEPENDENCIES=1       # Auto-install in CI
```

### Rules

- **Prefix:** `E_BASH` or `E_BASH_` for all library-level settings
- **Case:** SCREAMING_SNAKE_CASE
- **Scope:** Global, exported, affects entire library
- **Reserved:** Do NOT use `E_BASH_` prefix for non-library variables
- **Read-only when possible:** Use `readonly E_BASH=...` if value should not change

### Examples from Codebase

| Variable | Purpose | Set By | Used By |
|----------|---------|--------|---------|
| `E_BASH` | Path to `.scripts/` directory | Bootstrap code | All modules |
| `E_BASH_SKIP_CACHE` | Bypass dependency cache | User/CI | `_dependencies.sh` |
| `CI_E_BASH_INSTALL_DEPENDENCIES` | Enable auto-install in CI | CI environment | `_dependencies.sh` |

### When to Use

✅ **DO** use `E_BASH_*` for:
- Library-wide feature flags
- Cross-module configuration
- Core paths and directories

❌ **DON'T** use `E_BASH_*` for:
- Module-specific settings (use `MODULE_CONFIG` instead)
- Temporary/local state
- User application variables

---

## 1b. Well-Known Global Variables

The library may use **well-known names** for common configuration patterns.

### Pattern: Standard names (no `E_BASH_` prefix)

```bash
# Debug/tracing control
DEBUG="hooks,error"                # Logger tag control
TRACE=1                            # Trace mode (if used)

# Dry-run control
DRY_RUN=1                          # Dry-run mode
DRY_RUN_MODE="preview"             # Dry-run mode variant
UNDO=1                             # Undo mode

# Skipping control
SKIP_ARGS_PARSING=1                # Skip automatic argument parsing
SKIP_DEALIAS=1                     # Skip tool name aliasing
```

### Rules

- **Well-documented:** Each must be clearly documented in the module
- **Standard names:** Use conventional names (DEBUG, TRACE, DRY_RUN, SKIP_*)
- **Case:** SCREAMING_SNAKE_CASE
- **Scope:** Global, affects specific module behavior
- **Prefixes:** Common prefixes include `DRY_RUN*`, `SKIP_*`, `UNDO*`

### Examples from Codebase

| Variable | Module | Purpose |
|----------|--------|---------|
| `DEBUG` | logger | Control which logger tags are enabled |
| `SKIP_ARGS_PARSING` | arguments | Skip automatic parsing on module load |
| `SKIP_DEALIAS` | dependencies | Bypass tool name alias resolution |
| `DRY_RUN` | dryrun | Enable dry-run mode globally |

### Documentation Requirement

⚠️ **IMPORTANT:** All well-known global variables **MUST** be documented:
- In the module's header comments
- In the module's public documentation (e.g., `docs/public/{module}.md`)
- In this naming conventions document

```bash
# Example documentation in module file
## Globals:
## - DEBUG - Comma-separated list of logger tags to enable (supports wildcards)
## - SKIP_ARGS_PARSING - Set to 1 to skip automatic argument parsing on load
```

---

## 2. Module Configuration Variables

These variables configure **specific modules** and are user-facing.

### Pattern: `MODULE_CONFIG`

```bash
# Logger configuration
DEBUG="hooks,error"                    # Which tags to enable

# Hooks module configuration
HOOKS_DIR="ci-cd"                      # Hooks directory
HOOKS_PREFIX="hook:"                   # Hook function prefix
HOOKS_EXEC_MODE="exec"                 # exec or source
HOOKS_AUTO_TRAP="true"                 # Auto-install EXIT trap

# Trap module configuration
# (none currently - trap module uses runtime registration)

```

### Rules

- **Prefix:** Module name or functionality area
- **Case:** SCREAMING_SNAKE_CASE
- **Scope:** Global, exported or declared globally
- **User-facing:** These are documented and stable
- **Defaults:** Always provide sensible defaults

### Examples from Codebase

| Variable | Module | Purpose | Default |
|----------|--------|---------|---------|
| `DEBUG` | logger | Comma-separated tags to enable | `""` |
| `HOOKS_DIR` | hooks | Directory for hook scripts | `"ci-cd"` |
| `HOOKS_PREFIX` | hooks | Hook function name prefix | `"hook:"` |
| `HOOKS_EXEC_MODE` | hooks | Execution mode (exec/source) | `"exec"` |
| `HOOKS_AUTO_TRAP` | hooks | Auto-install EXIT trap | `"true"` |
| `SKIP_ARGS_PARSING` | arguments | Skip automatic parsing on load | `""` |
| `ARGS_DEFINITION` | arguments | Argument definition string | `""` |
| `SEMVER_CONSTRAINTS_IMPL` | semver | Constraint implementation (v1/v2) | `"v2"` |

### Initialization Pattern

```bash
# In module file (.scripts/_module.sh)
# Declare with default, allow user override
if [[ -z ${HOOKS_DIR+x} ]]; then
  declare -g HOOKS_DIR="ci-cd"
fi

# Alternative: Use parameter expansion with default
HOOKS_EXEC_MODE="${HOOKS_EXEC_MODE:-exec}"
```

---

## 3. Module Internal Variables

These variables store **module-private state** and are not intended for external use.

### Pattern: `__{UPPER_CASE_NAME}`

```bash
# Logger module internals
declare -A -g __LOGGER_TAGS              # Not used (TAGS is actual name)
declare -g __SESSION="session-$$-$RANDOM"
declare -g __TTY="/dev/pts/0"

# Hooks module internals
declare -A -g __HOOKS_DEFINED            # Registered hook names
declare -A -g __HOOKS_CONTEXTS           # Hook contexts
declare -A -g __HOOKS_REGISTERED         # Registered functions
declare -A -g __HOOKS_MIDDLEWARE         # Middleware functions
declare -a -g __HOOKS_SOURCE_PATTERNS    # Source-mode patterns
declare -a -g __HOOKS_SCRIPT_PATTERNS    # Exec-mode patterns
declare -g __HOOKS_CAPTURE_SEQ=0         # Capture sequence counter
declare -g __HOOKS_END_TRAP_INSTALLED="false"

# Trap module internals
__TRAP_PREFIX="__TRAP_HANDLERS_SIG_"     # Prefix for handler arrays
__TRAP_LEGACY_PREFIX="__TRAP_LEGACY_SIG_"
__TRAP_INIT_PREFIX="__TRAP_INITIALIZED_SIG_"
__TRAP_STACK_PREFIX="__TRAP_STACK_"
__TRAP_STACK_LEVEL=0
__TRAPS_MODULE_INITIALIZED="yes"

# Dependency cache internals
declare -g __DEPS_CACHE_TTL=86400         # Cache TTL (internal default)
declare -g __DEPS_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/e-bash"
declare -gA __DEPS_CACHE                  # In-memory cache
declare -g __DEPS_CACHE_LOADED=false
declare -g __DEPS_CACHE_PATH_HASH=""
declare -gA __DEPS_VERSION_FLAGS_EXCEPTIONS

# Semver internals
declare -A -g __SEMVER_PARSE_RESULT      # Parse results
declare -A -g __SEMVER_COMPARE_V1        # Comparison temp
declare -A -g __SEMVER_COMPARE_V2        # Comparison temp
```

### Rules

- **Prefix:** Double underscore `__`
- **Case:** SCREAMING_SNAKE_CASE (after prefix)
- **Scope:** Global, module-private (not documented for external use)
- **Not stable:** May change between versions
- **Declaration:** Use `declare -g` for globals, `declare -gA` for associative arrays

### Examples from Codebase

| Variable | Module | Type | Purpose |
|----------|--------|------|---------|
| `__HOOKS_DEFINED` | hooks | Associative array | Registered hook names |
| `__HOOKS_REGISTERED` | hooks | Associative array | Registered functions per hook |
| `__HOOKS_MIDDLEWARE` | hooks | Associative array | Middleware per hook |
| `__HOOKS_CAPTURE_SEQ` | hooks | Integer | Sequence counter for capture arrays |
| `__TRAP_PREFIX` | traps | String | Prefix for trap handler arrays |
| `__TRAP_STACK_LEVEL` | traps | Integer | Current stack depth |
| `__DEPS_CACHE` | dependencies | Associative array | In-memory dependency cache |
| `__DEPS_CACHE_LOADED` | dependencies | Boolean | Cache load state |
| `__SEMVER_PARSE_RESULT` | semver | Associative array | Parse results storage |
| `__SESSION` | logger | String | Unique session identifier |

### Declaration Patterns

```bash
# Simple scalar
declare -g __MODULE_COUNTER=0

# Associative array (use -A flag)
declare -A -g __MODULE_MAP
declare -gA __MODULE_CACHE           # Alternative syntax

# Indexed array (use -a flag)
declare -a -g __MODULE_LIST
declare -ga __MODULE_ITEMS           # Alternative syntax

# String with default
declare -g __MODULE_STATE="${__MODULE_STATE:-idle}"
```

---

## 4. Local Variables

These variables are **function-scoped** and temporary.

### Pattern: `snake_case`

```bash
function example:function() {
  local version="$1"
  local tag_name="$2"
  local exit_code=0
  local file_path="/tmp/example"
  local is_enabled=false

  # Multi-word names
  local parsed_result=""
  local error_message=""
  local cache_key=""
}
```

### Rules

- **Case:** snake_case (all lowercase with underscores)
- **Scope:** Declare with `local` keyword
- **Multiple per line:** Allowed (max 5 recommended)
  ```bash
  local major minor patch
  local name value default
  ```
- **Initialization:** Can initialize on declaration
  ```bash
  local version="1.0.0"
  local count=0
  local enabled=true
  ```

### Examples from Codebase

Common local variable names seen throughout e-bash:

| Variable | Usage | Typical Type |
|----------|-------|--------------|
| `version` | Version string | String |
| `tag` / `tag_name` | Logger tag or git tag | String |
| `signal` | Signal name (EXIT, INT, etc.) | String |
| `hook_name` | Name of hook being processed | String |
| `exit_code` | Exit status code | Integer |
| `file_path` | Path to file | String |
| `handler` | Function name for handlers | String |
| `result` | Computation result | Varies |
| `output` | Command output | String |
| `temp` | Temporary value | Varies |

### Best Practices

```bash
# ✅ DO: Declare at function start
function good:example() {
  local input="$1"
  local output=""
  local count=0

  # ... function body
}

# ✅ DO: Multiple related locals on one line
local major minor patch
local name value default

# ❌ DON'T: Use SCREAMING_CASE for locals
function bad:example() {
  local VERSION="$1"              # Wrong - looks like constant
  local version="$1"              # Correct
}

# ❌ DON'T: Mix global patterns with locals
function bad:example() {
  local __internal_var="temp"     # Wrong - __ is for module globals
  local _temp_var="temp"          # Wrong - single _ not needed
  local temp_var="temp"           # Correct
}
```

---

## 5. Function Parameters

Parameters are captured from `$@` into local variables.

### Pattern: `snake_case` (same as locals)

```bash
function example:function() {
  # Positional parameters
  local param_name="$1"
  local second_param="$2"
  local optional_param="${3:-default}"

  # Variadic parameters
  shift 2  # Remove first two args
  local remaining_args=("$@")

  # Named parameters via filtering
  local filtered_args=()
  for arg in "$@"; do
    case "$arg" in
      --exec|--optional|--silent) continue ;;
      *) filtered_args+=("$arg") ;;
    esac
  done
}
```

### Rules

- **Case:** snake_case
- **Capture early:** Capture `$1`, `$2`, etc. at function start
- **Use defaults:** `${1:-default_value}` for optional params
- **Document:** Clearly document parameter expectations in function header

### Examples from Codebase

```bash
# From logger:compose
function logger:compose() {
  local tag=${1}
  local suffix=${2}
  local flags=${3:-""}
  # ...
}

# From semver:compare
function semver:compare() {
  local version1="$1"
  local version2="$2"
  local iParts=0 # make $iParts local to avoid conflicts
  local LC_ALL=C
  # ...
}

# From hooks:register
function hooks:register() {
  local hook_name="$1"
  local friendly_name="$2"
  local function_name="$3"
  # ...
}

# From trap:on with flag parsing
function trap:on() {
  local allow_duplicates=false

  # Parse flags
  while [[ "$1" == --* ]]; do
    case "$1" in
      --allow-duplicates) allow_duplicates=true; shift ;;
      *) echo:Trap "Unknown flag: $1"; return 1 ;;
    esac
  done

  local handler="${1?Handler function required}"
  shift
  local signals=("$@")
  # ...
}
```

---

## 6. Loop Counters and Iteration Variables

Variables used in loops should be localized to avoid conflicts.

### Pattern: Descriptive `snake_case` or single letter

```bash
# ✅ GOOD: Descriptive loop variable
for tag in "${!TAGS[@]}"; do
  echo "Tag: $tag"
done

for file_path in "${files[@]}"; do
  process "$file_path"
done

# ✅ GOOD: Single-letter for simple loops (with local declaration)
local i=0
for ((i = 0; i < max; i++)); do
  echo "Index: $i"
done

# ✅ BEST: Explicitly local to avoid conflicts
function example:loop() {
  local i=0  # make $i local to avoid conflicts

  for ((i = 0; i < 10; i++)); do
    echo "$i"
  done
}
```

### Common Pattern from Codebase

```bash
# Seen frequently in e-bash code
local i=0 # make $i local to avoid conflicts
local iSeq=0 # make $iSeq local to avoid conflicts
local iParts=0 # make $iParts local to avoid conflicts
```

This pattern explicitly documents the localization to prevent variable leakage between functions.

---

## 7. Special Variables

### Session/State Variables

```bash
# Logger session ID (module-internal)
__SESSION=$(uuidgen 2>/dev/null || echo "session-$$-$RANDOM")

# TTY detection
__TTY=$(tty 2>/dev/null || echo "notty")
```

### Temporary/Scratch Variables

```bash
# Use descriptive names even for temporaries
local temp_file
temp_file="$(mktemp)" || return 1

local temp_dir
temp_dir="$(mktemp -d)" || return 1

# Clean up in traps
trap "rm -rf '$temp_dir'" EXIT
```

---

## Variable Declaration Cheatsheet

| Type | Pattern | Declaration | Example |
|------|---------|-------------|---------|
| **Library Config** | `E_BASH_*` | `readonly E_BASH=...` | `E_BASH="/path"` |
| **Module Config** | `MODULE_VAR` | `declare -g VAR="${VAR:-default}"` | `HOOKS_DIR="ci-cd"` |
| **Module Internal** | `__MODULE_VAR` | `declare -g __VAR=value` | `__HOOKS_DEFINED` |
| **Local Variable** | `var_name` | `local var_name="value"` | `local version="1.0"` |
| **Local Array** | `array_name` | `local -a array_name=()` | `local files=()` |
| **Local Assoc** | `map_name` | `local -A map_name=()` | `local config=()` |
| **Nameref** | `ref_name` | `local -n ref="target"` | `local -n out="$var"` |

---

## Best Practices

### ✅ DO

```bash
# Use appropriate prefixes
E_BASH="/path/to/.scripts"              # Library config
HOOKS_DIR="ci-cd"                       # Module config
declare -g __HOOKS_DEFINED=()           # Module internal
local version="$1"                      # Local variable

# Declare locals at function start
function good:example() {
  local input="$1"
  local output=""
  local count=0
  # ... rest of function
}

# Use descriptive names
local file_path="/tmp/example"          # Clear intent
local is_enabled=false                  # Boolean naming
local error_message=""                  # Descriptive

# Localize loop counters
local i=0  # make $i local to avoid conflicts
for ((i = 0; i < max; i++)); do
  echo "$i"
done
```

### ❌ DON'T

```bash
# Don't use E_BASH_ for non-library vars
E_BASH_MY_APP_VAR="value"               # Wrong - reserved prefix

# Don't use __ for non-module-internal
local __temp="value"                    # Wrong - not module state

# Don't use SCREAMING_CASE for locals
function bad:example() {
  local VERSION="$1"                    # Wrong
  local MY_VARIABLE="test"              # Wrong
}

# Don't pollute global namespace
MY_GLOBAL_VAR="value"                   # Wrong - use prefix or __
```

---

## Quick Decision Tree

```
What type of variable is this?

├─ Affects entire e-bash library?
│  └─ Use: E_BASH_FEATURE_NAME (library config)
│
├─ User-facing module configuration?
│  └─ Use: MODULE_CONFIG_NAME (module config)
│
├─ Module-internal state?
│  └─ Use: __MODULE_STATE_NAME (module internal)
│
└─ Function-local or parameter?
   └─ Use: snake_case_name (local)
```

---

## Known Code Deviations (to Fix)

- `.scripts/_semver.sh` and `demos/demo.semver.sh` use lowercase `__semver_*` internals; rename to `__SEMVER_*` to comply.

---

## See Also

- [Function Naming](naming-functions.md) - Naming patterns for functions
- [Array Naming](naming-arrays.md) - Specific patterns for arrays
- [Main Conventions](NAMING_CONVENTIONS.md) - Overview and quick reference
