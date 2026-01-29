# Function Naming Conventions

This document details function naming patterns used in the e-bash library.

---

## Overview

Functions in e-bash are categorized by their **visibility** and **purpose**:

1. **Public API functions** - Intended for external use
2. **Internal helper functions** - Module-private implementation details
3. **Generated functions** - Dynamically created by modules (e.g., logger)
4. **Legacy/compatibility functions** - Deprecated or backward-compatible wrappers

---

## 1. Public API Functions

These are the primary interface for library users.

### Pattern: `{domain}:{verb}`

```bash
function logger:init() { ... }
function hooks:do() { ... }
function trap:on() { ... }
function dependency:exists() { ... }
```

### Pattern: `{domain}:{entity}:{verb}` (nested namespaces)

```bash
function semver:increase:major() { ... }
function semver:increase:minor() { ... }
function semver:compare:readable() { ... }
function logger:redirect() { ... }
```

### Rules

- **All lowercase** - Module functions MUST be all lowercase (no mixed case, no CamelCase)
  - ✅ `logger:init`, `hooks:do`, `semver:compare`
  - ❌ `logger:Init`, `hooks:Do`, `semverCompare`
- **Colon separators** - Use `:` not `_` or `-`
- **Verb comes last** - Pattern is `{domain}:{verb}` or `{domain}:{entity}:{verb}`
- **Domain prefix** - First component is the domain/module name
- **Max 3 levels** - Avoid deeply nested names (`domain:cat1:cat2:verb` is too deep)
- **Clear verbs** - Use descriptive action verbs (init, do, get, set, list, clear, etc.)

### Important Scope Distinction

**Module functions** (in `.scripts/_*.sh`):
- MUST be all lowercase
- Example: `logger:init`, `hooks:register`, `trap:on`

**Script functions** (in `bin/*.sh` or user scripts that use e-bash):
- MAY use mixed case (CamelCase, PascalCase) if desired
- Example: `gitsv:add_keyword`, `processCommit`, `calculateVersion`
- Still recommended to follow lowercase convention for consistency

### Examples from Codebase

| Function | Module | Action | Purpose |
|----------|--------|--------|---------|
| `logger:init` | logger | init | Initialize logger with prefix and redirect |
| `logger:redirect` | logger | redirect | Change output redirection for a tag |
| `logger:prefix` | logger | prefix | Set/change prefix string for a tag |
| `logger:push` | logger | push | Save current logger state to stack |
| `logger:pop` | logger | pop | Restore previous logger state |
| `hooks:declare` | hooks | declare | Register available hook names |
| `hooks:do` | hooks | do | Execute a hook and all implementations |
| `hooks:register` | hooks | register | Register function for hook |
| `hooks:middleware` | hooks | middleware | Set middleware for hook |
| `trap:on` | traps | on | Register signal handler |
| `trap:off` | traps | off | Unregister signal handler |
| `trap:list` | traps | list | List all registered handlers |
| `trap:push` | traps | push | Save current trap state |
| `trap:pop` | traps | pop | Restore previous trap state |
| `semver:parse` | semver | parse | Parse version string into components |
| `semver:compare` | semver | compare | Compare two versions |
| `semver:constraints` | semver | constraints | Check version against constraints |
| `dependency:exists` | dependencies | exists | Check if tool exists (short form) |

### Naming Actions - Preferred Verbs

**Philosophy:** Use common, short verbs that are frequently used in everyday English.

#### ✅ Preferred Verbs (Common, Short)

| Verb | Meaning | Examples | Length |
|------|---------|----------|--------|
| `do` | Execute/perform | `hooks:do` | 2 chars |
| `on` | Enable/attach | `trap:on` | 2 chars |
| `off` | Disable/detach | `trap:off` | 3 chars |
| `get` | Retrieve value | `cache:get` | 3 chars |
| `set` | Store value | `cache:set` | 3 chars |
| `add` | Add item | `list:add` | 3 chars |
| `run` | Execute | `hooks:run` | 3 chars |
| `init` | Initialize/setup | `logger:init` | 4 chars |
| `list` | Show all items | `hooks:list`, `trap:list` | 4 chars |
| `push` | Save state to stack | `logger:push`, `trap:push` | 4 chars |
| `pop` | Restore state from stack | `logger:pop`, `trap:pop` | 3 chars |
| `clear` | Remove all | `trap:clear` | 5 chars |
| `reset` | Restore to default | `hooks:reset` | 5 chars |
| `parse` | Extract/analyze | `semver:parse` | 5 chars |
| `exists` | Check existence | `dependency:exists` | 6 chars |
| `declare` | Define/register | `hooks:declare` | 7 chars |
| `register` | Add to collection | `hooks:register` | 8 chars |
| `redirect` | Change output | `logger:redirect` | 8 chars |
| `compare` | Evaluate difference | `semver:compare` | 7 chars |
| `increase` | Increment | `semver:increase:major` | 8 chars |

#### ❌ Avoid These (Rare, Verbose, or Obscure)

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `execute` | Too long (7 chars) | `do` (2 chars), `run` (3 chars) |
| `initialize` | Too long (10 chars) | `init` (4 chars) |
| `configure` | Too long (9 chars) | `config` (6 chars), `set` (3 chars) |
| `retrieve` | Uncommon | `get` (3 chars) |
| `eliminate` | Rare | `remove` (6 chars), `clear` (5 chars) |
| `procure` | Obscure | `get` (3 chars) |
| `ameliorate` | Obscure | `improve` (7 chars), `fix` (3 chars) |
| `obviate` | Rare | `remove` (6 chars), `skip` (4 chars) |
| `instantiate` | Too technical | `create` (6 chars), `new` (3 chars) |
| `terminate` | Too formal | `stop` (4 chars), `end` (3 chars), `kill` (4 chars) |

#### Verb Selection Guidelines

1. **Prefer 2-5 character verbs** when possible
2. **Use common words** you'd use in everyday conversation
3. **Be consistent** - same verb = same action across all modules
4. **Consider readability** in 120-character lines:
   ```bash
   # Good: Short verbs keep lines readable
   logger:init "tag" "[prefix] " ">&2" && logger:redirect "tag" ">&2" && echo:Tag "msg"

   # Bad: Long verbs make lines unwieldy
   logger:initialize "tag" "[prefix] " ">&2" && logger:redirect_output "tag" ">&2" && echo:Tag "msg"
   ```

---

## 2. Internal Helper Functions

These functions are module-private and not intended for external use.

### Pattern: `_{domain}:*`

```bash
function _hooks:capture:run() { ... }
function _hooks:middleware:default() { ... }
function _hooks:env:apply() { ... }
function _hooks:logger:refresh() { ... }
function _hooks:on_exit() { ... }
function _hooks:trap:end() { ... }
function _cache:load() { ... }
function _cache:save() { ... }
function _cache:key() { ... }
function _cache:get() { ... }
function _cache:set() { ... }
function _cache:clear() { ... }
function _cache:is:valid() { ... }
function _cache:path:hash() { ... }
function _cache:ensure:loaded() { ... }
```

### Pattern: `_Module::method_name` (OOP-style, class-like - LEGACY)

```bash
# NOTE: This pattern is legacy and exists in older modules like _traps.sh
# New code should prefer _{domain}:* pattern instead
function _Trap::normalize_signal() { ... }
function _Trap::initialize_signal() { ... }
function _Trap::capture_legacy() { ... }
function _Trap::contains() { ... }
function _Trap::remove_handler() { ... }
```

### Rules

- **Single underscore prefix + colon** - `_{domain}:` indicates module-private function
- **Follows same structure as public** - Use `_{domain}:{verb}` or `_{domain}:{entity}:{verb}`
- **Legacy OOP-style** - `_Module::method` exists in older code but avoid in new code
- **Not for external use** - These may change without notice
- **Same verb conventions** - Use same verbs as public API (init, do, get, set, etc.)

### When to Use `_{domain}:*` vs `_Module::method`

| Use `_{domain}:*` (PREFERRED) | Use `_Module::method` (LEGACY) |
|-------------------------------|--------------------------------|
| All new internal functions | Only in legacy modules (_traps.sh) |
| Consistent with public API | OOP-style grouping |
| `_hooks:capture:run` | `_Trap::normalize_signal` |
| `_cache:load` | `_Trap::dispatch` |
| `_hooks:middleware:default` | `_Trap::contains` |

**Recommendation:** Use `_{domain}:*` pattern for all new code. The `_Module::method` pattern exists only for backward compatibility in `_traps.sh`.

### Examples from Codebase

| Function | Pattern | Purpose |
|----------|---------|---------|
| `_Trap::dispatch` | Class method | Main trap dispatcher (called by OS) |
| `_Trap::normalize_signal` | Class method | Convert signal names to standard format |
| `_Trap::initialize_signal` | Class method | First-time signal setup |
| `_Trap::capture_legacy` | Class method | Save existing trap before override |
| `_Trap::contains` | Class method | Check if handler in list |
| `_Trap::remove_handler` | Class method | Remove handler from list |
| `_hooks:capture:run` | Namespaced helper | Execute with output capture (internal) |
| `_hooks:middleware:default` | Namespaced helper | Default middleware implementation |
| `_hooks:env:apply` | Namespaced helper | Apply environment directive |
| `_hooks:logger:refresh` | Namespaced helper | Refresh logger tags after DEBUG change |
| `_cache:load` | Namespaced helper | Load cache from disk |
| `_cache:save` | Namespaced helper | Save cache to disk |
| `_cache:key` | Namespaced helper | Generate cache key |

---

## 3. Generated Functions

Functions created dynamically at runtime by the logger module via `eval`.

### Pattern: `action:Tag` (CamelCase allowed)

```bash
# Generated by logger module
echo:Common "message"      # Print if 'common' tag enabled
printf:Debug "format" args # Printf if 'debug' tag enabled
log:Error                  # Pipe-friendly logger for 'error' tag
echo:MyApp "Starting..."   # Multi-word tags use CamelCase
```

### Rules

- **CamelCase allowed** - Generated functions MAY use CamelCase for readability
  - Tag `common` → `echo:Common` (capitalized first letter)
  - Tag `myapp` → `echo:Myapp` or `echo:MyApp` (user preference)
  - Tag `error` → `echo:Error`
- **Colon separator** - Use `:` to separate action from tag
- **Standard actions** - `echo:Tag`, `printf:Tag`, `log:Tag`, `config:logger:Tag`
- **Created by `logger` function** - Dynamically generated via `eval`, not manually defined
- **Tag-specific** - Each tag gets its own set of functions

### Why CamelCase is Allowed Here

Generated functions are **dynamically created** (not statically defined in module files), and the tag portion serves as a **label/identifier** rather than a namespace component. CamelCase improves readability:

- ✅ `echo:MyApp` - Easier to read in logs
- ✅ `printf:ApiClient` - Clear multi-word tags
- ✅ `log:DatabaseMigration` - Self-documenting

Compare to module functions which must be lowercase:
- ✅ `logger:init` (module function - lowercase required)
- ✅ `echo:MyApp` (generated function - CamelCase allowed)

### Generated Functions Per Tag

When you call `logger mytag`, these functions are created:

| Function | Purpose | Example Usage |
|----------|---------|---------------|
| `echo:Mytag` | Print message if tag enabled | `echo:Mytag "Starting process..."` |
| `printf:Mytag` | Formatted print if tag enabled | `printf:Mytag "Progress: %d%%\n" 50` |
| `log:Mytag` | Pipe-mode logger | `find . \| log:Mytag` |
| `config:logger:Mytag` | Reconfigure tag state | (internal use) |

### Example

```bash
# Initialize logger tag
logger myapp "$@"

# Use generated functions
echo:Myapp "Application starting..."
printf:Myapp "Processing file: %s\n" "$filename"
find . -name "*.log" | log:Myapp
```

---

## 4. Utility/Helper Functions

These are general-purpose functions that may not fit the module:action pattern.

### Pattern: Varies by purpose

```bash
# Parsing helpers (used by _arguments.sh)
function parse:mapping() { ... }
function parse:arguments() { ... }
function parse:extract_output_definition() { ... }

# Conditional checks (used by _dependencies.sh)
function isDebug() { ... }
function isExec() { ... }
function isOptional() { ... }
function isSilent() { ... }

# Time utilities (used by _commons.sh)
function time:now() { ... }
function time:diff() { ... }

# Cursor utilities (used by _commons.sh)
function cursor:position() { ... }
function cursor:row() { ... }
```

### Rules

- **Match module conventions** - Follow the established pattern for that module
- **Descriptive names** - Choose names that reveal intent
- **Prefixed when needed** - Use module prefix to avoid collisions

---

## 5. Legacy/Compatibility Functions

Functions provided for backward compatibility or simplified access.

### Pattern: `simple_alias`

```bash
# Wrapper functions for common operations
function optional() {
  dependency "$@" --optional
}

function dependency() {
  # Main implementation
}
```

### Rules

- **Simple name** - No prefix when it's the only function of its kind
- **Document as wrapper** - Clearly mark in comments
- **Consider deprecation** - May be removed in future major versions

### Examples

| Function | Wraps | Purpose |
|----------|-------|---------|
| `optional` | `dependency` | Simplified API for optional dependencies |
| `semver:recompose` | `semver:*` | Reconstruct version from parsed parts |

---

## Best Practices

### ✅ DO

```bash
# MODULE FUNCTIONS: Use all lowercase
function logger:init() { ... }           # ✓ Module function - lowercase
function hooks:register() { ... }        # ✓ Module function - lowercase
function semver:parse() { ... }          # ✓ Module function - lowercase
function trap:on() { ... }               # ✓ Module function - lowercase

# GENERATED FUNCTIONS: CamelCase allowed
echo:Common "message"                    # ✓ Generated - CamelCase OK
printf:MyApp "Starting..."               # ✓ Generated - CamelCase OK
log:DatabaseMigration                    # ✓ Generated - CamelCase OK

# SCRIPT FUNCTIONS: Mixed case allowed (in bin/*.sh)
function gitsv:add_keyword() { ... }     # ✓ Script function - mixed OK
function processCommit() { ... }         # ✓ Script function - CamelCase OK

# INTERNAL FUNCTIONS: Use _{domain}:* pattern
function _hooks:capture:run() { ... }    # ✓ Internal - preferred pattern
function _Trap::dispatch() { ... }       # ✓ Internal - legacy OOP pattern
```

### ❌ DON'T

```bash
# DON'T use mixed case in MODULE functions (.scripts/_*.sh)
function Logger:Init() { ... }           # ✗ Module functions must be lowercase
function logger:Init() { ... }           # ✗ Module functions must be lowercase
function semverCompare() { ... }         # ✗ Module functions must use colons

# DON'T use underscores in public API
function logger_init() { ... }           # ✗ Use colons, not underscores
function logger_redirect() { ... }       # ✗ Use logger:redirect

# DON'T use ambiguous prefixes
function _logger_init() { ... }          # ✗ Use _logger:init or __logger_init

# DON'T omit module prefix
function redirect() { ... }              # ✗ Too generic, use logger:redirect
function init() { ... }                  # ✗ Too generic, use module:init
```

### Summary by Location

| Location | Pattern | Case | Example |
|----------|---------|------|---------|
| `.scripts/_*.sh` (modules) | `{domain}:{verb}` | **lowercase only** | `logger:init` ✅, `logger:Init` ❌ |
| `.scripts/_*.sh` (internal) | `_{domain}:*` | **lowercase only** | `_hooks:capture:run` ✅ |
| `bin/*.sh` (scripts) | `{domain}:{verb}` or `functionName` | **mixed case OK** | `gitsv:add_keyword`, `processCommit` |
| Generated (logger) | `action:Tag` | **CamelCase allowed** | `echo:MyApp` ✅, `log:DatabaseMigration` ✅ |

---

## Function Documentation

All functions should include header comments following this template:

```bash
##
## Brief one-line description of what function does
##
## Parameters:
## - param_name - Description, type, required/optional, e.g. "string, required"
## - @ - Variadic parameters description
##
## Globals:
## - reads/listen: GLOBAL_VAR (description)
## - mutate/publish: MODIFIED_VAR (description)
##
## Side effects:
## - What external changes this function makes
##
## Usage:
## - example:function "arg1" "arg2"
## - DEBUG=tag example:function
##
## Returns:
## - 0 on success, 1 on failure (or echo output description)
##
function example:function() {
  local param_name="$1"
  # implementation
}
```

---

## Quick Checklist

Before adding a new function, ask:

- [ ] Is this part of the public API? → Use `module:action`
- [ ] Is this module-internal? → Use `__module_function` or `_Module::method`
- [ ] Does it modify global state? → Document in `Globals:` section
- [ ] Is the name a clear verb? → Prefer `get`, `set`, `do`, `init`, etc.
- [ ] Does it follow existing patterns in the module? → Check similar functions
- [ ] Is it documented with `##` comments? → Follow template above

---

## See Also

- [Variable Naming](naming-variables.md) - Naming patterns for variables
- [File Naming](naming-files.md) - Naming patterns for files
- [Main Conventions](NAMING_CONVENTIONS.md) - Overview and quick reference
