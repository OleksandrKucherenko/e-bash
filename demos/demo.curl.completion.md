# Demo curl completion PoC

This PoC demonstrates Bash and Zsh completion driven by `ARGS_DEFINITION` metadata from `_arguments.sh`.

## Commands

The mock CLI accepts subcommands:

- `get`, `post`, `head`, `put`, `delete`

## Flags

- `-h, --help`
- `-X, --request` (enum: `GET POST PUT DELETE HEAD`)
- `-H, --header`
- `-d, --data`
- `--url`
- `-v, --verbose`

## Easiest vs Elegant integration

### Easiest (separate shell implementations)
- Bash and Zsh each maintain their own completion glue.
- Use a single metadata source (`_arguments.sh`) but keep shell-specific adapters.
- Faster to implement and test; minimal abstraction.

### Most elegant (shared spec + thin adapters)
- Define a shared completion spec from `_arguments.sh` metadata.
- Use a small Bash/Zsh adapter to interpret the spec.
- Requires extra scaffolding, but keeps behavior consistent across shells.

## Bash usage

```bash
alias demo-curl="$(pwd)/demos/demo.curl.sh"
source demos/demo.curl.bash
```

## Zsh usage

```zsh
alias demo-curl="$(pwd)/demos/demo.curl.sh"
fpath=("$(pwd)/demos" $fpath)
autoload -U compinit && compinit
```

## Auto-install completion

The demo script can install completion files automatically:

```bash
# Use explicit shell or pass current shell path, for example: "$SHELL"
demos/demo.curl.sh --completion-install zsh
demos/demo.curl.sh --completion-install bash
```

After installation, the script prints activation instructions for the selected
shell.
