# Shell Completion

The `_arguments.sh` module includes built-in shell completion generation. It
reads `ARGS_DEFINITION` metadata and produces completion scripts for **Bash**
and **Zsh** with zero extra configuration.

## Quick Start

```bash
source "$E_BASH/_arguments.sh"

# Generate bash completion
args:completion bash myscript > ~/.local/share/bash-completion/completions/myscript

# Generate zsh completion
args:completion zsh myscript > ~/.zsh/completion/_myscript
```

## API

### `args:completion <shell_type> <script_name> [output_file]`

Generate a completion script from the current `ARGS_DEFINITION`.

| Parameter     | Description                           | Required |
|---------------|---------------------------------------|----------|
| `shell_type`  | Target shell: `bash` or `zsh`         | yes      |
| `script_name` | Command name for completion binding   | yes      |
| `output_file` | File path (default: stdout)           | no       |

The function calls `parse:mapping` automatically if the lookup arrays are
empty, so it works whether you call it before or after `parse:arguments`.

### Helper Functions

| Function                | Description                                      |
|-------------------------|--------------------------------------------------|
| `_args:get:all_flags`   | Space-separated list of all flags (no positionals)|
| `_args:get:value_flags` | Flags that expect a value (`args_qt > 0`)        |
| `_args:get:description` | Description text for a given flag                |

## Bash Completion

The generated Bash script uses the standard `complete -F` mechanism.

Features:
- Integrates with `bash-completion` package (`_init_completion`) when available
- Falls back to manual `COMP_WORDS` parsing
- Offers flag completion when the cursor starts with `-`
- Provides file completion for value flags

### Installation

```bash
# System-wide
args:completion bash myscript | sudo tee /etc/bash_completion.d/myscript

# Per-user
args:completion bash myscript > ~/.local/share/bash-completion/completions/myscript

# Current session only
source <(args:completion bash myscript)
```

## Zsh Completion

The generated Zsh script uses the `_arguments` builtin with proper `compdef`
registration.

Features:
- Grouped flag aliases using `(alias1 alias2)'{alias1,alias2}'[desc]` syntax
- Descriptions from `args:d` are embedded in the completion spec
- Value flags get `:value:_files` for automatic file completion

### Installation

```bash
# Place in fpath
args:completion zsh myscript > "${fpath[1]}/_myscript"
autoload -U compinit && compinit

# Or add a custom directory
mkdir -p ~/.zsh/completion
args:completion zsh myscript > ~/.zsh/completion/_myscript
# Add to .zshrc: fpath=(~/.zsh/completion $fpath)
```

## Self-Installing Pattern

Scripts can offer `--install-completion` as a convenience flag:

```bash
#!/usr/bin/env bash
source "$E_BASH/_arguments.sh"

export ARGS_DEFINITION="-h,--help -o,--output=output::1"

if [[ "$1" == "--install-completion" ]]; then
  shell="${2:-bash}"
  script_name="$(basename "$0")"
  case "$shell" in
    bash) args:completion bash "$script_name" \
            > ~/.local/share/bash-completion/completions/"$script_name" ;;
    zsh)  args:completion zsh "$script_name" \
            > ~/.zsh/completion/"_${script_name//[^a-zA-Z0-9_]/_}" ;;
  esac
  echo "Completion installed for $shell. Restart your shell to activate."
  exit 0
fi

parse:arguments "$@"
```

## Example

See `demos/demo.completion.sh` for a working example that generates
completion scripts for itself.

```bash
# Generate and inspect
demos/demo.completion.sh --generate-completion bash
demos/demo.completion.sh --generate-completion zsh
```

## Limitations

- Fish shell is not yet supported
- Dynamic value completion (e.g. git branches) requires manual extension
- Positional arguments (`$1`, `$2`) are excluded from completion output
- Enum value completion (like `--format text|json`) needs custom handling
  per the `demo.curl.bash` pattern
