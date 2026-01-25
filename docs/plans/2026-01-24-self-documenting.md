# Script Commenting Standard

## Overview

This document defines the commenting standard for all shell scripts in the e-bash project. The standard uses `##` prefix for documentation to distinguish it from regular `#` comments and to enable automated documentation extraction.

## File Structure

Every shell script file should follow this structure:

1. **Copyright Header** - Required license and copyright information
2. **One-time Initialization Guard** - Prevents duplicate sourcing
3. **Dependencies** - Source statements for required modules
4. **Constants** - Read-only variables
5. **Global Variables** - Module state with initialization
6. **Function Definitions** - All functions with `##` documentation
7. **Return Guard** - `${__SOURCED__:+return}` for sourced files
8. **Module Initialization** - Logger initialization, etc.
9. **Module Documentation** - End-of-file module-level docs

## Function Documentation Standard

Every function MUST be documented with `##` comment blocks immediately preceding the function definition.

### Required Sections

```bash
##
## One-line summary of the function's purpose
##
## Parameters:
## - param_name - Description, type, [required|optional|default: value]
##
## Globals:
## - reads/listen: VAR1, VAR2
## - mutate/publish: VAR3, VAR4
##
## Side effects:
## - Description of side effects (if any)
##
## Returns:
## - Description of return value(s) or exit codes
##
## Usage:
## - function_name arg1 "arg2"
##
function function_name() {
  # function body
}
```

### Section Guidelines

#### Summary Line
- Start with a capital letter
- Use imperative mood (e.g., "Extract version from git repo")
- Keep to one line

#### Parameters
- List all parameters in order
- For each parameter include:
  - **Name**: Parameter identifier
  - **Description**: What the parameter is for
  - **Type**: string, number, boolean, array, associative array
  - **Requirement**: required, optional, variadic
  - **Default**: For optional parameters, specify default value

#### Globals
Divide into two categories:
- **reads/listen**: Variables that are read but not modified
- **mutate/publish**: Variables that are modified or exported

#### Side Effects
- List any state changes beyond return value
- Include file operations, subprocess creation, etc.
- Omit if no side effects (use "Returns" section only)

#### Returns
- Describe what is echoed/printed (if applicable)
- List possible exit codes and their meanings
- Use "Returns:" section even for void functions (state "none")

#### Usage
- Provide 1-3 realistic examples
- Show both simple and complex usage patterns
- Include common flags and options

## Optional Sections

### See Also
```bash
##
## See Also:
## - related_function_name
## - related_module
##
```

### Examples (Extended)
```bash
##
## Examples:
## - Basic usage:
##   function_name "input"
## - With options:
##   function_name --flag "input"
## - Chaining:
##   function_name "input" | other_function
##
```

## Module-Level Documentation

Each module file MUST have module-level documentation at the END of the file, after the return guard and initialization code.

### Required Sections

```bash
# -----------------------------------------------------------------------------
# Module: _module_name
# -----------------------------------------------------------------------------

## Purpose:
## Brief description of what this module provides

## References:
## - demos/demo_file.sh
## - bin/script_name.sh
## - docs/public/documentation.md
## - spec/module_spec.sh

## Globals Introduced:
## - GLOBAL_VAR - Description
## - GLOBAL_ARRAY - Description

## Function Categories:
## - Public API: function_name, another_function
## - Internal: _internal_function
## - Aliases: alias_name
```

## Naming Conventions

### Function Names
- **Public API**: `namespace:action` (e.g., `trap:on`, `logger:push`)
- **Internal**: `_namespace:action` (e.g., `_Trap::normalize_signal`)
- **Private**: Single underscore prefix for module-private functions

### Variable Names
- **Constants**: `UPPER_SNAKE_CASE` with `readonly` declaration
- **Globals**: `__DOUBLE_UNDERSCORE_PREFIX` for module globals
- **Locals**: `lower_snake_case` with `local` declaration

## Copyright Header

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2155

## Copyright (C) 2017-present, Oleksandr Kucherenko
## Last revisit: YYYY-MM-DD
## Version: X.Y.Z
## License: MIT
## Source: https://github.com/OleksandrKucherenko/e-bash
```

## One-Time Initialization Guard

```bash
# One-time initialization guard
if type "main_function" &>/dev/null; then return 0; fi
```

Or for modules with multiple entry points:

```bash
# Module initialization flag
__MODULE_NAME_INITIALIZED="yes"

# Check at top
if [[ "${__MODULE_NAME_INITIALIZED:-}" == "yes" ]]; then return 0; fi
```

## Return Guard

At the end of function definitions, before module initialization:

```bash
# DO NOT allow execution of code below this line in shellspec tests
${__SOURCED__:+return}
```

This prevents execution when the file is sourced (e.g., in tests).

## Best Practices

### DO
- Use `##` for all documentation comments
- Use `#` for implementation comments
- Keep summary lines concise and descriptive
- Document ALL functions including private/internal ones
- Include realistic usage examples
- Specify types for all parameters
- List all globals that are read or modified

### DON'T
- Don't use `#` for documentation that should be `##`
- Don't leave functions undocumented
- Don't omit parameter types or defaults
- Don't mix documentation styles
- Don't put module docs in the middle of the file (must be at end)

## Example: Complete Function

```bash
##
## Register handler function for one or more signals
##
## Parameters:
## - --allow-duplicates - Allow duplicate handler registration, flag, optional
## - handler_function - Function to call when signal triggers, string, required
## - @ - Signal names (EXIT, INT, TERM, ERR, etc.), string array, variadic
##
## Globals:
## - reads/listen: __TRAP_PREFIX, __TRAP_INIT_PREFIX
## - mutate/publish: __TRAP_HANDLERS_SIG_{signal} array, __TRAP_INITIALIZED_SIG_{signal}
##
## Side effects:
## - Creates trap on signal using Trap::dispatch
## - Initializes signal state on first registration
##
## Usage:
## - trap:on cleanup_temp EXIT
## - trap:on handle_interrupt INT TERM
## - trap:on --allow-duplicates log_event ERR
##
function trap:on() {
  # implementation
}
```

## Example: Internal Function

```bash
##
## Normalize signal name to uppercase format
##
## Parameters:
## - signal - Raw signal name, string, required
##
## Globals:
## - reads/listen: none
## - mutate/publish: none
##
## Returns:
## - 0 on success, echoes normalized signal name
## - 1 on invalid signal, echoes error message
##
## Usage:
## - normalized=$(_Trap::normalize_signal "exit")  # returns "EXIT"
##
function _Trap::normalize_signal() {
  # implementation
}
```

## Documentation Quality Checklist

Before committing code, verify:

- [ ] Every function has `##` documentation block
- [ ] Summary line is concise and descriptive
- [ ] All parameters are documented with type
- [ ] Required parameters are marked as such
- [ ] Optional parameters specify defaults
- [ ] Globals are divided into reads/listen and mutate/publish
- [ ] Side effects are documented (if applicable)
- [ ] Return values are clearly described
- [ ] At least one usage example is provided
- [ ] Module-level documentation exists at file end
- [ ] No old-style `#` function comments remain

## Tooling Integration

The `##` prefix standard enables:
- Automated documentation generation
- IDE hover tooltips
- LSP integration for shell scripts
- Consistent formatting across the codebase
- Easy extraction for external documentation

## Related Files

- `.shellspec` - Test configuration
- `CLAUDE.md` - Project documentation
- `docs/public/*.md` - Public documentation
