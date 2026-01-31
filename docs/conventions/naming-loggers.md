# Logger and Tag Naming Conventions

This document details naming patterns for logger tags and debug output in the e-bash library.

---

## Overview

The e-bash logger system uses **tags** to control which log output is displayed. Tags are controlled via the `DEBUG` environment variable.

---

## Logger Tag Naming

### Pattern: `lowercase`

```bash
# Initialize logger tags
logger common "$@"
logger debug "$@"
logger error "$@"
logger hooks "$@"
logger trap "$@"
logger dependencies "$@"
```

### Rules

- **Case:** All lowercase
- **No special characters:** Only letters and numbers (no hyphens, underscores, or colons)
- **Single word preferred:** Use compound words sparingly
- **Descriptive:** Tag name should indicate what it logs

### Examples from Codebase

| Tag | Module | Purpose |
|-----|--------|---------|
| `common` | logger | Common/general logging |
| `debug` | logger | Debug output |
| `error` | logger | Error messages |
| `loader` | logger | Module loading messages |
| `hooks` | hooks | Hook execution tracing |
| `modes` | hooks | Mode/middleware logging |
| `trap` | traps | Trap/signal logging |
| `dependencies` | dependencies | Dependency checking |
| `install` | dependencies | Auto-install operations |
| `semver` | semver | Semver parsing/comparison |
| `regex` | semver | Regex pattern debugging |
| `simple` | semver | Simple constraint evaluation |
| `edocs` | bin/e-docs.sh | e-docs general output |
| `parse` | bin/e-docs.sh | Parsing operations |
| `generate` | bin/e-docs.sh | Generation operations |
| `ctags` | bin/e-docs.sh | Ctags operations |
| `validate` | bin/e-docs.sh | Validation operations |

---

## Generated Function Names

When you initialize a tag with `logger tagname`, these functions are created:

### Pattern: `action:Tagname` (Capitalized)

```bash
# After: logger common "$@"
echo:Common "message"              # Print if 'common' tag enabled
printf:Common "format" args        # Printf if 'common' tag enabled
log:Common                         # Pipe-friendly logger

# After: logger debug "$@"
echo:Debug "message"
printf:Debug "format" args
log:Debug
```

### Rules

- **Capitalize first letter:** Tag `hooks` becomes `Hooks` in function name
- **Standard prefixes:** `echo:`, `printf:`, `log:`, `config:logger:`
- **Consistent pattern:** All tags follow same generation rules

---

## DEBUG Environment Variable

### Pattern: Comma-separated tag list

```bash
# Enable specific tags
export DEBUG="common,hooks"

# Enable all tags
export DEBUG="*"

# Enable all except specific tags
export DEBUG="*,-debug"

# Complex filtering
export DEBUG="hooks,error,-loader"
```

### Rules

- **Separator:** Comma `,` with no spaces
- **Wildcard:** `*` enables all tags
- **Negation:** `-tagname` disables specific tag
- **Order matters:** Later entries override earlier ones

### Examples

```bash
# Enable only hooks and error logging
DEBUG=hooks,error ./script.sh

# Enable everything except debug messages
DEBUG=*,-debug ./script.sh

# Enable all, then disable loader and debug
DEBUG="*,-loader,-debug" ./script.sh

# Enable hooks, then explicitly disable it (result: disabled)
DEBUG="hooks,-hooks" ./script.sh
```

---

## Tag Initialization Patterns

### Standard Initialization

```bash
# In module file (.scripts/_module.sh)
logger modulename "$@"
logger:redirect modulename ">&2"
```

### With Prefix and Redirect (Recommended)

```bash
# Initialize with prefix and redirect in one call
logger:init tagname "[prefix] " ">&2"

# Example from hooks module
logger:init hooks "${cl_grey}[hooks]${cl_reset} " ">&2"
logger:init error "${cl_red}[error]${cl_reset} " ">&2"
```

### Custom Configuration

```bash
# Initialize tag
logger myapp "$@"

# Set custom prefix
logger:prefix myapp "[MyApp] "

# Redirect to stderr
logger:redirect myapp ">&2"

# Or combine with logger:init
logger:init myapp "[MyApp] " ">&2"
```

---

## Tag Naming Guidelines

### ✅ DO

```bash
# Use descriptive, domain-specific names
logger api "$@"                     # ✓ Clear purpose
logger database "$@"                # ✓ Clear purpose
logger cache "$@"                   # ✓ Clear purpose

# Use lowercase
logger hooks "$@"                   # ✓ Lowercase
logger dependencies "$@"            # ✓ Lowercase

# Use single words when possible
logger parse "$@"                   # ✓ Simple
logger generate "$@"                # ✓ Simple
```

### ❌ DON'T

```bash
# Don't use special characters
logger my-app "$@"                  # ✗ Hyphen not allowed
logger my_app "$@"                  # ✗ Underscore not recommended
logger my:app "$@"                  # ✗ Colon not allowed

# Don't use uppercase or mixed case
logger API "$@"                     # ✗ Should be lowercase
logger MyApp "$@"                   # ✗ Should be lowercase

# Don't use overly long names
logger my_application_module "$@"   # ✗ Too long
logger app "$@"                     # ✓ Better
```

---

## Common Tag Categories

### System Tags (used by e-bash internally)

| Tag | Purpose |
|-----|---------|
| `common` | General library messages |
| `loader` | Module loading notifications |
| `error` | Error messages (always recommended) |
| `debug` | Detailed debug output |

### Module Tags (one per module)

| Tag | Module |
|-----|--------|
| `hooks` | Hooks system |
| `trap` | Trap/signal handling |
| `dependencies` | Dependency checking |
| `semver` | Semantic versioning |
| `dryrun` | Dry-run wrapper |

### Application Tags (user-defined)

| Tag | Usage Example |
|-----|---------------|
| `api` | API client logging |
| `database` | Database operations |
| `auth` | Authentication |
| `cache` | Caching operations |
| `deploy` | Deployment logging |

---

## Tag Lifecycle

### 1. Declaration

```bash
# Declare tag (in module or script)
logger myapp "$@"
```

### 2. Configuration

```bash
# Set prefix
logger:prefix myapp "[MyApp] "

# Set redirect
logger:redirect myapp ">&2"

# Or use logger:init
logger:init myapp "[MyApp] " ">&2"
```

### 3. Usage

```bash
# Use generated functions
echo:Myapp "Application started"
printf:Myapp "Processing: %s\n" "$file"
find . -name "*.log" | log:Myapp
```

### 4. State Management

```bash
# Save current state
logger:push

# Temporarily modify
DEBUG="*" some_function

# Restore previous state
logger:pop
```

---

## Special Patterns

### Pipe Mode Logging

```bash
# Redirect command output through logger
find . -type f | log:Common
git log --oneline | log:Git

# With prefix
find . -name "*.sh" | log:Common "  "
```

### Conditional Logging

```bash
# Only log if tag is enabled
if [[ "${TAGS[myapp]}" == "1" ]]; then
  expensive_debug_computation
  echo:Myapp "Result: $result"
fi
```

### Reconfiguration at Runtime

```bash
# Change DEBUG and refresh all loggers
export DEBUG="*"
_hooks:logger:refresh  # Internal function to reconfigure
```

---

## Integration with Other Systems

### With Arguments Module

```bash
# Define --debug flag
export ARGS_DEFINITION="--debug=DEBUG:*"
source "$E_BASH/_arguments.sh"  # Auto-parses $@

# Now DEBUG is set if --debug was passed
logger myapp "$@"  # Will enable if DEBUG contains 'myapp'
```

### With Hooks Contract System

```bash
# Hook can modify DEBUG via contract
echo "contract:env:DEBUG+=,newtag"   # Append tag
echo "contract:env:DEBUG^=newtag"    # Prepend tag
echo "contract:env:DEBUG-=oldtag"    # Remove tag
```

---

## Best Practices

### Application-Level Tagging

```bash
# In your application script
# Set up logging early
DEBUG="${DEBUG:-app,error}"  # Default tags if not set
logger app "$@"
logger:init app "[App] " ">&2"

# Use descriptive tags for subsystems
logger:init api "[API] " ">&2"
logger:init db "[DB] " ">&2"

# Disable internal e-bash noise
DEBUG="${DEBUG},-loader,-common"
```

### Module Development

```bash
# In module file (.scripts/_mymodule.sh)
# Always initialize your module tag
logger mymodule "$@"
logger:redirect mymodule ">&2"

# Use descriptive echo functions
echo:Mymodule "Initializing module..."
echo:Mymodule "Processing: $item"
printf:Mymodule "Progress: %d%%\n" "$percent"
```

### Debugging

```bash
# Enable all logging for debugging
DEBUG="*" ./script.sh

# Enable specific subsystem
DEBUG="api,database" ./script.sh

# Enable all except noisy tags
DEBUG="*,-loader,-common,-debug" ./script.sh
```

---

## Quick Reference

### Tag Control

```bash
# Enable specific tags
DEBUG=tag1,tag2

# Enable all
DEBUG=*

# Disable specific
DEBUG=*,-tag1

# In script
logger tag "$@"
```

### Generated Functions

```bash
echo:Tag "message"       # Print if enabled
printf:Tag "fmt" args    # Printf if enabled
log:Tag                  # Pipe mode
log:Tag "prefix"         # Pipe with prefix
```

### Configuration

```bash
logger:init tag "[prefix] " ">&2"   # All-in-one
logger:prefix tag "[prefix] "       # Set prefix
logger:redirect tag ">&2"           # Set redirect
logger:push                         # Save state
logger:pop                          # Restore state
```

---

## See Also

- [Variable Naming](naming-variables.md) - Includes `DEBUG` variable
- [Function Naming](naming-functions.md) - Generated function patterns
- [Logger Module Documentation](../public/logger.md) - Full logger guide
- [Main Conventions](NAMING_CONVENTIONS.md) - Overview
