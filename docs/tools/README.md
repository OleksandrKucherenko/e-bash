# Reproduce the TUI recordings

`record-tui.py` runs the existing demos in a Linux pseudo-terminal. It sends
sample text and navigation keys, captures actual ANSI output, and renders that
output with pyte and Pillow. It checks successful exit and expected saved text
or diagnostic tokens before publishing the assets. Images are terminal renders,
not screenshots of an invented UI.

From the repository root, using Python 3 with venv support:

```bash
python3 -m venv /tmp/e-bash-media-venv
/tmp/e-bash-media-venv/bin/pip install 'pyte==0.8.2' 'Pillow==12.3.0'
/tmp/e-bash-media-venv/bin/python docs/tools/record-tui.py
```

Requirements: Linux PTYs, Bash 5, `tput`, `stty`, GNU command aliases used by the
demos, and DejaVu Sans Mono at
`/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf`. Run with a writable checkout;
the demos create ignored GNU aliases if needed. The helper sets a 96 × 30
terminal and responds to stream-mode cursor-position queries.

The command refreshes these committed assets under `docs/images/public/`:

- `ui.multi-line-box.{gif,png,cast}`
- `ui.multi-line-stream.{gif,png,cast}`
- `ui.capture-key.{gif,png,cast}`

The PNG shows the last interactive frame before saving/exiting. The GIF includes
entry, editing and exit. The `.cast` is asciinema version 2 output and can be
replayed with `asciinema play docs/images/public/ui.multi-line-box.cast` if
asciinema is installed. Raw recording event timestamps preserve actual timing;
GIF timing is approximate because rendering samples terminal state.

Use sample data only. Do not record real passwords, tokens, personal paths or
production logs. The existing password demo prints the value after entry and
is deliberately excluded from this capture helper.
