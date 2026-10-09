# Terminal input: editor, selector, password and key diagnostics

Use `_tui.sh` when a script needs interactive terminal input. It provides a
multi-line editor, a menu selector, masked password input and key diagnostics.
`_commons.sh` also loads these functions, so existing callers can keep using it.

Run the examples below from the repository root in a real terminal, with Bash 5
and `tput`/`stty` available. The editor reads keyboard input from stdin and draws
on stderr; command substitution captures the resulting text on stdout. Do not
pipe text into it or redirect its terminal output to a file.

```bash
export E_BASH="$PWD/.scripts"
source "$E_BASH/_tui.sh"
```

## Try the multi-line editor

The box demo opens a positioned editor. Type a few lines, use the arrows to edit
an earlier line, then press Ctrl+D. The demo prints the saved text afterward.
Press Esc instead to cancel.

```bash
bash demos/demo.multi-line.sh box
```

![Actual box-mode demo: entering three lines, editing the second, and saving](../images/public/ui.multi-line-box.gif)

[Still image](../images/public/ui.multi-line-box.png) ·
[Replayable terminal recording](../images/public/ui.multi-line-box.cast)

The stream demo opens a five-line editor below the current terminal output:

```bash
bash demos/demo.multi-line.sh stream
```

![Actual stream-mode demo: editing inline, then printing the saved text](../images/public/ui.multi-line-stream.gif)

[Still image](../images/public/ui.multi-line-stream.png) ·
[Replayable terminal recording](../images/public/ui.multi-line-stream.cast)

These are recordings of the existing demos running in a 96 × 30 Linux terminal.
They use sample release notes, not a simulated interface. Terminal fonts, colors
and available clipboard integration may differ on your machine.

## Choose a mode

| Mode | Use it for | Example |
| --- | --- | --- |
| Box | A positioned editor inside your terminal UI | `input:multi-line -x 5 -y 2 -w 60 -h 10` |
| Box, alternate buffer | Editing without replacing the current terminal screen | `input:multi-line --alt-buffer` |
| Stream | A short inline prompt after existing output | `input:multi-line -m stream -h 5` |

Box dimensions are clamped to the available terminal space. Stream mode uses
the terminal width and makes room near the bottom of the screen; it ignores
`--alt-buffer`. Height includes the status bar, so allow room for both text and
controls. The status bar shows cursor position and `[+]` when text was modified.

Handle cancellation explicitly in your script:

```bash
if text=$(input:multi-line -w 60 -h 10); then
  printf 'Saved text:\n%s\n' "$text"
else
  printf 'Input cancelled.\n' >&2
fi
```

Save returns status 0; cancel returns 1. Command substitution removes trailing
newlines, as it does for other Bash commands.

## Keyboard controls

| Key | Action |
| --- | --- |
| Arrows, Home/End, Page Up/Down | Move through the text |
| Enter / Tab | Insert a newline / two spaces |
| Backspace / Delete | Delete before / at the cursor; join lines at a boundary |
| Ctrl+D | Save and close |
| Esc | Clear an active selection; otherwise cancel the editor |
| Ctrl+W / Ctrl+U | Delete the previous word / clear the current line |
| Ctrl+E | Edit the current line with Bash readline; Enter returns to the editor |
| Shift+Arrows, Shift+Home/End | Extend a selection |
| Ctrl+A | Select all |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / cut / paste using the system clipboard |
| F3 | Enter selection mode: arrows select, `c` copies, `x` cuts, Esc exits selection mode |

Ctrl+C is a copy action in the editor, not its normal exit key. Use Esc to cancel.
Clipboard actions need `xclip` or `xsel` with a working Linux display, or
`pbcopy`/`pbpaste` on macOS. Installing a clipboard executable alone does not
provide a display or clipboard in an SSH/headless session. Terminal paste also
works through bracketed paste when your terminal supports it; use the terminal's
paste shortcut rather than assuming Ctrl+V is mapped to terminal paste.

## Discover and customize keys

```bash
bash demos/demo.capture-key.sh
```

Press a key combination to see its semantic token. Ctrl+D exits the diagnostic.
This is useful when a terminal intercepts
a shortcut or sends a different sequence than expected.

![Actual key diagnostic showing arrows, modified keys, Alt+A and Ctrl+W](../images/public/ui.capture-key.gif)

[Still image](../images/public/ui.capture-key.png) ·
[Replayable terminal recording](../images/public/ui.capture-key.cast)

In the recorded version, the advertised **Hex** and **Bash literal** columns
remain empty. `_input:capture-key` reads the key through command substitution,
so the raw-byte metadata set by `_input:read-key --raw` stays in that subshell.
The semantic token is returned correctly. Use that token for editor bindings;
the raw-byte display needs a separate implementation fix.

The configurable editor actions take **semantic token names**, not hex bytes:

| Variable | Default |
| --- | --- |
| `ML_KEY_SAVE` | `ctrl-d` |
| `ML_KEY_EDIT` | `ctrl-e` |
| `ML_KEY_DEL_WORD` | `ctrl-w` |
| `ML_KEY_DEL_LINE` | `ctrl-u` |
| `ML_KEY_SELECT` | `f3` |

Set the variable for the call inside command substitution:

```bash
if text=$(ML_KEY_SAVE=ctrl-s input:multi-line -w 60 -h 10); then
  printf '%s\n' "$text"
fi
```

If a shortcut never appears in the diagnostic, check terminal or multiplexer
bindings first. After an interrupted terminal session, run `stty sane` if input
is left without echo.

## Selector and masked password input

These already have visual demonstrations:

| Feature | Run from the repository root | Preview |
| --- | --- | --- |
| Menu selector | `bash demos/demo.selector.sh` | [Selector GIF](../images/public/ui.selector.gif) |
| Masked password | `bash demos/demo.readpswd.sh` | [Password GIF](../images/public/ui.ask-for-password.gif) |

The password demo prints the captured value after entry to demonstrate the
return value. Use a dummy value when trying or recording it; production callers
should consume the value without printing it.

See the [TUI API reference](lib/_tui.md) for signatures and the
[demo catalog](demos.md) for the other library and tool examples.
