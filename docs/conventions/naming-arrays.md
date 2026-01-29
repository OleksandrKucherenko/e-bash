# Array Naming Conventions

This document details naming patterns for arrays (both indexed and associative) in the e-bash library.

---

## Overview

Bash supports two types of arrays:

1. **Indexed arrays** - Integer-indexed lists (like traditional arrays)
2. **Associative arrays** - Key-value maps (like dictionaries/hash maps)

---

## 1. Global Associative Arrays

Used for module-internal state storage.

### Pattern: `__{UPPER_CASE_NAME}`

```bash
# Declaration
declare -A -g __HOOKS_DEFINED
declare -gA __HOOKS_CONTEXTS          # Alternative syntax
declare -A -g __HOOKS_REGISTERED
declare -A -g __HOOKS_MIDDLEWARE

# Usage
__HOOKS_DEFINED[$hook_name]=1
__HOOKS_REGISTERED[$hook_name]="friendly1:func1|friendly2:func2"
```

### Rules

- **Prefix:** Double underscore `__`
- **Case:** SCREAMING_SNAKE_CASE (after prefix)
- **Declaration:** Use `declare -A -g` or `declare -gA`
- **Scope:** Module-global (not exported)
- **Naming:** Plural form often used for collections

### Examples from Codebase

| Array | Module | Purpose | Type |
|-------|--------|---------|------|
| `__HOOKS_DEFINED` | hooks | Registered hook names | Map: hook_name → 1 |
| `__HOOKS_CONTEXTS` | hooks | Hook contexts | Map: hook_name → contexts |
| `__HOOKS_REGISTERED` | hooks | Registered functions | Map: hook_name → functions |
| `__HOOKS_MIDDLEWARE` | hooks | Middleware functions | Map: hook_name → function |
| `__DEPS_CACHE` | dependencies | Dependency cache | Map: key → value |
| `__DEPS_VERSION_FLAGS_EXCEPTIONS` | dependencies | Version flag exceptions | Map: tool → flag |
| `__semver_parse_result` | semver | Parse results | Map: component → value |
| `__semver_compare_v1` | semver | Comparison temp | Map: component → value |
| `__semver_compare_v2` | semver | Comparison temp | Map: component → value |

### Declaration Patterns

```bash
# Method 1: declare -A -g
declare -A -g __MODULE_MAP

# Method 2: declare -gA (shorthand)
declare -gA __MODULE_CACHE

# Method 3: With default initialization
if [[ -z ${__MODULE_MAP+x} ]]; then
  declare -A -g __MODULE_MAP
fi

# Initialize with values
declare -A -g __DEPS_VERSION_FLAGS_EXCEPTIONS
__DEPS_VERSION_FLAGS_EXCEPTIONS[java]="-version"
__DEPS_VERSION_FLAGS_EXCEPTIONS[go]="version"
```

---

## 2. User-Facing Associative Arrays

Configuration or state exposed to users.

### Pattern: `ARRAY_NAME`

```bash
# Logger tags state
declare -A -g TAGS                # Tag enable state
declare -A -g TAGS_PREFIX         # Tag prefixes
declare -A -g TAGS_PIPE           # Tag named pipes
declare -A -g TAGS_REDIRECT       # Tag redirects

# Usage
TAGS[common]=1
TAGS_PREFIX[common]="[common] "
TAGS_REDIRECT[common]=">&2"
```

### Rules

- **No prefix:** User-facing arrays don't use `__`
- **Case:** SCREAMING_SNAKE_CASE
- **Declaration:** Use `declare -A -g`
- **Scope:** Global, documented for external use
- **Naming:** Descriptive, domain-specific

### Examples from Codebase

| Array | Module | Purpose |
|-------|--------|---------|
| `TAGS` | logger | Tag enable/disable state |
| `TAGS_PREFIX` | logger | Tag output prefixes |
| `TAGS_PIPE` | logger | Tag named pipe paths |
| `TAGS_REDIRECT` | logger | Tag output redirections |
| `CONVENTIONAL_KEYWORDS` | git.semantic-version.sh | Conventional commit mappings |
| `TAG_MAP` | git.semantic-version.sh | Commit → tags mapping |
| `BRANCH_TAG_INFO` | git.semantic-version.sh | Branch tag information |

---

## 3. Global Indexed Arrays

Simple lists stored globally.

### Pattern: `__{UPPER_CASE_NAME}` (internal) or `ARRAY_NAME` (public)

```bash
# Internal arrays (module-private)
declare -a -g __HOOKS_SOURCE_PATTERNS
declare -ga __HOOKS_SCRIPT_PATTERNS      # Alternative syntax

# Public arrays (user-facing)
declare -a -g FILTERED_ARGS
declare -ga REMAINING_ARGS
```

### Rules

- **Prefix:** Double underscore `__` for internal, none for public
- **Case:** SCREAMING_SNAKE_CASE
- **Declaration:** Use `declare -a -g` or `declare -ga`
- **Usage:** For ordered collections

### Examples from Codebase

| Array | Module | Purpose |
|-------|--------|---------|
| `__HOOKS_SOURCE_PATTERNS` | hooks | File patterns for sourced execution |
| `__HOOKS_SCRIPT_PATTERNS` | hooks | File patterns for script execution |

---

## 4. Local Arrays

Function-scoped arrays (both indexed and associative).

### Pattern: `snake_case`

```bash
function example:function() {
  # Local indexed array
  local -a files=()
  local -a args=("$@")
  local -a filtered_args=()

  # Local associative array
  local -A config=()
  local -A parsed=()
  local -A options=()
}
```

### Rules

- **Case:** snake_case (all lowercase with underscores)
- **Declaration:** Use `local -a` (indexed) or `local -A` (associative)
- **Scope:** Function-local only
- **Naming:** Descriptive, plural form common

### Common Local Array Names

| Array Name | Type | Usage |
|------------|------|-------|
| `args` | Indexed | Captured arguments from `$@` |
| `filtered_args` | Indexed | Arguments after filtering |
| `files` | Indexed | List of file paths |
| `entries` | Indexed | List of entries |
| `signals` | Indexed | List of signal names |
| `handlers` | Indexed | List of handler functions |
| `config` | Associative | Configuration map |
| `parsed` | Associative | Parsed data |
| `options` | Associative | Option flags |

### Examples from Codebase

```bash
# From logger:compose
function logger:compose() {
  local tag=${1}
  local suffix=${2}
  # ... (no arrays in this simple function)
}

# From semver:parse
function semver:parse() {
  local version="$1"
  local output_variable="${2:-"__semver_parse_result"}"
  declare -A parsed=(["version"]="" ["version-core"]="" ["pre-release"]="" ["build"]="")
  # ...
}

# From hooks:do
function hooks:do() {
  local hook_name="$1"
  shift

  local -a merged_impls=()
  local -a ands=()
  local -a expressions=()
  # ...
}

# From dependency function
function dependency() {
  local filtered_args=()
  for arg in "$@"; do
    case "$arg" in
      --exec|--optional|--silent|--no-cache|--debug) continue ;;
      *) filtered_args+=("$arg") ;;
    esac
  done
}
```

---

## 5. Nameref Arrays

References to other arrays (Bash 4.3+).

### Pattern: `local -n ref_name="target_array"`

```bash
function example:with:nameref() {
  local var_name="__MODULE_CACHE"

  # Create nameref to global array
  local -n cache_ref="$var_name"

  # Use nameref like the original array
  cache_ref[key]="value"
  echo "${cache_ref[key]}"

  # Iterate using nameref
  for key in "${!cache_ref[@]}"; do
    echo "$key -> ${cache_ref[$key]}"
  done
}
```

### Rules

- **Declaration:** Use `local -n`
- **Naming:** Usually suffix with `_ref` for clarity
- **Purpose:** Indirect access to dynamically-named arrays
- **Caution:** Avoid circular references

### Examples from Codebase

```bash
# From _traps.sh
function trap:on() {
  local var_name="${__TRAP_PREFIX}${signal}"

  # Use nameref for indirect access
  local -n handlers="$var_name"
  handlers+=("$handler")
}

# From _hooks.sh
function _hooks:middleware:default() {
  local capture_var="$3"

  local -n capture_ref="$capture_var"
  for line in "${capture_ref[@]}"; do
    # Process captured output
  done
}
```

---

## Array Access Patterns

### Indexed Arrays

```bash
# Declaration and initialization
local -a my_array=()
local -a files=("file1.txt" "file2.txt")

# Append elements
my_array+=("element1")
my_array+=("element2")

# Access element
echo "${my_array[0]}"

# Get array length
echo "${#my_array[@]}"

# Iterate
for item in "${my_array[@]}"; do
  echo "$item"
done

# Iterate with index
for i in "${!my_array[@]}"; do
  echo "$i: ${my_array[$i]}"
done
```

### Associative Arrays

```bash
# Declaration
declare -A config=()

# Set values
config[key]="value"
config[timeout]=30

# Get value
echo "${config[key]}"

# Check if key exists
if [[ -v config[key] ]]; then
  echo "Key exists"
fi

# Iterate over keys
for key in "${!config[@]}"; do
  echo "$key -> ${config[$key]}"
done

# Iterate over values
for value in "${config[@]}"; do
  echo "$value"
done
```

---

## Best Practices

### ✅ DO

```bash
# Use descriptive plural names
local -a files=()                   # ✓ Clear collection
local -a handlers=()                # ✓ Clear collection

# Use associative arrays for mappings
declare -A -g __MODULE_CACHE        # ✓ Key-value store
declare -A config=()                # ✓ Configuration map

# Declare at function start
function good:example() {
  local -a items=()
  local -A config=()
  # ... function body
}

# Use nameref for indirection
local -n ref="$var_name"            # ✓ Clear intent
ref[key]="value"
```

### ❌ DON'T

```bash
# Don't use generic names without context
local -a array=()                   # ✗ What kind of array?
local -A map=()                     # ✗ What does it map?

# Don't mix naming conventions
declare -A myCache                  # ✗ Should be snake_case or __MODULE_CACHE
declare -a MyArray                  # ✗ Wrong case

# Don't forget -A for associative arrays
declare -g CONFIG                   # ✗ Wrong type (indexed)
declare -A -g CONFIG                # ✓ Correct (associative)
```

---

## Common Pitfalls

### 1. Forgetting -A for Associative Arrays

```bash
# Wrong - creates indexed array
declare -g MY_MAP
MY_MAP[key]="value"  # Creates MY_MAP[0]="value", ignores "key"

# Correct
declare -A -g MY_MAP
MY_MAP[key]="value"  # Correctly uses "key" as associative key
```

### 2. Not Checking if Key Exists

```bash
# Risky - may be unset
value="${config[$key]}"

# Better - check first
if [[ -v config[$key] ]]; then
  value="${config[$key]}"
else
  value="default"
fi

# Or use default
value="${config[$key]:-default}"
```

### 3. Array vs String Confusion

```bash
# Wrong - string assignment, not array
my_array="value1 value2 value3"

# Correct - array initialization
my_array=("value1" "value2" "value3")
```

---

## Array Declaration Cheatsheet

| Type | Declaration | Example |
|------|-------------|---------|
| **Global Assoc (internal)** | `declare -A -g __NAME` | `declare -A -g __HOOKS_DEFINED` |
| **Global Assoc (public)** | `declare -A -g NAME` | `declare -A -g TAGS` |
| **Global Indexed (internal)** | `declare -a -g __NAME` | `declare -a -g __HOOKS_PATTERNS` |
| **Global Indexed (public)** | `declare -a -g NAME` | `declare -a -g FILTERED_ARGS` |
| **Local Assoc** | `local -A name=()` | `local -A config=()` |
| **Local Indexed** | `local -a name=()` | `local -a files=()` |
| **Nameref** | `local -n ref="target"` | `local -n cache="__CACHE"` |

---

## Quick Reference

### Check Array Type

```bash
# Check if array exists and get type
declare -p ARRAY_NAME

# Example outputs:
# declare -A TAGS='([common]="1" [debug]="0")'  # Associative
# declare -a files='([0]="file1" [1]="file2")'   # Indexed
# bash: declare: ARRAY_NAME: not found           # Doesn't exist
```

### Array Operations

```bash
# Length
${#array[@]}              # Number of elements

# All elements
"${array[@]}"             # All values (space-separated)

# All keys/indices
"${!array[@]}"            # All keys (associative) or indices (indexed)

# Check if key exists
[[ -v array[key] ]]       # Returns 0 if exists

# Remove element
unset 'array[key]'        # Remove specific key (quote to prevent glob)

# Clear array
unset array               # Remove entire array
array=()                  # Clear to empty array
```

---

## See Also

- [Variable Naming](naming-variables.md) - Variable naming patterns
- [Function Naming](naming-functions.md) - Function naming patterns
- [Main Conventions](NAMING_CONVENTIONS.md) - Overview
