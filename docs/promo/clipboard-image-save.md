# You Took a Screenshot in Windows. Now Get It into WSL.

You're working in WSL. You hit `Win+Shift+S` to capture a screenshot. It's in the Windows clipboard.

Now what?

You can't `Ctrl+V` into a terminal. There's no `pbpaste` for images. The clipboard lives in Windows, your code lives in Linux, and nothing bridges them.

Most people end up: open Paint → paste → save as PNG → navigate to `/mnt/c/Users/.../Downloads/` → copy to project folder. Every. Single. Time.

## What You Actually Want

```bash
$ clipboard-image-save.sh
```

```
⟳ Reading clipboard...

┌─ Clipboard History ─────────────────────────────────────
│
│  🖼️   [ 0]  Image  2026-04-14 12:34:56
│      1920x1080px
│
│  📁   [ 1]  File  2026-04-14 12:30:01
│      screenshot-api-response.png
│
│  📝   [ 2]  Text  2026-04-14 12:28:45
│      curl -X POST https://api.example.com/... (128 chars)
│
│
└──────────────────────────────────────────────────────────

Select item to save [0-9] (auto-select 0 in 15s): 0

⟳ Saving image...
✓ Saved: /home/user/Desktop/clipboard_20260414-123456.png

▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
▌ (ASCII preview of image) ▐
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀

For LLM (copy this line):
Please analyze the image at: /home/user/Desktop/clipboard_20260414-123456.png
```

One command. Screenshot goes from Windows clipboard to a Linux file path. With a preview right in the terminal.

## What It Does

1. **Reads the Windows clipboard** via PowerShell (auto-detects pwsh 7 or PowerShell 5)
2. **Shows clipboard history** — images, files, and text entries with timestamps
3. **Previews images inline** using your terminal's graphics protocol
4. **Saves to disk** with timestamped filenames
5. **Outputs an LLM-ready path** so you can paste it straight into Claude, ChatGPT, or Copilot

## Smart Terminal Graphics

The preview automatically adapts to your terminal:

| Terminal | Protocol | Quality |
|----------|----------|---------|
| Kitty | Kitty graphics | Full color, pixel-perfect |
| WezTerm | iTerm2 inline images | Full color |
| Tabby (SSH) | Sixels | Good quality |
| iTerm2 | iTerm2 protocol | Full color |
| Everything else | Unicode sextant symbols | ASCII art fallback |
| tmux / screen | Passthrough wrapping | Works inside multiplexers |

No configuration. It detects the protocol and picks the best one.

## Usage Patterns

```bash
# Interactive: browse clipboard history, pick an item
clipboard-image-save.sh

# Quick: save current clipboard image, no menu
clipboard-image-save.sh -n

# List what's in the clipboard without saving
clipboard-image-save.sh -l

# Save specific item by index
clipboard-image-save.sh -i 1

# Custom output location
clipboard-image-save.sh -d ./screenshots -p bug-report

# Specific filename
clipboard-image-save.sh -o ./docs/images/architecture.png

# No preview (faster, for scripts)
clipboard-image-save.sh --no-preview -n
```

## The AI Developer Workflow

This was built for developers who work with AI assistants:

```
Win+Shift+S            → capture error/UI/diagram
clipboard-image-save   → save to ~/Desktop/clipboard_*.png
paste path into Claude  → "analyze this screenshot"
```

The script outputs `For LLM (copy this line):` specifically for this — paste the line, the AI reads the image.

Works with:
- Claude Code (reads local files)
- ChatGPT (upload the saved file)
- GitHub Copilot
- Any tool that accepts image file paths

## Requirements

- WSL (1 or 2) with PowerShell accessible
- Windows 10/11
- Optional: `chafa` for image previews (`sudo apt install chafa`)
- Optional: Enable Windows clipboard history (`Win+V` → Turn on)

## Install

```bash
# Homebrew (works in WSL too)
brew tap artfulbits-se/tap
brew install e-bash
e-bash versions

# Run it
~/.e-bash/bin/clipboard-image-save.sh

# Or add to PATH for shorter access
echo 'alias clip-save="$HOME/.e-bash/bin/clipboard-image-save.sh"' >> ~/.bashrc
```

## Environment Variables

```bash
OUTPUT_DIR="$HOME/screenshots"   # Where to save (default: ~/Desktop)
OUTPUT_PREFIX="screenshot"       # Filename prefix (default: clipboard)
SELECT_TIMEOUT=5                 # Auto-select seconds (default: 15, 0=off)
PREVIEW_ENABLED=false            # Disable preview (default: true)
```

## Part of e-bash

This is one tool from [e-bash](https://github.com/OleksandrKucherenko/e-bash) — a Bash framework for professional shell scripting. 13 modules, 24 tools, 200+ tests.

```bash
brew install artfulbits-se/tap/e-bash
```

---

*MIT Licensed. Requires WSL + Windows 10/11.*
