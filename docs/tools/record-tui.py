#!/usr/bin/env python3
"""Capture real e-bash demos in a PTY; render their output with pyte and Pillow.

Run from the repo: python3 docs/tools/record-tui.py
Requires: Python 3, pyte, Pillow, DejaVu Sans Mono, Bash 5 and Linux PTYs.
"""
import codecs
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import signal
import struct
import time
import termios

import pyte
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/images/public"
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 15)
COLS, ROWS = 96, 30
COLORS = {"default": "#d8dee9", "black": "#242933", "red": "#bf616a",
          "green": "#a3be8c", "brown": "#ebcb8b", "blue": "#81a1c1",
          "magenta": "#b48ead", "cyan": "#88c0d0", "white": "#eceff4"}


def color(value, default):
    if value == "default":
        return default
    return COLORS.get(value, "#" + value if len(value) == 6 else default)


def render(screen):
    image = Image.new("RGB", (COLS * 9 + 24, ROWS * 18 + 24), "#242933")
    draw = ImageDraw.Draw(image)
    for row in range(ROWS):
        for col in range(COLS):
            char = screen.buffer[row][col]
            fg, bg = color(char.fg, "#d8dee9"), color(char.bg, "#242933")
            if char.reverse:
                fg, bg = bg, fg
            x, y = 12 + col * 9, 12 + row * 18
            draw.rectangle((x, y, x + 8, y + 17), fill=bg)
            draw.text((x, y), char.data, font=FONT, fill=fg)
    if not screen.cursor.hidden:
        x, y = 12 + screen.cursor.x * 9, 12 + screen.cursor.y * 18
        draw.rectangle((x, y + 16, x + 8, y + 17), fill="#d8dee9")
    return image


def capture(name, command, actions, expected):
    screen = pyte.Screen(COLS, ROWS)
    stream = pyte.Stream(screen)
    decoder = codecs.getincrementaldecoder("utf-8")("replace")
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(ROOT)
        os.environ.update(TERM="xterm-256color", E_BASH=str(ROOT / ".scripts"),
                          XDG_CACHE_HOME="/tmp/e-bash-media-cache")
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        os.execvp("bash", ["bash", *command])
    frames, events, transcript = [], [], []
    started = time.monotonic()
    status = None

    def drain(duration):
        until = time.monotonic() + duration
        while time.monotonic() < until:
            if select.select([fd], [], [], min(0.04, max(0, until - time.monotonic())))[0]:
                try:
                    data = os.read(fd, 65536)
                except OSError:
                    break
                if not data:
                    break
                text = decoder.decode(data)
                transcript.append(text)
                events.append([round(time.monotonic() - started, 4), "o", text])
                stream.feed(text)
                if "\x1b[6n" in text:
                    os.write(fd, f"\x1b[{screen.cursor.y + 1};{screen.cursor.x + 1}R".encode())
            frames.append(render(screen))

    try:
        drain(0.8)
        ready = "------------------------" if "capture-key" in name else "\x1b[?2004h"
        deadline = time.monotonic() + 10
        while ready not in "".join(transcript) and time.monotonic() < deadline:
            drain(0.1)
        if ready not in "".join(transcript):
            raise RuntimeError(f"{name}: interactive demo did not become ready")
        drain(0.1)
        for keys, delay in actions:
            if keys == b"\x04":
                preview = render(screen)
            os.write(fd, keys)
            drain(delay)
        drain(0.5)
        for _ in range(20):
            done, status = os.waitpid(pid, os.WNOHANG)
            if done:
                break
            status = None
            drain(0.1)
        if status is None:
            Path(f"/tmp/{name}-capture-error.txt").write_text("".join(transcript))
            raise RuntimeError(f"{name}: demo did not exit after Ctrl+D")
        if os.waitstatus_to_exitcode(status) != 0:
            raise RuntimeError(f"{name}: demo exited with {status}")
        raw = "".join(transcript)
        for marker in expected:
            if marker not in raw:
                raise RuntimeError(f"{name}: expected output missing: {marker}")
        # Last interactive frame, before Ctrl+D, is the still-image preview.
        preview.save(OUT / f"{name}.png")
        frames[0].save(OUT / f"{name}.gif", save_all=True, append_images=frames[1:],
                       duration=40, loop=0, optimize=True)
        header = {"version": 2, "width": COLS, "height": ROWS,
                  "title": name, "env": {"TERM": "xterm-256color"}}
        (OUT / f"{name}.cast").write_text("\n".join(json.dumps(e) for e in [header, *events]) + "\n")
        print(f"{name}: real PTY output captured; expected output verified")
    finally:
        if status is None:
            os.kill(pid, signal.SIGTERM)
            os.waitpid(pid, 0)
        os.close(fd)


# Fake sample text only: recordings must never contain passwords or credentials.
if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    editing = [(b"Draft release notes", 0.6), (b"\r", 0.2),
               (b"Add terminal screenshots", 0.6), (b"\r", 0.2),
               (b"Ship docs", 0.6), (b"\x1b[A", 0.3), (b"\x1b[F", 0.3),
               (b" and recordings", 0.8), (b"\x04", 0.3)]
    for mode in ("box", "stream"):
        capture(f"ui.multi-line-{mode}", ["demos/demo.multi-line.sh", mode], editing,
                ["Captured text:", "Add terminal screenshots and recordings", "Ship docs"])
    capture("ui.capture-key", ["demos/demo.capture-key.sh"],
            [(b"\x1b[A", 0.5), (b"\x1b[1;5A", 0.5), (b"\x1b[15;2~", 0.5),
             (b"\x1ba", 0.5), (b"\x17", 0.5), (b"\x04", 0.3)],
            ["ctrl-up", "shift-f5", "alt-a", "ctrl-w"])
