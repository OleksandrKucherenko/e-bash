# Arguments Parsing in E-Bash

## Overview

The `_arguments.sh` script provides a powerful yet simple command-line argument parsing system for bash scripts. It offers a declarative approach to defining and working with command-line arguments, making it easier to create consistent, user-friendly command-line interfaces.

<!-- TOC -->

- [Arguments Parsing in E-Bash](#arguments-parsing-in-e-bash)
  - [Overview](#overview)
  - [Best Practices](#best-practices)
  - [Basic Structure](#basic-structure)
  - [Argument Definition Syntax](#argument-definition-syntax)
    - [NOT FULLY SUPPORTED CASES WITH WORKAROUNDS](#not-fully-supported-cases-with-workarounds)
  - [Types of Arguments](#types-of-arguments)
    - [Boolean Flags](#boolean-flags)
    - [Value Arguments](#value-arguments)
    - [Arguments with Default Values](#arguments-with-default-values)
    - [Arguments with Multiple Parameters](#arguments-with-multiple-parameters)
    - [Positional Arguments](#positional-arguments)
  - [Default Values](#default-values)
  - [Help Composing System](#help-composing-system)
    - [Defining Argument Help](#defining-argument-help)
    - [Environment Variables](#environment-variables)
    - [Default Values](#default-values)
    - [Displaying Help](#displaying-help)
  - [Complete Example](#complete-example)
  - [Advanced Usage](#advanced-usage)
    - [Pipeline Usage](#pipeline-usage)
    - [Handling Special Cases](#handling-special-cases)
    - [Compose Argument Definition by Function](#compose-argument-definition-by-function)
      - [Usage](#usage)
      - [Example](#example)
  - [Defaults Pre-fill](#defaults-pre-fill)
  - [Scoped Parsing](#scoped-parsing)
    - [Pattern A: Named Scopes](#pattern-a-named-scopes)
    - [Pattern B: COMPOSER Builder Functions](#pattern-b-composer-builder-functions)
    - [Key Functions](#key-functions)
  - [Type Validation](#type-validation)

<!-- /TOC -->

## Best Practices

1. **Pre-declare variables** to make shellcheck happy
2. **Group related arguments** in the help system
3. **Use consistent naming** for arguments
4. **Validate the number of arguments** to avoid unexpected behavior
5. **Provide clear help text** for each argument

For scripts with multiple commands and sub-commands, use scoped parsing (see [Scoped Parsing](#scoped-parsing) below) to define per-command flags and parse them in phases.

## Basic Structure

The argument parsing system follows this simplified workflow:

1. Define your expected arguments in the `ARGS_DEFINITION` variable
2. Include the `_arguments.sh` script
3. Access parsed arguments via environment variables
4. Optionally define help text with `args:d` function

## Argument Definition Syntax

The `ARGS_DEFINITION` variable uses a specific pattern to define arguments:

```
"{argument_index},-{short},--{alias}={output_variable}:{default_value}:{args_quantity}"
```

Where:
- `{argument_index}`: (Optional) Position of a positional argument (e.g., `$1`, `$2`)
- `-{short}`: Short version of argument (e.g., `-h`), can be used multiple times `-h,-H,-?`
- `--{alias}`: Long version of argument (e.g., `--help`), can be used multiple times `--help,--show-help`
- `{output_variable}`: Variable name to store the argument value
- `{default_value}`: Default value if argument is provided without a value. Use `::` as a `no deafult value`.
- `{args_quantity}`: Number of parameters this argument expects

### WORKAROUNDS AND SPECIAL FEATURES

**Counter flags (`-vvv`):** Define separate flags mapping to the same variable with different defaults:

```bash
ARGS_DEFINITION="-v=verbose:1 -vv=verbose:2 -vvv=verbose:3"
```

**Short option bundling (`-abc`):** Use `args:unbundle` to decompose before parsing:

```bash
readarray -t expanded < <(args:unbundle "$@")
parse:arguments "${expanded[@]}"
# -abc becomes -a -b -c, then each is parsed individually
```

**End-of-options (`--`):** Natively supported. Everything after `--` is treated as positional:

```bash
./script.sh --verbose -- --not-a-flag file.txt
# --verbose is parsed as flag, --not-a-flag becomes positional
```

**Flag/no-flag toggle (`--flag`/`--no-flag`):** Two definitions mapping to same variable:

```bash
ARGS_DEFINITION="--dry-run=dry:true --no-dry-run=dry:false"
# --dry-run sets dry=true, --no-dry-run sets dry=false, last wins
```

**Argument order:** All flags are treated as global and can appear in any position. `script.sh arg1 --flag` is equivalent to `--flag arg1`. For subcommand-specific flags, use scoped parsing (see below).

## Types of Arguments

### Boolean Flags

Simple flags that set a value to "1" when present:

```bash
# Definition
export ARGS_DEFINITION=" -h,--help"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Usage
./script.sh --help
# Result: help=1
```

### Value Arguments

Arguments that accept a value:

```bash
# Definition
export ARGS_DEFINITION=" -d,--debug=DEBUG:*"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Usage
./script.sh --debug=verbose
# Result: DEBUG="verbose"

./script.sh --debug
# Result: DEBUG="*"
```

### Arguments with Default Values

Arguments that have default values when specified without a value:

```bash
# Definition
export ARGS_DEFINITION=" --version=version:1.0.0"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Usage
./script.sh --version
# Result: version="1.0.0"
```

### Arguments with Multiple Parameters

Arguments that expect multiple parameters:

```bash
# Definition
export ARGS_DEFINITION=" -n,--new=args_new::2"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Usage
./script.sh --new first second
# Result: args_new="first second"
```

### Positional Arguments

Arguments based on position rather than flags:

```bash
# Definition
export ARGS_DEFINITION=" \$1,<command>=args_command:default:1"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Usage
./script.sh execute
# Result: args_command="execute"
```

> Notes: in sample `,<command>` part ignored by parser. This is a placeholder for positional arguments. Can be used `[command]` for example.

## Default Values

Default values can be specified in the definition:

```bash
# Format: --flag=variable:default_value
export ARGS_DEFINITION=" --debug=DEBUG:*"

# Include arguments parser
source "$E_BASH/_arguments.sh"
```

If a default value is provided and the flag is used without a value, the default is applied.

> Note: This is a special case. DEBUG variable can be provided by shell, but parsing will override it, if flag is used, without any notice. Can be used `" --debug:DEBUG:${DEBUG:-"demo"}:*"` pattern as a valid workaround.

## Help Composing System

The `_arguments.sh` script includes a help system that allows you to:

1. Define argument descriptions
2. Group arguments by category
3. Specify environment variables
4. Set default values for help display

### Defining Argument Help

```bash
# Define arguments
ARGS_DEFINITION=" -h,--help"
ARGS_DEFINITION+=" --version=version:1.0.0"
ARGS_DEFINITION+=" -s,--switch=switch"
export ARGS_DEFINITION

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Format: args:d 'flag' 'description' 'group' priority
args:d '-h' 'Show help and exit.' "global"
args:d '--version' 'Show version and exit.' "global" 2
args:d '-s' 'Switch to another environment.'

# Will fail, `-d` option is not defined in `ARGS_DEFINITION`!
args:d '-d' 'Enable debug output.' "global"
```

The `args:d` function accepts the following parameters:

1. `'flag'` - The flag identifier (use the shortest form, e.g., '-h' not '--help')
2. `'description'` - Human-readable description of the argument
3. `'group'` (optional) - Category grouping for the argument (e.g., "global", "commands"), default: "common"
4. `priority` (optional) - Integer value for sorting within groups (lower numbers appear first). default: 100

Example:
```bash
args:d '-h' 'Show help text' "global" 1
```


### Environment Variables

Specify related environment variables in help text:

```bash
# Define arguments
ARGS_DEFINITION+=" --debug=DEBUG:*"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Format: args:e 'flag' 'ENV_VAR=value' (args:e - argument environment variable)
args:e '--debug' 'DEBUG=demo'
```

### Default Values

Display default values in help text:

```bash
# Define arguments
export ARGS_DEFINITION=" --debug=DEBUG:*"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Format: args:v 'flag' 'default value' (args:v - argument default value)
args:v '--debug' '<empty>'
```

### Displaying Help

Use the `print:help` function to display help information:

```bash
# Define arguments
export ARGS_DEFINITION=" -h,--help"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Define help description
args:d '-h' 'Show help and exit.'

[[ "$help" == "1" ]] && {
  echo "Usage: ${BASH_SOURCE[0]} [options]"
  echo ""
  print:help
}
```

## Complete Example

Here's a complete example of argument parsing:

```bash
#!/usr/bin/env bash

# Pre-declare variables for shellcheck
declare help version debug args_command

# Define arguments
ARGS_DEFINITION=""
ARGS_DEFINITION+=" -h,--help"
ARGS_DEFINITION+=" --version=version:1.0.0"
ARGS_DEFINITION+=" -d,--debug=DEBUG:*"
ARGS_DEFINITION+=" \$1,<command>=args_command:default:1"
export ARGS_DEFINITION

# Include arguments parser
source "$E_BASH/_arguments.sh"

# Define help text
args:d '-h' 'Show help and exit.' "global"
args:d '--version' 'Show version and exit.' "global"
args:d '-d' 'Enable debug output.' "global"
args:d "\$1" 'Command to execute.' "commands"

# Show help if requested
[[ "$help" == "1" ]] && {
  echo "My Script - Example tool"
  echo "Usage: ${BASH_SOURCE[0]} [options] [command]"
  echo ""
  print:help
  exit 0
}

# Use the parsed arguments
echo "Command: $args_command"
echo "Debug mode: $DEBUG"
echo "Version: $version"
```

## Advanced Usage

### Pipeline Usage

The help definition functions can be used in a pipeline:

```bash
# Define arguments
ARGS_DEFINITION+=" -s,--switch=switch"

# Include arguments parser
source "$E_BASH/_arguments.sh"

# ERROR! args:d works in pipeline, but it has a sideeffect: pipelines are 
# executed in sub-shell which make all changes isolated in own scope and 
# description will not be added to main script help.
args:d '-s' 'Switch to another environment.' | (
  read -r flag
  echo "Processing flag: $flag"
)
# Output: Processing flag: -s
```

### Handling Special Cases

If you need to handle special cases where the argument might have an empty value:

```bash
# Handle empty values with <empty> as placeholder
ARGS_DEFINITION+=" -i,--id=args_pno::1"

# Include arguments parser
source "$E_BASH/_arguments.sh"

./script.sh --id=""
# Result: args_pno="<empty>"
```

### Compose Argument Definition by Function

You can programmatically compose argument definition strings using the `args:i` function. This is useful for scripts that need to build ARGS_DEFINITION dynamically or in a more readable way.

> Note: By default `source _arguments.sh` will trigger parsing of the script parameters and ARGS_DEFINITION.
> Usually this should be done later, when we compose script arguments definition with the `args:i` function.
> So to skip initial parsing, you should set `export SKIP_ARGS_PARSING=1` before sourcing the script. 
> Can be used any value for `SKIP_ARGS_PARSING` variable, we check only if variable defined and not empty.

#### Usage

```bash
args:i "output_variable" [options]
```

- `output_variable`: Name of the variable to store the argument value. Will be dynamically created by eval during parsing.
- Options (can use short or long form):
  - `-h <desc>`, `--help <desc>`: Description for help output
  - `-a <alias>`, `--alias <alias>`: Add an alias/flag (repeatable, e.g. `-a "-f" -a "--foo"`)
  - `-q <quantity>`, `--quantity <quantity>`: Number of arguments this option expects
  - `-d <default>`, `--default <default>`: Initial/default value

#### Example

```bash
# Compose a definition for an argument with short and long flags, default value, and description
args:i FORCE -a "-f" -a "--force" -q 1 -d "0" \
  -h "Use this flag to force potentially harmful actions without confirmation" 

# or equivalently with long options:
args:i FORCE --alias "\$1,-f,--force" --quantity 1 --default "0" \
  --help "Use this flag to force potentially harmful actions without confirmation"

# Output:
# $1,-f,--force=FORCE:0:1
```

You can use this in a script to build ARGS_DEFINITION, for example:

```bash
export COMPOSED_ARGS_DEFINITION="
  $(args:i VERBOSE  -a "-v" -a "--verbose" -d "" -h "Enable verbose mode") 
  $(args:i OUTPUT   -a "-o" -a "--output"  -d "result.txt" -h "Output file")
  $(args:i DEBUG    -a "-d" -a "--debug"   -d "*" -h "Enable debug mode")
  $(args:i DEBUG    -a "--no-debug" -d "-*" -h "Disable Any debug output")
"
eval "$COMPOSED_ARGS_DEFINITION" >/dev/null
```

This approach improves maintainability and readability, especially for scripts with many arguments.

## Defaults Pre-fill

Value flags (`args_qt > 0`) with default values are automatically pre-filled before CLI parsing. If the user provides a value on the command line, it overrides the default. Boolean flags (`args_qt == 0`) are NOT pre-filled.

```bash
ARGS_DEFINITION="--port=port:8080:1 --host=host:0.0.0.0:1 --verbose"

source "$E_BASH/_arguments.sh"

# Without any CLI flags:
# port="8080" (pre-filled from default)
# host="0.0.0.0" (pre-filled from default)
# verbose is unset (boolean, not pre-filled)

# With: ./script.sh --port 9090
# port="9090" (overridden by CLI)
# host="0.0.0.0" (kept default)
```

## Scoped Parsing

For CLI tools with subcommands, use scoped parsing to define per-command flags:

### Pattern A: Named Scopes

Pre-declare scopes as variables and pass by name to `args:scope`:

```bash
export SKIP_ARGS_PARSING=1
source "$E_BASH/_arguments.sh"

# Pre-declare scopes
GLOBAL_SCOPE="--verbose --config=config:prod.toml:1 \$1=command::1"
DEPLOY_SCOPE="--replicas=replicas:1:1 --region=region:us-east-1:1"
SERVE_SCOPE="--port=port:8080:1 --host=host:0.0.0.0:1"

# Phase 1: parse global flags + extract command
ARGS_DEFINITION="$GLOBAL_SCOPE"
parse:arguments "$@"
# config="prod.toml" (default pre-filled)
# ARGS_UNPARSED has remaining args not consumed by global scope

# Phase 2: parse command-specific flags
case "$command" in
  deploy) args:scope DEPLOY_SCOPE "${ARGS_UNPARSED[@]}" ;;
  serve)  args:scope SERVE_SCOPE  "${ARGS_UNPARSED[@]}" ;;
esac
# replicas="1", region="us-east-1" (defaults pre-filled)
```

### Pattern B: COMPOSER Builder Functions

For complex CLIs, wrap the COMPOSER pattern in scope functions:

```bash
function scope:deploy() {
  args:reset
  args:i --replicas -q 1 -v 1 -d "Number of replicas" -g deploy
  args:i --region   -q 1 -v us-east-1 -d "AWS region" -g deploy
  args:t "--replicas" "int:1:100"
  args:t "--region" "enum:us-east-1,us-west-2,eu-west-1"
  parse:arguments "$@"
  args:validate || return 1
}

case "$command" in
  deploy) scope:deploy "${ARGS_UNPARSED[@]}" ;;
esac
```

### Key Functions

- `ARGS_UNPARSED` — array collecting unknown flags and unmatched positionals from each parse
- `args:reset` — clears all parser state for a fresh scope
- `args:scope VAR_NAME "${args[@]}"` — convenience wrapper: reset + set definition from named variable + parse

## Type Validation

Register validation rules with `args:t` and check with `args:validate`:

```bash
args:t "--format" "enum:json,csv,text"        # one of listed values
args:t "--count"  "int:1:100"                  # integer in range
args:t "--ratio"  "float:0.0:1.0"             # float in range
args:t "--name"   "string:2:50"               # string length bounds
args:t "--email"  "pattern:^[^@]+@[^@]+$"     # regex match

parse:arguments "$@"
args:validate || exit 1
# Error: --count value '200' exceeds maximum 100
```

Supported types:

| Type | Format | Example |
|------|--------|---------|
| `enum` | `enum:val1,val2,val3` | `enum:json,csv,text` |
| `int` | `int:min:max` | `int:1:65535` |
| `float` | `float:min:max` | `float:0.0:1.0` |
| `string` | `string:min_len:max_len` | `string:2:50` |
| `pattern` | `pattern:regex` | `pattern:^[a-z]+$` |

Empty bounds mean unbounded (e.g., `int::100` = no minimum, max 100).
