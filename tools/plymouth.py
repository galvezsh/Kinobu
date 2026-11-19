#!/usr/bin/env python3
"""Draws the frames of Kinobu's boot splash (Plymouth): a small logo of tools/logo.py turning under
the maker's logo, as Windows does with its dots. Every ring turns (the outer one to the left, the
inner ones each its own way and speed, so their notches meet and part) and the golden centre
breathes; every ring turns a whole number of times per loop, so the loop has no seam. Also
bgrt-fallback.png, the still logo shown instead of the maker's when the firmware has none (a
virtual machine, some desktops). files/apps/kinobu-boot-splash installs them.

    python3 tools/plymouth.py                     # files/branding/plymouth/throbber-0001.png …
    python3 tools/plymouth.py --preview out.gif   # only an animated preview, to look at it
"""
import argparse
import importlib.util
import math
import pathlib
import sys

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, GLib  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("logo", ROOT / "tools" / "logo.py")
logo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(logo)

FRAMES = 90             # one loop: 3 s at 30 frames a second
SIZE = 96               # pixels: the turning logo (Ubuntu's spinner is 64: too small to see the rings)
FALLBACK = 192          # pixels: the still logo when the firmware has none (twice the turning one)
SCREEN = (1920, 1080)   # the preview's screen; the turning logo sits at 70 % of its height, as Ubuntu's
ALIGN = 0.7
TURNS = (-1, 1, -1, 2)  # whole turns per loop of each ring, outer first (negative: to the left)
BREATH = 0.06           # how much the centre grows at the top of its breath


def frame_svg(i):
    """One frame as SVG, with the logo's own rings, notches and colours."""
    rings, centre = logo.FULL
    colours = logo.DARK
    phase = i / FRAMES
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800">']
    for n, (r, width, angle, notch) in enumerate(rings):
        length = 2 * math.pi * r
        turn = angle + math.degrees(notch / r) / 2 + 360 * TURNS[n] * phase
        out.append(f'<circle cx="400" cy="400" r="{r}" fill="none" stroke="{colours[0 if n == 0 else 1]}" '
                   f'stroke-width="{width}" stroke-dasharray="{length - notch:.2f} {notch:.2f}" '
                   f'transform="rotate({turn:.3f} 400 400)"/>')
    grow = 1 + BREATH * (1 - math.cos(2 * math.pi * phase)) / 2
    out.append(f'<circle cx="400" cy="400" r="{centre * grow:.2f}" fill="{colours[2]}"/>')
    return "\n".join(out) + "</svg>"


def render(i, size):
    """A frame as a GdkPixbuf (transparent around the logo, as Plymouth draws it on black)."""
    loader = GdkPixbuf.PixbufLoader.new_with_type("svg")
    loader.set_size(size, size)
    loader.write(frame_svg(i).encode())
    loader.close()
    return loader.get_pixbuf()


def image(pix):
    from PIL import Image
    return Image.frombytes("RGBA", (pix.get_width(), pix.get_height()), pix.get_pixels(), "raw", "RGBA",
                           pix.get_rowstride())


def preview(path, size=SIZE):
    """An animated GIF of the whole screen at half size, as Plymouth lays it out: this computer's
    own maker logo when the firmware lets it be read (/sys/firmware/acpi/bgrt), else the fallback."""
    from PIL import Image
    w, h = SCREEN
    screen = Image.new("RGB", SCREEN, "black")
    bgrt = pathlib.Path("/sys/firmware/acpi/bgrt")
    try:
        maker = Image.open(bgrt / "image").convert("RGB")
        x, y = (int((bgrt / f"{c}offset").read_text()) for c in "xy")
        screen.paste(maker, (x, y))
    except (OSError, ValueError):
        still = image(render(0, FALLBACK))
        screen.paste(still, ((w - FALLBACK) // 2, (h - FALLBACK) // 2), still)
    frames = []
    for i in range(FRAMES):
        frame, turning = screen.copy(), image(render(i, size))
        frame.paste(turning, ((w - size) // 2, int((h - size) * ALIGN)), turning)
        frames.append(frame.resize((w // 2, h // 2), Image.LANCZOS).convert("P", palette=Image.Palette.ADAPTIVE, colors=128))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=1000 // 30, loop=0, optimize=True)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--preview", metavar="GIF", help="write only an animated preview")
    p.add_argument("--size", type=int, default=SIZE, help=f"the turning logo's size in the preview ({SIZE})")
    args = p.parse_args()
    if args.preview:
        preview(args.preview, args.size)
        return 0
    out = ROOT / "files" / "branding" / "plymouth"
    out.mkdir(parents=True, exist_ok=True)
    for old in [*out.glob("throbber-*.png"), *out.glob("animation-*.png")]:
        old.unlink()
    try:
        for i in range(FRAMES):
            render(i, SIZE).savev(str(out / f"throbber-{i + 1:04d}.png"), "png", [], [])
        # two-step looks for an end animation (animation-…) and, without one, takes the throbber's
        # frames for it: one still frame keeps them the looping throbber (the theme never shows it)
        render(0, SIZE).savev(str(out / "animation-0001.png"), "png", [], [])
        render(0, FALLBACK).savev(str(out / "bgrt-fallback.png"), "png", [], [])
    except GLib.Error as e:
        print(f"frames: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
