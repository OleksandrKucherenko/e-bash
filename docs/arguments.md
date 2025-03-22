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

<!-- /TOC -->

## Best Practices

1. **Pre-declare variables** to make shellcheck happy
2. **Group related arguments** in the help system
3. **Use consistent naming** for arguments
4. **Validate the number of arguments** to avoid unexpected behavior
5. **Provide clear help text** for each argument

If you need to create script that accepts multiple commands, sub-commands - you have to develop logic separately. parser will only help you with the initial parsing and placing arguments into specific variables, after that you apply your business logic and validations.

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

### NOT FULLY SUPPORTED CASES WITH WORKAROUNDS

Not supported use case that are common for linux commands parsing:

- `-vvv` - multiple flags combined into one argument. As workaround you can define multiple commands: ` -v=verbose1:: -vv=verbose2:: -vvv=verbose3::`. It has limitations in case you want to use to many different simple flags.

- `--` is not supported. In Bash and many Unix-like command-line utilities, the `--` is used as an "end-of-options" separator. Here’s what that means:
  - End of Options: When you include `--` in a command or script, it tells the command-line parser to treat everything that follows as positional parameters or arguments, not as options—even if those arguments start with a dash (-).
  - As a workaround: you should pre-filter arguments before source the `_arguments.sh` script, otherwise parser will skip it and continue with other arguments.

- Order of arguments is not supported. All flags are treated as global and can be used in any place of arguments line. `script.sh arg1 --flag-for-arg1` will be treated as `--flag-for-arg1 arg1`. More complicated cases: `command --flag subcommand --flag2 subsubcommand` === `--flag --flag2 command subcommand subsubcommand`. Be careful with this and support restriction by custom logic.

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
