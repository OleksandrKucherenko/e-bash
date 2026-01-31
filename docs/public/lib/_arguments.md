# _arguments.sh

**Declarative Command-Line Argument Parser**

This module provides a declarative argument parsing system with auto-generated help.

## References

- demo: demo.args.sh
- bin: git.log.sh, git.verify-all-commits.sh, git.semantic-version.sh,
  version-up.v2.sh, vhd.sh, npm.versions.sh
- documentation: docs/public/arguments.md
- tests: spec/arguments_spec.sh

## Module Globals

- E_BASH - Path to .scripts directory
- ARGS_NO_FLAGS - Array of arguments with flags removed
- ARGS_DEFINITION - Argument definitions string, default: "-h,--help -v,--version=:1.0.0 --debug=DEBUG:*"
- lookup_arguments - Associative array: flag name -> definition index
- index_to_outputs - Associative array: index -> variable name
- index_to_args_qt - Associative array: index -> argument quantity
- index_to_default - Associative array: index -> default value
- index_to_keys - Associative array: index -> flag keys
- args_to_description - Associative array: flag -> help text
- args_to_group - Associative array: flag -> group name
- group_to_order - Associative array: group -> display order
- args_to_envs - Associative array: flag -> environment variable
- args_to_defaults - Associative array: flag -> default value
- SKIP_ARGS_PARSING - Set to skip argument parsing during sourcing

## Additional Information

### Definition Format

- "{index}[,-{short},--{long}=]{output}[:{default}[:{quantity}]]"
- Examples:
  - "-h,--help"           -> boolean flag
  - "-v,--verbose"       -> boolean flag
  - "--port=:8080"       -> --port with default 8080
  - "--file=::1"         -> --file expects 1 argument
  - "$1,--output=::1"    -> first positional arg
  - "-c,--config=file:default:1" -> full definition

### Usage Pattern

  export ARGS_DEFINITION="--verbose --output=file.txt --port=:8080"
  source "$E_BASH/_arguments.sh"
  # Variables $verbose, $output, $port are now set


---

## Functions

<!-- TOC -->

- [_arguments.sh](#_argumentssh)
    - [`args:d`](#argsd)
    - [`args:e`](#argse)
    - [`args:i`](#argsi)
    - [`args:v`](#argsv)
    - [`parse:arguments`](#parsearguments)
    - [`parse:exclude_flags_from_args`](#parseexclude_flags_from_args)
    - [`parse:extract_output_definition`](#parseextract_output_definition)
    - [`parse:mapping`](#parsemapping)
    - [`print:help`](#printhelp)

<!-- /TOC -->

---

### args:d

Add description for an argument flag (for help output)

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `flag` | string | required | Argument flag name |
| `description` | string | required | Help text for the argument |
| `group` | string | default: "common" | Group name for organization |
| `order` | integer | default: 100 | Display order within group |

#### Globals

- reads/listen: group_to_order
- mutate/publish: args_to_description, args_to_group, group_to_order

#### Usage

```bash
args:d "--verbose" "Enable verbose output" "options" 10
args:d "-h" "Show help message"
```

---

### args:e

Map argument flag to environment variable name

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `flag` | string | required | Argument flag name (or read from stdin) |
| `env` | string | optional | Environment variable name (or read flag from stdin) |

#### Globals

- reads/listen: none
- mutate/publish: args_to_envs

#### Usage

```bash
args:e "--config" "APP_CONFIG"           # direct mapping
echo "--output" | args:e "OUTPUT_FILE"   # pipe mode
```

---

### args:i

Compose argument definition string for ARGS_DEFINITION

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `output` | string | required | Variable name for output |
| `-h,` | string | optional | -help - Description text |
| `-g,` | string | optional | -group - Group name |
| `-a,` | string | optional | -alias - Comma-separated aliases |
| `-q,` | integer | optional | -quantity - Number of arguments to consume |
| `-d,` | string | optional | -default - Default value |

#### Globals

- reads/listen: none
- mutate/publish: none (outputs to stdout)

#### Usage

```bash
args:i config -h "Config file" -a "-c,--config" -d "/etc/app.conf"
# outputs: export ARGS_DEFINITION+=" -c,--config=config:/etc/app.conf"
```

---

### args:v

Set default value for an argument flag

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `flag` | string | required | Argument flag name (or read from stdin) |
| `defaults` | string | optional | Default value (or read flag from stdin) |

#### Globals

- reads/listen: none
- mutate/publish: args_to_defaults

#### Usage

```bash
args:v "--port" "8080"
echo "--timeout" | args:v "30"
```

---

### parse:arguments

Parse command-line arguments and assign values to output variables
This function iterates through arguments, handles flags with values via
skip-ahead buffering, and dynamically exports variables based on the
ARGS_DEFINITION pattern. It supports both flag-based (--flag value) and
positional ($1, $2) argument styles.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Script arguments to parse |

#### Globals

- reads/listen: lookup_arguments, index_to_outputs, index_to_args_qt, index_to_default
- mutate/publish: Creates exported variables for each parsed argument

#### Side Effects

- Exports variables based on argument definitions
- May exit with error=1 if insufficient arguments provided

#### Usage

```bash
export ARGS="--verbose --output=file.txt"
parse:arguments $ARGS
echo "$verbose" -> "1"
echo "$output" -> "file.txt"
```

---

### parse:exclude_flags_from_args

Remove all flag arguments (starting with --) from arguments array

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Array of arguments to filter |

#### Globals

- reads/listen: none
- mutate/publish: ARGS_NO_FLAGS

#### Side Effects

- Sets ARGS_NO_FLAGS global array

#### Usage

```bash
parse:exclude_flags_from_args "$@" && set -- "${ARGS_NO_FLAGS[@]}"
```

---

### parse:extract_output_definition

Extract variable name, default value, and quantity from argument definition

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `definition` | string | required | Argument key (e.g. "--cookies=first") |
| `full_definition` | string | required | Full definition string |

#### Globals

- reads/listen: none
- mutate/publish: none (outputs "variable|default|quantity")

#### Usage

```bash
result=$(parse:extract_output_definition "--cookies" "--cookies=first:default:1")
```

#### Returns

- Echoes "variable_name|default_value|args_quantity"

---

### parse:mapping

Parse ARGS_DEFINITION and build global lookup arrays for argument processing

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Arguments array (unused except for logging) |

#### Globals

- reads/listen: ARGS_DEFINITION
- mutate/publish: lookup_arguments, index_to_outputs, index_to_args_qt,
                 index_to_default, index_to_keys

#### Side Effects

- Declares/initializes global associative arrays

#### Usage

```bash
parse:mapping "$@"
```

---

### print:help

Print formatted help output for all defined arguments

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: args_to_description, args_to_group, group_to_order,
                args_to_envs, args_to_defaults, lookup_arguments,
                index_to_keys
- mutate/publish: none (outputs to stdout)

#### Side Effects

- Prints grouped, formatted help to stdout

#### Usage

```bash
print:help    # typically triggered by --help flag
```

