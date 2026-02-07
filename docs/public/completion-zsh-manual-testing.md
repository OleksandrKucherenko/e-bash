# Zsh Completion Manual Testing

This guide shows how to manually verify completion generated from `_arguments.sh`
works in a real Zsh terminal.

## Scope

Target shell: **Zsh**

Test subject: `demos/demo.completion.sh`

## Prerequisites

Run from repo root:

```bash
cd /path/to/e-bash
export REPO="$(pwd)"
```

Ensure the demo command is available on `PATH` with the same name used by
`compdef`:

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$REPO/demos/demo.completion.sh" "$HOME/.local/bin/demo.completion.sh"
chmod +x "$REPO/demos/demo.completion.sh"
export PATH="$HOME/.local/bin:$PATH"
hash -r
```

## 1. Generate Completion (Manual)

```bash
"$REPO/demos/demo.completion.sh" --generate-completion zsh > /tmp/_demo_completion_sh
head -n 8 /tmp/_demo_completion_sh
```

Expected output includes:

- `#compdef demo.completion.sh`
- `_arguments -s -S`

## 2. Install Completion

### Option A: auto-install via API wrapper

```bash
"$REPO/demos/demo.completion.sh" --install-completion zsh
```

Expected:

- prints `Completion installed: <path>`
- may print a note about rebuilding `~/.zcompdump`

### Option B: manual install to user completion dir

```bash
mkdir -p "$HOME/.zsh/completions"
cp /tmp/_demo_completion_sh "$HOME/.zsh/completions/_demo_completion_sh"
```

## 3. Load Completion In Current Zsh Session

Run these commands in Zsh:

```zsh
fpath=("$HOME/.zsh/completions" $fpath)
autoload -Uz compinit
rm -f "$HOME/.zcompdump"
compinit -i
```

## 4. Verify Registration

```zsh
echo "${_comps[demo.completion.sh]}"
whence -w _demo_completion_sh
```

Expected:

- `_comps[demo.completion.sh]` is `_demo_completion_sh`
- `_demo_completion_sh` exists (autoload/function)

## 5. Interactive Tab Tests

In the same Zsh session, type these and press `Tab`:

1. `demo.completion.sh --<Tab>`
Expected suggestions include `--help`, `--version`, `--verbose`, `--output`, `--format`.

2. `demo.completion.sh -<Tab>`
Expected suggestions include `-h`, `-v`, `-o`, `-f`.

3. `demo.completion.sh --output <Tab>`
Expected: filesystem path/file suggestions.

4. `demo.completion.sh -o <Tab>`
Expected: filesystem path/file suggestions.

5. `demo.completion.sh -f <Tab>`
Expected today: filesystem suggestions (enum values are not auto-generated yet).

## 6. Smoke Run

```bash
demo.completion.sh --verbose -o /tmp/result.txt -f json
```

Expected: script runs and prints parsed values.

## Troubleshooting

- No completion at all:
  - confirm command is in `PATH`: `command -v demo.completion.sh`
  - confirm mapping: `echo "${_comps[demo.completion.sh]}"`
  - rebuild cache: `rm -f ~/.zcompdump && compinit -i`

- Completion file ignored:
  - ensure file name starts with `_` (example: `_demo_completion_sh`)
  - ensure its directory is in `fpath`

- Completion works only after restart:
  - expected if `compinit` cache was stale; rebuild `~/.zcompdump`
