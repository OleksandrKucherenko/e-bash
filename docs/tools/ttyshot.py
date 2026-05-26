#!/usr/bin/env python3
"""Run a command in a pseudo-terminal, emulate the screen with pyte, render PNG.

Stack: PTY (stdlib) -> pyte (VT/xterm screen emulation) -> Pillow (raster).
"""
import argparse, os, pty, select, signal, struct, sys, termios, fcntl, time
import pyte
from PIL import Image, ImageDraw, ImageFont

# Tango-ish palette: (normal, bright) per ANSI color name pyte uses.
NORMAL = {
    "black": (46, 52, 54), "red": (204, 0, 0), "green": (78, 154, 6),
    "brown": (196, 160, 0), "blue": (52, 101, 164), "magenta": (117, 80, 123),
    "cyan": (6, 152, 154), "white": (211, 215, 207),
}
BRIGHT = {
    "black": (85, 87, 83), "red": (239, 41, 41), "green": (138, 226, 52),
    "brown": (252, 233, 79), "blue": (114, 159, 207), "magenta": (173, 127, 168),
    "cyan": (52, 226, 226), "white": (238, 238, 236),
}
DEFAULT_FG = (213, 216, 210)
DEFAULT_BG = (24, 24, 28)


def to_rgb(color, default, bright=False):
    if color == "default":
        return default
    if color in NORMAL:
        return (BRIGHT if bright else NORMAL)[color]
    try:  # pyte gives a 6-digit hex string for 256/true colors
        return (int(color[0:2], 16), int(color[2:4], 16), int(color[4:6], 16))
    except (ValueError, IndexError):
        return default


def run_in_pty(cmd, cols, rows, duration, sends):
    """Spawn cmd in a cols x rows PTY; feed output to a pyte screen for `duration`s."""
    screen = pyte.Screen(cols, rows)
    screen.set_mode(pyte.modes.LNM)
    stream = pyte.ByteStream(screen)

    pid, master = pty.fork()
    if pid == 0:  # child
        os.environ["TERM"] = "xterm-256color"
        os.environ["COLUMNS"], os.environ["LINES"] = str(cols), str(rows)
        os.execvp(cmd[0], cmd)
        os._exit(127)

    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    schedule = list(sends)
    start = time.time()
    while time.time() - start < duration:
        elapsed = time.time() - start
        for i, (off, data) in enumerate(schedule):
            if off is not None and elapsed >= off:
                try:
                    os.write(master, data)
                except OSError:
                    pass
                schedule[i] = (None, data)
        r, _, _ = select.select([master], [], [], 0.05)
        if r:
            try:
                chunk = os.read(master, 65536)
            except OSError:
                break
            if not chunk:
                break
            stream.feed(chunk)

    try:  # ask the app to quit, then reap
        os.write(master, b"\x1b")
        os.write(master, b"\x03")
    except OSError:
        pass
    try:
        os.kill(pid, signal.SIGTERM)
        os.waitpid(pid, os.WNOHANG)
    except OSError:
        pass
    os.close(master)
    return screen


def render(screen, cols, rows, out, title, font_size=20):
    font_dir = "/usr/share/fonts/truetype/dejavu"
    font = ImageFont.truetype(f"{font_dir}/DejaVuSansMono.ttf", font_size)
    try:
        bold = ImageFont.truetype(f"{font_dir}/DejaVuSansMono-Bold.ttf", font_size)
    except OSError:
        bold = font

    cw = int(round(font.getlength("M")))
    asc, desc = font.getmetrics()
    ch = asc + desc + 4
    pad = 16
    bar = 34  # title bar height
    W = cols * cw + 2 * pad
    H = rows * ch + 2 * pad + bar

    img = Image.new("RGB", (W, H), DEFAULT_BG)
    d = ImageDraw.Draw(img)

    # title bar with traffic-light dots
    d.rectangle([0, 0, W, bar], fill=(43, 43, 49))
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        cx = 18 + i * 20
        d.ellipse([cx, bar // 2 - 6, cx + 12, bar // 2 + 6], fill=c)
    if title:
        tw = d.textlength(title, font=font)
        d.text(((W - tw) / 2, (bar - font_size) / 2 - 1), title, font=font, fill=(170, 170, 178))

    oy = bar + pad
    for y in range(rows):
        row = screen.buffer.get(y, {})
        for x in range(cols):
            cell = row.get(x)
            if cell is None:
                continue
            data = cell.data or " "
            reverse = cell.reverse
            fg = to_rgb(cell.fg, DEFAULT_FG, bright=cell.bold)
            bg = to_rgb(cell.bg, DEFAULT_BG)
            if reverse:
                fg, bg = bg, fg
            px, py = pad + x * cw, oy + y * ch
            if bg != DEFAULT_BG:
                d.rectangle([px, py, px + cw, py + ch], fill=bg)
            if data != " ":
                d.text((px, py + 2), data, font=(bold if cell.bold else font), fill=fg)

    # cursor block
    cur = screen.cursor
    if cur and not cur.hidden and cur.y < rows:
        px, py = pad + cur.x * cw, oy + cur.y * ch
        d.rectangle([px, py, px + cw, py + ch], outline=(220, 220, 120), width=1)

    img.save(out)
    print(f"wrote {out} ({W}x{H})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=110)
    ap.add_argument("--rows", type=int, default=30)
    ap.add_argument("--duration", type=float, default=2.0)
    ap.add_argument("--out", required=True)
    ap.add_argument("--title", default="")
    ap.add_argument("--send", action="append", default=[], help="offset:text")
    ap.add_argument("cmd", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.cmd[1:] if a.cmd and a.cmd[0] == "--" else a.cmd
    sends = []
    for s in a.send:
        off, _, text = s.partition(":")
        sends.append((float(off), text.encode()))
    screen = run_in_pty(cmd, a.cols, a.rows, a.duration, sends)
    render(screen, a.cols, a.rows, a.out, a.title)


if __name__ == "__main__":
    main()
