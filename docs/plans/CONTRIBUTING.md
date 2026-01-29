# Contributor Instructions: .scripts Documentation

These rules apply to all shell modules under `.scripts/` and describe how to
document functions and globals so `e-docs` can extract consistent docs.

## Function Documentation

- Every function MUST have a `##` documentation block immediately above it.
- Use `##` only for documentation. Use `#` for implementation comments.
- Document public, internal, and private functions (no exceptions).

Required sections and order:

```bash
##
## One-line summary of the function's purpose
##
## Parameters:
## - name - Description, type, required|optional|default: value
##
## Globals:
## - reads/listen: VAR1, VAR2
## - mutate/publish: VAR3
##
## Returns:
## - 0 on success, 1 on failure
## - Echoes result string
##
## Usage:
## - function_name "arg1" --flag
##
function function_name() {
  ...
}
```

### Summary line

- Single line, imperative mood, capitalized.
- Keep it short and concrete.

### Parameters

- List parameters in call order.
- Include name, description, type, and requirement.
- Use types: string, number, boolean, array, variadic, flag.

### Globals

- Always split into:
  - `reads/listen`: globals read but not modified.
  - `mutate/publish`: globals modified or exported.
- Use `none` if a category has no globals.

### Returns

- Describe stdout/stderr output (if any).
- Document exit codes and meaning.
- If nothing is returned, write `none`.

### Usage

- Provide 1-3 realistic examples.
- Include common flags if applicable.

### Optional sections

- `Side effects:` for file operations, subprocesses, state changes.
- `See Also:` and `Examples:` for extended info.

### Section order and flexibility

- Section order is flexible; `e-docs` renders sections in the order it finds them.
- Text before the first section header is treated as the description.
- Only these headers are parsed into sections: `Parameters`, `Globals`,
  `Side effects`, `Returns`, `Usage`, `References`, `Categories`.
- Unknown headers are treated as plain text inside the current section.
- Header names are case-sensitive; use exact spelling.

### Authoring template (replace placeholders)

`e-docs` does not process Mustache. Use this as a local authoring aid and
replace all placeholders before committing.

```bash
##
## {{summary}}
##
## Parameters:
## - {{param1}} - {{desc}}, {{type}}, required
## - {{param2}} - {{desc}}, {{type}}, required
## - {{param3}} - {{desc}}, {{type}}, optional|default: {{value}}
##
## Globals:
## - reads/listen: {{globals_read}}
## - mutate/publish: {{globals_write}}
##
## Side effects:
## - {{side_effects}}
##
## Returns:
## - {{return_value}}
##
## Usage:
## - {{example_1}}
##
function {{function_name}}() {
  ...
}
```

## e-docs Tags

`e-docs` supports inline tags inside `##` documentation blocks to control
output and metadata. Tags use the `@{...}` format and can appear in the summary
line or anywhere within the doc block.

Supported tags:

- `@{internal}` - Skip this function in generated docs.
- `@{ignore}` - Skip this function in generated docs (explicit exclusion).
- `@{deprecated:msg}` - Mark as deprecated with a short reason.
- `@{since:version}` - Mark the version the function was introduced.

Examples:

```bash
##
## @{internal}
## Normalize temporary state for internal callers
##
## Parameters:
## - $1: raw_value - Raw value to normalize, string, required
##
## Returns:
## - 0 on success, echoes normalized value
##
function _Module::normalize() { ... }
```

```bash
##
## @{deprecated:use "new:func" instead}
## @{since:2.4.0}
## Process input using legacy algorithm
##
## Parameters:
## - input - Input string, string, required
##
## Returns:
## - 0 on success
##
function legacy:process() { ... }
```

## Global Variables

- Declare globals in the global section near the top of the file.
- Naming:
  - Constants: `UPPER_SNAKE_CASE` with `readonly`.
  - Module globals: `__DOUBLE_UNDERSCORE_PREFIX` or existing module prefix.
  - Arrays: `declare -g -a` or `declare -g -A`.
- Document each global in two places:
  1) Module summary `## Globals:` list (name + purpose + default if relevant).
  2) Each function `## Globals:` list that reads or mutates it.

Example global declarations:

```bash
readonly MY_CONST="value"
__MY_PREFIX_STATE="ready"
declare -g -A __MY_PREFIX_CACHE
```

## Module Summary (End of File)

Place the module summary at the END of the file, after `${__SOURCED__:+return}`
and any initialization code. Include a `Globals` section listing all globals
defined in the module.

Template:

```bash
##
## Module: Descriptive Module Title
##
## One or two lines describing what the module provides.
##
## References:
## - demo: demo.example.sh
## - bin: tool.sh
## - documentation: docs/public/module.md
## - tests: spec/module_spec.sh
##
## Globals:
## - __MY_PREFIX_STATE - State flag, default: "ready"
## - __MY_PREFIX_CACHE - Cache map for lookups
##
## Key Features:
## - Short, user-facing capabilities
##
## Usage Pattern:
##   my:func "arg"
##
```

## Checklist

- [ ] Every function has a `##` doc block directly above it
- [ ] Parameters list includes type + requirement
- [ ] Globals list split into reads/listen and mutate/publish
- [ ] Returns section present (use `none` if applicable)
- [ ] Usage examples are realistic
- [ ] Module summary at end includes all globals
