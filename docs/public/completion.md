# Shell Completion

The `_arguments.sh` module includes built-in shell completion generation. It
reads `ARGS_DEFINITION` metadata and produces completion scripts for **Bash**
and **Zsh** with zero extra configuration.

## Quick Start

```bash
source "$E_BASH/_arguments.sh"

# One-liner: auto-discover OS directory and install
args:completion:install bash myscript
args:completion:install zsh myscript

# Or generate to stdout for manual placement
args:completion bash myscript > ~/.local/share/bash-completion/completions/myscript
args:completion zsh myscript > ~/.zsh/completions/_myscript
```

## API

### `args:completion:install <shell_type> <script_name>`

Auto-discover the correct OS completion directory and write the generated
script there. Prints the installed file path to stdout.

| Parameter     | Description                           | Required |
|---------------|---------------------------------------|----------|
| `shell_type`  | Target shell: `bash` or `zsh`         | yes      |
| `script_name` | Command name for completion binding   | yes      |

**Bash** directory discovery order (first writable wins):
1. `$BASH_COMPLETION_USER_DIR/completions/` or `$XDG_DATA_HOME/bash-completion/completions/` or `~/.local/share/bash-completion/completions/`
2. `$HOMEBREW_PREFIX/share/bash-completion/completions/` (macOS)
3. `pkg-config --variable=completionsdir bash-completion` (Linux)
4. `/usr/share/bash-completion/completions/`, `/usr/local/share/bash-completion/completions/`

**Zsh** directory discovery order:
1. `$HOMEBREW_PREFIX/share/zsh/site-functions/` (macOS)
2. `/usr/local/share/zsh/site-functions/`, `/usr/share/zsh/site-functions/`
3. `~/.zsh/completions/` (per-user fallback)

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

| Function                    | Description                                        |
|-----------------------------|----------------------------------------------------|
| `_args:get:all_flags`       | Space-separated list of all flags (no positionals)  |
| `_args:get:value_flags`     | Flags that expect a value (`args_qt > 0`)           |
| `_args:get:description`     | Description text for a given flag                   |
| `_args:completion:dir`      | Discover the OS completion directory for a shell     |

## Bash Completion

The generated Bash script uses the standard `complete -F` mechanism.

Features:
- Integrates with `bash-completion` package (`_init_completion`) when available
- Falls back to manual `COMP_WORDS` parsing
- Offers flag completion when the cursor starts with `-`
- Provides file completion for value flags
- Bash-completion v2 **lazy-loads** from file name — just name the file after the command

### Installation

```bash
# Recommended: auto-install
args:completion:install bash myscript

# System-wide (requires root)
args:completion bash myscript | sudo tee /etc/bash_completion.d/myscript

# Per-user (bash-completion v2 auto-discovers this)
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
- `#compdef` header for `compinit` auto-discovery

### Installation

```bash
# Recommended: auto-install
args:completion:install zsh myscript

# Homebrew site-functions (macOS, already in fpath)
args:completion zsh myscript > "$(brew --prefix)/share/zsh/site-functions/_myscript"

# Custom directory (add to .zshrc: fpath=(~/.zsh/completions $fpath))
mkdir -p ~/.zsh/completions
args:completion zsh myscript > ~/.zsh/completions/_myscript

# After installing, rebuild the completion cache:
rm -f ~/.zcompdump; compinit
```

## Self-Installing Pattern

Scripts can offer `--install-completion` as a convenience flag:

```bash
#!/usr/bin/env bash

export SKIP_ARGS_PARSING=1
export ARGS_DEFINITION="-h,--help -o,--output=output::1"

source "$E_BASH/_arguments.sh"

if [[ "$1" == "--install-completion" ]]; then
  shell="${2:-bash}"
  file=$(args:completion:install "$shell" "$(basename "$0")")
  echo "Completion installed: $file"
  exit 0
fi

parse:arguments "$@"
```

**Important:** `SKIP_ARGS_PARSING` and `ARGS_DEFINITION` must be set
*before* `source "$E_BASH/_arguments.sh"`. The module auto-parses `$@`
during sourcing unless `SKIP_ARGS_PARSING` is set.

## Example

See `demos/demo.completion.sh` for a working example:

```bash
# Auto-install to OS directory
demos/demo.completion.sh --install-completion bash
demos/demo.completion.sh --install-completion zsh

# Generate and inspect
demos/demo.completion.sh --generate-completion bash
demos/demo.completion.sh --generate-completion zsh
```

For an end-to-end terminal validation flow (generation, installation, and
interactive Tab checks), see
`docs/public/completion-zsh-manual-testing.md`.

## OS Completion Directory Discovery

The `_args:completion:dir` function uses this priority for finding a writable
directory:

### Bash
```
$BASH_COMPLETION_USER_DIR/completions/
  └─ $XDG_DATA_HOME/bash-completion/completions/
      └─ ~/.local/share/bash-completion/completions/   (default per-user)
$HOMEBREW_PREFIX/share/bash-completion/completions/     (macOS)
pkg-config --variable=completionsdir bash-completion    (Linux)
/usr/share/bash-completion/completions/                 (system)
/usr/local/share/bash-completion/completions/           (system)
```

### Zsh
```
$HOMEBREW_PREFIX/share/zsh/site-functions/              (macOS, in fpath)
/usr/local/share/zsh/site-functions/                    (system)
/usr/share/zsh/site-functions/                          (system)
~/.zsh/completions/                                     (per-user fallback)
```

## Limitations

- Fish shell is not yet supported
- Dynamic value completion (e.g. git branches) requires manual extension
- Positional arguments (`$1`, `$2`) are excluded from completion output
- Enum value completion (like `--format text|json`) needs custom handling
  per the `demo.curl.bash` pattern
- Zsh per-user directory (`~/.zsh/completions/`) must be added to `fpath`
  manually in `.zshrc`
