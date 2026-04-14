# "xdg-open" Doesn't Work in WSL. Here's the Fix.

You're in WSL. You run `xdg-open https://google.com`. Nothing happens.

Or worse — you get an error, because there's no display server, no desktop environment, and `xdg-open` has no idea what to do inside a Linux kernel running on Windows.

Every WSL developer hits this. Links from `git`, `npm`, `gh`, `code` — anything that calls `xdg-open` — just silently fail.

## The Usual "Fix"

Most people end up with some version of this in their `.bashrc`:

```bash
export BROWSER="powershell.exe /c start"
```

It kinda works. Until it doesn't:

- Breaks on paths with spaces
- Breaks on file:// URLs
- Breaks on Linux paths that need `/mnt/c/` translation
- Doesn't detect which browser you want
- Doesn't work with tools that call `xdg-open` directly (not `$BROWSER`)
- PowerShell path resolution differs between PS5 and pwsh 7

## The Actual Fix

We built a proper `xdg-open` replacement for WSL that handles all of this:

```bash
brew install artfulbits-se/tap/e-bash
~/.e-bash/bin/wsl/xdg-open.sh --config
```

First run launches a wizard:

```
1. Select Windows launcher
   > PowerShell 7 (pwsh.exe)     [recommended]
     PowerShell 5 (powershell.exe)
     Command Prompt (cmd.exe)

2. Select browser
   > System default
     Chrome
     Firefox
     Edge
     Brave

3. Install shim to ~/.local/bin/xdg-open? [Y/n]
```

After setup, `xdg-open` just works:

```bash
xdg-open https://github.com          # opens in your chosen browser
xdg-open ~/documents/report.pdf      # translates path, opens in Windows
xdg-open /mnt/c/Users/me/file.txt    # passes through to Windows
```

## What It Handles

| Scenario | One-liner hack | e-bash xdg-open |
|----------|---------------|-----------------|
| `https://` URLs | Works | Works |
| `file:///home/...` paths | Breaks | Translates to `\\wsl$\...` |
| Paths with spaces | Breaks | Properly quoted |
| `/mnt/c/` passthrough | Maybe | Detects and converts |
| Browser selection | No | Wizard + config file |
| PowerShell 5 vs 7 | Hardcoded | Auto-detected |
| Scoop/AppData browsers | No | Auto-discovered |
| `git` / `gh` / `npm` links | Depends | Drop-in `xdg-open` shim |
| Reconfigure later | Edit `.bashrc` | `xdg-open --config` |
| Non-WSL fallback | Breaks on Linux | Falls back to real `xdg-open` |

## Install

```bash
# Install e-bash via Homebrew (works on WSL too)
brew tap artfulbits-se/tap
brew install e-bash
e-bash versions

# Run the WSL xdg-open wizard
~/.e-bash/bin/wsl/xdg-open.sh --config

# Or just open something — wizard runs automatically on first use
~/.e-bash/bin/wsl/xdg-open.sh https://github.com
```

The wizard creates a shim at `~/.local/bin/xdg-open` that intercepts all `xdg-open` calls system-wide. No `.bashrc` hacks needed.

## Manage

```bash
xdg-open --status      # show current configuration
xdg-open --config      # re-run wizard
xdg-open --uninstall   # remove shim and config
```

## Part of e-bash

This is one tool from [e-bash](https://github.com/OleksandrKucherenko/e-bash) — a Bash framework with 13 modules for logging, argument parsing, dependency management, shell completion, and more.

```bash
brew install artfulbits-se/tap/e-bash
```

---

*MIT Licensed. Works on WSL1 and WSL2.*
