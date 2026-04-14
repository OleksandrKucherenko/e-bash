# _arguments.sh

**Declarative Command-Line Argument Parser**

This module provides a declarative argument parsing system with auto-generated help.

## References

- demo: demo.args.sh, completion/demo.completion.sh
- bin: git.log.sh, git.verify-all-commits.sh, git.semantic-version.sh,
  version-up.v2.sh, vhd.sh, npm.versions.sh
- documentation: docs/public/arguments.md, docs/public/completion.md,
  docs/public/cli-strategy.md
- tests: spec/arguments_spec.sh, spec/arguments_completion_spec.sh,
  spec/arguments_parser_edge_cases_spec.sh, spec/arguments_stress_spec.sh,
  spec/arguments_scoped_spec.sh, spec/arguments_validation_spec.sh

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
    - [`args:completion`](#argscompletion)
    - [`args:completion:install`](#argscompletioninstall)
    - [`args:d`](#argsd)
    - [`args:dispatch`](#argsdispatch)
    - [`args:e`](#argse)
    - [`args:i`](#argsi)
    - [`args:reset`](#argsreset)
    - [`args:scope`](#argsscope)
    - [`args:t`](#argst)
    - [`args:unbundle`](#argsunbundle)
    - [`args:v`](#argsv)
    - [`args:validate`](#argsvalidate)
    - [`parse:arguments`](#parsearguments)
    - [`parse:exclude_flags_from_args`](#parseexclude_flags_from_args)
    - [`parse:extract_output_definition`](#parseextract_output_definition)
    - [`parse:mapping`](#parsemapping)
    - [`print:help`](#printhelp)

<!-- /TOC -->

---

### args:completion

Generate shell completion script from ARGS_DEFINITION metadata

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `shell_type` | string | required | Target shell: "bash" or "zsh" |
| `script_name` | string | required | Name of the script/command |
| `output_file` | string | optional | Optional file path (default: stdout) |

#### Globals

- reads/listen: ARGS_DEFINITION, lookup_arguments, index_to_*,
                args_to_description
- mutate/publish: none (outputs to stdout or file)

#### Usage

```bash
args:completion bash myscript
args:completion zsh myscript /path/to/_myscript
```

---

### args:completion:install

Install completion script to the appropriate OS directory
Discovers the correct completion directory for the target shell,
creates it if necessary, and writes the generated script.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `shell_type` | string | required | "bash" or "zsh" |
| `script_name` | string | required | Command name for completion |

#### Globals

- reads/listen: ARGS_DEFINITION, lookup_arguments, etc.
- mutate/publish: none (writes file, outputs path to stdout)

#### Usage

```bash
args:completion:install bash myscript
args:completion:install zsh myscript
```

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

### args:dispatch

Auto-dispatch built-in flags after argument parsing.
Handles --version, --debug, --completion, and --install-completion
so that individual scripts do not need to repeat this boilerplate.
NOTE: --help is NOT handled here (scripts have custom help patterns).
The function exits the process (exit 0) when a handled flag is detected,
so it must be called AFTER parse:arguments.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: version, DEBUG, completion, install_completion,
                BASH_SOURCE (to derive the script name)
- mutate/publish: DEBUG (for --debug)

#### Usage

```bash
args:dispatch   # call right after parse:arguments
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

### args:reset

Reset all parser state for a fresh parse cycle.
Clears lookup arrays, metadata arrays, and ARGS_UNPARSED.
Use between scoped parse phases so the next parse starts clean.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- mutate/publish: lookup_arguments, index_to_outputs, index_to_args_qt,
                 index_to_default, index_to_keys, args_to_description,
                 args_to_group, group_to_order, args_to_envs,
                 args_to_defaults, ARGS_UNPARSED

#### Usage

```bash
args:reset   # call between parse phases
```

---

### args:scope

Run a scoped parse: reset state, set definition from named variable, parse.
Takes a variable NAME (by reference) containing the ARGS_DEFINITION string.
Scopes are pre-declared as named variables and passed by name.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `scope_var` | string | required | Name of variable holding ARGS_DEFINITION string |
| `args` | string array | variadic | Arguments to parse |

#### Globals

- reads/listen: variable referenced by scope_var
- mutate/publish: ARGS_DEFINITION, all parse:arguments globals

#### Usage

```bash
DEPLOY_SCOPE="--replicas=replicas:1:1 --region=region:us-east-1:1"
  args:scope DEPLOY_SCOPE "${ARGS_UNPARSED[@]}"
```

---

### args:t

Register a type/validation rule for an argument flag

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `flag` | string | required | Argument flag name |
| `rule` | string | required | Validation rule string |
| `"enum:val1,val2,val3"` | string | required | value must be one of listed strings |
| `"int:min:max"` | string | required | integer in range (empty min/max = unbounded) |
| `"float:min:max"` | string | required | float in range (empty min/max = unbounded) |
| `"string:min_len:max_len"` | string | required | string length bounds |
| `"pattern:regex"` | string | required | POSIX extended regex match |

#### Globals

- reads/listen: none
- mutate/publish: args_to_type

#### Usage

```bash
args:t "--format" "enum:json,csv,text"
args:t "--count" "int:1:100"
args:t "--ratio" "float:0.0:1.0"
args:t "--name" "string:2:50"
args:t "--email" "pattern:^[^@]+@[^@]+$"
```

---

### args:unbundle

Decompose bundled short options into individual flags.
Expands tokens like -abc into -a -b -c so that parse:arguments
can process each flag individually. Long options (--flag) and
non-flag arguments are passed through unchanged.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `args` | string array | variadic | Command-line arguments to expand |

#### Globals

- reads/listen: none
- mutate/publish: none (outputs expanded args to stdout, one per line)

#### Usage

```bash
readarray -t expanded < <(args:unbundle "$@")
  parse:arguments "${expanded[@]}"
Or inline:
  eval "set -- $(args:unbundle "$@" | xargs printf '%q ')"
  parse:arguments "$@"
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

### args:validate

Validate all parsed arguments against their declared type rules.
Checks each variable that has a type rule registered via args:t.
Only validates variables that are currently set (skips unset).
Returns 1 on first validation failure with error message to stderr.

#### Parameters

| Name | Type | Default | Description |
|------|------|---------|-------------|

#### Globals

- reads/listen: args_to_type, lookup_arguments, index_to_outputs
- mutate/publish: none

#### Usage

```bash
args:validate || exit 1
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

